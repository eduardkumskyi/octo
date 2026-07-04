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

# copy scenario: shim copied to a temp dir with no OCTO_GUARD set →
# force-push must NOT throw (fail-open), and the INACTIVE warning must be emitted.
node - <<'COPY_TEST'
const fs = require("fs");
const os = require("os");
const path = require("path");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "octo-copy-"));
const copyPath = path.join(tmp, "octo-guard.js");
fs.copyFileSync(path.resolve("adapters/opencode/octo-guard.js"), copyPath);
delete process.env.OCTO_GUARD;
const mod = require(copyPath);
(async () => {
  const plugin = await mod.OctoGuard({ directory: process.cwd() });
  const hook = plugin["tool.execute.before"];
  let blocked = false;
  let warned = false;
  const origErr = console.error;
  console.error = (...args) => {
    if (String(args[0]).includes("[octo-guard]")) warned = true;
    origErr.apply(console, args);
  };
  try {
    await hook({ tool: "bash" }, { args: { command: "git push --force origin main" } });
  } catch (e) { blocked = true; }
  console.error = origErr;
  if (blocked) { console.error("FAIL: copied shim should fail-open, not throw"); process.exit(1); }
  if (!warned) { console.error("FAIL: copied shim must emit INACTIVE warning"); process.exit(1); }
  console.log("copy scenario OK: fail-open + INACTIVE warning emitted");
})().catch(e => { console.error(e); process.exit(1); });
COPY_TEST

# OCTO_GUARD override: shim copied to a temp dir but OCTO_GUARD points at the
# real hooks/guard.sh → force-push must be blocked (guard is active via env var).
OCTO_GUARD="$(pwd)/hooks/guard.sh" node - <<'ENV_TEST'
const fs = require("fs");
const os = require("os");
const path = require("path");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "octo-env-"));
const copyPath = path.join(tmp, "octo-guard.js");
fs.copyFileSync(path.resolve("adapters/opencode/octo-guard.js"), copyPath);
const mod = require(copyPath);
(async () => {
  const plugin = await mod.OctoGuard({ directory: process.cwd() });
  const hook = plugin["tool.execute.before"];
  let blocked = false;
  try {
    await hook({ tool: "bash" }, { args: { command: "git push --force origin main" } });
  } catch (e) { blocked = true; }
  if (!blocked) { console.error("FAIL: OCTO_GUARD override should block force-push"); process.exit(1); }
  console.log("OCTO_GUARD override OK: force-push blocked via env var");
})().catch(e => { console.error(e); process.exit(1); });
ENV_TEST
