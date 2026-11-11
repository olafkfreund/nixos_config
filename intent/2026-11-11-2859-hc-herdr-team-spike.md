---
status: approved
issue: 2859
author: olafkfreund
---

# Intent: spike — can herdr-core (hc) carry part of herdr-team?

## Problem

`herdr-team` (#2810) is our own plumbing for mixed agent teams inside the
Herdr TUI: `home/development/herdr-team.sh` (1,185 lines) plus
`herdr-team-test.sh` (1,461 lines). It covers:

- team tabs and member panes;
- `ask` / `converse` with `TO: … END` relays, hop limits and deadlines;
- answers as turn files from each agent's `notify` turn;
- launch through `agent-env`, the guard preflight, a `systemd-run --scope`
  per member and a lead-death watchdog;
- git safety: refusing `main` and `~/.config/nixos`, `changed_during_review`,
  and `finish`'s HEAD, staged and empty-diff checks.

We maintain all of it, and it breaks: #2863 was a herdr agent-name rule that
failed every Codex member with an issue-number task.

herdr-core (`hc` 0.1.20, on p620 and razer since #2861) is a headless
runtime that covers some of the same ground:

- persistent named terminals (`hc run --bg --name`, `hc read`, `hc attach`);
- parent/child agents (`hc send`, `hc wait --children all`, parent notes,
  children ending with their parent);
- saved templates (`hc templates`);
- program status through OSC 7501 instead of screen reads;
- remote machines (`hc run --on`);
- an OpenRPC API (`hc schema`).

`hc` and the Herdr TUI don't share agents (herdr.dev: the TUI "has its own
server"). `hc` terminals won't appear as TUI panes; you watch them with
`hc attach` / `hc read`, or in the Herdr desktop app.

We don't know which part of herdr-team, if any, `hc` could replace.

## Proposed outcome

A written answer on #2859, backed by one real run on p620:

- One read-only Codex review runs through `hc` in an **isolated** core: its
  own `HC_SESSION` and scratch XDG paths, so the owner's core and terminals
  are never touched. The core and the Codex terminal have no tokens in
  their environment, and `forced_login_method=chatgpt` is set.
  `git status --porcelain` is the same before and after.
- The same prompt runs through `herdr-team ask` (after #2863 is fixed).
- The two are compared on setup, getting the full answer back, cleanup,
  failure reporting and how much of our code each needs.
- The "to find out" questions below are answered, or marked unverified when
  a Codex-only run can't answer them.
- A recommendation limited to what the run showed: replace that part of
  herdr-team (as a follow-up issue), keep herdr-team, or wait for `hc` to
  mature.

## Affected users and systems

- p620 only, for the runs. Spike scripts stay in the task worktree. No
  module, profile or host change.
- No change to `herdr-team`, the guard or the agent launch paths.

## Constraints

- **Never stop, restart or attach to the owner's `hc` core** (the `hc`
  manual says so too). Only the spike's own isolated core is stopped at the
  end, and its test terminals are removed.
- Read-only for the reviewing agent; the #2812 instruction-only rules apply,
  and Claude checks `git status --porcelain` before and after.
- Subscription login only (#1831). `hc` gives programs the environment its
  **core** started with, not the caller's, so the isolated core itself
  starts through `agent-env`.
- Codex runs with `--no-daemon`. Without it, the `hc` manual says, its
  commands run outside `hc`.
- No deploy. Not razer or p510.

## To find out

1. **Status vs answer:** does Codex emit OSC 7501, so `hc wait` returns when
   its turn ends? `hc` waits return status only, so how does the full final
   answer come back without duplicates or screen chrome (`hc read`, a file,
   or our `notify` turn files)? Is prompt delivery confirmed
   (`first_message.sent`), and how do a trust dialog, a timeout and an early
   exit show up?
2. **Lead outside `hc`:** Claude runs in a Herdr TUI pane, so it has no
   `$HC_TERMINAL_ID`. Without a parent terminal, what happens to `hc wait`,
   parent notes, and cleanup when the lead dies? Is a holder terminal needed?
3. **Containment:** `hc` doesn't sweep detached processes on exit, kill or
   server stop. Can a template keep `agent-env`, the guard preflight and a
   `systemd-run --scope` without breaking `hc` status?
4. **Naming:** `hc` names are 1-32 of `a-z 0-9 - _`, and `t<n>` looks like an
   `hc` terminal address, so task names need mapping here too.
5. **Stability of 0.1.x:** environment on `hc server restart` (inside the
   isolated core only), and wait timing.
6. **What stays ours anyway:** how much of herdr-team is transport that `hc`
   could replace, and how much is git safety and relay rules that `hc`
   doesn't touch.

agy and Claude Code are not run. Whether they emit OSC 7501, and the agy
guard inside a template, stay unverified. (In herdr-team, agy already runs
through our own ACP client, which writes its own turn files.)

## Open questions

1. Report as a comment on #2859 only (method in the spec and plan), or also a
   `docs/` page? Proposed: the comment only. A `docs/` page for a point-in-time
   0.1.20 spike would need nav entries in both mkdocs files. The PR then holds
   only the three artifacts. Both reviewers agree.
2. Codex only, as the issue says? Proposed: yes. Both reviewers agree.

## Review notes

Reviewed read-only by Codex (gpt-6.1-sol) and agy (model not reported)
against `hc --help`, `hc run --help`, `hc wait --help` and `hc --skill`. They
added:

- the isolated core (the first draft stopped the owner's core);
- `--no-daemon` for Codex;
- that the core's environment, not the caller's, reaches programs;
- the lead-outside-`hc` and detached-process questions;
- the status-vs-answer split;
- naming;
- limiting the recommendation to what a Codex-only run shows.

They also corrected the line counts. Advice only, not approval.
