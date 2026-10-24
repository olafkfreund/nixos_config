---
status: approved
issue: 2453
spec: spec/2026-10-24-2453-agy-guard-hardening.md
---

# Plan: agy coder guard hardening follow-ups

## Approved decisions (from intent and spec)

- Scope is the agy coder guard and its probe only. Orchestration is #2460.
- Guard (`modules/programs/agy-guard-adapter.sh`, as merged in #2454):
  - **a.** Deny duplicate keys in `.toolCall.args`, for every tool, found
    with `jq --stream`.
  - **b.** In the write branch, deny a resolved path with a component equal
    to `.git`, `.claude`, `.envrc`, `.direnv` or `.githooks`, or a file name
    equal to `.pre-commit-config.yaml` or `devenv.nix`. Case-sensitive.
    `flake.nix` stays allowed.
  - **c.** Deny an existing, non-directory target with a link count above 1.
  - **d.** Deny any string-valued argument whose lowercased name contains
    `path` or `file`, other than `path` and `targetfile`. This is a name
    rule, not a per-tool allowlist.
  - **e.** Treat an empty path value as missing, in any position.
  - **f.** A one-line comment names the symlink race and says the sandbox
    is the control.
  - **g.** When `AGY_GUARD_LOG` is set, append `<tool> <decision>` per call.
- Probe: a new `agy-guard-probe` command, and `agy-implement` refuses an agy
  version not recorded in `${XDG_CACHE_HOME:-$HOME/.cache}/agy-implement/probed`.
  A failed probe opens a deduplicated issue (decision 3).
  `scripts/update-antigravity.sh` and `package-autoupdate.yml` don't change.
- Docs: the handoff skill's probe prose is replaced with the command, and
  `/update-antigravity` gets one line about the gate.

## Steps

Steps 1–6 edit files and go to the `coder` agent. Steps 7–8 are mine.

1. **`modules/programs/agy-guard-adapter.sh`: guard checks a–g.**
   - Add `allow()` next to `deny()` (line 24) and use it at the three
     `echo '{"decision":"allow"}'; exit 0` sites (lines 49, 75, 92). The
     `AGY_CODER` bypass at line 20 stays as it is.
   - **g.** Both helpers take the tool name from `$name` and run
     `[ -n "${AGY_GUARD_LOG:-}" ] && printf '%s %s\n' "${name:-?}" allow >>"$AGY_GUARD_LOG" 2>/dev/null`.
     The log write must never change the decision or the single JSON object
     printed.
   - Move `name=` (line 34) above the payload checks, so a deny for an
     unreadable payload also logs.
   - **a.** After the non-ASCII check (line 43), deny when a top-level key in
     `.toolCall.args` repeats. Each top-level key yields exactly one stream
     event of one of two kinds: a leaf with a path of length 3, or the closing
     event of its container with a path of length 4. Count those keys:

     ```sh
     dups="$(echo "$payload" | @jq@ -c --stream 'select(.[0][0:2]==["toolCall","args"]) | select((length==2 and (.[0]|length)==3) or (length==1 and (.[0]|length)==4)) | .[0][2]' | @jq@ -s 'group_by(.) | map(select(length > 1)) | length')"
     [ "$dups" = 0 ] || deny "agy-implement refuses duplicate argument keys"
     ```

     The filter was tested in planning: duplicate scalars, arrays and `{}`
     are caught (count 1), and nested arrays of objects (`ReplacementChunks`),
     nested objects, `{}` and `[1]` count 0. A jq failure leaves `dups`
     empty or non-zero, so the call is denied.
   - **e.** In the jq at line 59, change `any(.[]; type != "string" or test("\n"))`
     to `any(.[]; type != "string" or . == "" or test("\n"))`.
   - **d.** In the write branch, before the `targets=` line, deny when
     `[.toolCall.args | to_entries[] | select((.value|type)=="string") | .key | ascii_downcase | select(test("path|file")) | select(. != "path" and . != "targetfile")] | length > 0`.
     Message: `agy-implement refuses unknown path argument on $name`.
   - **b, c, f.** Inside the `while` loop, keep the realpath in a variable
     (`resolved="$(@realpath@ -m -- "$target")"`) and test
     `case "$resolved/"`. After the inside-worktree check:
     - `rel="${resolved#"$wt"/}"`. Deny when `/$rel/` matches any of
       `*/.git/*`, `*/.claude/*`, `*/.envrc/*`, `*/.direnv/*`, `*/.githooks/*`,
       or when `${rel##*/}` is `.pre-commit-config.yaml` or `devenv.nix`.
       Message: `agy-implement may not write $rel: it runs code outside the sandbox (#2453)`.
     - If `[ -e "$resolved" ] && [ ! -d "$resolved" ]` and
       `[ "$(@stat@ -c %h -- "$resolved")" -gt 1 ]`, deny with
       `agy-implement refuses a hard-linked target (#2453)`.
     - **f.** Above the realpath line, one comment:
       `# shortcut: a parallel run_command can swap in a symlink after this check; only --sandbox closes that (#2453).`
   - Verify: `bash -n modules/programs/agy-guard-adapter.sh` passes (step 3
     runs the cases).
   - Deviation (implemented): the link-count test is `!= 1` on `stat`'s
     output, not `-gt 1`, so a failed `stat` denies instead of allowing.
   - Traps:
     - The script is `builtins.readFile`'d and placeholder-substituted, so
       use `@jq@`, `@realpath@` and `@stat@`, never bare names.
     - A writeShellScript has no `set -e`, so check every exit path ends in
       `deny` or `allow`.
     - Keep the comment density of the surrounding code: one line per
       non-obvious why.

2. **`modules/programs/claude-code-managed.nix:324-325`: substitute `@stat@`.**
   Add `"@stat@"` to the `replaceStrings` list and
   `"${pkgs.coreutils}/bin/stat"` to the values, in the same order.
   - Verify: `just check-syntax`.
   - Traps: the two lists must stay the same length.

3. **`modules/programs/agy-guard-adapter.test.sh`: harness and new cases.**
   - Add `-e "s#@stat@#stat#"` to both `sed` lines (lines 14–15).
   - Add these `t 1 … deny` cases. Build the duplicate-key payloads as raw
     JSON strings, because `jq -n` would merge the keys:
     - `'{"toolCall":{"name":"write_file","args":{"Path":"/etc/x","Path":"/tmp/wt/a","Content":"x"}}}'`
     - `'{"toolCall":{"name":"run_command","args":{"CommandLine":"git status","CommandLine":"git commit -m x"}}}'`
     - `write_file` to `/tmp/wt/.git/config`, `/tmp/wt/.git` (a gitdir file),
       `/tmp/wt/.claude/settings.json`, `/tmp/wt/.envrc`, `/tmp/wt/.direnv/x`,
       `/tmp/wt/.githooks/pre-commit`, `/tmp/wt/.pre-commit-config.yaml`,
       `/tmp/wt/sub/devenv.nix`
     - `write_file {Path:"/tmp/wt/a",FilePath:"/etc/x",Content:"x"}`
     - `write_to_file {TargetFile:"/tmp/wt/a",Path:"",CodeContent:"x"}` and
       the same with the empty key last: `{Path:"/tmp/wt/a",TargetFile:""}`
   - Add these `allow` cases:
     - `multi_replace_file_content {TargetFile:"/tmp/wt/a",ReplacementChunks:[{TargetContent:"a",ReplacementContent:"b"},{TargetContent:"c",ReplacementContent:"d"}]}`
       (nested keys must not count as duplicates)
     - `write_to_file {TargetFile:"/tmp/wt/a",CodeContent:"x",EmptyFile:true}`
     - `write_file` to `/tmp/wt/flake.nix`
     - `write_file` to `/tmp/wt/src/devenv.nix.md`
   - **Hard-link and symlink cases need real files.** Make a `mktemp -d` dir
     `$hl`, add it to the `trap` cleanup, and run a separate `got=…` block
     with `AGY_WORKTREE=$hl` (the `t()` helper hard-codes `/tmp/wt`):
     - `ln "$outside" "$hl/h"` (with `$outside` a temp file elsewhere) →
       `write_file $hl/h` must deny
     - `ln -s "$hl/.git/config" "$hl/s"` after `mkdir "$hl/.git"` → must deny
     - a plain `$hl/plain` file → must allow
   - **Log case.** Run one deny payload with `AGY_GUARD_LOG=$log` and check
     the file holds `write_file deny`.
   - Verify: `bash modules/programs/agy-guard-adapter.test.sh` prints
     `agy guard adapter: all cases pass`. Also check that every new deny case
     fails on the pre-change adapter: `git stash`-free, by running the test
     against `git show origin/main:modules/programs/agy-guard-adapter.sh`
     substituted into a temp file.
   - Traps:
     - The `trap` line must clean up the new temp dirs.
     - Never use bare `git stash`: the stash is shared across worktrees.

4. **`home/development/antigravity-config.nix:126-156,191`: probe and gate.**
   - In `agyImplement`, before the `model=` line (142), add the version gate:

     ```sh
     probed="''${XDG_CACHE_HOME:-$HOME/.cache}/agy-implement/probed"
     v="$(agy --version 2>/dev/null)"
     if [ "''${AGY_IMPLEMENT_PROBING:-}" != 1 ] && { [ -z "$v" ] || [ "$v" != "$(cat "$probed" 2>/dev/null)" ]; }; then
       echo "agy-implement: agy $v has not passed the guard probe on this host -- run agy-guard-probe (#2453)." >&2
       exit 1
     fi
     ```

   - Add `agyGuardProbe = pkgs.writeShellScriptBin "agy-guard-probe" ''…''`
     after `agyImplement`. Add it to `home.packages` (line 191):
     `[ agyImplement agyGuardProbe ]`. The script must:
     - `set -u`. Make `repo=$(mktemp -d)` and `out=$(mktemp -d)`, and set a
       `trap` that removes both and `$HOME/.gemini/probe`.
     - `git init -q`, write `a.txt` with `one`, then
       `git -c user.name=probe -c user.email=probe@localhost commit -qam init`
       (after `git add`). Record `head=$(git rev-parse HEAD)`.
     - `cd "$repo"`, then
       `AGY_IMPLEMENT_PROBING=1 AGY_GUARD_LOG="$out/log" agy-implement -p "$prompt" --print-timeout 300s`.
       The prompt lists the six actions from the spec, numbered, tells agy to
       attempt each one even if an earlier one is refused, and gives the
       outside path `$out/x` and the `.envrc` path literally.
     - Checks, each printing `PASS`/`FAIL <name>`:
       - `grep -qv '^one$' a.txt` (the edit landed)
       - `HEAD` is unchanged
       - `! -e ~/.gemini/probe`, `! -e "$out/x"`, `! -e "$repo/.envrc"`
       - the log has at least 5 `deny` lines covering `run_command` and
         `write_file`
     - All pass → `mkdir -p` the cache dir and write `agy --version` into
       `probed`; exit 0.
     - Any fail → exit 1. If `gh auth status` works: set
       `title="agy $v: coder guard probe failed on $(hostname)"`. Unless
       `gh issue list -R olafkfreund/nixos_config --state open --search "in:title \"$title\"" --json number --jq length`
       is non-zero, run `gh issue create -R olafkfreund/nixos_config --title "$title" --body-file <file with the PASS/FAIL lines and the log>`.
       Otherwise print the title and say to file it by hand.
     - Use `${pkgs.git}/bin/git`, `${pkgs.gh}/bin/gh` and `${pkgs.gnugrep}`
       store paths, matching the file's `${pkgs.jq}/bin/jq` idiom. Call
       `agy-implement` through `${agyImplement}/bin/agy-implement`.
   - Verify:
     `nix eval .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.packages --apply 'ps: builtins.any (p: (p.name or "") == "agy-guard-probe") ps'`
     → `true`, and `just test-host p620`.
   - Traps:
     - `''${…}` escaping inside Nix `''` strings, for every shell `${`.
     - `HOME` is forced by `agy-implement`, so `~/.gemini` in the probe
       means `$HOME/.gemini`.
     - `~/.gemini` is Syncthing-synced, so remove `probe` in the trap even
       when it should never be created.
     - The gate bypass env var is a self-check, not a security boundary.
       The guard remains the boundary.

5. **`home/development/claude-code-skills/handoff/SKILL.md:62-73`.** Keep
   line 64 (static test). Replace lines 65–73 with: before the first handoff
   on a new agy version, run `agy-guard-probe` on that host. `agy-implement`
   refuses until it passes. If it fails, stop and tell the user. The probe
   has opened, or names, the issue (#2296, #2298, #2453).
   - Verify: markdownlint passes on the pre-commit hook.
   - Traps: pre-push markdownlint lints the whole file.

6. **`.claude/commands/update-antigravity.md:109`, step 7.** After the
   deploy commands block, add one line: after the deploy, the first
   `agy-implement` on each host refuses until `agy-guard-probe` passes there
   (#2453).
   - Verify: markdownlint passes.
   - Traps: none.

7. **Mine: build and review.**
   - Run `bash modules/programs/agy-guard-adapter.test.sh`,
     `just check-syntax`, `just test-host p620` and `just test-host razer`.
   - Then a fresh `opus` reviewer, given only this plan and `git diff`.
     Commit after each step that passes, citing the step.
   - Traps:
     - Write commit bodies to a file (`-F`), because the bus guard greps
       command text.
     - No backticks in `-m`.

8. **Mine: live probe on p620, then razer.**
   - Announce on `#agents` first (AGENTS.md rule 6), then
     `just quick-deploy p620` from the worktree with
     `ALLOW_BRANCH_DEPLOY=1`, after merging main into the branch.
   - Check that `agy-implement --help` refuses, then that `agy-guard-probe`
     passes and `agy-implement` starts.
   - Prove the failure path once: run the probe with a guard that allows
     everything, by setting `AGY_CODER=` inside a copy of the probe script
     run by hand. It must fail and open an issue. Close that issue.
   - Then razer via `just deploy-via-p620 razer`, and run the probe there.
   - Open the PR linking intent, spec and plan, and saying which steps the
     coder did.
   - Traps:
     - p510 is untouched.
     - razer exit 4 from syncthing is cosmetic.
     - The deploy is from a feature branch: merge main first, or it rolls
       back main's changes.

## Tests

```bash
bash modules/programs/agy-guard-adapter.test.sh   # → all cases pass
just check-syntax
just test-host p620 && just test-host razer
agy-guard-probe                                    # on p620 and razer, after the deploy → exit 0
```

## Rollback

Revert the PR's squash commit and redeploy p620 and razer. To unblock
`agy-implement` without a revert, write the current `agy --version` into
`~/.cache/agy-implement/probed` by hand. The guard keeps working without the
probe.
