---
status: draft
issue: 2453
author: olafkfreund
---

# Intent: agy coder guard hardening follow-ups

## Problem

The agy coder guard (`modules/programs/agy-guard-adapter.sh`) keeps
`agy-implement` writing only inside its task worktree. The #2452 review found
three gaps that the #2452 fix left out on purpose:

1. **Writes that run code later, outside the sandbox.** A write inside the
   worktree is allowed, but some paths there run code the next time the user
   or Claude touches the tree: `<wt>/.git` (a `gitdir:` file pointing at a
   fake git dir with `core.fsmonitor`), `<wt>/.claude/settings.json` (project
   hooks), `.envrc` / `.direnv` (direnv), and `devenv.nix`. The next
   `git status` or `cd` runs them unsandboxed. `.gemini` is already denied;
   these are not.
2. **Duplicate JSON keys.** For `{"Path":"/etc/x","Path":"<wt>/a"}` jq checks
   the last value. If agy's parser takes the first, the guard approves one
   path and agy writes another.
3. **Gaps the PR #2454 review found:**
   - **A hard link defeats the path fence.** `run_command ln ~/.bashrc ./h`
     followed by `write_file <wt>/h` resolves inside the worktree, so it is
     allowed, and the write lands in `~/.bashrc`. Whether agy's sandbox stops
     the cross-mount link has not been tested.
   - **Unknown path arguments are allowed.** In
     `write_file {Path:"<wt>/a", FilePath:"/etc/x"}` only the argument names
     the guard knows are checked. This is a bypass if agy reads any other path
     argument.
   - **An empty trailing value is skipped.** `TargetFile:""` placed last is
     never checked. This is not an escape, but it breaks the fail-closed rule.
   - **A symlink race** between a parallel `run_command` and a `write_file`
     cannot be closed by a hook. Write it down as accepted and rely on the
     sandbox.
4. **The guard probe is manual.** agy's 1.4.5 tool rename (#2447) shipped
   unnoticed and broke every edit until #2452. The auto-updater has since
   bumped agy to 1.4.6 (#2459) with no probe run either.

## Proposed outcome

- `agy-implement` is denied a write to any of the code-running paths above,
  with a message that names the path, and the guard's test script covers each
  one.
- A tool call whose `args` contain a duplicate key is denied.
- A write tool call is denied when its target has more than one hard link,
  when it carries an argument outside the known set for that tool, or when any
  path value is empty.
- `update-antigravity` (the script and the slash command) runs
  `agy-guard-adapter.test.sh` plus a live probe against the new agy, and
  refuses the bump when either fails.

## Affected users and systems

- `modules/programs/agy-guard-adapter.sh` and its `.test.sh`
- `scripts/update-antigravity.sh`, `.claude/commands/update-antigravity.md`,
  and the scheduled auto-update that produced #2447 / #2459
- p620 and razer (both run agy and the guard). p510 is not affected.
- Anyone running `agy-implement`. `agy --mode plan` and `codex-implement` are
  unchanged.

## Constraints

- The guard stays fail-closed. A new check that cannot decide must deny.
- No new legitimate edit may be blocked. `agy-implement` works on normal
  source files, including `.nix` files other than `devenv.nix`.
- The live probe must not need a deploy or touch the shared checkout. It runs
  in a scratch repo, as the #2452 reproduction did.
- Nothing about the sandbox flag changes (#2296).

## Open questions

1. **Split out the orchestration half of #2453?** The issue also asks to let
   Claude dispatch Codex and agy as coders and reviewers without being asked
   each time (`coders:` / `reviewers:` in `plan/` frontmatter, plus changes to
   `AGENTS.md`, the `handoff`, `second-opinion` and `team` skills, and the
   managed CLAUDE.md model split). That is a policy change, not a guard fix,
   and it touches different files. Recommendation: a separate issue and
   intent, with this task covering the guard only.
2. **Deny list for code-running paths:** the four above are a start. Should
   it also cover `.vscode/`, `.githooks/`, `.pre-commit-config.yaml` and
   `flake.nix`? `flake.nix` is the main thing agy edits in this repo, so
   denying it would break real tasks. Recommendation: deny `.git`, `.claude`,
   `.envrc`, `.direnv`, `.githooks`, `.pre-commit-config.yaml` and
   `devenv.nix`, and leave `flake.nix` allowed.
3. **Auto-update behaviour on a failed probe:** should the scheduled updater
   skip the bump silently, or open an issue? Recommendation: open an issue.
