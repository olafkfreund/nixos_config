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
- `task_ok` (line 60) allows `^[A-Za-z0-9][A-Za-z0-9_-]*$`: leading digits,
  capitals, any length. herdr's agent names allow none of those, and are
  capped at 32 characters.
- The call sends stderr to `/dev/null`, so the reason was lost.
- `herdr-team-test.sh` uses task `t1`, which is a valid agent name, and its
  fake `herdr` accepts any rename. So the tests never hit this.
- The agy branch (line 577) uses `pane rename`, which accepted
  `2853-agy-implement`, so agy members are not affected.
- Nothing reads the agent name back: it only labels the member in herdr.

Every `herdr-team` run since herdr started enforcing this has fallen back to
headless `agent-run` / `codex exec`.

## Proposed outcome

- `herdr-team up` works for Codex members with issue-number task names (and
  any other name `task_ok` accepts), and the member gets a valid herdr agent
  name.
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

1. Agent name format. Proposed: lowercase the name, swap any character
   outside `[a-z0-9_-]` for `-`, add a `t` prefix when it doesn't start with
   a letter (`2863-review` → `t2863-review`), and cut it to 32 characters.
   The other option is to drop the rename (it is cosmetic), but then the
   member shows as plain `codex` in herdr.
2. A rename failure: keep it fatal (with herdr's message), or warn and
   continue, since the name is cosmetic? Proposed: keep it fatal, because a
   failure now means something unexpected, and herdr's message says what.
