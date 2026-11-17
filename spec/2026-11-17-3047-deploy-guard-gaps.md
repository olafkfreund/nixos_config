---
status: draft
issue: 3047
intent: intent/2026-11-17-3047-deploy-guard-gaps.md
---

# Spec: deploy guards catch the script path, quoted forms, and allow dry runs

## Design

All changes are in `modules/programs/claude-code-managed.nix`: `deployGuardScript` (p510 guard, ~line 355) and
`busAnnounceScript` (~line 530). Both keep their escape checks (`P510_DEPLOY_APPROVED=1`,
`AGENT_BUS_ANNOUNCED=1`) on the raw command text, first, unchanged.

### One shared preparation step

A Nix `let` string, `guardPrepare`, spliced into both scripts after the escape check. From `$cmd` it builds
`$checked`, the text the patterns run on:

1. **Normalise:** replace `'`, `"`, `(`, `)`, `` ` `` and `$(` with a space. `'nhs' p510`, `"nhs" p510`,
   `(nhs p510)`, `$(nhs p510)` and `bash -c 'nhs p510'` all become plain words, so the existing word-boundary
   patterns (`(^|[[:space:]])nhs([[:space:]]|$)`, `$just(p510|…)$end`) match them, and `just 'p510'` becomes
   `just  p510`.
2. **Split into invocations:** turn `&&`, `||`, `;`, `|`, `&` and newlines into newlines, one invocation per line.
3. **Drop read-only `just` inspections:** remove a line that is a `just` invocation (optionally after `NAME=value`
   words and `sudo`/`env`) carrying `-n`, `--dry-run`, `-s`, `--show`, `-l` or `--list` **before** its first
   non-option word. Only that line is dropped: `just -n razer && just razer` keeps the second line and stays
   blocked. A `just` inside `bash -c …` is not at the start of its line after step 1, so it is not dropped (blocks
   rather than allows).

The existing `grep -qE` calls then run on `$checked` instead of `$cmd`. grep is line-based already, so the existing
`[^|;]*` patterns behave as before within one invocation.

### The update script

A shared pattern, `updateScript`, `(^|[[:space:]/])update-commit-deploy\.sh([[:space:]]|$)`, added:

- to the bus guard's `disruptive` list (any host);
- to the p510 guard's `deploy_verb`, so `bash scripts/update-commit-deploy.sh p510`, `./scripts/…` and absolute
  paths match `($deploy_verb)[^|;]*p510`, and on p510 itself the existing "local switch names no host" branch
  (`$deploy_verb` alone) catches the script with no host argument.

`--no-deploy` gets no exception, exactly like `nhs --no-deploy` today (intent answer 1). `nhsb` / `just
update-commit` are unchanged (intent answer 2). `--evaluate` and `--summary` are not allowed (intent answer 3).

### Tests

`scripts/test-bus-guard.py` and `scripts/test-p510-deploy-guard.py` gain cases (both guards, and the p510 guard
with the hostname faked as p510 the way the existing suite does):

- now blocked: `bash scripts/update-commit-deploy.sh p510`, `./scripts/update-commit-deploy.sh razer`, an absolute
  path, the script with `--no-deploy` before and after the host, the script with no host (p510 guard on p510 only),
  `'nhs' p510`, `"nhs" p510`, `bash -c 'nhs p510'`, `(nhs p510)`, `$(nhs p510)`, `just 'p510'`,
  `just -n razer && just razer`, `just --show razer; just razer`;
- now allowed: `just -n razer`, `just --dry-run p510`, `just --show p510`, `just -s razer`, `just --list p510`,
  `FOO=1 just -n razer`;
- still allowed: everything the suites allow today (`nix build …`, `just --list`, `nhsb p510` / `just update-commit`
  for the bus guard, read-only ssh);
- still blocked: everything the suites block today.

## Alternatives rejected

- **Parse the command with a real shell parser (e.g. `bash -n` plus an AST tool):** much more code in a hook that
  runs on every Bash call; the text approach with normalisation covers the listed literal forms, which is what the
  intent promises.
- **Allow `just -n` by matching it anywhere in the command:** `just -n razer && just razer` would pass.
- **Exempt `--no-deploy` as read-only:** it commits, pushes and opens a PR (intent answer 1).
- **Two separate implementations, one per guard:** they already drifted once; one shared step keeps them equal.

## Risks

- **New false positives from normalisation:** a quoted argument such as `git commit -m 'run nhs p510 later'`
  becomes `run nhs p510 later` and blocks. The guards already match prose today (memory: bus guard matches prose);
  the workaround stays the same (write prose to a file). Tested with one such case to document it.
- **Hook cost:** a few `sed`/`grep` calls more per Bash call; negligible.
- **A broken guard blocks every Bash call or none:** the Python suites run the generated scripts; `just test-host
  p620` builds them; a p620 switch puts them live, checked by running a blocked and an allowed command after it.

## Verification

- `python3 scripts/test-bus-guard.py` and `python3 scripts/test-p510-deploy-guard.py` with all new cases;
  `just test-guards` passes.
- `just test-host p620` and `just test-host razer` build.
- After an announced p620 switch: `just -n razer` runs without a block; `bash scripts/update-commit-deploy.sh p510
  --help` is blocked by both guards (without escape variables; nothing runs).
