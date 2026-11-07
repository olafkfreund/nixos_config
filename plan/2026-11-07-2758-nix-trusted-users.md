---
status: draft
issue: 2758
spec: spec/2026-11-07-2758-nix-trusted-users.md
coders:
  1: coder # VM test; codex-implement and agy-implement are barred until #2757 ships
  3: coder # small Nix edit in one module; same reason
  4: coder # two host files, one attribute each; same reason
  5: coder # mechanical deletions in three files; agy would be the default, barred until #2757
  6: coder # Justfile recipe logic; codex would be the default, barred until #2757
  8: coder # one-line edits in three files; same reason
  10: coder # one-line deletion; same reason
reviewers:
  - codex # independent read of the diff against this plan, strongest on shell and Nix logic
  - agy # second independent read, strongest on large mechanical edits (Justfile, flake.nix)
---

# Plan: drop olafkfreund from Nix trusted-users

Spec: `spec/2026-11-07-2758-nix-trusted-users.md` (approved). Intent:
`intent/2026-11-07-2758-nix-trusted-users.md` (approved). Sudo is #2759; a separate agent user is #2760.

## Decisions carried over from the spec

1. `olafkfreund` leaves `trusted-users` on p620 and razer. p510 keeps it through a host override
   until the owner's go-ahead; no team builds or deploys p510.
2. Every cache the flake names moves into `nix.settings` in `modules/nix/nix.nix`: devenv, nixarchy,
   hyprland, with the keys at `flake.nix:32-34`. cuda-maintainers is dropped (stale; misses on
   2026-10-23 and 2026-11-07 where `cache.nixos-cuda.org` hits). `cache.nixos-cuda.org` stays with
   nixarchy, which adds it on NVIDIA hosts. Duplicates are harmless. No `trusted-substituters`.
3. `accept-flake-config` goes: `modules/nix/flake-settings.nix:8`, the `nixConfig` block
   `flake.nix:4-36`, and the 11 `--accept-flake-config` flags in `Justfile`.
4. Signing: one agenix secret per building host, `secrets/nix-signing-key-p620.age` (recipients
   `olafkfreund`, `p620`) and `secrets/nix-signing-key-razer.age` (`olafkfreund`, `razer`). Each host
   declares `age.secrets.nix-signing-key` with `owner = "root"`, `mode = "0400"`.
   `secret-key-files` is set only where that secret is declared. Public keys `p620-nix-1:<pub>` and
   `razer-nix-1:<pub>` go into `trusted-public-keys` on all three hosts. The key never enters the store.
5. After a host's key is live, run `sudo nix store sign --all --key-file /run/agenix/nix-signing-key`
   once there.
6. `.drv` closures are signed on the invoking host before a `--build-host` upload:
   `sudo nix store sign -r --key-file /run/agenix/nix-signing-key <drv>`, with `<drv>` from
   `nix eval --raw .#nixosConfigurations.HOST.config.system.build.toplevel.drvPath`. Owner accepted
   this extra `sudo` while #2759 is open.
7. Paths built on p510 cannot reach an untrusted p620 or razer until p510's own change. Accepted.
8. Rollout: stage A (caches, keys, `nixConfig` removal) on p620, then razer. Stage B (trust removal)
   on razer first, then p620.
9. The VM test (step 1) runs first. If it fails, stop and revise the spec; no other step starts.

## Rules for every step

- Work in `~/.config/nixos-2758` (or a fresh worktree from `origin/main` for a later stage). Never
  check out a branch in `~/.config/nixos`.
- `git add` new files before any `nix build`/`nix eval`: flakes ignore untracked files.
- Run commands that might read stdin with `</dev/null`. Commit bodies go in a file, `git commit -F`.
- No deploy, switch, reboot, restart or GC by the coder. Deploys are the lead's or owner's, after the
  bus announcement (`read_new("#agents:freundcloud.org.uk")`, `post`, then `AGENT_BUS_ANNOUNCED=1`).
- Line numbers are from `origin/main` at `8f78b7d76`. PR #2763 (#2759) changes the same `Justfile`
  lines (adds `--ask-elevate-password`); if it merged first, rebase and find each line by its
  recipe name, not its number.
- Never print a secret. `test -r` / `-e` checks only.

## Steps

### Stage A: caches, keys, no flake config (still trusted)

1. **New `checks/nix-untrusted-remote-build.nix`; wire it in `checks/default.nix` (last attribute,
   before the closing `}` at the end of the file).**
   `pkgs.testers.runNixOSTest` with three nodes `builder`, `client`, `stranger`. Each node:
   `nix.settings.trusted-users = [ "root" ]`, `require-sigs = true`, `experimental-features =
   [ "nix-command" "flakes" ]`, its own signing key generated in the test script with
   `nix key generate-secret` into a root-only file named in `secret-key-files` (set
   `nix.extraOptions = "!include /etc/nix/test-signing.conf"` or write the file before the daemon
   starts and restart `nix-daemon` in the script), user `alice` with SSH keys to the other nodes.
   `builder` trusts `client`'s public key, `client` trusts `builder`'s, `stranger` trusts neither.
   Script, as `alice` on `client` unless stated:
   1. assert `nix store info` and `nix store info --store ssh-ng://<node>` report `Trusted: 0` on
      every node;
   2. build a path on `client` with signing off (`--option secret-key-files ''` as root), use it via
      `builtins.storePath` in a derivation's `inputSrcs`; `nix-copy-closure --to builder <drv>`
      must fail; after `sudo nix store sign -r --key-file <client key> <drv>` it must succeed;
   3. `ssh builder nix build '<drv>^*'` succeeds;
   4. `nix-copy-closure --from builder <out>` succeeds and `nix path-info --sigs <out>` shows the
      builder key;
   5. `nix copy --to ssh-ng://builder` of a fresh client-built path succeeds;
   6. a fresh output built on `builder`, asserted absent on `stranger`, copied to `stranger` fails
      with `lacks a signature by a trusted key`.
   → verify: `nix build .#checks.x86_64-linux.nix-untrusted-remote-build -L </dev/null` on p620
   (KVM) passes; `just check-syntax` passes.
   Traps: same nixpkgs as the hosts (it is: `checks/default.nix` gets `nixpkgs.legacyPackages`), so
   Nix 2.34.9. `nix flake check` (`just validate`) will now run a VM test and needs KVM; note it in
   the PR. CI skips `nix flake check` (`.github/workflows/ci.yml:31`), so CI is unaffected.
   Gate: if any case fails, stop and report to the lead; the spec needs revising.

2. **Signing keys (lead, not a coder: secret material).**
   - `secrets.nix`: add
     `"secrets/nix-signing-key-p620.age".publicKeys = allUsers ++ [ p620 ];` and
     `"secrets/nix-signing-key-razer.age".publicKeys = allUsers ++ [ razer ];`, next to the
     per-host pair at `secrets.nix:116-117`.
   - For each host H in p620, razer, generate and encrypt without printing:
     `nix key generate-secret --key-name H-nix-1 | tee >(nix key convert-secret-to-public >H.pub) |
     ./scripts/manage-secrets.sh create nix-signing-key-H` from a non-tty stdin (agenix then copies
     stdin into the file). `H.pub` goes to a scratch dir and holds only the public key.
   → verify: `test -s secrets/nix-signing-key-H.age`; `agenix -d` piped to `wc -c` is non-zero (never
   to the terminal); `cat H.pub` matches `^H-nix-1:`.
   Traps: agenix with a non-tty stdin overwrites the target with stdin, so never run `edit` on an
   existing key non-interactively. Commit the `.age` files and `secrets.nix` together.

3. **`modules/nix/nix.nix:27-72`.**
   - `substituters` (`:64-67`): append `https://devenv.cachix.org`, `https://nixarchy.cachix.org`,
     `https://hyprland.cachix.org`.
   - `trusted-public-keys` (`:69-72`): append the devenv, nixarchy and hyprland keys from
     `flake.nix:32-34` verbatim, plus `p620-nix-1:<pub>` and `razer-nix-1:<pub>` from step 2.
   - Add `secret-key-files = lib.mkIf (config.age.secrets ? nix-signing-key)
     config.age.secrets.nix-signing-key.path;`.
   - Leave `trusted-users` (`:29`) alone in this stage. Delete the stale Cachix comment `:74-78`.
   → verify: `nix eval --json .#nixosConfigurations.{p620,razer,p510}.config.nix.settings.substituters`
   lists all five plus nixarchy's; `...secret-key-files` is the agenix path on p620/razer and absent
   on p510 (`nix eval` errors or returns the option default).
   Traps: if `config.age.secrets ?` recurses, move the `secret-key-files` line into the step 4 host
   declarations instead and record the deviation here.

4. **`hosts/p620/configuration.nix` and `hosts/razer/configuration.nix`: declare the secret.**
   Add `age.secrets.nix-signing-key = { file = ../../secrets/nix-signing-key-<host>.age;
   owner = "root"; mode = "0400"; };`. On p620 the existing `age.secrets = lib.mkIf ...` block
   (`:210-220`) is conditional: add a separate `age.secrets.nix-signing-key` attribute, do not put it
   inside that `mkIf`.
   → verify: `just test-host p620` and `just test-host razer` build;
   `nix eval .#nixosConfigurations.razer.config.nix.settings.secret-key-files` returns
   `/run/agenix/nix-signing-key`.
   Traps: no `builtins.readFile` of the key; no `pathExists` guard (the files exist after step 2).

5. **Remove flake-level config.**
   - `modules/nix/flake-settings.nix:7-8`: delete the comment and `accept-flake-config = true;`.
   - `flake.nix:4-36`: delete the whole `nixConfig` block (and the blank line after it).
   - `Justfile`: delete `--accept-flake-config` at `:493`, `:497`, `:502`, `:868`, `:978`, `:983`,
     `:1007`, `:1016`, `:1018`, `:1021`, `:1027` (11 flags).
   → verify: `grep -rn 'accept-flake-config\|nixConfig' Justfile flake.nix modules/` is empty;
   `nix eval .#nixosConfigurations.razer.config.nix.settings.accept-flake-config` is not `true`;
   `just check-syntax`; `just test-host razer` prints no `ignoring the client-specified setting`.
   Traps: `docs/guides/deployment-guide.md` and `docs/guides/CACHE-STRATEGY.md` mention the flag; update them in this commit;
   `scripts/` has none today (checked).

6. **`Justfile`: sign the `.drv` closure before a `--build-host` upload.**
   Add one private recipe next to `deploy-via-p620` (`:1010`):

   ```just
   _sign-drv HOST:
       #!/usr/bin/env bash
       set -euo pipefail
       # shortcut: skips when the invoking host has no key (p510), the copy then needs a trusted receiver
       [ -e /run/agenix/nix-signing-key ] || { echo "no signing key here, skipping"; exit 0; }
       drv=$(nix eval --raw .#nixosConfigurations.{{HOST}}.config.system.build.toplevel.drvPath)
       sudo nix store sign -r --key-file /run/agenix/nix-signing-key "$drv"
   ```

   Call `just _sign-drv <host>` (or make it a recipe dependency) before the `nixos-rebuild` line in
   the recipes that pass `--build-host`: `razer` (`:493`, host razer), `p510` (`:502`),
   `emergency-deploy` (`:868`), `deploy-fast` (`:978`), `deploy-cached` (`:1007`),
   `deploy-via-p620` (`:1018` branch only, host p620 builds; skip in the `hostname = p620` branch),
   `build-on-p620` (`:1027`).
   → verify: `just --evaluate` and `just --dry-run deploy-via-p620 razer </dev/null` show the sign
   call before the build; `shellcheck` on the shebang body passes at info level.
   Traps: after #2759 `sudo` asks for a password on p620/razer, so this is one more prompt per
   recipe (sudo caches the timestamp per tty); `-e` not `-r` because the file is root-only 0400;
   the bus guard matches `deploy`/`switch` words in command text, so write the commit body to a file.

7. **Rollout of stage A (lead/owner, not a coder).** Merge stage A to `main` through its own PR, then
   deploy p620, then razer. Then, still trusted, on each host:
   - `sudo test -r /run/agenix/nix-signing-key`, after the deploy and again after a reboot;
   - `nix config show | grep -E '^(secret-key-files|trusted-public-keys|substituters) '`;
   - `nix build --impure --expr '(import <nixpkgs> {}).writeText "sig-$RANDOM" "x"'` and
     `nix path-info --sigs` on it shows `H-nix-1`;
   - `sudo nix store sign --all --key-file /run/agenix/nix-signing-key` (decision 5);
   - on razer: `nix store verify --sigs-needed 1 -r /run/current-system` passes for a p620-built
     closure (after `just deploy-via-p620 razer`);
   - `nix config show | grep accept-flake-config` is not `true`.
   Traps: merge to `main` before deploying, because the nightly `system.autoUpgrade` (`nix.nix:7-18`)
   pulls `github:olafkfreund/nixos_config` main at 04:00 on p620 and razer and would undo a branch
   deploy. p510 picks up stage A only at its next owner-run deploy.

### Stage B: trust removal, razer first

1. **Trust removal, with p620 and p510 held back.**
   - `modules/nix/nix.nix:29`: `trusted-users = [ "root" ];`.
   - `hosts/p510/configuration.nix` (next to `nix.settings.build-dir` at `:941`):
     `nix.settings.trusted-users = [ "olafkfreund" ];` with a one-line comment naming #2758.
   - `hosts/p620/configuration.nix`: the same override, temporary, comment "removed in plan step 10".
   → verify: `nix eval --json .#nixosConfigurations.<h>.config.nix.settings.trusted-users` gives
   `["root"]` on razer and contains `olafkfreund` on p620 and p510; `just test-host razer`.
   Traps: the list merges, so the overrides add to `[ "root" ]`; do not `mkForce`.

2. **Rollout of step 8 (lead/owner).** Merge to `main`, deploy razer from p620
   (`nhs razer` or `just deploy-via-p620 razer`, run from p620), then run the after-removal checks in
   Tests on razer. Do not start step 10 until they pass and one further deploy to razer succeeds.

### Stage C: p620

 1. **`hosts/p620/configuration.nix`: delete the temporary override from step 8.**
    → verify: `nix eval ...p620.config.nix.settings.trusted-users` gives `["root"]`;
    `just test-host p620`.
    Rollout: merge, deploy p620 locally, run the after-removal checks on p620.

## Tests

- Step 1: `nix build .#checks.x86_64-linux.nix-untrusted-remote-build -L </dev/null` passes on p620.
- Every stage: `just check-syntax`, `just test-host p620`, `just test-host razer`. p510 is evaluated
  only (`nix eval .#nixosConfigurations.p510.config.system.build.toplevel.drvPath`), never built.
- After each trust removal, on the host:
  - `nix config show | grep '^trusted-users '` reports `root` only;
  - `nix store info --store daemon` reports `Trusted: 0`;
  - `just deploy-via-p620 razer` (from razer) and `nhs razer` (from p620) complete;
  - `nhs` locally completes;
  - a nixarchy path substitutes rather than builds: pick one from
    `nix path-info --store https://nixarchy.cachix.org <path>` and `nix build` it with `-L`;
  - `journalctl -u github-runner-nixarchy` shows the next job ran normally (p620).
- Fallback if `deploy-via-p620` fails on the `.drv` upload: `nhs razer` from p620 (local build, copy
  by signature). Record which one worked in the PR.

## Rollback

- Stage B or C: revert the trust-removal commit and redeploy the host. Root stays trusted, so
  `sudo nixos-rebuild switch --rollback` on the host works even when copies are refused.
- Stage A: a key that fails to decrypt makes every new local build fail at signing. Recover with
  `sudo nixos-rebuild switch --rollback`, or rebuild with `--option secret-key-files ''` (root is
  trusted). Keys and the cache list may otherwise stay; they are harmless alone.
- After #2759, each rollback needs the owner's sudo password on p620/razer.

## Open questions for the owner

1. Three PRs (stage A, step 8, step 10) so the nightly upgrade never reverts a branch deploy, or one
   PR with stage-gated merges? The plan assumes three.
2. With #2759 merged, deploys and `_sign-drv` prompt for your password, so stage rollouts need you at
   the terminal. Agreed?
