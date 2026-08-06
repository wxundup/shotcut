//! Wire-format contract: the JSON the C++ client sends and expects.
//!
//! Runs the relay binary and speaks raw JSON so a rename in the protocol
//! enum fails here rather than silently in the editor.

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

async fn recv_json<S>(s: &mut S) -> serde_json::Value
where
    S: StreamExt<Item = Result<Message, tokio_tungstenite::tungstenite::Error>> + Unpin,
{
    let frame = tokio::time::timeout(Duration::from_secs(5), s.next())
        .await
        .expect("timed out waiting for relay message")
        .expect("stream closed")
        .expect("websocket error");
    match frame {
        Message::Text(t) => serde_json::from_str(&t).expect("relay sent invalid JSON"),
        other => panic!("expected text frame, got {other:?}"),
    }
}

#[tokio::test]
async fn cpp_client_wire_format() {
    let addr = "127.0.0.1:7799";
    let relay = Relay(
        Command::new(env!("CARGO_BIN_EXE_editogether-collab"))
            .arg(addr)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .expect("failed to start relay"),
    );

    // wait for the listener
    let url = format!("ws://{addr}");
    let mut host = None;
    for _ in 0..50 {
        if let Ok((ws, _)) = connect_async(&url).await {
            host = Some(ws);
            break;
        }
        tokio::time::sleep(Duration::from_millis(100)).await;
    }
    let (mut host_tx, mut host_rx) = host.expect("relay never accepted a connection").split();

    // exactly what CollabClient::startHost sends
    host_tx
        .send(Message::Text(
            r#"{"t":"hello","name":"Host","role":"host"}"#.into(),
        ))
        .await
        .unwrap();

    let welcome = recv_json(&mut host_rx).await;
    assert_eq!(welcome["t"], "welcome");
    // fields CollabClient::onText reads
    assert!(welcome["peer_id"].is_number());
    assert!(welcome["host_id"].is_number());
    assert!(welcome["peers"].is_array());
    let code = welcome["room_code"].as_str().expect("room_code").to_string();
    assert_eq!(code.len(), 6);

    // CollabClient::join
    let (guest, _) = connect_async(&url).await.unwrap();
    let (mut guest_tx, mut guest_rx) = guest.split();
    guest_tx
        .send(Message::Text(
            format!(r#"{{"t":"hello","name":"Guest","role":"guest","invite":"{code}"}}"#).into(),
        ))
        .await
        .unwrap();
    assert_eq!(recv_json(&mut guest_rx).await["t"], "welcome");

    // host sees peer-joined with the shape onText expects
    let joined = recv_json(&mut host_rx).await;
    assert_eq!(joined["t"], "peer-joined");
    assert_eq!(joined["peer"]["name"], "Guest");
    assert_eq!(joined["peer"]["role"], "guest");

    // CollabSession::broadcastSnapshot -> guest opens it
    host_tx
        .send(Message::Text(
            r#"{"t":"snapshot","from":0,"mlt_xml":"<mlt><playlist/></mlt>"}"#.into(),
        ))
        .await
        .unwrap();
    let snapshot = recv_json(&mut guest_rx).await;
    assert_eq!(snapshot["t"], "snapshot");
    assert_eq!(snapshot["mlt_xml"], "<mlt><playlist/></mlt>");

    // a guest cannot forge a session event: room-closed would kick the room
    guest_tx
        .send(Message::Text(
            r#"{"t":"room-closed","reason":"forged"}"#.into(),
        ))
        .await
        .unwrap();
    // the host must not see it; prove the connection still carries real traffic
    guest_tx
        .send(Message::Text(
            r#"{"t":"presence","from":0,"playhead":0.5}"#.into(),
        ))
        .await
        .unwrap();
    let next = recv_json(&mut host_rx).await;
    assert_eq!(
        next["t"], "presence",
        "relay forwarded a peer-forged session event: {next}"
    );

    // a bad invite is answered privately, not broadcast
    let (stranger, _) = connect_async(&url).await.unwrap();
    let (mut stranger_tx, mut stranger_rx) = stranger.split();
    stranger_tx
        .send(Message::Text(
            r#"{"t":"hello","name":"Nobody","role":"guest","invite":"ZZZZZZ"}"#.into(),
        ))
        .await
        .unwrap();
    let err = recv_json(&mut stranger_rx).await;
    assert_eq!(err["t"], "error");
    assert!(err["reason"].is_string());

    drop(relay);
}
