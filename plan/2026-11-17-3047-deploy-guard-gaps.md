---
status: approved
issue: 3047
spec: spec/2026-11-17-3047-deploy-guard-gaps.md
coders:
  1: codex # small, tricky shell: the split / drop / normalise rules and the word walk, with its test
  2: codex # regex and Nix '' quoting in two guards that run on every Bash call
  3: coder # mechanical: harness substitution and many base64 test cases
reviewers:
  - codex # independent read of the diff against this plan
  # agy: out of use by owner decision (#2748)
---

# Plan: deploy guards catch the script path, quoted forms, and allow dry runs

Branch `fix/3047-deploy-guard-gaps`, worktree `~/.config/nixos-shelfish`.

## Approved decisions (from the spec)

- New `modules/programs/claude-guard-prepare.sh` defining `guard_prepare`: raw command on stdin, prepared text on
  stdout. Sourced by both guards right after their escape check; the patterns then run on its output (`$checked`)
  instead of `$cmd`.
  1. Split the raw text into lines at `&&`, `||`, `;`, `|` and newlines; a single `&` is not a split point.
  2. Drop a line only if it contains none of `$(`, `` ` ``, `<(`, `>(`, `&`; it starts, after optional
     `NAME=value` words, with `just` (no other prefix); and the word walk finds an inspection flag: after `just`,
     `-f`/`--justfile`/`-d`/`--working-directory` consume the next word; `-n`, `--dry-run`, `-s`, `--show`, `-l`,
     `--list` as an option word marks an inspection; other `-…` words are skipped; the first other word ends the
     walk.
  3. In the kept lines replace `'`, `"`, `(`, `)`, `` ` `` and `$` with a space.
- Pattern `(^|[[:space:]/])update-commit-deploy\.sh([[:space:]]|$)` added to the bus guard's `disruptive` and to
  the p510 guard's `deploy_verb` (the ERE grep sees must contain `\.sh`).
- `--no-deploy` gets no exception; `nhsb` / `just update-commit` unchanged; `--evaluate`/`--summary` not allowed.
- Escape checks (`AGENT_BUS_ANNOUNCED=1`, `P510_DEPLOY_APPROVED=1`) stay first, on the raw text, unchanged.

## Deviation after review (2026-11-18)

The Codex and Opus reviews found three bypasses that the guards on main block; each now has a regression case in
both suites and fails against the original prepare step.

- Split only to decide what to drop. Kept segments are printed with their original `&&`, `||`, `;`, `|` (padded
  with a space each side, so `true;nhs p510` still has `nhs` as a word) and
  newlines, so `ssh p510 'cd /etc/nixos && sudo nixos-rebuild switch'` and `H=p510 && nhs $H` still match the
  host-plus-verb patterns (they passed the p510 guard when the split was printed as lines).
- Quotes are deleted, as the shell removes them, instead of becoming spaces; `$`, `(`, `)` and backticks still
  become spaces. `just --justfile="Justfile" p510` passed both guards when the quotes became spaces.
- The word walk drops a line only for `-f`/`--justfile`/`-d`/`--working-directory X` and the inspection flags;
  any other option ends the walk and keeps the line, because its value may look like `-n`
  (`just --shell-arg -n p510` runs the recipe).

- A segment is dropped only if it has no quote or backslash (they change word boundaries the split cannot see:
  `LABEL="text just -n p510" nhs p510`) and no option word after the inspection flag (`just -n --command nhs
  p510` runs the command despite `-n`).

Known limits, not regressions (main behaves the same): an option value the recipe patterns cannot skip
(`just --shell-arg 0 p510`), and words split by quotes (`nh''s p510`).

## Steps

- **Step 1:** `modules/programs/claude-guard-prepare.sh` and `modules/programs/claude-guard-prepare.test.sh` (new).
  - The prepare file: only a function definition (no top-level side effects, no `set -e`), bash using `sed` and
    `awk` from PATH. `guard_prepare` runs its pipeline with `pipefail` (locally, in a subshell) and returns non-zero
    when any tool fails, so a missing or broken tool is detectable by the caller.
  - The test sources the file and asserts the exact output lines for: each split operator; `2>&1` not split; each
    drop rule (dropped: `just -n razer`, `just --dry-run p510`, `just -s razer`, `just --show p510`,
    `just --list p510`, `FOO=1 just -n p510`, `just -f Justfile -n p510`; kept: `just -f -n p510`,
    `sudo just -n p510`, `env X=1 just -n p510`, `just -n "$(nhs p510)"`, ``just -n `nhs p510` ``,
    `just -n razer & just p510`, `just p510 -n`); `just -n razer && just razer` keeps only the second; the
    normalisation of `'nhs' p510`, `"nhs" p510`, `(nhs p510)`, `$(nhs p510)`, `bash -c 'nhs p510'`, `just 'p510'`;
    with `PATH` lacking `sed` (and again lacking `awk`), `guard_prepare` returns non-zero.
  Check: `bash modules/programs/claude-guard-prepare.test.sh` passes; shellcheck clean on both; break the
  substitution rule on purpose (drop the `$(` check) and see a case fail, then restore.
  Traps: the bus guard matches command text, so test data with deploy words must not appear in a Bash tool call:
  keep it inside the test file and run the file; base64 is not needed there because the file is read, not typed.

- **Step 2:** `modules/programs/claude-code-managed.nix`.
  - `deployGuardScript` (~line 355) and `busAnnounceScript` (~line 530): after the escape `case`, add
    `PATH=${lib.makeBinPath [ pkgs.gnused pkgs.gawk pkgs.coreutils ]}:$PATH`, `. ${./claude-guard-prepare.sh}`
    and `checked="$(printf '%s' "$cmd" | guard_prepare)" || { echo "BLOCKED: guard could not check this command
    (guard_prepare failed)." >&2; exit 2; }` (fail closed: a guard that cannot read the command denies it), and
    change the final `printf '%s' "$cmd" | … grep -qE …` to read `"$checked"`. The hooks set no PATH of their own,
    so the tools must come from the guard script itself.
  - Add the update-script pattern to `deploy_verb` (p510 guard, line ~371) and to `disruptive` (bus guard,
    after line ~543).
  Check: `just test-host p620` builds; the existing `python3 scripts/test-bus-guard.py` and
  `python3 scripts/test-p510-deploy-guard.py` still pass once step 3's substitution is in (run step 3 right after).
  Traps: `''…''` strings: a shell `${…}` must be written `''${…}` and a literal `''` must be written `'''`; only
  `${pkgs.jq}`, `${pkgs.gnugrep}`, `${lib.makeBinPath …}` and `${./claude-guard-prepare.sh}` are Nix
  interpolations; avoid introducing either escape form, because the harnesses read the raw Nix source and do not
  decode them; the new file must be added to git or the flake cannot see it.

- **Step 3:** `scripts/test-bus-guard.py`, `scripts/test-p510-deploy-guard.py`, `Justfile` line ~164.
  - Both harnesses: add `.replace("${./claude-guard-prepare.sh}", <absolute path of
    modules/programs/claude-guard-prepare.sh>)` and replace the `${lib.makeBinPath …}` interpolation with an empty
    string (the test PATH supplies the tools) in the body substitution. They read raw Nix source, not the evaluated
    script; that limitation stays, which is why step 2 avoids `''${` and `'''`.
  - A harness case where the prepare file is replaced by one whose `guard_prepare` fails: both guards exit 2.
  - Add the spec's cases as base64 entries with the expected exit per context (bus; p510 guard off p510; p510 guard
    on p510): every "now blocked", "still blocked although they contain an inspection", "now allowed" and
    "context-specific" case in the spec's Tests section, plus the documented prose false positive; a negative
    filename case (`update-commit-deployXsh p510`, allowed by the bus guard and by the p510 guard on p510); and the
    unchanged decisions made explicit: `nhsb p510` and `just update-commit` allowed by the bus guard,
    `just --evaluate p510` and `just --summary p510` still blocked.
  - `test-guards`: add `@bash ./modules/programs/claude-guard-prepare.test.sh`.
  Check: both Python suites and `just test-guards` pass; the existing 68 cases are unchanged (diff shows only
  additions in the case lists).
  Traps: encode cases with `base64 -w0` from a file, never with the plain command in a tool call (the live guard
  would block the call).

- **Step 4 (lead):** all checks; `just test-host razer`; bus `read_new` + `post`; announced p620 switch with
  the meetingai / meeting-mode overrides if the bus or the session still needs them, and `just deploy-via-p620
  razer`. Live on p620: `just -n razer` as a real Bash tool call runs without a block. Then, without running any
  deploy command, a probe file feeds the JSON payload `{"tool_input":{"command":"bash
  scripts/update-commit-deploy.sh p510 --help"}}` (decoded from base64 inside the file) to each installed guard
  script (paths from the deployed managed settings) and checks each exits 2 independently. Commit per step,
  PR linking intent, spec and plan (who did which step), Opus review of the diff, Codex review.

## Tests

- `bash modules/programs/claude-guard-prepare.test.sh`, `python3 scripts/test-bus-guard.py`,
  `python3 scripts/test-p510-deploy-guard.py`, `just test-guards`.
- `just test-host p620`, `just test-host razer`.
- Step 4's live checks.

## Rollback

Revert the PR and switch. The guards go back to matching the raw text.
