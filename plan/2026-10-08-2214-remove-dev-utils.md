---
status: approved
issue: 2214
spec: spec/2026-10-08-2214-remove-dev-utils.md
---

# Plan: remove the dev-utils flake app

## Summary of approved decisions

- Delete the `dev-utils` app in two places and nothing else: its entry in `apps.x86_64-linux` in `flake.nix`, and
  its attribute in `tools/default.nix`. No replacement.
- The intent was approved on the condition that nothing breaks. Steps 2 and 5 prove that by comparing build hashes
  before and after:
  - the system toplevel `drvPath` of p620, razer and p510
  - the `drvPath` of the `deploy` and `test` apps

  Every hash must be identical.
- PR #2213 deletes the blocks directly above both edits, so this branch is rebased onto `main` after #2213 merges.
  The edits use the anchor text below, not line numbers, because the lines move with the rebase.
- Two file edits in two files sits below the coder-handoff threshold, so the session implements it directly.

## Steps

1. Wait until PR #2213 is merged, then rebase: `git fetch origin && git rebase origin/main` in
   `~/.config/nixos-2214`.
   → verify that `git log --oneline origin/main -5` shows the #2205 commits and that the rebase is clean.
   Traps: never check out a branch in `~/.config/nixos`.

2. Record the baseline before editing. Write it to the session scratchpad as `baseline.txt`:
   - `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`, for p620, razer and p510
   - `nix eval --raw .#apps.x86_64-linux.deploy.program` and `...test.program`, the output paths that identify
     the derivations

   → verify that `baseline.txt` has 5 non-empty lines.
   Traps: evaluation only. Nothing is built for p510.

3. `flake.nix`: in `apps.x86_64-linux`, delete the four lines from `dev-utils = {` through its closing `};`. Keep
   the `test = { ... };` entry above it and the set's closing `};` below it.
   → verify with `grep -n dev-utils flake.nix`, which prints nothing, and with `nix-instantiate --parse flake.nix`.
   Traps: none.

4. `tools/default.nix`: delete from `# Development utilities` through the `};` that closes
   `dev-utils = pkgs.writeShellApplication {`, plus the blank line before the comment if one is left trailing.
   The file's final `}` stays, and it must directly follow the `test` attribute's `};`.
   → verify with `grep -n dev-utils tools/default.nix`, which prints nothing, and with
   `nix-instantiate --parse tools/default.nix`.
   Traps: none.

5. Re-evaluate the five values from step 2 into `after.txt`.
   → verify with `diff baseline.txt after.txt`, which prints nothing.
   Traps: if any hash differs, stop and report. That is the approval condition failing.

6. Commit steps 3-4 as one commit, `chore(flake): remove the never-built dev-utils app (#2214)`, with the message
   passed through `-F`.
   → verify that the pre-commit hooks pass.

## Tests

1. Step 5's diff is empty: no host and no remaining app changed.
2. `nix eval .#apps.x86_64-linux --apply builtins.attrNames` gives `[ "deploy" "test" ]`.
3. `nix build --no-link` of the `deploy` and `test` app programs succeeds:

   ```bash
   nix build --no-link --impure --expr \
     '(import ./tools/default.nix { pkgs = (builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.x86_64-linux; }).deploy'
   ```

   Run it again with `.test` in place of `.deploy`.
4. `grep -rn "dev-utils" --exclude-dir=.git .` finds nothing outside `intent/`, `spec/` and `plan/`.
5. `just check-syntax` and `nix flake check --no-build` pass.
6. Push, then open a PR that links all three artifacts and closes Issue #2214.

No deploy is involved. No host changes, as test 1 proves.

## Rollback

`git revert` of the commit restores both blocks. No state is involved.
