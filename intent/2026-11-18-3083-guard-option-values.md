---
status: draft
issue: 3083
author: olafkfreund
---

# Intent: deploy guards miss a recipe that is not the first word after just's options

## Problem

The bus-announcement guard and the p510-approval guard (`modules/programs/claude-code-managed.nix`, the `just=`
patterns at lines 372 and 556) find a deploy by matching `just`, then options, then a recipe name. They check only the
first word after the options. Any form that puts something else in that position gets a deploy recipe past both
guards.

Checked on 2026-11-18 against the installed guards on p620, with payloads fed straight to the guards and nothing
executed:

| Form | Example | Both guards |
| --- | --- | --- |
| option with a separate value | `just --shell-arg 0 p510` | exit 0, missed |
| `--set` (two values) | `just --set A B p510` | exit 0, missed |
| quoted value with a space | `just -f "a b" p510` | exit 0, missed |
| second recipe in one call | `just check-syntax p510` | exit 0, missed |
| module path | `just mod::p510` | exit 0, missed |
| plain deploy | `just p510` | exit 2, blocked |
| `=` form, attached short value, `--` | `--shell-arg=0`, `-fFILE`, `-- p510` | exit 2, blocked |

just 1.59 has 24 options in its Options section that take a value. The patterns skip a separate value for only two of
them, `-f`/`--justfile` and `-d`/`--working-directory`. just runs every recipe named in one call, in order (checked
with a test justfile), so the second-recipe form deploys.

Main had this gap before #3047, so it is not a regression. #3047 listed it as a known limit.

There is a smaller problem the other way round. Two dry runs that the spec of #3047 meant to allow are blocked:
`just --color=always -n p510` and `just -fFILE -n p510`. The preparer's word walk (`claude-guard-prepare.sh`, lines
27 to 38) stops at the first option it doesn't know, before it reaches `-n`.

## Proposed outcome

- A `just` call that would run a deploy recipe is blocked by both guards, wherever the recipe appears. That covers
  all five missed forms above.
- The forms blocked today stay blocked, and no command in the existing suites becomes less strict. This is checked
  against main, as in #3047.
- `just test-guards` has a case for every row of the table.
- Optional: the two blocked dry runs pass. An option value such as `--shell-arg -n` must still not count as a dry
  run.

## Affected users and systems

- Claude Code sessions on p620, razer and p510, through the managed PreToolUse hooks.
- `modules/programs/claude-code-managed.nix` (both `just=` patterns), `modules/programs/claude-guard-prepare.sh`, and
  both test suites (`scripts/test-bus-guard.py`, `scripts/test-p510-deploy-guard.py`).

## Constraints

- Fail closed: if a command is ambiguous, block it.
- Deploy with the usual bus announcement. p510 needs the owner's OK.

## Open questions

1. How should the guard decide? There are two ways:
   - **Any word:** block when any word of a `just` segment is a deploy recipe name, ignoring where it sits. This is
     the smallest change and fails closed. It covers module paths too if the `::` suffix is matched. Its cost is
     blocking a safe call whose option value happens to be a recipe name, such as `just --list-heading p510 --list`,
     which is blocked today anyway.
   - **Parse just's arguments:** know each option's arity (including `--set`'s two values), keep quoted values whole,
     and check every recipe argument. This is exact, but it is more code and needs updating when just adds an option.
2. Fix the two blocked dry runs in this task, or leave them?
3. Should a test catch a just upgrade that adds a value-taking option? This matters only for the parse approach.
