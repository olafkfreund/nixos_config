---
status: draft
issue: 3083
author: olafkfreund
---

# Intent: deploy guards miss just options that take a value

## Problem

The bus-announcement guard and the p510-approval guard (`modules/programs/claude-code-managed.nix`) find a deploy by
matching `just`, then any options, then a recipe name. The option part of the pattern knows that only `-f`,
`--justfile`, `-d` and `--working-directory` take a separate value. Any other option that takes one, such as
`--shell-arg 0`, leaves its value behind as a word. The pattern then reads the value as the recipe, sees that it is not
a deploy recipe, and lets the whole command through.

Checked on 2026-11-18 against the installed guards on p620, with nothing executed. `just --shell-arg 0 p510` exits 0
in both guards, and `just p510` exits 2 in both.

just 1.59 has 24 options that take a value. 22 of them are not handled, `--set` among them, and `--set` takes two values.

Main had this gap before #3047, so it is not a regression. #3047 listed it as a known limit.

## Proposed outcome

- Any `just` option that takes a value, in its separate or `=` form, no longer hides the recipe after it from either
  guard. That includes `--set NAME VALUE`.
- The forms the guards already block are still blocked.
- `just` dry runs (`-n`, `--dry-run`, `-s`, `--show`, `-l`, `--list`) still pass, as the spec of #3047 allows.
- `just test-guards` has cases for the new forms.

## Affected users and systems

- Claude Code sessions on p620, razer and p510, through the managed PreToolUse hooks.
- The files: `modules/programs/claude-code-managed.nix` (both copies of the `just` pattern),
  `modules/programs/claude-guard-prepare.sh` (its word walk knows the same four options), and both test suites.

## Constraints

- Fail closed. If a command is ambiguous, block it rather than allow it.
- Don't make the guards less strict on any command in the existing suites. Compare them against main, as #3047 did.
- Deploy with the usual announcement. p510 needs the owner's OK.

## Open questions

1. Should the guard list just's value-taking options by name? That is exact, but the list needs updating when just
   adds an option. The other way is to read every unknown option both ways, as a flag and as taking a value, and
   block when either reading finds a deploy recipe. That fails closed. Its cost is that a safe command whose option
   value happens to be a recipe name is blocked too, such as `just --color p510 --list`, though such a command is
   unlikely.
2. Should a just upgrade that adds a new value-taking option be detected? For example, a test could compare
   `just --help` against the list.
