---
status: approved
issue: 2616
author: olafkfreund
---

# Intent: subagents as a tree in herdr's sidebar, and no lingering agents

## Problem

herdr's left sidebar on p620 and razer shows only top-level agent sessions.
When a Claude session spawns teammates or coder agents, they are invisible
there. Claude runs them in its own private tmux server
(`/run/user/1000/tmux-1000/claude-swarm-<pid>`), not as herdr panes.
Agent-tool subagents run inside the parent process and have no pane at all.
You cannot see which subagents a session is running.

Finished agents also linger. On 2026-11-02 two `claude-swarm` tmux servers
from coder agents started at 11:16 and 11:51 were still alive hours after
their work ended. Nineteen `claude-swarm` sockets had piled up in
`/run/user/1000/tmux-1000/`. herdr's own Claude and Codex integrations are
outdated (claude v10 < v11, codex v8 < v10).

## Proposed outcome

- In herdr's left sidebar, a session's running subagents and teammates
  appear nested under it as a tree, and disappear when they finish.
- A subagent or teammate that has finished, or whose parent session has
  ended, is shut down and its pane or tmux server removed, so nothing idle
  is left behind.
- Codex and agy subagents, which have no pane of their own, are at least
  shown as a count on their parent's row.
- herdr's built-in agent integrations are current.

## Affected users and systems

- The user, on p620 and razer. Not p510.
- `home/development/herdr.nix` (config, plugins), and the Claude Code hooks
  in `modules/programs/claude-code-managed.nix`, which already publish a
  subagent count on the parent pane.
- herdr plugins already installed: herdr-radar (owns the grouped sidebar
  view) and zoetrope.
- Possibly new: a packaged tmux shim so Claude teammates open as herdr
  panes, and a small tree-view plugin.

## Constraints

- Never kill an agent that is still needed. An idle teammate can still
  receive work, so "idle" alone is not "finished". Only close what the
  integration created and still owns. Never close one of the user's own
  panes.
- herdr's sidebar has one active view projection (`agent.view.set`) at a
  time, and herdr-radar already owns it. The tree must cooperate with radar
  or replace it while keeping its grouping.
- Third-party code is MIT, pinned and built by Nix (the omateams pattern).
  There is no runtime self-update.
- The shim found (david-lutz/herdr-claude-teams) is validated only on macOS
  with herdr 0.6.10. It must be proven on Linux with herdr 0.9.5 and
  Claude 2.1.316 before it is relied on.
- Research came from Codex (cited, verified by the session), the Claude Code
  docs, and agy (first run returned only a plan; a second run is pending).
  Their output is advice, not approval.

## Open questions

These go to the spec.

1. The tree: extend herdr-radar's view, or replace it with a tree view that
   keeps radar's grouping?
2. If the shim cannot be made reliable on Linux, is a count-only display
   (subagent and teammate counts on the parent row) acceptable as the
   fallback?
