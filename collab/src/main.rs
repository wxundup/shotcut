//! EdiTogether collaboration relay.
//!
//! Fully local, self-hosted: one process per editing session. The host client
//! is the authority; the relay only validates bounds, tracks membership, and
//! forwards messages. No cloud, no persistence.

use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Arc;

use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{mpsc, Mutex};
use tokio_tungstenite::tungstenite::Message;

const MAX_MSG_BYTES: usize = 1 << 20; // 1 MiB frame cap
const MAX_OP_BYTES: usize = 64 * 1024;
const MAX_NAME_LEN: usize = 64;
const RATE_PER_SEC: usize = 200;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "t", rename_all = "kebab-case")]
pub enum Wire {
    Hello {
        name: String,
        role: String, // "host" | "guest"
        #[serde(default)]
        invite: Option<String>,
    },
    Welcome {
        peer_id: u64,
        room_code: String,
        host_id: u64,
        peers: Vec<PeerInfo>,
    },
    PeerJoined {
        peer: PeerInfo,
    },
    PeerLeft {
        peer_id: u64,
    },
    Op {
        from: u64,
        rev: u64,
        op: serde_json::Value,
    },
    SnapshotReq {
        from: u64,
    },
    Snapshot {
        from: u64,
        mlt_xml: String,
    },
    Presence {
        from: u64,
        #[serde(default)]
        playhead: Option<f64>,
        #[serde(default)]
        selection: Option<String>,
    },
    RoomClosed {
        reason: String,
    },
    Error {
        reason: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PeerInfo {
    pub id: u64,
    pub name: String,
    pub role: String,
}

struct Peer {
    info: PeerInfo,
    tx: mpsc::UnboundedSender<String>,
}

struct Room {
    code: String,
    host_id: u64,
    peers: HashMap<u64, Peer>,
}

impl Room {
    fn broadcast(&self, msg: &Wire, except: Option<u64>) {
        let s = serde_json::to_string(msg).unwrap_or_default();
        for (id, p) in &self.peers {
            if Some(*id) != except {
                let _ = p.tx.send(s.clone());
            }
        }
    }
}

struct Server {
    rooms: Mutex<HashMap<String, Room>>,
    next_id: Mutex<u64>,
}

impl Server {
    fn new() -> Self {
        Server {
            rooms: Mutex::new(HashMap::new()),
            next_id: Mutex::new(1),
        }
    }

    async fn alloc_id(&self) -> u64 {
        let mut n = self.next_id.lock().await;
        *n += 1;
        *n
    }
}

fn new_invite_code() -> String {
    use rand::Rng;
    const ALPHABET: &[u8] = b"ABCDEFGHJKMNPQRSTUVWXYZ23456789"; // no 0/O/1/I/L
    let mut rng = rand::rng();
    (0..6)
        .map(|_| ALPHABET[rng.random_range(0..ALPHABET.len())] as char)
        .collect()
}

fn valid_invite(code: &str) -> bool {
    code.len() == 6
        && code
            .chars()
            .all(|c| c.is_ascii_uppercase() || c.is_ascii_digit())
}

fn validate(w: &Wire) -> Result<(), String> {
    match w {
        Wire::Hello { name, role, invite } => {
            if name.len() > MAX_NAME_LEN || name.trim().is_empty() {
                return Err("bad name".into());
            }
            if role != "host" && role != "guest" {
                return Err("bad role".into());
            }
            if let Some(c) = invite {
                if !valid_invite(c) {
                    return Err("bad invite".into());
                }
            }
            Ok(())
        }
        Wire::Op { op, .. } => {
            if serde_json::to_string(op).map(|s| s.len()).unwrap_or(usize::MAX) > MAX_OP_BYTES {
                return Err("op too large".into());
            }
            // closed op vocabulary: unknown kinds are dropped, not relayed
            match op.get("k").and_then(|k| k.as_str()) {
                Some(
                    "clip.add" | "clip.remove" | "clip.move" | "clip.trim" | "track.add"
                    | "track.remove" | "transition.add" | "transition.remove" | "filter.add"
                    | "filter.remove" | "meta.set",
                ) => Ok(()),
                _ => Err("unknown op kind".into()),
            }
        }
        Wire::Snapshot { mlt_xml, .. } => {
            if mlt_xml.len() > 8 * 1024 * 1024 {
                return Err("snapshot too large".into());
            }
            Ok(())
        }
        _ => Ok(()),
    }
}

async fn handle_conn(server: Arc<Server>, stream: TcpStream, _addr: SocketAddr) {
    let ws = match tokio_tungstenite::accept_async(stream).await {
        Ok(ws) => ws,
        Err(_) => return,
    };
    let (mut out, mut inc) = ws.split();
    let (tx, mut rx) = mpsc::unbounded_channel::<String>();

    // pump outbound
    let pump = tokio::spawn(async move {
        while let Some(text) = rx.recv().await {
            if out.send(Message::Text(text.into())).await.is_err() {
                break;
            }
        }
    });

    let mut peer_id: Option<u64> = None;
    let mut room_code: Option<String> = None;
    let mut budget = RATE_PER_SEC;
    let mut last_refill = tokio::time::Instant::now();

    while let Some(msg) = inc.next().await {
        let msg = match msg {
            Ok(Message::Text(t)) => t,
            Ok(Message::Close(_)) | Err(_) => break,
            _ => continue,
        };
        if msg.len() > MAX_MSG_BYTES {
            let _ = tx.send(serde_json::to_string(&Wire::Error {
                reason: "frame too large".into(),
            }).unwrap_or_default());
            continue;
        }
        if last_refill.elapsed().as_secs() >= 1 {
            budget = RATE_PER_SEC;
            last_refill = tokio::time::Instant::now();
        }
        if budget == 0 {
            continue; // silent drop: rate-limited
        }
        budget -= 1;

        let wire: Wire = match serde_json::from_str(&msg) {
            Ok(w) => w,
            Err(_) => continue,
        };
        if let Err(reason) = validate(&wire) {
            // suspicious input produces no relay, only a private error
            let _ = tx.send(serde_json::to_string(&Wire::Error { reason }).unwrap_or_default());
            continue;
        }

        match wire {
            Wire::Hello { name, role, invite } => {
                if peer_id.is_some() {
                    continue; // one hello per connection
                }
                let id = server.alloc_id().await;
                let mut rooms = server.rooms.lock().await;
                let (code, host_id) = if role == "host" {
                    let code = new_invite_code();
                    rooms.insert(
                        code.clone(),
                        Room { code: code.clone(), host_id: id, peers: HashMap::new() },
                    );
                    (code, id)
                } else {
                    match invite.and_then(|c| rooms.get(&c)) {
                        Some(r) => (r.code.clone(), r.host_id),
                        None => {
                            let _ = tx.send(serde_json::to_string(&Wire::Error {
                                reason: "no such session".into(),
                            }).unwrap_or_default());
                            continue;
                        }
                    }
                };
                let info = PeerInfo { id, name, role };
                let room = rooms.get_mut(&code).unwrap();
                room.peers.insert(id, Peer { info: info.clone(), tx: tx.clone() });
                let peers: Vec<PeerInfo> = room.peers.values().map(|p| p.info.clone()).collect();
                room.broadcast(&Wire::PeerJoined { peer: info.clone() }, Some(id));
                let _ = tx.send(
                    serde_json::to_string(&Wire::Welcome {
                        peer_id: id,
                        room_code: code.clone(),
                        host_id,
                        peers,
                    })
                    .unwrap_or_default(),
                );
                drop(rooms);
                peer_id = Some(id);
                room_code = Some(code);
            }
            w => {
                let (Some(id), Some(code)) = (peer_id, room_code.clone()) else {
                    continue;
                };
                let mut rooms = server.rooms.lock().await;
                if let Some(room) = rooms.get_mut(&code) {
                    // stamp sender so forged origins cannot lie
                    let stamped = match w {
                        Wire::Op { rev, op, .. } => Wire::Op { from: id, rev, op },
                        Wire::SnapshotReq { .. } => Wire::SnapshotReq { from: id },
                        Wire::Snapshot { mlt_xml, .. } => Wire::Snapshot { from: id, mlt_xml },
                        Wire::Presence { playhead, selection, .. } => {
                            Wire::Presence { from: id, playhead, selection }
                        }
                        other => other,
                    };
                    room.broadcast(&stamped, Some(id));
                }
            }
        }
    }

    pump.abort();

    // leave
    if let (Some(id), Some(code)) = (peer_id, room_code) {
        let mut rooms = server.rooms.lock().await;
        if let Some(room) = rooms.get_mut(&code) {
            room.peers.remove(&id);
            if room.host_id == id {
                room.broadcast(
                    &Wire::RoomClosed { reason: "host left".into() },
                    None,
                );
                rooms.remove(&code);
            } else {
                room.broadcast(&Wire::PeerLeft { peer_id: id }, None);
            }
        }
    }
}

#[tokio::main]
async fn main() {
    let bind: SocketAddr = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "127.0.0.1:7788".into())
        .parse()
        .expect("usage: editogether-collab [bind-addr]");
    let listener = TcpListener::bind(bind).await.expect("bind failed");
    eprintln!("editogether-collab listening on {bind}");
    if !bind.ip().is_loopback() {
        eprintln!(
            "warning: reachable beyond this machine. Traffic is unencrypted and \
             the invite code is the only credential — use on a trusted network only."
        );
    }
    let server = Arc::new(Server::new());
    loop {
        let (stream, addr) = match listener.accept().await {
            Ok(x) => x,
            Err(_) => continue,
        };
        let server = Arc::clone(&server);
        tokio::spawn(handle_conn(server, stream, addr));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use futures_util::{SinkExt, StreamExt};
    use tokio_tungstenite::connect_async;

    async fn next_wire<S>(s: &mut S) -> Wire
    where
        S: StreamExt<Item = Result<Message, tokio_tungstenite::tungstenite::Error>> + Unpin,
    {
        loop {
            if let Some(Ok(Message::Text(t))) = s.next().await {
                return serde_json::from_str(&t).unwrap();
            }
        }
    }

    #[tokio::test]
    async fn host_guest_relay() {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let server = Arc::new(Server::new());
        tokio::spawn({
            let server = Arc::clone(&server);
            async move {
                loop {
                    let (stream, a) = listener.accept().await.unwrap();
                    let server = Arc::clone(&server);
                    tokio::spawn(handle_conn(server, stream, a));
                }
            }
        });

        // host joins
        let (hws, _) = connect_async(format!("ws://{addr}")).await.unwrap();
        let (mut hout, mut hin) = hws.split();
        hout.send(Message::Text(
            serde_json::to_string(&Wire::Hello {
                name: "Host".into(),
                role: "host".into(),
                invite: None,
            })
            .unwrap()
            .into(),
        ))
        .await
        .unwrap();
        let code = match next_wire(&mut hin).await {
            Wire::Welcome { room_code, .. } => room_code,
            other => panic!("expected welcome, got {other:?}"),
        };
        assert_eq!(code.len(), 6);

        // guest joins with the invite
        let (gws, _) = connect_async(format!("ws://{addr}")).await.unwrap();
        let (mut gout, mut gin) = gws.split();
        gout.send(Message::Text(
            serde_json::to_string(&Wire::Hello {
                name: "Guest".into(),
                role: "guest".into(),
                invite: Some(code),
            })
            .unwrap()
            .into(),
        ))
        .await
        .unwrap();
        match next_wire(&mut gin).await {
            // roster includes self
            Wire::Welcome { peers, .. } => assert_eq!(peers.len(), 2),
            other => panic!("expected welcome, got {other:?}"),
        }
        // host sees the join
        match next_wire(&mut hin).await {
            Wire::PeerJoined { peer } => assert_eq!(peer.name, "Guest"),
            other => panic!("expected peer-joined, got {other:?}"),
        }

        // guest op relays to host, stamped with guest id
        gout.send(Message::Text(
            serde_json::to_string(&Wire::Op {
                from: 0,
                rev: 1,
                op: serde_json::json!({"k":"clip.add","track":1,"in":0,"out":1500}),
            })
            .unwrap()
            .into(),
        ))
        .await
        .unwrap();
        match next_wire(&mut hin).await {
            Wire::Op { from, op, .. } => {
                assert!(from > 0);
                assert_eq!(op["k"], "clip.add");
            }
            other => panic!("expected op, got {other:?}"),
        }

        // unknown op kind is dropped silently
        gout.send(Message::Text(
            serde_json::to_string(&Wire::Op {
                from: 0,
                rev: 2,
                op: serde_json::json!({"k":"shell.exec","cmd":"rm"}),
            })
            .unwrap()
            .into(),
        ))
        .await
        .unwrap();
        match tokio::time::timeout(std::time::Duration::from_millis(500), hin.next()).await {
            Err(_) => {} // silence = dropped, correct
            Ok(Some(Ok(Message::Text(t)))) => panic!("forbidden op leaked: {t}"),
            Ok(_) => {}  // connection close is acceptable
        }
    }
}
