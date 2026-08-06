# EdiTogether collaboration

One machine runs the relay. Editors join it with a six-character invite
code and edit the same sequence. There is no cloud service and no account:
the relay is a single binary you run yourself, and the project never leaves
the machines taking part.

## Running it

```
cargo build --release
target/release/editogether-collab            # 127.0.0.1:7788, this machine only
target/release/editogether-collab 0.0.0.0:7788   # reachable on the LAN
```

The default bind is loopback, so nothing is exposed until you ask for it.
Binding beyond loopback prints a warning, because traffic is unencrypted and
the invite code is the only credential — that is a trusted-network posture,
not an internet-facing one. Put it behind a VPN or an SSH tunnel to work
across sites.

In the editor: **Collaborate > Start Session** prints an invite code,
**Join Session** takes one. The host's machine is the only one that needs to
run the relay.

## What crosses the wire

| Message | Direction | Purpose |
|---|---|---|
| `hello` | peer → relay | join as host or guest, with an invite code |
| `welcome` | relay → peer | your id, the room code, the current roster |
| `peer-joined` / `peer-left` | relay → peers | roster changes |
| `snapshot` | peer ↔ peers | the whole project document |
| `op` | peer ↔ peers | a single edit |
| `presence` | peer ↔ peers | playhead and selection |
| `room-closed` | relay → peers | the host left |
| `error` | relay → peer | a refusal, sent only to the peer concerned |

## Boundaries

- **Closed vocabulary.** Only `clip.*`, `track.*`, `transition.*`, `filter.*`
  and `meta.set` operations are relayed. Anything else is dropped, so the
  protocol cannot be widened into running code on a peer's machine.
- **The relay owns session events.** A peer cannot send `welcome`,
  `peer-joined`, `peer-left`, `room-closed` or `error`; only peer-originated
  messages cross, each stamped with the authenticated sender. Without this a
  guest could kick the room or fake the roster.
- **Bounded.** 1 MiB frames, 64 KiB operations, 8 MiB snapshots, and a
  per-peer rate limit. Oversized or malformed input is refused privately.
- **Invite codes** use an unambiguous alphabet and retry on collision rather
  than replacing a live room.

## Tests

```
cargo test
```

- `host_guest_relay` — join, relay, and the silent drop of an unknown
  operation kind.
- `cpp_client_wire_format` — the exact JSON the editor's `CollabClient`
  sends, against the running binary, including a guest's attempt to forge a
  session event.
- `two_peers_edit_the_same_sequence` — two peers, a project handed over on
  join, a trim made by one arriving at the other, an operation relayed, and
  the room closing when the host leaves.

Each was checked by breaking the behaviour it covers and confirming it
fails.
