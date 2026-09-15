---
status: approved
issue: 1818
author: olafkfreund
---

# Intent: intent → spec → plan workflow for every Claude session

## Problem

Tasks are planned in chat. The plan disappears with the session, nobody
approves it in a durable way, and there is no trail from "why" to the diff.

## Proposed outcome

Every non-trivial task produces three committed artifacts — intent, spec,
plan — each approved before the next is written. Implementation follows the
approved plan; the commit history is the audit trail.

## Affected users and systems

- Every Claude Code session on p620, razer and p510
- `modules/programs/claude-code-managed.nix` (PARR hook)
- `/create-spec` (Agent OS)

## Constraints

- Must reach all hosts declaratively, not rely on one synced file
- Small tasks (typo, lock bump, one-line config) stay exempt
- No second spec system: `/create-spec` must write to `spec/`

## Open questions

None — resolved in chat on 2026-09-15.
