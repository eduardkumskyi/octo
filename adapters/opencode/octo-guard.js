// octo guard shim for OpenCode — delegates tool.execute.before to the same
// hooks/guard.sh used natively. Exit 2 => block (throw); anything else => allow.
const { execFileSync } = require("child_process");
const path = require("path");
const fs = require("fs");

const BASH_TOOLS = new Set(["bash", "shell", "run"]);

// Resolution state (cached per module load).
let _guardResolved = false;
let _guardPath = null;
let _warnedMissing = false;

// resolveGuard() returns the absolute path to guard.sh, or null if not found.
// Resolution order:
//   (a) process.env.OCTO_GUARD if set and the path exists on disk
//   (b) ../../hooks/guard.sh relative to __dirname (works for symlinked installs
//       because Node resolves __dirname via realpath on symlinked modules)
// The result is cached so the filesystem is only probed once per process.
function resolveGuard() {
  if (_guardResolved) return _guardPath;
  _guardResolved = true;
  const envPath = process.env.OCTO_GUARD;
  if (envPath && fs.existsSync(envPath)) {
    _guardPath = envPath;
    return _guardPath;
  }
  const defaultPath = path.join(__dirname, "..", "..", "hooks", "guard.sh");
  if (fs.existsSync(defaultPath)) {
    _guardPath = defaultPath;
    return _guardPath;
  }
  return null;
}

const OctoGuard = async () => ({
  "tool.execute.before": async (input, output) => {
    const tool = (input && input.tool ? String(input.tool) : "").toLowerCase();
    if (!BASH_TOOLS.has(tool)) return;
    const command = output && output.args ? output.args.command : undefined;
    if (!command) return;
    const guard = resolveGuard();
    if (!guard) {
      // Fail-open, but never silent: warn exactly once so the operator knows
      // the guard is inactive (e.g. the shim was copied instead of symlinked).
      if (!_warnedMissing) {
        _warnedMissing = true;
        console.error(
          "[octo-guard] guard.sh not found — guard is INACTIVE. " +
          "Symlink the shim or set OCTO_GUARD=/path/to/hooks/guard.sh"
        );
      }
      return;
    }
    const payload = JSON.stringify({ tool_name: "Bash", tool_input: { command } });
    try {
      execFileSync("bash", [guard], { input: payload, stdio: ["pipe", "pipe", "pipe"] });
    } catch (e) {
      if (e.status === 2) {
        const reason = e.stderr ? e.stderr.toString().trim() : "blocked by octo guard";
        throw new Error(reason);
      }
      // any other failure: fail-open, same as the native hook
    }
  },
});

module.exports = { OctoGuard };
