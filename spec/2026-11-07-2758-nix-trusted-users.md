---
status: draft
issue: 2758
intent: intent/2026-11-07-2758-nix-trusted-users.md
---

# Spec: drop olafkfreund from Nix trusted-users

The approved intent's owner decisions apply: drop the trust, move the caches into
`nix.settings`, sign with agenix-held keys on every building host, leave p510 for later. Sudo is
the separate issue #2759, and a separate agent user is #2760.

## Design

### Evidence this design rests on

- Evaluated `nix.settings` per host (read-only `nix eval`, 2026-11-07):
  - p620: nixarchy, hyprland, cache.nixos.org, nix-community, devenv.
  - razer: the same plus `cache.nixos-cuda.org`.
  - p510: the same as razer without devenv.
  - All three: `trusted-users = root root olafkfreund` and `accept-flake-config = true`.
- Sources of those caches:
  - nixarchy `modules/nixos.nix:1077-1088` adds nixarchy and hyprland. It adds
    `cache.nixos-cuda.org` (key `cache.nixos-cuda.org:74DUi4Ye…`) only where
    `hardware.nvidia.enabled`.
  - nixarchy `modules/services/devenv.nix` adds devenv where that service is on.
  - Our `modules/nix/nix.nix:62-72` adds cache.nixos.org and nix-community.
- **cuda-maintainers.cachix.org is set only in `flake.nix:22,31`, and it is stale.** On
  2026-10-23 a razer `llama-cpp` cudaSupport build was a hit on `cache.nixos-cuda.org` and a miss
  on cuda-maintainers.
- `--build-host` in nixos-rebuild-ng 26.11 (`nixos_rebuild/nix.py:153-187`, `services.py:211`)
  runs in four steps:
  1. evaluate `drvPath` locally;
  2. `nix-copy-closure --to <build-host> <drv>`;
  3. `nix build <drv>^*` over SSH on the build host;
  4. copy the result back to the target, which is the local host when `--target-host` is not
     given: `nix-copy-closure --from <build-host>`.
- No host sets `secret-key-files`.

### Changes

1. **`modules/nix/nix.nix`**
   - Set `trusted-users = [ "root" ]`.
   - Add `https://devenv.cachix.org`, `https://nixarchy.cachix.org` and
     `https://hyprland.cachix.org` to `substituters`, with their keys from `flake.nix:30-35`, so
     the cache set no longer depends on nixarchy's defaults or on a flake's `nixConfig`.
   - Drop cuda-maintainers (stale, above). `cache.nixos-cuda.org` stays with nixarchy, which
     adds it only on NVIDIA hosts. Duplicate entries are harmless; the lists already hold
     duplicates.
   - Add `secret-key-files = config.age.secrets."nix-signing-key".path` on hosts that declare
     the secret.
   - Add the public keys `p620-nix-1:<pub>` and `razer-nix-1:<pub>` to `trusted-public-keys`
     on every host. Public keys are not secret and may sit in the store.
2. **Signing keys.**
   - Two new agenix secrets: `secrets/nix-signing-key-p620.age`, with recipients
     `olafkfreund` and the `p620` host key, and `secrets/nix-signing-key-razer.age`, with
     recipients `olafkfreund` and the `razer` host key. Each goes into `secrets.nix`.
   - Each host's config declares `age.secrets.nix-signing-key` with its own file,
     `owner = "root"` and `mode = "0400"`. nix-daemon runs as root and reads it at runtime
     from `/run/agenix/nix-signing-key`. The key never enters the store.
   - To generate: `nix key generate-secret --key-name <host>-nix-1`, piped straight into
     `./scripts/manage-secrets.sh` and never printed. Then
     `nix key convert-secret-to-public` gives the line for step 1.
   - The daemon then signs every path it builds. p510 gets neither a key nor a trust change
     in this task.
3. **p510 keeps its trust** until the owner's go-ahead: `hosts/p510/configuration.nix` sets
   `nix.settings.trusted-users = [ "olafkfreund" ]`, which merges with `[ "root" ]` from
   nix.nix. p510 still receives the cache list change and the two public keys at its next
   owner-run deploy; both are additive and change nothing else.
4. **`accept-flake-config` goes.**
   - Remove it from `modules/nix/flake-settings.nix:8`, which leaves the default, false.
   - Delete the whole `nixConfig` block in `flake.nix:4-36`; step 1 now covers every cache.
   - Drop the 11 `--accept-flake-config` flags in `Justfile`.
   - Reason: without trust the daemon ignores the restricted settings and prints a warning on
     every evaluation. Root, which is still trusted (the nightly `system.autoUpgrade`, any
     `sudo nix`), would otherwise accept whatever settings a flake ships.
5. **Paths already in the store stay unsigned.**
   - Once the key is live on a host, run
     `sudo nix store sign --all --key-file /run/agenix/nix-signing-key` once. This adds a
     signature to every valid path. Cache paths get a second signature, which is harmless.
   - Without this step, copying an old locally built path (a toplevel closure that p620 built
     before signing existed, for example) to an untrusted host fails with "lacks a signature
     by a trusted key".

### Flows after the change (p620 and razer untrusted, p510 still trusted)

| Flow | What crosses a daemon boundary as olafkfreund | Why it is accepted |
| ---- | --------------------------------------------- | ------------------ |
| Local `nhs`, `just test-host`, `nix build`, devenv | nothing | the local daemon builds and substitutes for untrusted users from the system list |
| `nhs razer` from p620 (`nh os switch --target-host razer`) | p620 outputs → razer store | p620 signature, trusted on razer |
| `just deploy-via-p620 razer` from razer | `.drv` closure → p620; outputs p620 → razer | `.drv`s and sources are content-addressed and need no signature (to be proved); outputs carry p620's signature |
| `--build-host X --target-host X` recipes (`Justfile:493,868,978,1007`) | `.drv` closure → X | content-addressed (to be proved) |
| `nhs p620` from razer | razer outputs → p620 | razer signature, trusted on p620 |
| any deploy to p510 | → p510 | p510 is still trusted |

## Alternatives rejected

- **Keep `olafkfreund` trusted on receiving hosts only.** razer and p620 each receive from the
  other, so both would stay trusted and the root path through the daemon stays open on the
  hosts that matter. It only moves the problem.
- **Open the receiving store connection as root** (a `remote-program=sudo nix-daemon` store URL, or
  `ssh root@`). `--sudo` in nixos-rebuild covers activation, not `nix-copy-closure`. Root SSH
  between hosts does not exist (`catalog-info.yaml:378`), and adding it would be a bigger grant
  than the one removed. It also relies on passwordless sudo, which #2759 may remove.
- **A separate low-privilege user for agents (#2760).** That keeps the owner trusted and
  confines agents instead. It is complementary, not a substitute: the owner's own shell, and
  any tool it runs, keeps root through the daemon. Tracked separately by the owner's decision.
- **`trusted-substituters` instead of `substituters`.** Any client could then opt in to them.
  A fixed `substituters` list is narrower, and nothing here needs a per-client choice.
- **Keep the flake's `nixConfig` and `accept-flake-config`.** Without trust they only produce
  warnings, and for root they remain a way for a flake to set restricted settings.

## Risks

- **A deploy that breaks halfway.**
  - If the agenix secret fails to decrypt, `secret-key-files` names a missing file. Every
    build on that host then fails with an open error, including the build that would fix it.
  - Recovery is root-only: `sudo nixos-rebuild switch --rollback`, or rebuild with
    `--option secret-key-files ''` (root is trusted).
  - Mitigation: ship the key in its own deploy (rollout step 1), still trusted, and check
    `/run/agenix/nix-signing-key` exists before the trust removal.
- **A trust change taking effect mid-run.** The copy of a deploy happens before activation, so
  the deploy that removes trust succeeds. The next deploy is the first to depend on signatures,
  so the post-switch checks below run before any further deploy.
- **The nightly upgrade** runs as root and stays trusted. With `nixConfig` gone it uses the
  system cache list, which now holds the same caches minus the stale cuda-maintainers. p510 has
  it off.
- **`nhs`.** It refuses a dirty tree and builds locally (`update-commit-deploy.sh:413`). Remote
  targets need the signature path. nh 4.4.2's copy method (`nix copy --to ssh-ng://` or
  `nix-copy-closure`) is not confirmed; both import through the receiving daemon, so the same
  signature rule applies.
- **`deploy-via-p620`.**
  - The `.drv` upload to an untrusted p620 is the one step not yet proved; see Verification.
  - If it fails, the fallback is `nhs razer` from p620: build on p620 locally and copy to razer
    by signature. No `.drv` upload is needed, so razer heavy rebuilds keep a working path.
- **CI runners on p620.** They are DynamicUsers and already untrusted; their caches come from
  `nixarchy-runner.nix:236-246`. Unaffected, except that the daemon now signs what they build.
  That is harmless, and `sign --all` covers paths they built earlier.
- **devenv.** A project `devenv.yaml` that asks for an extra cachix cache will be ignored with a
  warning. devenv.cachix.org itself stays, at system level.
- **p510.** Unchanged in trust. Its next owner-run deploy adds the cache entries and two
  public keys; nothing in this task builds or deploys it.
- **#2759 interplay.** If passwordless sudo is removed first, the rollbacks above need the
  owner's password. Nothing breaks.

## Verification

1. **Prove the untrusted remote-build flow first, in a NixOS VM test.**
   - New file `checks/nix-untrusted-remote-build.nix`, a `pkgs.testers.runNixOSTest`, exposed
     as `checks.x86_64-linux.nix-untrusted-remote-build` and run with
     `nix build .#checks.x86_64-linux.nix-untrusted-remote-build` on p620 (KVM).
   - Two nodes: `builder` (as p620: a signing key at a root-only path, `secret-key-files`) and
     `client` (as razer). Both have `trusted-users = [ "root" ]`, an ordinary user `alice` with
     SSH keys between the nodes, and the builder's public key in the client's
     `trusted-public-keys`.
   - It uses the same nixpkgs, so the same Nix (2.34.9) as the hosts.
   - The test runs, as `alice` on `client`, exactly what nixos-rebuild-ng does:
     1. `nix-copy-closure --to builder <drv>`: must succeed;
     2. `ssh builder nix build '<drv>^*'`: must succeed;
     3. `nix-copy-closure --from builder <out>`: must succeed, and
        `nix path-info --sigs <out>` shows the builder key;
     4. `nix copy --to ssh-ng://builder` of a client-built path: succeeds once the client
        signs too;
     5. negative case: the same `--from` copy with the builder key removed from the client's
        trusted keys must fail with "lacks a signature by a trusted key".
   - Why a VM test rather than a throwaway local user: a local user on p620 changes a live
     shared host and exercises one daemon. The question is about two daemons, neither
     trusting the user, and a VM test answers it without touching the real `trusted-users`.
2. **Before the trust removal, on the real hosts (rollout step 1 deployed, still trusted):**
   - `test -r /run/agenix/nix-signing-key` as root;
   - `nix config show | grep -E '^(secret-key-files|trusted-public-keys|substituters) '`;
   - build a trivial derivation and check `nix path-info --sigs` shows the host key;
   - after `sign --all`, check `nix store verify --sigs-needed 1 -r /run/current-system` on
     razer for a p620-built closure;
   - `nix config show` must no longer report `accept-flake-config = true`, and a
     `just test-host razer` must evaluate with no "ignoring the client-specified setting"
     warning.
3. **Rollout order:** step 1 (caches, keys, `nixConfig` removal) on p620, then razer. Step 2
   (trust removal) on razer first, then p620, because p620 builds for razer and its trust
   removal is the larger change.
4. **After each trust removal:**
   - `nix config show | grep '^trusted-users '` reports `root` only;
   - `nix store info --store daemon` reports `Trusted: 0` for olafkfreund;
   - `just deploy-via-p620 razer` and `nhs razer` from p620 both complete;
   - `nhs` locally on each host completes;
   - a build is substituted from nixarchy.cachix.org rather than built (pick a path from
     `nix path-info` with `--store https://nixarchy.cachix.org`);
   - `journalctl -u github-runner-nixarchy` shows the next job ran normally.
5. **Rollback:** revert the trust removal commit and redeploy the host. Root stays trusted, so
   `sudo nixos-rebuild switch --rollback` on the host works even when copies are broken. The
   signing keys and cache list can stay; they are harmless on their own.
6. **p510 later:** with the owner's go-ahead, after p620 and razer have run untrusted for a
   while, give p510 a key and drop its override. That is a separate change.
