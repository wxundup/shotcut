// Fails when the catalogue and the renderer disagree about which effects
// exist.
//
//   node scripts/check-effect-parity.js
//
// The interface reads edition/EffectCatalogue.js; the exporter has its own
// copy of each effect in PowerShell. An effect present in only one of them
// either appears in the browser and does nothing on export, or renders
// something the interface never offered. Fourteen effects had drifted this
// way before this check existed.

const fs = require("fs");
const path = require("path");

const repo = path.dirname(__dirname);

function catalogueNames() {
  const source = fs
    .readFileSync(path.join(repo, "edition", "EffectCatalogue.js"), "utf8")
    .replace(".pragma library", "");
  // Wrapped in a function: the catalogue declares `effects` at top level,
  // which collides with this module's own binding under a bare eval.
  const { effects } = eval("(function () {" + source + "; return { effects }; })()");
  return effects
    .filter((e) => e.render && !e.geometric && !e.audio)
    .map((e) => e.name);
}

function rendererNames() {
  const source = fs.readFileSync(
    path.join(repo, "edition", "export", "render-sequence.ps1"),
    "utf8"
  );
  const names = new Set();
  const pattern = /^\s+'([A-Za-z ]+)' \{/gm;
  let match;
  while ((match = pattern.exec(source)) !== null) names.add(match[1]);
  return names;
}

function main() {
  const catalogue = catalogueNames();
  const renderer = rendererNames();

  const missing = catalogue.filter((name) => !renderer.has(name));
  if (missing.length) {
    console.error(
      `${missing.length} effect(s) in the catalogue that the renderer cannot apply:`
    );
    for (const name of missing) console.error("  " + name);
    console.error("\nThey would appear in the browser and do nothing on export.");
    process.exit(1);
  }

  console.log(`catalogue and renderer agree on ${catalogue.length} effects`);
}

main();
