---
status: draft
issue: 3083
intent: intent/2026-11-18-3083-guard-option-values.md
---

# Spec: deploy guards miss a recipe that is not the first word after just's options

## Design

The approved decision is "any word": a `just` segment is a deploy when any of its words is a deploy recipe name.
Two exceptions keep everyday read-only commands working. Prepare drops a segment it can prove harmless: a dry run,
or a safe recipe given only its own arguments.

### 1. The `just=` pattern (both guards)

`modules/programs/claude-code-managed.nix`, lines 372 (p510 guard) and 556 (bus guard). Both lines get the same
change:

```bash
just='(^|[^[:alnum:]_-])just([[:space:]]+[^[:space:];|&]+)*[[:space:]]+([^[:space:];|&]*(::|/))?'
```

- `([[:space:]]+[^[:space:];|&]+)*` takes any words before the recipe, not only options and `NAME=value`. That
  covers an option's value, `--set`'s two values, a quoted value whose quotes prepare deletes, and an earlier
  recipe. The words stop at `;`, `|` and `&`, so a deploy word in the next segment is not credited to this `just`
  call.
- `([^[:space:];|&]*(::|/))?` lets the recipe carry a module path (`mod::p510`) or a search directory
  (`../p510`), both forms just accepts.
- `(^|[^[:alnum:]_-])` before `just` stops `adjust p510` and similar words from matching. Main blocks those; they
  are not commands.

The patterns that use `$just` (`$just[a-z-]*deploy`, `$just(p510|p620|razer)$end`, the #2951 recipe list, the
p510-only recipes, and the on-p510 local list) do not change.

### 2. Prepare drops two more harmless shapes

`modules/programs/claude-guard-prepare.sh`. These are dropped only within the existing allow-list of plain
characters (line 18).

**a. Dry runs behind attached values** (intent question 2). In the word walk, a word of the form `--name=value` or
`-fX`, `-dX`, `-EX`, `-FX` (a short value-taking option with its value attached) is skipped, and the walk goes on.
That lets `just --color=always -n p510` and `just -fFILE -n p510` reach `-n`. Separate-value options other than
`-f` and `-d` still end the walk, so `--shell-arg -n` is not taken for a dry run. The rule that keeps a dry run when
a later word starts with `-` (`--command` after `-n`) stays.

**b. Safe recipes with their own arguments.** A segment is dropped when, after any `NAME=value` words, it is exactly
`just <recipe>` followed by at most that recipe's number of parameters, and none of those arguments starts with
`-`. The recipes are those that are read-only for the hosts and take a host argument:

| Recipe | Parameters |
| --- | --- |
| `test-host`, `diff`, `build-on-p620`, `secrets-status-host`, `_sign-drv` | 1 |
| `dry-run`, `boot-space`, `system-diff`, `preview-updates` | 1 (optional) |
| `update-commit` | 2 (optional) |

Arity matters. just treats a word beyond the recipe's parameters as another recipe, so `just test-host p620 p510`
runs `p510`. That segment has one word too many, so it is not dropped and the any-word pattern blocks it. Options
before the recipe are not allowed in this shape; any segment that has them goes to the pattern.

`boot-space-clean`, `cleanup`, `fix-agenix-remote`, the deploy recipes and `update-commit-deploy` are not on the
list.

### 3. Tests

- `modules/programs/claude-guard-prepare.test.sh`: a case for each dropped shape, and a case for each near miss
  that must be kept. The near misses are one argument too many, an argument starting with `-`, an option before the
  recipe, and `--shell-arg -n`.
- `scripts/test-bus-guard.py` and `scripts/test-p510-deploy-guard.py`: each row of the intent's table, checked in
  every context (bus guard; p510 guard off p510 and on p510). Also `just test-host p510` and
  `just check-syntax ; ssh p510 uptime`, which must pass.
- The arity table is checked against the Justfile. A test in `just test-guards` reads `just --dump --dump-format
  json` and fails if a listed recipe is missing or its parameter count differs. It also feeds each listed recipe's
  body, with `{{ HOST }}` filled in, to the bus guard, and fails if the guard would block any line. That reuses
  the guard's own disruptive patterns instead of a second word list. Checked by hand on 2026-11-18: the bodies use
  `nixos-rebuild build`, `nixos-rebuild dry-activate` and `systemctl status`, and none is disruptive.
- The comparison against main from #3047 (every suite command through main's guards and the branch's) reports no
  command that the branch is more permissive on, other than the two dry runs intended here.

## Alternatives rejected

- **Parse just's arguments exactly** (option arity, quoted values, every recipe argument). The owner chose any-word
  for the intent.
- **Any word, no exemptions.** A prototype of it blocked `just test-host p510`, `just test-host p620` and
  `just boot-space p510`, which main allows and which AGENTS.md requires before every deploy. Blocking the build
  step trains everyone to add `AGENT_BUS_ANNOUNCED=1` by reflex.
- **Exempt safe recipes inside the regex** (a negative match). ERE has no lookahead, and arity can't be expressed
  there.

## Risks

- **More false positives in prose.** A command whose text has `just`, a few words and a host name in one segment is
  now blocked, for example `gh pr create --title "just docs for p510"`. The rule for commit messages and PR text
  already puts prose in files (AGENTS.md, "Claude Code"), which avoids this.
- **The arity table drifts from the Justfile.** If a safe recipe gains a parameter, or a new read-only recipe is
  added, the drift test catches the first case. The second just blocks until the table is updated, which fails
  closed.
- **A safe recipe changes to deploy.** The drift test's check of the body for deploy words is a guard against this,
  not a proof.
- All three hosts carry the guards. A bad pattern would block every `just` call, or none. The guard suites and
  a live probe after deploy (step below) cover that.

## Verification

1. `just test-guards` passes. shellcheck is clean.
2. The comparison against main: the branch is more permissive only on `just --color=always -n p510` and
   `just -fFILE -n p510`.
3. The p620 and razer toplevels build.
4. After deploying p620 and razer, payloads are fed straight to the installed guards, with nothing executed:
   - all six missed forms exit 2 in both guards;
   - `just test-host p510` and `just -n p510` exit 0.
5. p510 is deployed only with the owner's OK.
