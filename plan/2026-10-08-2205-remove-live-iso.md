---
status: approved
issue: 2205
spec: spec/2026-10-08-2205-remove-live-iso.md
---

# Plan: remove the per-host live installer ISO path

## Summary of approved decisions

- Pure deletion of the per-host live ISO path: nothing is renamed, moved,
  fixed or replaced. User installers stay in nixarchy.
- Removed: the `liveImages` binding, `live-iso-razer` package and `build-live`
  app in `flake.nix`; `lib/live-images.nix`; `modules/installer/`;
  `scripts/install-helpers/`; `build-live` in `tools/default.nix`;
  `pkgs.nixos-generators`; the Justfile "Live USB Installer Commands" section;
  the README live-installer section; the `/nix-live` agent command for Claude
  and Gemini, with its `/nix-help` mentions; the two `modules/installer/*`
  entries in `.gemini/state/topology.json`, edited by hand.
- Unchanged: `docs/`, `mkdocs.yml`, `mkdocs-full.yml` (nothing there refers to
  the live path); `deploy`, `test` and `dev-utils` in `tools/default.nix`.
- p510 is verified by evaluation only. Its full build is left to CI, and it is
  never built or deployed locally without asking.

Line numbers are as of commit `8c12bcc12`. Within a file, edit bottom-up or
find the anchor text quoted below, because earlier deletions shift later lines.

## Steps

1. Delete the whole-file pieces:
   `git rm -r lib/live-images.nix modules/installer scripts/install-helpers .claude/commands/nix-live.md .gemini/commands/nix-live.toml`
   → verify with `git status --short`, which shows 10 deletions: 1 lib file,
   3 module files, 4 helper scripts and 2 command files.
   Traps: none.

2. `flake.nix`, three edits, bottom-up:
   - Lines 650-653: delete the `build-live = { type = "app"; program =
     "${appPkgs.build-live}/bin/nixos-build-live"; };` block. Keep `test` above
     it and `dev-utils` below it.
   - Lines 605-607: delete `# Live ISO images`, the
     `live-iso-razer = liveImages.liveImages.live-iso-razer...;` line and the
     blank line after it.
   - Lines 379-383: delete `# Live image builder`, the 3-line
     `liveImages = import ./lib/live-images.nix { inherit nixpkgs inputs hostUsers; };`
     binding and the blank line after it. Leave `hostUsers`: other code uses it.

   → verify with `grep -n "liveImages\|live-iso\|build-live" flake.nix`, which
   prints nothing.
   Traps: never check out the branch in `~/.config/nixos`; work in
   `~/.config/nixos-2205`. A leftover `appPkgs.build-live` would still evaluate
   and only fail at build time, so the grep is the real check.

3. `tools/default.nix` lines 163-246: delete from `# Live USB builder`
   through the `};` closing `build-live = pkgs.writeShellApplication {` and
   the blank line after it. The next kept line is `# Development utilities`.
   → verify with `grep -n "build-live" tools/default.nix`, which prints nothing,
   and `nix-instantiate --parse tools/default.nix >/dev/null`.
   Traps: none.

4. `modules/development/nix.nix` line 25: delete `pkgs.nixos-generators`.
   → verify with `grep -n nixos-generators modules/development/nix.nix`, which
   prints nothing.
   Traps: none.

5. `Justfile` lines 1181-1333: delete from the
   `# Live USB Installer Commands` banner (its leading `# ===` line at 1181)
   through the blank line after `@echo "⚠️  WARNING: flash-live will ERASE the target device!"`.
   The next kept line is the `# ===` that opens `# MicroVM Management Commands`
   (old line 1334).
   → verify with `just --list >/dev/null`, which still parses, and
   `grep -n "live\b\|show-devices\|test-hw-config" Justfile`, which prints
   nothing for these recipes.
   Traps: the pre-commit "Validate justfile" hook runs on commit.

6. `README.md`, bottom-up:
   - Lines 225-237: delete from `## Live Installer` through the blank line
     before `## Theming`.
   - Line 124: change `(hostTypes, features, secrets, live-images)` to
     `(hostTypes, features, secrets)`, keeping the column alignment.

   → verify with `grep -n "live" README.md`, which shows no installer reference.
   Traps: the pre-push markdownlint lints the whole file, so pre-existing errors
   anywhere in README.md block the push and must be cleared too.

7. `.claude/commands/nix-help.md`, bottom-up:
   - Line 324: delete the `| Build live USB installer | /nix-live | 5-10min |` row.
   - Lines 76-85: delete from `**/nix-live** - Live USB installer management`
     through the blank line before `**/nix-microvm**`.

   → verify with `grep -n "nix-live\|live USB" .claude/commands/nix-help.md`,
   which prints nothing.
   Traps: same whole-file markdownlint as step 6.

8. `.gemini/state/topology.json` lines 98-99: delete
   `"modules/installer/installer-tools.nix",` and
   `"modules/installer/live-system.nix",`. Check the surrounding commas so the
   array stays valid JSON.
   → verify with `jq empty .gemini/state/topology.json` and
   `grep -n installer .gemini/state/topology.json`, which prints nothing.
   Traps: the pre-commit JSON formatter may reformat the file. Accept its output.

   **Step 8a, added during implementation:** `.github/workflows/ci.yml` line 140: drop
   `\|lib/live-images.nix\|modules/installer` from the secret-scan `grep -v`
   exclusions. The paths no longer exist, and the leftover made test 1 fail.
   → verify with test 1 below.
   Traps: none. Left on purpose: the example changelog entries in the
   `documentation-sync` agents and the `.agent-os/product/` history, which
   describe the past rather than instruct.

9. Commit steps 1-8 as one commit,
   `chore(installer): remove unused live ISO path and nixos-generators (#2205)`,
   with the message passed via `-F - <<'MSG'`, never `-m` with backticks.
   → verify that the pre-commit hooks pass.

## Tests

Run these from `~/.config/nixos-2205` after step 9:

1. Each grep below prints nothing:

   ```bash
   grep -rn "live-iso\|liveImages\|live-images\|install-helpers\|nixos-generators" --exclude-dir=.git . \
     | grep -v "^\(\./\)\?\(docs\|intent\|spec\|plan\)/"
   grep -rn "build-live\|flash-live\|nix-live" --exclude-dir=.git . \
     | grep -v "^\(\./\)\?\(docs\|intent\|spec\|plan\)/"
   ```

2. `just --list` succeeds.
3. `just check-syntax` passes.
4. `nix flake check --no-build` evaluates.
   `nix eval .#packages.x86_64-linux --apply builtins.attrNames` lacks
   `live-iso-razer`, and `nix eval .#apps.x86_64-linux --apply builtins.attrNames`
   lacks `build-live`.
5. `just test-host p620` and `just test-host razer` build. For p510, run only
   `nix eval .#nixosConfigurations.p510.config.system.build.toplevel.drvPath`.
6. `nix path-info -r` on the p620 toplevel built in test 5 contains no
   `nixos-generators`.
7. The pre-push hooks pass on `git push`. Then open the PR linking
   `intent/`, `spec/` and `plan/`, with `Closes #2205`.

No deploy is part of this plan. The change reaches the hosts through the
normal `nhs` / `just quick-deploy` flow after merge.

## Rollback

`git revert <commit>` on main restores every file. Nothing has state: no
service, secret or data path is touched, so a revert and a normal deploy are
the whole rollback.
