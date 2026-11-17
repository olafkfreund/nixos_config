# freund-agents

`herdr-app do mod.clone '{"name":"agents","as":"freund-agents"}'` on herdr-app 0.1.16. Our changes (plan step 9 of
issue 2978) are listed below; on an app bump, re-clone `agents` and re-apply them.

- Imports `InputState`, `Input` and `exec` for the control popup and counter reads.
- `init` handles control-popup input, initializes the runtime path and per-terminal counter cache, and redraws
  every five seconds instead of thirty.
- Adds `send`, `controlMenu` and `subagentCount`: the popup uses app commands for focus, peek, stop and
  pane/hide, `hc` for send and interrupt, and reads live Claude counts from the runtime directory.
- `subRow` adds a controls button for nested agents.
- `render` switches to the control popup when requested; `withKids` adds the Task subagents line and Graph button.
- Agent rows add right-click (including the narrow rail) and a controls button to open that popup.
- The controls popup has a Copy ID item (`cx.write_to_clipboard`, as herdr-terminal-ids does); its item
  helper passes `cx` to the action.
