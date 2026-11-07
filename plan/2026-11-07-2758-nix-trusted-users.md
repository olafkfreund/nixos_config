---
status: approved
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

One numbered list across all stages: stage A is steps 1-7, stage B steps 8-9, stage C step 10.

1. **Stage A. New `checks/nix-untrusted-remote-build.nix`; wire it in `checks/default.nix` as the
   last attribute, before the file's closing `}`.**
   `pkgs.testers.runNixOSTest` with three nodes `builder`, `client`, `stranger`. Each node:
   `nix.settings.trusted-users = [ "root" ]`, `require-sigs = true`, `substituters = [ ]` (so nothing
   arrives by substitution), `experimental-features = [ "nix-command" "flakes" ]`, its own signing key
   generated in the test script with `nix key generate-secret` into a root-only file named in
   `secret-key-files` (write it, then restart `nix-daemon`), user `alice` with SSH keys to the other
   nodes. `builder` trusts `client`'s public key, `client` trusts `builder`'s, `stranger` neither.
   Every test derivation is input-addressed and carries a unique name, so no path pre-exists.
   Script, as `alice` on `client` unless stated:
   1. assert `nix store info` and `nix store info --store ssh-ng://<node>` report `Trusted: 0` on
      every node;
   2. as root on `client`, build a path with `--option secret-key-files ''` (unsigned); use it via
      `builtins.storePath` in the `inputSrcs` of derivation D; assert neither is valid on `builder`;
      `nix-copy-closure --to builder <D.drv>` must fail with `lacks a signature by a trusted key`;
      after `sudo nix store sign -r --key-file <client key> <D.drv>` it must succeed;
   3. assert D's output is absent on `client` and `builder`; `ssh builder nix build '<D.drv>^*'`
      succeeds; `ssh builder nix path-info --sigs <out>` shows the builder key;
   4. `nix-copy-closure --from builder <out>` succeeds;
   5. `nix copy --to ssh-ng://builder` of a fresh client-built path (absent on `builder` first)
      succeeds;
   6. a fresh output built on `builder`, asserted absent on `stranger`, copied to `stranger` fails
      with `lacks a signature by a trusted key`.
   → verify: `git add` the file, then `nix build .#checks.x86_64-linux.nix-untrusted-remote-build -L
   </dev/null` on p620 (KVM) passes; `just check-syntax` and `just validate` pass.
   Traps: same nixpkgs as the hosts (`checks/default.nix` gets `nixpkgs.legacyPackages`), so Nix
   2.34.9. `nix flake check` (`just validate`) now runs a VM test and needs KVM; say so in the PR.
   CI skips `nix flake check` (`.github/workflows/ci.yml:31`), so CI is unaffected.
   Gate: if any case fails, stop and report to the lead; the spec needs revising.

2. **Stage A. Signing keys (lead, not a coder: secret material).**
   - `secrets.nix`: add
     `"secrets/nix-signing-key-p620.age".publicKeys = allUsers ++ [ p620 ];` and
     `"secrets/nix-signing-key-razer.age".publicKeys = allUsers ++ [ razer ];`, next to the
     per-host pair at `secrets.nix:116-117`.
   - For each host H in p620, razer, generate and encrypt without printing, from a non-tty stdin
     (agenix then copies stdin into the file; `scripts/manage-secrets.sh:238-240` calls `agenix -e`):
     `set -o pipefail; nix key generate-secret --key-name H-nix-1 | tee >(nix key
     convert-secret-to-public >"$S/H.pub") | ./scripts/manage-secrets.sh create nix-signing-key-H`,
     where `$S` is a scratch dir. `H.pub` holds only the public key.
   → verify: `test -s secrets/nix-signing-key-H.age`;
   `agenix -d secrets/nix-signing-key-H.age | grep -q '^H-nix-1:'` exits 0 (output never shown);
   `grep -q '^H-nix-1:' "$S/H.pub"`.
   Traps: agenix with a non-tty stdin overwrites the target with stdin, so never run `edit` on an
   existing key non-interactively. Commit the `.age` files and `secrets.nix` together.

3. **Stage A. `modules/nix/nix.nix:64-78`: caches and public keys.**
   - `substituters` (`:64-67`): append `https://devenv.cachix.org`, `https://nixarchy.cachix.org`,
     `https://hyprland.cachix.org`.
   - `trusted-public-keys` (`:69-72`): append the devenv, nixarchy and hyprland keys from
     `flake.nix:32-34` verbatim, plus `p620-nix-1:<pub>` and `razer-nix-1:<pub>` from step 2.
   - Delete the stale Cachix comment `:74-78`. Leave `trusted-users` (`:29`) alone in this stage.
   → verify, per host: `for h in p620 razer p510; do nix eval --json
   ".#nixosConfigurations.$h.config.nix.settings.substituters" </dev/null; done` lists all five plus
   nixarchy's; the same loop on `trusted-public-keys` shows both host keys.
   Traps: none beyond the shared rules.

4. **Stage A. `hosts/p620/configuration.nix` and `hosts/razer/configuration.nix`: secret and
   `secret-key-files`.** Both live in the host file, not `nix.nix`, so no module reads
   `config.age.secrets` from inside `nix.settings` and p510 is left out by construction.
   - razer (no top-level `age.secrets` today; `age.identityPaths` is at `:631`): add
     `age.secrets.nix-signing-key = { file = ../../secrets/nix-signing-key-razer.age;
     owner = "root"; mode = "0400"; };` and
     `nix.settings.secret-key-files = config.age.secrets.nix-signing-key.path;`.
   - p620: `age.secrets = lib.mkIf (...) { api-huggingface = ...; };` at `:210-220` already binds
     `age.secrets`, so a second `age.secrets.nix-signing-key` line is a duplicate-attribute error.
     Change it to `age.secrets = lib.mkMerge [ (lib.mkIf (...) { api-huggingface = ...; })
     { nix-signing-key = { file = ../../secrets/nix-signing-key-p620.age; owner = "root";
     mode = "0400"; }; } ];`, keeping the huggingface body unchanged. Add the same
     `nix.settings.secret-key-files` line.
   → verify: `just test-host p620` and `just test-host razer` build; for p620 and razer,
   `nix eval --raw .#nixosConfigurations.<h>.config.nix.settings.secret-key-files` prints
   `/run/agenix/nix-signing-key`; for p510,
   `nix eval .#nixosConfigurations.p510.config.nix.settings --apply 's: s ? secret-key-files'`
   prints `false`; p620's `config.age.secrets` still contains
   `api-huggingface`.
   Traps: no `builtins.readFile` of the key; no `pathExists` guard (the files exist after step 2).

5. **Stage A. Remove flake-level config.**
   - `modules/nix/flake-settings.nix:7-8`: delete the comment and `accept-flake-config = true;`.
   - `flake.nix:4-36`: delete the whole `nixConfig` block (and the blank line after it).
   - `Justfile`: delete every `--accept-flake-config`. On `8f78b7d76` there are 11, at `:493`, `:497`,
     `:502`, `:868`, `:978`, `:983`, `:1007`, `:1016`, `:1018`, `:1021`, `:1027`; after a rebase,
     find them with `grep -n accept-flake-config Justfile`.
   - `docs/guides/deployment-guide.md:82` (the flag's bullet: delete it) and
     `docs/guides/CACHE-STRATEGY.md:17` (say the caches come from `nix.settings` in
     `modules/nix/nix.nix`, not from the flake). No page is added or moved, so no nav change.
   → verify: `grep -rn 'accept-flake-config\|nixConfig' Justfile flake.nix modules/ scripts/` is empty;
   `nix eval .#nixosConfigurations.razer.config.nix.settings --apply 's: s.accept-flake-config or
   false'` prints `false`; `just check-syntax`; `just test-host razer` prints no
   `ignoring the client-specified setting`; markdownlint passes on both docs (whole-file lint).
   Traps: pre-push lints the whole doc file, so fix any old MD013 failures it reports there.

6. **Stage A. `Justfile`: sign the `.drv` closure before a `--build-host` upload.**
   Add one private recipe next to `deploy-via-p620` (`:1010`). Its argument is the host whose
   configuration is being built:

   ```just
   _sign-drv HOST:
       #!/usr/bin/env bash
       set -euo pipefail
       # shortcut: skips when the invoking host has no key (p510); the copy then needs a trusted receiver
       [ -e /run/agenix/nix-signing-key ] || { echo "no signing key here, skipping"; exit 0; }
       drv=$(nix eval --raw ".#nixosConfigurations.{{HOST}}.config.system.build.toplevel.drvPath")
       sudo nix store sign -r --key-file /run/agenix/nix-signing-key "$drv"
   ```

   Make it a dependency, so `just` runs it first and stops if it fails: `razer: _require-main
   (_sign-drv "razer")`, `p510: ... (_sign-drv "p510")`, and `(_sign-drv HOST)` on
   `emergency-deploy` (`:868`), `deploy-fast` (`:978`), `deploy-cached` (`:1007`), `deploy-via-p620`
   (`:1010`) and `build-on-p620` (`:1025`). In `deploy-via-p620` on p620 itself the signing is
   unneeded but harmless.
   → verify: `just --dry-run deploy-via-p620 razer </dev/null` lists the `_sign-drv` body before
   the `nixos-rebuild` lines (dry-run prints dependency bodies); the same for each recipe above;
   `just --show _sign-drv` body passes `shellcheck -S info`; run `just _sign-drv razer` once on p620
   after step 7 and check `nix path-info --sigs` on the `.drv` shows `p620-nix-1`.
   Traps: after #2759 `sudo` asks for a password on p620/razer, so this is one more prompt per
   recipe (sudo caches the timestamp per tty). `-e`, not `-r`: the file is root-only 0400. The bus
   guard matches `deploy`/`switch` words in command text, so write the commit body to a file.

7. **Stage A. Rollout (lead/owner, not a coder).** Merge stage A to `main` through its own PR, then
   deploy p620, then razer. Then, still trusted, on each host H:
   - `sudo test -r /run/agenix/nix-signing-key` after the deploy;
   - announce on the bus and reboot H, then `sudo test -r /run/agenix/nix-signing-key` again: this
     proves agenix runs before nix-daemon at boot, which the VM test does not;
   - `nix config show | grep -E '^(secret-key-files|trusted-public-keys|substituters) '`;
   - a fresh build is signed: `n="sig-$(date +%s%N)"; p=$(nix build --no-link --print-out-paths
     --impure --expr "derivation { name = \"$n\"; system = \"x86_64-linux\"; builder = \"/bin/sh\";
     args = [ \"-c\" \"echo $n > \$out\" ]; }")`, then `nix path-info --sigs "$p"` shows `H-nix-1`;
   - `sudo nix store sign --all --key-file /run/agenix/nix-signing-key` (decision 5);
   - on razer: `nix store verify --sigs-needed 1 -r /run/current-system` passes for a p620-built
     closure (after `just deploy-via-p620 razer`);
   - `nix config show | grep '^accept-flake-config'` is not `= true`.
   Gate: stage B does not start until every check passes on both hosts, both reboots included.
   Traps: merge to `main` before deploying, because the nightly `system.autoUpgrade` (`nix.nix:7-18`)
   pulls `github:olafkfreund/nixos_config` main at 04:00 on p620 and razer and would undo a branch
   deploy. p510 picks up stage A only at its next owner-run deploy.

8. **Stage B. Trust removal, with p620 and p510 held back.**
   - `modules/nix/nix.nix:29`: `trusted-users = [ "root" ];`.
   - `hosts/p510/configuration.nix` (next to `nix.settings.build-dir` at `:941`):
     `nix.settings.trusted-users = [ "olafkfreund" ];` with a one-line comment naming #2758.
   - `hosts/p620/configuration.nix`: the same override, temporary, comment "removed in plan step 10".
   → verify: `nix eval --json .#nixosConfigurations.<h>.config.nix.settings.trusted-users` gives
   `["root"]` on razer and contains `olafkfreund` on p620 and p510; `just test-host razer`.
   Traps: the list merges, so the overrides add to `[ "root" ]`; do not `mkForce`.

9. **Stage B. Rollout of step 8 (lead/owner).** Merge to `main`, deploy razer from p620
   (`nhs razer` or `just deploy-via-p620 razer`, run from p620), then run the after-removal checks in
   Tests on razer. Do not start step 10 until they pass and one further deploy to razer succeeds.

10. **Stage C. `hosts/p620/configuration.nix`: delete the temporary override from step 8.**
    → verify: `nix eval --json .#nixosConfigurations.p620.config.nix.settings.trusted-users` gives
    `["root"]`; `just test-host p620`.
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
  - a nixarchy path substitutes rather than builds: pick a path P that
    `nix path-info --store https://nixarchy.cachix.org P` finds and `nix path-info P` (local) does not,
    then `nix build P -L` shows `copying path ... from 'https://nixarchy.cachix.org'` and no build;
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

## Owner decisions (2026-11-07)

- Ship as three PRs: stage A (steps 1-7), step 8-9, step 10. Each merges before it rolls out, because
  the 04:00 nightly upgrade pulls `main` and would roll a branch-deployed host back.
- The owner is at the keyboard for each rollout, since #2759 makes sudo ask for the password.

## Deviations during implementation

- **Step 1 (coder):** the VM test sets `nix.settings.sandbox = false` and uses `builder = "/bin/sh"`, so its
  derivations need no store-path builder. Peer keys go through `!include /etc/nix/test-keys.conf` with
  `extra-trusted-public-keys`, with `nix.checkConfig = false`. `alice` uses the nixpkgs snakeoil ed25519 key with
  host-key checking off. Case 6 copies from the client with `--from ssh-ng://builder --to ssh-ng://stranger`.
  All six subtests pass; the check needs KVM, which p620 has, and `nix flake check` now runs it.
- **Step 5 (coder), done before steps 2-4:** it does not depend on the signing keys, so it ran while step 2 waits for
  the owner. `CACHE-STRATEGY.md` also loses the sentence about the commented Cachix example that step 3 deletes, and
  its new text describes the state after step 3. Two comment lines at `modules/services/nixarchy-runner.nix:214-215`
  still match the grep; they describe nixarchy's own flake, so they stay. Stage A must not roll out before step 3.
- **Step 6 (coder), done before steps 2-4:** `build-on-p620` had no `_require-main`, so it only gains
  `(_sign-drv HOST)`. The live check (`just _sign-drv razer`, then `nix path-info --sigs`) moves to step 7,
  because it needs the key.
- **Step 2 (lead):** each public key is derived after encryption, `agenix -d | nix key convert-secret-to-public`,
  instead of `tee >(…)`, whose process substitution can still be writing when the next command reads the file.
  Public keys: `p620-nix-1:hqZIIrJ1DQAb3yBFhxW5ww6DV0XG9NBxQY7E0yyPoH8=` and
  `razer-nix-1:5C9bEvpGznTuMVhzQ0yzZR6HKMwdWEjfjh+pC2lW0aw=`.
- **Step 4 (coder):** on razer the new secret block sits above `age.identityPaths`, with the "Agenix identity
  configuration" comment moved back next to that line.
