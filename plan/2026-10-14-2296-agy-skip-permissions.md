---
status: approved
issue: 2296
spec: spec/2026-10-14-2296-agy-skip-permissions.md
---

# Plan: agy-implement runs with --dangerously-skip-permissions under the guard

Worktree `../nixos-2296`, branch `feat/2296-agy-skip-permissions`.

## Approved decisions (carried over from the spec)

- `agy-implement` passes `--dangerously-skip-permissions` itself, and only
  after both guard checks pass. The per-run shadow home from #2291 is
  removed.
- **Kept unchanged:**
  - both fail-closed checks;
  - `--mode accept-edits`;
  - `--sandbox`;
  - the `--model gemini-4-argon-medium` default (skipped when `--model` or
    `--effort` is passed);
  - the adapter `modules/programs/agy-guard-adapter.sh` (deny by default,
    the `.gemini` fence, the shared guard for `run_command`).
- **The flag stays banned everywhere else:** plain `agy`, `--mode plan` and
  Codex. `HUMANIZE_CODEX_BYPASS_SANDBOX` stays banned.
- **The main risk** is an agy release that skips hooks under the flag. The
  mitigation is a required probe after every agy bump, written into the
  skill.
- **razer's `--model` note** stays until razer's agy is signed in with the
  Ultra account. Step 4 decides.
- **Probe on p620 (2026-10-14):** under the flag, the edit ran, `git commit`
  was blocked by the guard, a `touch ~/.gemini/...` was blocked by the fence,
  and there were no `denied_actions`.

## Steps

1. **`home/development/antigravity-config.nix:120-173`, the `agyImplement` wrapper.**
   - Delete:
     - the comment lines 124-125 ("agy runs under a per-run shadow HOME ...");
     - everything from the `shadow="$(mktemp ...` line through the
       `settings.json` jq block (lines 142-163).
   - Replace the last three lines (`# shellcheck disable=SC2086`, the
     `HOME="$shadow" ...` line and `exit $?`) with:

     ```sh
     # shellcheck disable=SC2086
     AGY_CODER=1 exec agy --mode accept-edits --sandbox --dangerously-skip-permissions $model "$@"
     ```

   - Add one line to the comment above the wrapper: "The guard is the only
     barrier under --dangerously-skip-permissions, which is why both checks
     must pass first (#2296)."

   Verify:
   - `just check-syntax`;
   - with `set -o pipefail`,
     `nix build --no-link --print-out-paths .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.path`;
   - `shellcheck` on the built `bin/agy-implement`;
   - a run with a stub `agy` first on `PATH` (printing its args): exactly one
     `--model` and the flag present, and no `--model` added when `--effort`
     is passed.

   Traps:
   - `''${` escaping in the Nix string;
   - keep comments minimal.

2. **`AGENTS.md:66-67`.** Replace the bullet with:

   > Never set `HUMANIZE_CODEX_BYPASS_SANDBOX`, and never pass
   > `--dangerously-skip-permissions` to plain `agy`, `--mode plan` or Codex.
   > They drop the sandbox. The one exception is `agy-implement`, which adds
   > the flag itself after confirming the coder guard (Issue #2296).

   Then, in **`home/development/claude-code-skills/handoff/SKILL.md`**:
   - **"Never" list:** change the `--dangerously-skip-permissions` item to
     "passing `--dangerously-skip-permissions` yourself; `agy-implement`
     already adds it, under the guard".
   - **New section "After an agy update",** before "Never". Before the first
     handoff on a new agy version, run the guard probe in a scratch git
     repo:
     - append a line;
     - `git commit -am x`;
     - `touch ~/.gemini/probe`.

     The edit must succeed, the commit and the touch must be blocked, and
     `HEAD` must not move. If either is not blocked, stop and tell the user:
     hooks no longer fire under the flag.

   Verify:
   - `pre-commit run --files AGENTS.md home/development/claude-code-skills/handoff/SKILL.md`;
   - the same files with `--hook-stage pre-push`.

   Trap: write "Issue #2296", never a line that starts with "#2296".

3. **Deploy p620 and verify.** Read the bus with `recent`, `post`, run
   `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just p620` from the
   worktree, then post completion. Before deploying, rebase onto
   `origin/main` if it has moved, so main's changes are not rolled back.

   In a scratch repo under the scratchpad:
   - **The guard probe** from step 2, run through `agy-implement`. The edit
     is made, the commit and the touch are blocked, `HEAD` is unchanged, and
     there are no `denied_actions`.
   - **`pgrep -af 'agy --mode accept-edits'`** during the run shows the flag
     and one `--model`.
   - **Plain `agy -p "run date"`** still has `denied_actions` containing
     `command`.

4. **Deploy razer and verify.** Announce, then run
   `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just deploy-via-p620 razer`
   and run the guard probe over ssh.
   - If `agy models` on razer lists `gemini-4-argon-medium`, probe without
     `--model` and delete the razer sentence from `SKILL.md:31-32` in a
     follow-up commit on this branch.
   - Otherwise probe with `--model gemini-3.8-flash-medium` and keep the
     note.

   p510 is not deployed.

## Tests

| Command | Expected |
| --- | --- |
| `just check-syntax` | passes |
| p620 `home.path` and toplevel builds | succeed (`pipefail`) |
| `shellcheck` on `agy-implement` | clean |
| Stub `agy` run | the flag is present, one `--model` |
| Step 3 and step 4 probes | as listed |

## Rollback

Revert the squash-merged PR and redeploy p620 and razer. That restores the
shadow-home wrapper from Issue #2291. There is no state to clean.

## Handoff note

Steps 1–2 edit three files, which meets the managed rule's three-file
threshold, so the `coder` subagent implements steps 1–2. Claude reviews the
work and runs steps 3–4.

## Deviations from the Opus review

Under the flag, the guard is the only barrier, so every way around it had
to be closed:

- **The wrapper pins `HOME`.** It now runs with
  `HOME=${config.home.homeDirectory}` and clears
  `CASCADE_GLOBAL_CONFIG_OVERRIDE`. Before this, `HOME=/tmp/x agy-implement`
  passed both checks, because they use fixed paths, and then agy loaded a
  `hooks.json` with no guard.
- **The wrapper refuses config-dir flags.** It rejects flag arguments
  matching `gemini_dir`, `gemini-dir`, `config…dir` or `config_override`.
  A probe showed that agy accepts `--gemini_dir=`. Prompt text is not
  matched.
- **The hooks check is exact.** It compares the whole `coder-guard` entry
  with the generated `coderGuardHookEntry`, instead of a substring.
- **The adapter fences file writes.**
  - `write_to_file`, `replace_file_content` and `multi_replace_file_content`
    must have a `TargetFile` that resolves inside `$PWD`, which is the task
    worktree.
  - A probe showed that `--sandbox` confines shell commands only:
    `write_to_file` created a file outside the worktree.
  - `realpath` comes from coreutils, substituted as `@realpath@` in
    `modules/programs/claude-code-managed.nix`.
- **The skill's post-update probe** adds a `write_to_file` outside the repo,
  which must be blocked. The skill also notes that a guard block does not
  show in `denied_actions`.
- **The razer note is removed.** The user signed razer's agy in with the
  Ultra account, so the step-4 probe runs without `--model`.
