---
status: draft
issue: 2859
author: olafkfreund
---

# Intent: spike — can herdr-core (hc) carry part of herdr-team?

## Problem

`herdr-team` (#2810, `home/development/herdr-team.sh`, about 1,400 lines plus
its test) is our own plumbing for mixed agent teams inside the Herdr TUI:

- team tabs and member panes;
- `ask` / `converse` with `TO: … END` relays, hop limits and deadlines;
- answers as turn files from each agent's `notify` turn;
- launch through `agent-env`, the guard preflight, and cleanup.

We maintain all of it, and it breaks: #2863 was a herdr agent-name rule that
failed every Codex member.

herdr-core (`hc` 0.1.20, on p620 and razer since #2861) is a headless
runtime that covers much of the same ground:

- persistent named terminals (`hc run --bg --name`, `hc ls`, `hc read`,
  `hc attach`);
- parent/child agents (`hc send`, `hc wait --children all`, parent notes,
  children ending with their parent);
- saved templates (`hc templates`);
- program status through OSC 7501 instead of screen reads;
- remote machines (`hc run --on`);
- an OpenRPC API (`hc schema`).

`hc` and the Herdr TUI don't share agents (herdr.dev: the TUI "has its own
server"). `hc` terminals won't appear as TUI panes; they are watched with
`hc attach` / `hc read`, or in the Herdr desktop app.

We don't know whether `hc` can do herdr-team's job with less of our code.

## Proposed outcome

A written answer on #2859, backed by one real run on p620:

- One read-only Codex review runs through `hc`, launched through `agent-env`
  (no tokens in its environment, `forced_login_method=chatgpt`).
  `git status --porcelain` is the same before and after.
- The same prompt runs through `herdr-team ask` (after #2863 is fixed).
- The two are compared on setup, getting the answer back, cleanup,
  failure reporting and lines of our code needed.
- The "to find out" questions below are answered.
- A recommendation: replace part of herdr-team (as a follow-up issue),
  keep herdr-team, or wait for `hc` to mature.

## Affected users and systems

- p620 only, for the runs. Spike scripts live in the task worktree, or in
  the spike notes if committed. No module or profile changes.
- No change to `herdr-team`, the guard, or the agent launch paths.

## Constraints

- Read-only for the reviewing agent; the #2812 instruction-only rules apply,
  and Claude checks `git status --porcelain` before and after.
- Subscription login only (#1831); no API keys reach the `hc` terminal.
- No deploy and no host change. `hc` server use is user-level and on demand.
  Stop the core (`hc server stop`) and remove the test terminals at the end.
- Not razer or p510.

## To find out

1. Do Codex, agy and Claude Code emit OSC 7501? If not, what does `hc` show
   as their status, and would we still need `notify` turn files?
2. Can a template keep the `codex-implement` / `agy-implement` guard
   preflight and the `agent-env` launch?
3. How do `hc wait` and parent notes compare with `herdr-team ask` for
   getting a final answer back?
4. How stable is 0.1.x: environment on `hc server restart`, wait timing, and
   behaviour when the agent exits early?

## Open questions

1. Is a spike notes file in the repo wanted (`docs/` or the spec), or only
   the comment on #2859? Proposed: only the issue comment; the spec and plan
   record the method.
2. Include agy in the run, or Codex only, as the issue says? Proposed:
   Codex only. agy is listed under "to find out" for OSC 7501 only.
