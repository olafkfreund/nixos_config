---
status: approved
issue: 3047
intent: intent/2026-11-17-3047-deploy-guard-gaps.md
---

# Spec: deploy guards catch the script path, quoted forms, and allow dry runs

## Design

Changes are in `modules/programs/claude-code-managed.nix`: `deployGuardScript` (p510 guard, ~line 355) and
`busAnnounceScript` (~line 530), plus one new shell file both of them source. Both keep their escape checks
(`P510_DEPLOY_APPROVED=1`, `AGENT_BUS_ANNOUNCED=1`) on the raw command text, first, unchanged.

### One shared preparation step: `modules/programs/claude-guard-prepare.sh`

A plain shell file (not a Nix string), sourced in both guards right after the escape check with
`. ${./claude-guard-prepare.sh}`. It defines `guard_prepare`, which reads the raw command on stdin and prints
`$checked`, the text the patterns run on. Being a real file, it is linted by shellcheck and tested directly, and the
Python harnesses substitute its path the way they substitute the other interpolations (see Tests).

1. **Split into invocations, on the raw text:** turn `&&`, `||`, `;`, `|` and newlines into newlines. A single `&` is
   **not** a split point, so redirections such as `2>&1` stay inside their invocation (`nhs 2>&1 p510` remains one
   line and still matches `nhs … p510`).
2. **Drop only plain read-only `just` inspections.** A line is dropped only if all of these hold:
   - it contains none of `$(`, `` ` ``, `<(`, `>(`, `&` (so a substitution, process substitution, redirection to a
     descriptor, or a background job always keeps the line);
   - after optional `NAME=value` words it starts with `just` (no `sudo`, `env`, `bash -c` or other prefix; those
     lines are kept);
   - walking the words after `just`: `-f`, `--justfile`, `-d`, `--working-directory` consume the next word as their
     operand; one of `-n`, `--dry-run`, `-s`, `--show`, `-l`, `--list` seen as an option word (not as an operand)
     marks the line as an inspection; any other word starting with `-` is skipped; the first word not starting with
     `-` ends the walk. `just -f -n p510` is therefore **not** an inspection (`-n` is the justfile), and
     `just -n razer` is.
   Only that line is dropped: `just -n razer && just razer` keeps the second line.
3. **Normalise the remaining lines:** replace `'`, `"`, `(`, `)`, `` ` `` and `$` with a space. `'nhs' p510`,
   `"nhs" p510`, `(nhs p510)`, `$(nhs p510)`, `bash -c 'nhs p510'` and `just 'p510'` become plain words that the
   existing word-boundary patterns match.

The existing `grep -qE` calls then run on `$checked` instead of `$cmd`. grep is line-based already, so the existing
`[^|;]*` patterns behave as before within one invocation.

### The update script

A pattern `(^|[[:space:]/])update-commit-deploy\.sh([[:space:]]|$)` (the ERE as grep sees it must contain `\.sh`;
mind the quoting layer it is written in) added:

- to the bus guard's `disruptive` list (any host);
- to the p510 guard's `deploy_verb`, so `bash scripts/update-commit-deploy.sh p510`, `./scripts/…` and absolute paths
  match `($deploy_verb)[^|;]*p510`, and on p510 itself the existing "local switch names no host" branch
  (`$deploy_verb` alone) catches the script with no host argument.

`--no-deploy` gets no exception, like `nhs --no-deploy` today (intent answer 1). `nhsb` / `just update-commit` are
unchanged (intent answer 2). `--evaluate` and `--summary` are not allowed (intent answer 3).

### Nix string traps

Both guards are `''…''` strings: a literal `''` must be written `'''`, a shell `${…}` must be `''${…}`, and only the
intended Nix interpolations (`${pkgs.jq}`, `${pkgs.gnugrep}`, `${./claude-guard-prepare.sh}`) stay unescaped. The
prepare file itself has none of these traps.

### Tests

- `modules/programs/claude-guard-prepare.test.sh` (new): feeds commands to `guard_prepare` and asserts the printed
  lines, including every drop and keep rule above.
- `scripts/test-bus-guard.py` and `scripts/test-p510-deploy-guard.py`: their extraction of the script bodies gains a
  substitution of `${./claude-guard-prepare.sh}` with the real file path, so the harness runs exactly what Nix
  generates. Expected results are listed per context: bus guard, p510 guard off p510, p510 guard on p510 (faked
  hostname, as the suite already does).
  - Now blocked (bus; and p510 guard where the host is p510 or the context is local-p510):
    `bash scripts/update-commit-deploy.sh p510`, `./scripts/update-commit-deploy.sh razer`, an absolute path, the
    script with `--no-deploy` before and after the host, the script with no host (p510 guard on p510 only),
    `bash scripts/update-commit-deploy.sh 2>&1 p510`, `nhs 2>&1 p510`, `'nhs' p510`, `"nhs" p510`,
    `bash -c 'nhs p510'`, `(nhs p510)`, `$(nhs p510)`, `just 'p510'`.
  - Still blocked although they contain an inspection: `just -n "$(sudo nhs p510)"`, ``just -n `nhs p510` ``,
    `just -f -n p510`, `sudo just -n p510`, `env X=1 just -n p510`, `just -n razer & just p510`, and
    `just -n p510` followed by `just p510` joined by newline, `&&`, `||`, `;` and `|`.
  - Now allowed (all contexts): `just -n razer`, `just --dry-run p510`, `just --show p510`, `just -s razer`,
    `just --list p510`, `FOO=1 just -n p510`, `just -f Justfile -n p510`.
  - Context-specific: `just -n razer; just razer` is blocked by the bus guard and allowed by the p510 guard off p510.
  - Still allowed and still blocked: every existing case in both suites (68 today).
  - Documented false positive: `git commit -m 'run nhs p510 later'` blocks (prose; write it to a file).

## Alternatives rejected

- **Parse with a real shell parser:** much more code in a hook on every Bash call; the listed literal forms are the
  promise.
- **Allow `just -n` anywhere in the command:** `just -n razer && just razer` would pass.
- **Normalise before deciding what to drop:** erases `$(`/backticks, so a substitution inside an inspection would be
  dropped with it (review finding).
- **Split on single `&`:** breaks `2>&1` and loses the verb-plus-host match (review finding).
- **Exempt `--no-deploy`:** it commits, pushes and opens a PR (intent answer 1).
- **The shared step as a Nix string spliced into both guards:** the Python harnesses read the raw Nix source and
  would run it unexpanded (review finding); a real file is testable.

## Risks

- **New false positives from normalisation:** quoted prose naming a deploy (`-m 'run nhs p510'`) blocks; the guards
  already match prose today and the workaround is unchanged.
- **Hook cost:** one sourced file and a few `sed`/`grep`/`awk` calls per Bash call; negligible.
- **A broken guard blocks every Bash call or none:** the suites run the generated text; `just test-host p620` builds
  it; after the announced p620 switch, one blocked and one allowed command are run to prove it live.

## Verification

- `bash modules/programs/claude-guard-prepare.test.sh`, `python3 scripts/test-bus-guard.py`,
  `python3 scripts/test-p510-deploy-guard.py`; `just test-guards` runs all three and passes; shellcheck on the
  prepare file.
- `just test-host p620` and `just test-host razer` build.
- After an announced p620 switch: `just -n razer` runs without a block; `bash scripts/update-commit-deploy.sh p510
  --help` is blocked by both guards (no escape variables; nothing runs).
