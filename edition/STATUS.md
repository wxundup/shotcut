# EdiTogether: what works, and what doesn't

Written to be read by someone deciding whether to rely on this. Every
"verified" line below was checked by running the thing and inspecting real
output — a rendered file, a captured frame, a measured number — not by
reading the code. For how this stands against Premiere, Resolve and CapCut, see
COMPARISON.md.

Re-run the checks yourself with:

    powershell -ExecutionPolicy Bypass -File scripts/check-editogether.ps1

## Verified

| Capability | How it was checked |
|---|---|
| Multi-track composite | Two sources decode at once; V2 renders over V1 in the exported file |
| Export to H.264/AAC | 96 s, 1920×1080, 2877 frames; frames sampled at four positions match the clips the timeline places there |
| Effect stack | A clip carrying Monochrome + Vignette + Text comes back desaturated, corner-darkened and captioned; a blurred clip resolves sharp bars into gradients |
| Effect catalogue | 19 effects, 13 rendering as filters; tests fail if an effect renders nothing when its parameter moves |
| Colour management | Output tagged bt709 primaries/transfer/matrix, tv range, where the source read `unknown` and `bt470bg` |
| Audio DSP | EQ, compressor, limiter reach the file: a band centred on the material drops 6.0 dB versus a bypassed render |
| Proxy workflow | 2160p master → 540p proxy at 6% of the size; delivery scores SSIM 0.9477 against the master versus 0.9359 if a proxy leaked in |
| Hardware encode | 49.3 s → 28.9 s on the same render, a 1.7× speedup; falls back to software when the probe finds nothing |
| Collaboration | Two peers through the running relay binary: project handed over on join, a trim by one arrives at the other, room closes when the host leaves |
| Installer | 164.8 MB wizard; silent install of 1417 files, the installed copy launches with Qt removed from PATH, uninstall exits clean |
| Timeline interaction | Clip drag, trim handles, snapping, zoom about the pointer |
| Keyframed effects | Animated saturation measured against a bypassed render at matching times: 22.2 / 98.0 / 27.1 versus 46.5 / 40.7 / 53.7 — low, high, low, tracking the keyframes |
| Keyframed rotation | Renders as an angle expression ramping 0->25 degrees, not a constant |
| In-app shell | Hosted in a `QDockWidget` inside the application: a harness compiling the dock code against Qt reports the interface loads from the compiled resource, and preflight fails if the resource drifts from what is on disk |

Each test was checked by breaking the behaviour it covers and confirming it
fails — a test that cannot fail proves nothing.

## Not done

- **GPU compositing.** `scale_cuda` and `overlay_cuda` work in isolation and
  a device-side composite was built and confirmed, but integrating it into
  the renderer failed: a later CUDA-decoded stream falls back to system
  memory and `scale_cuda` refuses the frame. This machine has only virtual
  display adapters, so the failure may be environmental. The attempt was
  reverted rather than shipped behind a flag that breaks. Worth retrying on
  a machine with a physical GPU. Hardware *encode* is unaffected and works.
- **Editing through the new interface.** The interface now reads the open
  document — visible tracks, their clips, positions and lengths — and
  refreshes as the project changes, so the dock shows the real edit rather
  than a fixture. It is read-only: edits still go through the existing
  timeline and its undo stack. A second write path into the document would
  be a way to corrupt it, and giving the new interface one is the next real
  piece of work.

- **Partial opacity ramps.** A ramp between two non-zero levels becomes a
  full fade over the same span, because this FFmpeg build's `fade` has no
  `start_alpha`. Stepping the alpha with chained `colorchannelmixer`
  filters was tried and reverted: the steps do not compose reliably, and
  the output could not be shown correct.
- **Filter effects without an expression form.** `gblur`, `unsharp` and
  `colorbalance` take no per-frame expression in this build, so a keyframed
  parameter on those holds its mid value. `eq`-based effects (Saturation,
  Brightness, Monochrome), Vignette and Rotation do animate.

## Known limits worth stating plainly

- The relay has no transport encryption and no credential beyond the invite
  code. Binding beyond loopback is a trusted-network posture and warns at
  startup.
- Untagged SDR sources are treated as Rec.709. Almost always right, but it
  is an assumption, and the renderer says so per clip.
- The audio meters and scopes read from real data, but the shell's session
  model is a fixture when run standalone. Hosted in the application it reads
  the open MLT document; there is still no save and load of its own.

## Bugs found and fixed during development

Recorded because a list of features says less than a list of what was wrong
with them:

- Video tracks composited in document order, so V1 painted over V2 and the
  upper track vanished entirely.
- A transformed layer was padded to the canvas before scaling, dragging a
  frame of opaque black along with the picture.
- Position offsets multiplied by full frame width, pushing layers off screen.
- `onText` was a private non-slot invoked by name, so no collaboration
  message was ever handled.
- Snapshot echo: peers ping-ponged the same document forever.
- A guest could forge `room-closed` and kick the room.
- Invite-code collision replaced a live room.
- The timeline lane is a `Flickable` and claimed every horizontal drag as a
  flick, so nothing could be dragged.
- `Monochrome` defaulted to fully desaturated: adding it changed the picture
  immediately and moving it to zero did nothing.
- `drawtext` aborts on Windows without an explicit font.
- `$args` is a reserved PowerShell name; assigning to it broke a script that
  parsed cleanly.
- Short clips were drawn at a 24 px minimum width, so they overlapped their
  neighbours and the timeline showed an overlap the sequence did not have.
- A clip's height was bound to `parent`, which is null while the delegate is
  being built.
- The effects browser offered Position and Rotation for an audio clip.
- The edition resource had fallen fourteen files behind the shell, so the
  in-app preview would have failed to load. It is generated now, and
  preflight fails when it drifts.
