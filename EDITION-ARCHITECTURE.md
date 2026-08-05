# EdiTogether Architecture (Shotcut fork)

EdiTogether is a fork of [Shotcut](https://github.com/mltframework/shotcut)
(github.com/wxundup/shotcut) with a rebuilt frontend design system and a
fully local, self-hosted collaboration backend. MLT remains the media engine;
Shotcut's C++/QML codebase remains the editor core. This document supersedes
the earlier Rust/egui architecture (retired).

## Product invariants

- Exports never carry a watermark.
- Collaboration is local-first: one machine runs the relay; no cloud service.
- A suspicious or invalid collaboration packet is dropped silently and
  answered only with a private error to its originator — never broadcast.
- The UI follows one design system: dark-first neutral surfaces, a single
  accent (#0a84ff dark / #007aff light), 4px spacing grid, one decelerating
  easing curve. Less, but better.

## Repository layout

```
shotcut/            fork of mltframework/shotcut (editor core, MLT-backed)
  src/collab/       collaboration client (WebSocket) + session glue
  src/qml/modules/EdiTogether/   design system: Theme tokens + Controls
  edition/          standalone shell prototype (target UX reference)
  collab/           editogether-collab: local relay server (Rust)
```

## Frontend

Two consumers share one design system:

1. **Design system** — `shotcut/src/qml/modules/EdiTogether/Theme/Theme.qml`
   is a singleton holding palette, spacing, radii, typography, and motion
   tokens. `EdiTogether/Controls/` provides Button, ToolButton, TextField,
   Slider, Switch, Segmented, Panel, ScrubBar built on
   `QtQuick.Controls.Basic` so customization is style-supported.
2. **Shell prototype** — `edition/Shell.qml` (+ Toolbar, LibraryPanel,
   PreviewPanel, InspectorPanel, TimelinePanel) is the runnable target UX:
   unified toolbar with transport and session presence, library, program
   monitor, inspector, multi-track timeline. Run from the fork root with:
   `qml -I src/qml/modules -I edition edition/Shell.qml`.
3. **In-app reskin** — `MainWindow::changeTheme` applies the
   EdiTogether palette (dark-first, light scheme honored) to all widgets and
   docks; `EdiTogether.Controls` restyles the QML surfaces.
4. **In-app preview** — View → *Preview EdiTogether Interface* opens the
   shell from bundled resources (`src/edition.qrc`), the transition path
   from current chrome to target UX.

All QML is kept `qmllint`-clean (`pragma ComponentBehavior: Bound`,
qualified id access, required delegate properties).

## Collaboration

- **Relay** (`collab/`, Rust/tokio/tungstenite): rooms keyed by 6-char
  invite codes (unambiguous alphabet), membership roster, presence, snapshot
  relay. Bounded messages (1 MiB frame, 64 KiB op, 8 MiB snapshot), closed
  op vocabulary (`clip.*`, `track.*`, `transition.*`, `filter.*`, `meta.set`),
  per-peer rate limit, origin stamping so forged `from` fields are ignored.
  Host leaving closes the room.
- **Client** (`shotcut/src/collab/`): `CollabClient` is the thin WebSocket
  transport; `CollabSession` glues it to `MainWindow`. Sync v1 is
  snapshot-level: undo-stack changes debounce 400 ms into an MLT XML snapshot
  broadcast; received snapshots open into the project. The Collaborate menu
  offers Start Session / Join Session (invite code) / Leave Session.
- Sync v2 (op-level through the undo stack) is the upgrade path; the relay's
  op vocabulary already matches it.

Run the relay: `editogether-collab [bind-addr]` (default 127.0.0.1:7788).

## Build and verification

```powershell
# design system + shell (no compile needed)
C:\Qt\6.9.3\msvc2022_64\bin\qmllint.exe -I shotcut\src\qml\modules -I edition edition\*.qml
C:\Qt\6.9.3\msvc2022_64\bin\qml.exe -I shotcut\src\qml\modules -I edition edition\Shell.qml

# relay
cd collab; cargo test

# full editor (MSYS2 MINGW64, mirrors CI)
echo INSTALL_DIR=\"$(pwd)/build\" > build-shotcut.conf
bash scripts/build-shotcut-msys2.sh
```

GitHub Actions `build-windows.yml` runs the same MSYS2 recipe on the fork
(upstream-only S3 upload unchanged).

## Remaining work

- Op-level collaboration through QUndoStack commands.
- Presence cursors/playhead overlay in the timeline.
- Edition shell panels replacing widget docks incrementally.
- Hardware decode/encode, GPU compositing (upstream Shotcut roadmap).
