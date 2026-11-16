---
status: draft
issue: 2978
author: olafkfreund
---

# Intent: herdr-app parity with the TUI workflow, plus an issues and agent-team overview

## Problem

Since #2861, p620 and razer run the Herdr desktop app (`herdr-app` 0.1.15)
and herdr-core (`hc` 0.1.20) next to the Herdr TUI (`herdr` 0.9.x). The
owner wants to work in the app from now on, but everything that makes the
TUI useful is bound to the TUI. The TUI and herdr-core run separate
servers and don't share agents (#2861).

**TUI plugins.** `herdr plugin list` shows 13, all enabled and installed by
hand on each host:

- herdr-radar: the agent sidebar, per-agent logos and the tab bar.
- zoetrope: Claude Task subagents drawn as a live flow graph.
- reviewr: comment on diff lines and send the comments to the agent.
- herdr-splits: ctrl+hjkl across herdr panes and Neovim splits, alt+hjkl resize.
- hintr and pretty-which: key help.
- The rest: command palette (fzf), sessionizer, auto-title, collie,
  mirror, file viewer and GitHub start. What each one does for the owner
  becomes part of the baseline that the spec checks against.

**Our TUI config** (`home/development/herdr.nix`):

- Keys: a lazygit popup, plugin keys, previous/next workspace, open worktree.
- System notifications and sounds.
- A theme that follows `omarchy theme set` live.
- Agent labels on pane borders, panel order that puts teammates under their
  lead, status symbols that don't rely on colour, and the host and workspace
  in the window title.
- Worktree folder.
- One systemd scope per pane (#2959).
- 50 MB scrollback and pane history across restarts.
- Agent-state integrations for Claude, Codex and agy.

**Repo tooling that speaks the TUI's socket API:**

- `herdr-claude-teams`: Claude Code agent teams as panes. The `claude()`
  launcher picks it when `HERDR_ENV=1` and `HERDR_SOCKET_PATH` is set.
- `herdr-team`: Codex (and, when enabled, agy) members in a visible tab,
  with:
  - resumable asks and structured replies;
  - teammate conversations with hop and deadline limits and an audit log;
  - `finish` checks, with repair retries and staged-change / moved-HEAD
    detection;
  - a watchdog that cleans up when the lead disappears or a member outlives
    its time.
- `herdr-run`: one-shot runs shown as rows, passing stdin, stdout, stderr,
  the exit status and cancellation through.
- A Claude hook that reports Task-subagent counts with
  `herdr pane report-metadata`.
- The Omarchy `nixarchy.herdr` widget.

The #2859 spike tried `hc` under `herdr-team` and recommended keeping it on
the TUI.

**App configuration.** The app's package wrapper (core path, update
manifest, telemetry) comes from Nix. Its workflow and UI configuration does
not: no layouts, keys, settings or extensions are declared, so it runs on
upstream defaults.

**Two new needs** that neither tool covers today:

- **One overview of GitHub and GitLab issues and PRs/MRs.** Both are
  logged in on these hosts: github.com through `gh` and gitlab.com through
  `glab`.
- **Every agent and agent team in one place, with control:**
  - Claude Code agents and teammates;
  - Claude Task subagents;
  - the Codex and agy members that `herdr-team` starts;
  - sub-agents started with `hc run`.

  Control means: see the state, focus or peek, send input, answer a blocked
  prompt, stop. Task subagents run inside Claude with no terminal of their
  own (`modules/programs/claude-code-managed.nix:676`), so they may only be
  controllable through their parent. The spec must say exactly where
  control stops.

## Proposed outcome

On p620 and razer, after a deploy:

1. Every function in the baseline above has a working equivalent in
   herdr-app, unless the owner has accepted it as a gap (see question 1).
   The spec lists each one: how it carries over or why it can't, and
   nothing is dropped silently.
2. Whatever the app needs is declared in this repo and lands on both hosts
   the same way, not by hand-install per host.
3. Inside the app the owner sees open GitHub and GitLab issues and PRs/MRs,
   and can act on one (question 4 says what "act" means).
4. Inside the app the owner sees every agent and team member with its
   state, and controls each one as far as question 2 allows.
5. The owner's habits carry over: the same keys for the same actions where
   the app allows it, the same notifications, and the same Claude Code,
   `herdr-team` and `herdr-run` commands, keeping their safety behaviour
   (limits, finish checks, watchdog cleanup, exit status).
6. The TUI keeps working as it does today, so the owner can go back to it
   at any time.

## Affected users and systems

- Hosts: p620 and razer (the owner's profile). Not p510.
- Areas: the herdr Home Manager module, the herdr-app and herdr-core
  packages, the `herdr-team` / `herdr-run` tooling, herdr-claude-teams, the
  Claude subagent hook and the Omarchy herdr widget.
- People: the owner, and other agents that use `herdr-team` inside herdr.

## Constraints

- Don't break the TUI or any running TUI or hc terminal. A deploy must
  not end live terminals.
- Third-party extensions are pinned and reviewed before they land. They run
  code with the owner's rights.
- Carried over from #2861:
  - the app's own settings stay writable;
  - self-update stays off;
  - telemetry stays off.
- Changes the owner makes in the app (clicks, sizes, chosen layout) must
  not be thrown away by a later deploy, or the spec must say which ones are
  and why.
- Credentials stay with `gh` and `glab`: no tokens in the Nix store or in
  app files.
- Agents started from the app keep the existing rules: `agent-env` for
  Codex and agy, per-pane systemd scopes, the guard hooks.
- Deploys follow the bus rule. razer builds on p620
  (`just deploy-via-p620 razer`).

## Open questions

1. **What counts as parity?** Must every function work inside the app, or
   may a function that only works in the TUI (still installed alongside)
   count, if the spec names it?
2. **Agent control limits:** is control through the parent acceptable for
   Claude Task subagents, which have no terminal of their own? Should the
   view cover agents on both hosts at once (hc machines), or only the
   local host?
3. **Agent teams:** #2859 kept `herdr-team` on the TUI. Is this task
   allowed to move `herdr-team` and `herdr-claude-teams` to `hc`, or only
   to show and control them from the app while they keep running on the
   TUI?
4. **Issues:**
   - Which ones: assigned to or opened by the owner, or all open in a set
     of repos and groups (which ones)?
   - Act on one how: open it in the browser, start an agent on it, or run
     the repo's issue → branch → worktree flow?
   - Read-only, or also comment and close?
   - gitlab.com only?
5. **Own extensions:** where nothing suitable exists, is it OK to write
   small ones in this repo?
6. **TUI plugins:** keep installing them by hand on each host, as today,
   or bring them under Nix as part of this task?
