#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v node >/dev/null 2>&1 || { echo "SKIP: node not available"; exit 0; }
node --check adapters/opencode/octo-guard.js || { echo "shim has syntax errors"; exit 1; }
# behavioral smoke: drive the exported hook with a stubbed context
node - <<'EOF'
const path = require("path");
const mod = require(path.resolve("adapters/opencode/octo-guard.js"));
(async () => {
  const plugin = await mod.OctoGuard({ directory: process.cwd() });
  const hook = plugin["tool.execute.before"];
  let blocked = false;
  try {
    await hook({ tool: "bash" }, { args: { command: "git push --force origin main" } });
  } catch (e) { blocked = true; }
  if (!blocked) { console.error("force push not blocked"); process.exit(1); }
  await hook({ tool: "bash" }, { args: { command: "git status" } }); // must not throw
  await hook({ tool: "read" }, { args: {} }); // non-bash ignored
  console.log("shim behavior OK");
})().catch(e => { console.error(e); process.exit(1); });
EOF
