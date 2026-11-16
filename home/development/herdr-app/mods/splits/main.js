import { View, div } from "gpui-kit";
import { exec, focused, nextCommand, notify, openOverlay, panes, run, spaces } from "herdr";
import { resizeDoc } from "./tree.js";

const keys = { left: "h", down: "j", up: "k", right: "l" };

async function rpc(method, params) {
  const request = JSON.stringify({ jsonrpc: "2.0", id: 1, method, params });
  const r = await exec("sh", ["-c", 'printf "%s\\n" "$1" | hc connect', "sh", request]);
  let reply = null;
  try { reply = JSON.parse(r.stdout); } catch { /* reported below */ }
  if (!reply?.result) throw new Error(reply?.error?.message ?? (r.stderr.trim() || "hc connect gave no answer"));
  return reply.result;
}

// Versioned write: retry once when another layout change wins the race.
async function resize(pane, machine, direction) {
  for (let attempt = 0; attempt < 2; attempt++) {
    const { value, version } = await rpc("doc.get", { name: "herdr-app", on: machine });
    if (!resizeDoc(value, pane, direction, 1)) return;
    try {
      await rpc("doc.set", { name: "herdr-app", on: machine, value, version });
      return;
    } catch (error) {
      if (attempt) throw error;
    }
  }
}

export default class Splits extends View {
  init(_props, cx) {
    cx.spawn(async () => {
      for (;;) {
        const command = await nextCommand();
        if (command === "worktree-open") {
          // Same dialog as the + menu's "Open worktree…"; a key can't pass props itself.
          openOverlay({ mod: "worktree", kind: "dialog", width: 560, height: 480,
            props: { space: focused()?.space, folder: panes().find((p) => p.focused)?.cwd, action: "open" } });
          continue;
        }
        const match = /^(go|resize)-(left|down|up|right)$/.exec(command);
        if (!match) continue;
        const [, action, direction] = match;
        const current = focused();
        const pane = panes().find((p) => p.pane === current?.pane);
        if (!pane?.terminal) continue;
        try {
          if (pane.program?.key === "nvim") {
            await exec("hc", ["keys", pane.terminal, `${action === "go" ? "ctrl" : "alt"}+${keys[direction]}`]);
          } else if (action === "go") {
            run("pane.go", { direction });
          } else {
            const machine = spaces().find((s) => s.id === current.space)?.machine ?? null;
            await resize(pane.pane.split("/").pop(), machine, direction);
          }
        } catch (error) {
          notify({ title: "Splits", body: String(error), level: "error" });
        }
      }
    });
  }

  render() { return div(); }
}
