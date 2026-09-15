---
name: artifact-workflow
description: >-
  Write and gate the intent → spec → plan artifacts for a task. Use when
  starting any task tracked as an issue or touching more than one file, when
  asked to write an intent, spec or plan, on `/create-spec`, or when the user
  approves one of these artifacts. Not for typos, lock bumps or one-line config.
---

# Artifact workflow

Three committed files per task, each approved before the next is written.
Approval is a git commit, so the history is the audit trail.

## Naming

One slug per task, shared across all three folders at the repo root:
`YYYY-MM-DD-<issue>-<short-slug>.md`. Create the issue and the branch
(`<type>/<issue>-<description>`) first; artifacts are committed on the branch.

## Stages

| Stage  | File                | Answers | Stop and ask for |
| ------ | ------------------- | ------- | ---------------- |
| Intent | `intent/<slug>.md`  | why     | approval of the problem framing |
| Spec   | `spec/<slug>.md`    | what    | approval of the design |
| Plan   | `plan/<slug>.md`    | how     | approval to implement |

Rules:

- Write one stage, commit it with `status: draft`, stop. Never write the next
  stage in the same turn.
- On approval, flip `status: approved` and commit it alone:
  `docs(<stage>): approve <slug> (#<issue>)`.
- Changes requested: edit, commit, ask again. Status stays `draft`.
- The plan copies the approved spec decisions so it can be implemented without
  opening the intent or spec. The spec file stays where it is.
- During implementation, cite the plan step being executed. A deviation updates
  `plan/` in the same commit as the code.
- Open the PR linking all three files. Review compares the diff to `plan/`.

## Intent template

```markdown
---
status: draft
issue: <n>
author: <git user>
---

# Intent: <title>

## Problem

What is wrong or missing, in plain language. No solution yet.

## Proposed outcome

What is true when this is done, observable by the user.

## Affected users and systems

Hosts, modules, services, people.

## Constraints

Must / must not. Compatibility, security, hosts that need approval.

## Open questions

Anything the approver must decide. "None" is allowed.
```

## Spec template

```markdown
---
status: draft
issue: <n>
intent: intent/<slug>.md
---

# Spec: <title>

## Design

The chosen solution and why. Reference real files.

## Alternatives rejected

Each with the reason.

## Risks

What could break, and on which host.

## Verification

How "done" is proven: eval, build, test, runtime check.
```

## Plan template

```markdown
---
status: draft
issue: <n>
spec: spec/<slug>.md
---

# Plan: <title>

Self-contained summary of the approved decisions.

## Steps

1. <file>: <change> → verify by <check>

## Tests

Commands to run and the expected result.

## Rollback

How to undo it.
```
