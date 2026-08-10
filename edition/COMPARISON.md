# EdiTogether against the editors it is measured by

The brief asks for software that "contends and beats out corporations like
ByteDance and Adobe." This is an honest inventory of where it stands
instead of a claim that it does.

Rows are scored against Premiere Pro, DaVinci Resolve and CapCut as they
ship today. Nothing here is measured on a benchmark rig — the comparison is
capability, not performance. Where a number appears it was measured on this
project's own material and says so.

## Where it is genuinely competitive

| Capability | EdiTogether | The others |
|---|---|---|
| Local self-hosted collaboration | Relay you run yourself, invite codes, no account, no cloud | Premiere and Resolve need Team Projects or a Blackmagic server; CapCut is cloud-only |
| Cost and licence | GPLv3, no subscription | Subscription (Premiere), free/Studio split (Resolve), free with account (CapCut) |
| Colour-managed export | Linear-light compositing in 32-bit float, delivery tagged bt709 or PQ | All three do this |
| Proxy workflow | Generated at 6% of source size, delivery always from the master | All three do this |

Collaboration is the row where this project is actually differentiated:
nobody else offers a session that runs entirely on one editor's machine
with no account and no service. The rest of that table is parity at best.

## Where it is behind, and by how much

| Capability | EdiTogether | Premiere / Resolve / CapCut |
|---|---|---|
| Effects | 44, of which 38 render and are checked against FFmpeg | Hundreds, plus third-party ecosystems (Sapphire, Red Giant, FxFactory) |
| Editing through the new interface | Moves, trims, effects and grading, on its own project model. Hosted in the application it reads the open MLT document but does not yet write to it | Full editing, obviously |
| GPU | Encode and decode only; compositing is CPU | Full GPU pipelines; Resolve is built on one |
| Colour grading | Lift/gamma/gain wheels, a tone curve, and .cube LUTs | Resolve's node graph is the industry reference and is not close |
| Audio | 3-band EQ, compressor, limiter per channel | Full mixers, buses, sends, VST/AU hosting, Fairlight in Resolve |
| Text and titles | Two generators, no styling | Essential Graphics, Fusion titles, animated templates |
| Formats | H.264, HEVC, ProRes, AAC, PCM | Dozens of codecs, RAW, camera formats, IMF, broadcast delivery |
| Tracking, warp, morph | None | Standard in all three |
| Keying | Chroma key and despill | Keyers with spill suppression, edge and light wrap |
| Captions and speech | Local whisper transcription to SRT, no upload | Automatic transcription in all three, cloud-assisted, more accurate |
| Stabilisation | None | Standard |
| Multicam | Angles synced by audio correlation, within ~25 ms on tested material | Standard, with live switching and angle editing |
| Media management | An index of a folder | Bins, metadata, search, shared libraries, conform and relink |
| Maturity | Weeks of work, one contributor | Decades, hundreds of engineers, millions of users |

## What that adds up to

It does not beat Adobe. It is not close, and the gap is not the kind that
closes with more of the same work — an effects ecosystem, a node-based
grading system, camera format support and speech recognition are each
larger than everything built here so far.

What it is: a working editor with a coherent interface, a correct
colour-managed render path, and a collaboration model none of the
incumbents offer. That last part is a real reason for someone to use it,
and it is the honest pitch — not that it replaces Premiere, but that it
does one thing they do not do at all.

Anyone deciding whether to rely on this should read `STATUS.md` next: it
lists what is verified, what is missing, and every bug found while building
it.
