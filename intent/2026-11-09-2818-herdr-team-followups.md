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
   Members run unrestricted since #2812, which makes this more likely.
2. **A flaky test.** The revision test (`home/development/herdr-team-test.sh:413`) edits the tree after a fixed
   `sleep 0.4`. On a slow run the edit can land before the request is sent, so `changed_during_review` is false
   and the test fails.
3. **The exchange is lost.** `down` deletes `conversation.jsonl` and the answers with the work dirs, so a
   finished conversation cannot be read afterwards.
4. **One key variable is not stripped.** `ANTHROPIC_API_KEY_FILE` is missing from the `env -u` lists (#2812).
   Neither tool reads it today, so this only tidies the list.

## Proposed outcome

- After `finish` or `down`, no process from a member's process group is left, even when the launcher exited first.
  A reused pgid is still never signalled.
- The herdr-team test passes on repeated runs, with no fixed sleep deciding the result.
- After `down`, the conversation log and the answers of that task are still readable under
  `$XDG_RUNTIME_DIR/herdr-team/archive/<gen>/` until the next login (tmpfs).
- Every `env -u` key list also strips `ANTHROPIC_API_KEY_FILE`.

## Affected users and systems

- `home/development/herdr-team.sh` and `home/development/herdr-team-test.sh` (p620 and razer, through Home
  Manager).
- The key lists in `agent-env.sh`, `herdr-team.sh`, `codex-cli.nix`, `codex-cli/module.nix`,
  `antigravity-config.nix` and `modules/ai/antigravity-cli.nix`.
- Docs that describe `down` (`docs/applications/herdr.md`).

## Constraints

- No change to how members launch, talk or finish, beyond these four points.
- Only signal a process group whose recorded start time still matches (no pid reuse).
- The archive stays in the runtime dir: private (0700), never in the repo or the Nix store.
- Deploy to p620 and razer only; p510 is not touched.

## Open questions

- Should the archive be pruned (for example, keep the last 20 generations), or is tmpfs clearing at logout
  enough? Default: no pruning.
