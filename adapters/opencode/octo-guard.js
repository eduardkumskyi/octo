// octo guard shim for OpenCode — delegates tool.execute.before to the same
// hooks/guard.sh used natively. Exit 2 => block (throw); anything else => allow.
const { execFileSync } = require("child_process");
const path = require("path");

const GUARD = path.join(__dirname, "..", "..", "hooks", "guard.sh");
const BASH_TOOLS = new Set(["bash", "shell", "run"]);

const OctoGuard = async () => ({
  "tool.execute.before": async (input, output) => {
    const tool = (input && input.tool ? String(input.tool) : "").toLowerCase();
    if (!BASH_TOOLS.has(tool)) return;
    const command = output && output.args ? output.args.command : undefined;
    if (!command) return;
    const payload = JSON.stringify({ tool_name: "Bash", tool_input: { command } });
    try {
      execFileSync("bash", [GUARD], { input: payload, stdio: ["pipe", "pipe", "pipe"] });
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
