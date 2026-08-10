// Runs every renderable effect's filter through FFmpeg.
//
//   node scripts/validate-effects.js
//
// The catalogue tests check an effect's shape — that it is inert at its
// defaults and responds when a parameter moves. They cannot tell whether
// the filter string it produces is one FFmpeg will accept. This does, by
// encoding a few frames through each.
//
// It caught two effects whose text filters crashed for want of an explicit
// font, which the exporter handled and the catalogue did not.

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const repo = path.dirname(__dirname);

function ffmpeg() {
  const bin = process.env.EDITOGETHER_FFMPEG_BIN;
  return bin ? path.join(bin, "ffmpeg.exe") : "ffmpeg";
}

function loadCatalogue() {
  const source = fs
    .readFileSync(path.join(repo, "edition", "EffectCatalogue.js"), "utf8")
    .replace(".pragma library", "");
  // Wrapped in a function: the catalogue declares `effects` at top level,
  // which collides with this module's own binding under a bare eval.
  return eval("(function () {" + source + "; return { effects }; })()");
}

function main() {
  const { effects } = loadCatalogue();
  const renderable = effects.filter((e) => e.render && !e.geometric && !e.audio);

  const failures = [];
  let checked = 0;

  for (const effect of renderable) {
    // Push the leading parameter to its extreme: that is the setting that
    // decides whether the effect does anything.
    const values = {};
    for (const p of effect.params) values[p.name] = p.value;
    const first = effect.params[0];
    values[first.name] = first.value === first.max ? first.min : first.max;

    let fragment = effect.render(values, effect);

    // An effect that needs an analysis pass names a file the renderer
    // supplies. Point it at a real one so the filter is still checked
    // rather than skipped.
    if (fragment && effect.needsAnalysis) {
      const vectors = path.join(repo, "edition", "media", "stabilisation",
                                "Handheld_01.trf");
      if (!fs.existsSync(vectors)) {
        console.warn(`  ${effect.name}: no analysis to check against, skipped`);
        continue;
      }
      // Both separators and the drive colon end a filter argument early.
      const escaped = vectors.split("\\").join("/").split(":").join("\\:");
      fragment = fragment.replace("vidstabtransform=",
                                  `vidstabtransform=input='${escaped}':`);
    }
    if (!fragment) {
      // An effect that needs a file — a LUT — is inert until one is
      // chosen. That is the right behaviour, not a broken filter.
      if (effect.file) continue;
      failures.push(`${effect.name}: renders nothing with ${first.name} moved`);
      continue;
    }

    try {
      execFileSync(
        ffmpeg(),
        ["-y", "-hide_banner", "-loglevel", "error",
         "-f", "lavfi", "-i", "testsrc2=s=320x180:r=15:d=0.4",
         "-vf", fragment, "-f", "null", "-"],
        { stdio: "pipe" }
      );
      checked++;
    } catch (error) {
      const detail = (error.stderr || "").toString().trim().split("\n")[0] || error.message;
      failures.push(`${effect.name}: ${detail}\n    ${fragment}`);
    }
  }

  if (failures.length) {
    console.error(`${failures.length} of ${renderable.length} effects produce a filter FFmpeg rejects:\n`);
    for (const f of failures) console.error("  " + f);
    process.exit(1);
  }

  console.log(`all ${checked} renderable effects produce a working filter`);
}

main();
