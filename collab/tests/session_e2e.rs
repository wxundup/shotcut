//! End-to-end: two peers editing the same sequence through a running relay.
//!
//! Speaks the exact wire format the editor's CollabClient sends, against the
//! real relay binary, and asserts that an edit made by one peer reaches the
//! other and that the document they end up with matches.

use std::process::{Child, Command, Stdio};
use std::time::Duration;

use futures_util::{SinkExt, StreamExt};
use tokio_tungstenite::{connect_async, tungstenite::Message};

struct Relay(Child);

impl Drop for Relay {
    fn drop(&mut self) {
        let _ = self.0.kill();
    }
}

type Socket = tokio_tungstenite::WebSocketStream<
    tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>,
>;

async fn recv(s: &mut futures_util::stream::SplitStream<Socket>) -> serde_json::Value {
    let frame = tokio::time::timeout(Duration::from_secs(5), s.next())
        .await
        .expect("timed out waiting for the relay")
        .expect("stream closed")
        .expect("websocket error");
    match frame {
        Message::Text(t) => serde_json::from_str(&t).expect("relay sent invalid JSON"),
        other => panic!("expected text, got {other:?}"),
    }
}

/// The project both peers are editing, in the shape the shell uses.
fn sequence() -> serde_json::Value {
    serde_json::json!({
        "duration": 96.0,
        "tracks": [
            { "name": "V1", "audio": false, "clips": [
                { "label": "A003_Take2", "media": "A003_Take2", "start": 0.0, "width": 0.22 },
                { "label": "A007_Take1", "media": "A007_Take1", "start": 0.24, "width": 0.30 }
            ]}
        ]
    })
}

#[tokio::test]
async fn two_peers_edit_the_same_sequence() {
    let addr = "127.0.0.1:7801";
    let _relay = Relay(
        Command::new(env!("CARGO_BIN_EXE_editogether-collab"))
            .arg(addr)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .expect("failed to start the relay"),
    );

    let url = format!("ws://{addr}");
    let mut host_ws = None;
    for _ in 0..50 {
        if let Ok((ws, _)) = connect_async(&url).await {
            host_ws = Some(ws);
            break;
        }
        tokio::time::sleep(Duration::from_millis(100)).await;
    }
    let (mut host_tx, mut host_rx) = host_ws.expect("relay never accepted").split();

    // The host opens the session and holds the document.
    host_tx
        .send(Message::Text(
            r#"{"t":"hello","name":"Editor A","role":"host"}"#.into(),
        ))
        .await
        .unwrap();
    let welcome = recv(&mut host_rx).await;
    let invite = welcome["room_code"].as_str().unwrap().to_string();
    let mut host_doc = sequence();

    // A second editor joins with the invite code.
    let (guest, _) = connect_async(&url).await.unwrap();
    let (mut guest_tx, mut guest_rx) = guest.split();
    guest_tx
        .send(Message::Text(
            format!(r#"{{"t":"hello","name":"Editor B","role":"guest","invite":"{invite}"}}"#)
                .into(),
        ))
        .await
        .unwrap();
    assert_eq!(recv(&mut guest_rx).await["t"], "welcome");
    assert_eq!(recv(&mut host_rx).await["t"], "peer-joined");

    // The host hands over the current document, as CollabSession does on join.
    host_tx
        .send(Message::Text(
            serde_json::json!({
                "t": "snapshot",
                "from": 0,
                "mlt_xml": host_doc.to_string(),
            })
            .to_string()
            .into(),
        ))
        .await
        .unwrap();

    let handover = recv(&mut guest_rx).await;
    assert_eq!(handover["t"], "snapshot");
    let mut guest_doc: serde_json::Value =
        serde_json::from_str(handover["mlt_xml"].as_str().unwrap()).unwrap();
    assert_eq!(guest_doc, host_doc, "the guest did not receive the project");

    // The guest trims a clip and broadcasts the result.
    guest_doc["tracks"][0]["clips"][1]["width"] = serde_json::json!(0.18);
    guest_tx
        .send(Message::Text(
            serde_json::json!({
                "t": "snapshot",
                "from": 0,
                "mlt_xml": guest_doc.to_string(),
            })
            .to_string()
            .into(),
        ))
        .await
        .unwrap();

    // The host sees the trim, stamped with the guest's identity.
    let update = recv(&mut host_rx).await;
    assert_eq!(update["t"], "snapshot");
    assert!(
        update["from"].as_i64().unwrap() > 0,
        "the relay did not stamp the sender"
    );
    host_doc = serde_json::from_str(update["mlt_xml"].as_str().unwrap()).unwrap();

    assert_eq!(
        host_doc["tracks"][0]["clips"][1]["width"],
        serde_json::json!(0.18),
        "the edit did not reach the other peer"
    );
    assert_eq!(host_doc, guest_doc, "the peers disagree about the project");

    // A clip edit relayed as an operation rather than a whole document.
    guest_tx
        .send(Message::Text(
            serde_json::json!({
                "t": "op",
                "from": 0,
                "rev": 1,
                "op": { "k": "clip.move", "track": 0, "clip": 0, "start": 0.05 },
            })
            .to_string()
            .into(),
        ))
        .await
        .unwrap();
    let op = recv(&mut host_rx).await;
    assert_eq!(op["t"], "op");
    assert_eq!(op["op"]["k"], "clip.move");
    assert_eq!(op["op"]["start"], serde_json::json!(0.05));

    // When the host leaves, the guest is told the session ended rather than
    // being left editing alone.
    drop(host_tx);
    drop(host_rx);
    let closed = recv(&mut guest_rx).await;
    assert_eq!(closed["t"], "room-closed");
}
