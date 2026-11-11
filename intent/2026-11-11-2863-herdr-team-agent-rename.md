---
status: draft
issue: 2863
author: olafkfreund
---

# Intent: herdr-team up fails with "agent rename failed" for Codex members

## Problem

`herdr-team up <task> review` (or `implement`) fails for every Codex member
when the task name is an issue number, which is how we name tasks:

```json
{"ok":false,"outcome":"failed","reason":"agent rename failed"}
```

Reproduced on p620 on 2026-11-11 (herdr 0.9.5) with task `2863`. With the
error output kept, herdr says why:

```json
{"error":{"code":"invalid_agent_name","message":"agent name must start with a lowercase letter and contain only lowercase letters, digits, '-' or '_' (1-32 characters)"}}
```

- `home/development/herdr-team.sh:579` renames the agent to
  `"$task-$role"` (`2863-review`). That starts with a digit, so herdr
  rejects it.
- `task_ok` (line 60) allows `^[A-Za-z0-9][A-Za-z0-9_-]*$`: a leading
  digit, capitals, any length. herdr agent names must start with a
  lowercase letter, may then have digits, `-` and `_`, and are capped at 32
  characters.
- The call sends both stdout and stderr to `/dev/null`. herdr wrote the error
  JSON on stderr, and it was lost. The `pane rename` call (line 577) swallows
  its output the same way.
- `herdr-team-test.sh` covers a rename failure in general (`fail-agent-rename`,
  lines 46 and 819), but its fake `herdr` accepts any name, and every test task
  (`t1`, `t2`, `a`, …) starts with a lowercase letter. A rejected name is
  never tested.
- The agy branch (line 577) uses `pane rename`, which accepted
  `2853-agy-implement`, so agy members are not affected.
- Nothing reads the agent name back: identity checks use the pane, the
  terminal and `.result.pane.agent == "codex"` (`same_pane`, line 237), not
  the name.

Every Codex member whose task name is an issue number fails and is torn
down. That happened twice on 2026-11-11, and the work moved to headless
`agent-run` / `codex exec`. A task name like `t1` still works.

## Proposed outcome

- `herdr-team up` works for Codex members with issue-number task names (and
  any other name `task_ok` accepts), and each member's herdr label still
  shows its task and role, distinct between members.
- `ask` and `finish` still recognise the member after the rename.
- If a rename does fail, the failure reason includes herdr's own message.
- A test covers a task name that starts with a digit, and the fake `herdr`
  enforces herdr's name rule, so a regression is caught.

## Affected users and systems

- `home/development/herdr-team.sh`, `home/development/herdr-team-test.sh`.
- Hosts with herdr-team: p620 and razer (developer profile).
- Claude Code sessions inside herdr that delegate to Codex.

## Constraints

- Task names stay as they are (issue numbers). The fix maps a task name to a
  valid agent name; it doesn't tighten `task_ok`.
- The member's tab, files and state keep using the task name unchanged.
- No change to agy members or `pane rename`.
- Members run unrestricted (#2812); this doesn't touch launch or guard paths.

## Open questions

1. Keep the rename with a mapped name (`2863-review` → `t2863-review`; the
   exact rule goes in the spec), or drop it, since it is cosmetic? Proposed:
   keep it, so members are easy to tell apart in herdr. Both reviewers
   agree. A long task name must be shortened before `-<role>` is added, or
   members collide (agy).
2. A rename failure: keep it fatal (with herdr's message), or warn and
   continue? Proposed: keep it fatal, because once names are valid a failure
   means the pane or agent is in a bad state, and the existing test (line
   819) already expects that. agy agrees. Codex prefers warn-and-continue,
   since the name is only a label. Your call.

## Review notes

Reviewed read-only by Codex (gpt-6.1-sol) and agy (model not reported).
Both confirmed the root cause. They corrected:

- the "every run" claim (narrowed to issue-number task names);
- that both output streams are discarded, not only stderr;
- that rename failure in general is tested, but a rejected name is not;
- that truncating after `-<role>` would collide members (agy).

They disagree on question 2. Advice only, not approval.
