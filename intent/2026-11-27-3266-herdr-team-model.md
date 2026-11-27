---
status: approved
issue: 3266
author: olafkfreund
---

# Intent: herdr-team up --model/--effort per member

## Problem

`herdr-team up` starts a review, implement or agy-implement member with the
role map's default model (#3263) and offers no way to choose another one
for a single task. A manager that wants a cheaper reviewer for a trivial
plan, or a stronger implementer for one hard step, has to bypass herdr-team.

## Proposed outcome

`herdr-team up <task> <role> [--step k] [--model M] [--effort E]` starts the
member on that model and effort; without the flags nothing changes. The
choice is recorded in the member's state so `status` shows it.

## Affected users and systems

herdr-team on p620 and razer (both TUI and hc backends).

## Constraints

- Values are validated (`^[A-Za-z0-9._-]+$`) before they reach a command
  line or TOML.
- Defaults stay the role map's.

## Open questions

None.
