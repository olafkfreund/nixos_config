---
status: draft
issue: 2818
author: olafkfreund
---

# Intent: herdr-team follow-ups

## Problem

Four gaps found by Codex's review of PR #2815 and by the live team test (#2810):

1. **Stray processes survive.** `teardown` only kills a member's process group while the launcher is still
   alive (`stop_member`, `home/development/herdr-team.sh:166`). When an implementer starts a background process
   and then quits, `finish` and `down` find the launcher gone and skip the group, so the process keeps running.
   The group leader is the member itself, so once it exits `/proc/<pgid>` is gone too and today's start-time
   check cannot pass. `sweep` (run by every `up`) removes a dead task's records without stopping its group at all,
   which loses the pgid for good. Members run unrestricted since #2812, which makes this more likely.
2. **A flaky test.** The revision test (`home/development/herdr-team-test.sh:413`) edits the tree after a fixed
   `sleep 0.4`. On a slow run the edit can land before the request is sent, so `changed_during_review` is false
   and the test fails. Three other tests order concurrent events with a fixed sleep the same way
   (herdr-team-test.sh:350, :484, :609).
3. **The exchange is lost.** Every member teardown deletes that member's answers (`<work>/ans/`), and the last
   one deletes `conversation.jsonl`. That happens in `finish`, in `down` (whole task or one member) and in
   `sweep`, so a finished conversation cannot be read afterwards. In the usual order, `finish implement` has
   already removed the implementer's answers before `down` runs.
4. **One key variable is not stripped.** `ANTHROPIC_API_KEY_FILE` is missing from the `env -u` lists (#2812).
   Neither tool reads it today, so this only tidies the list.

## Proposed outcome

- After `finish`, `down` or a `sweep`, no process from a member's process group is left, even when the member and
  its launcher exited first. A pgid that now belongs to an unrelated process is never signalled.
- The herdr-team test passes on repeated runs: the four tests above wait for the state they need instead of a
  fixed sleep.
- Whichever command tears a member down (`finish`, `down`, `sweep`), its answers are kept first, per member,
  under `$XDG_RUNTIME_DIR/herdr-team/archive/<gen>/<member>/`, and the conversation log under
  `archive/<gen>/conversation.jsonl`. They stay readable until the runtime dir is cleared at logout.
- Every `env -u` key list also strips `ANTHROPIC_API_KEY_FILE`.

## Affected users and systems

- `home/development/herdr-team.sh` and `home/development/herdr-team-test.sh` (p620 and razer, through Home
  Manager).
- The key lists, and the test's environment checks, in `agent-env.sh`, `herdr-team.sh`, `codex-cli.nix`, `codex-cli/module.nix`,
  `antigravity-config.nix` and `modules/ai/antigravity-cli.nix`.
- Docs that describe `down` (`docs/applications/herdr.md`).

## Constraints

- No change to how members launch, talk or finish, beyond these four points.
- Only signal a process group that is provably still the member's: its recorded leader still runs with the
  recorded start time, or the leader is gone and the kernel still holds the pgid for surviving members (a pid
  is not reused while a process group of that id has members).
- The archive stays in the runtime dir: private (0700), never in the repo or the Nix store.
- Deploy to p620 and razer only; p510 is not touched.

## Open questions

- Should the archive be pruned (for example, keep the last 20 generations), or is tmpfs clearing at logout
  enough? Default: no pruning.
