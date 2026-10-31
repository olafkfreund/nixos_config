---
status: approved
issue: 2577
intent: intent/2026-10-31-2577-repo-review-fixes.md
---

# Spec: Fix the remaining review findings (bugs, security, simplification)

Follows the dead-code spec (`spec/2026-10-31-2577-repo-review-fixes.md`,
PR #2579). This covers every remaining finding of #2577 except those
already resolved there. Stacked on the dead-code branch.

## Design

Same measure as the dead-code work, now with expected changes: before
the work, record the three host drvPaths of the branch (`base2`). Each
change states whether it must leave drvPaths identical (refactors) or
which hosts and derivations it changes (fixes). The check reads `nix-diff`
and fails on anything not explained by the change. p620 and razer are
built; p510 is evaluated only. Codex reviews every work package; agy
reviews the integrated result. Nothing is deployed.

Decisions, one per finding (ids from #2577):

**Bugs**

- tooling-1: `nhs` splices the node names resolved from
  `.nodes.root.inputs`, not the literal `nixpkgs`.
- tooling-2: `$$` → `$` in every Justfile recipe that uses it.
- tooling-3: `preview-updates.sh` restores the lock when the build fails
  (`if ! NEW_SYSTEM=$(…)`), reads the rev through the root input.
- tooling-4: `set -uo pipefail` in the shebang recipes that pipe to tee.
- tooling-5: delete the openclaw "known issue" carve-outs in CI.
- tooling-9: pre-commit `files: '^[Jj]ustfile$'`.
- tooling-11: drop the inner `&` in `deploy-all-parallel`.
- hosts-1: delete `greetd.restartIfChanged` on p620 and razer (no greetd).
- hosts-2: tailscale-serve oneshots (p510, p620) get `set -euo pipefail`,
  a bounded wait and `TimeoutStartSec`, ordered after `tailscaled`.
- hosts-6: delete p620's dead `scream-ivshmem` user unit (vfio is gone).
- services-3: generation cleanup runs `before` nix-gc.
- services-2, home-10: `mkEnableOption "<name>"` in six modules; quote the
  kdeconnect device id.
- pkgs-2: wl-paste shim via `writeShellScriptBin`.
- pkgs-3: pin `whatsapp-mcp` to a commit SHA.
- pkgs-10: fix the playerctl status check, `mktemp -d`, drop `kill -9`.
- home-12: delete the bogus `log.oneline` git key.
- modules-rest-8: storage `vm.dirty_*` via `boot.kernel.sysctl` with
  `mkDefault`, drop the `/proc/sys` echo block.
- hosts-15: AGENTS.md says where `hostUsers` really lives (flake.nix).

**Security**

- services-6/modules-rest-3: `api-ollama` 0440 root:users (meetingai keeps
  group read); ollama reads it through `LoadCredential`.
- home-2: no `GH_TOKEN` export in every shell. A `gh` wrapper (and the
  splashboard widgets) read the agenix file at call time, so `gh` keeps
  working everywhere it did.
- hosts-8: delete p510's dead cosmic and cosmic-remote-desktop blocks with
  the plaintext VNC password. It stays in git history; rotation is yours.
- hosts-9: FlareSolverr loses SCHED_FIFO and Nice -5.
- hosts-13: recyclarr moves to `modules/services/recyclarr.nix` behind
  `features.recyclarr`, hardened (`DynamicUser`, `ProtectSystem=strict`,
  `ProtectHome`, `NoNewPrivileges`); p510 enables it.
- pkgs-11: `obsidian-mcp-rest` gets `set -euo pipefail` and a split
  `export`; npx/docker MCP wrappers pin exact versions.
- services-9: delete the always-false `hashedPasswordFile` mkIf blocks.
  Enabling the secret instead could change the login password; not done.

**Simplification** (drvPath-identical unless stated)

- hosts-14: the ~150 lines p620 and razer share move to one common module.
- modules-rest-12: drop the `features.ai.providers` mirror; p620 sets
  `ai.providers` directly.
- modules-rest-11: `garbage-collection.nix` stops re-declaring `nix.gc` /
  `nix.optimise` (p510 optimises once a week, not twice; changes p510).
- modules-rest-6: replace `fstrim-optimization` with `services.fstrim`
  (changes the hosts that use it).
- home-11, home-13: p510_home imports one profile and drops restated
  values; direnv and git core settings defined once. p510's
  home-manager-path must stay identical.
- home-15: shared aliases in `home.shellAliases` (rc file order may move).
- home-14: gate `com.nix` on `features.desktop.enable`.
- pkgs-8, pkgs-9: one definition per package (flake `packages` inherits
  from pkgs; consumers use `pkgs.customPkgs`).
- pkgs-12: one secret-loading function in `atlassian-mcp`.
- pkgs-13: the status-line hook reads `/etc/nixos/nixarchy-theme.nix`.
- pkgs-14: pkgs/README.md describes the real registration points.
- tooling-10: `check-nixos-updates.sh` uses `--output-lock-file`.
- tooling-12: CI pre-commit job gates (drop `|| true`) if the tree passes
  `pre-commit run --all-files` today, otherwise the job is removed.
- modules-rest-1: add `lsof`, `usbutils`, `inetutils` the comments
  promised (adds packages on all hosts).
- p510's `nodejs` packageOverride is removed if `nodejs` already is 24.
- hosts-5: `nixpkgs-unstable` (same rev as `nixpkgs`) is replaced by a
  `pkgs-unstable = pkgs` shim. Runs last, alone; dropped if its nix-diff
  shows rebuilds beyond the 38 call sites' packages or a build fails.

Not done: home-5 (lan-mouse is not on p510; already import-gated).

## Alternatives rejected

- **Separate specs per group** — the user asked for one pass and
  pre-approved the changes.
- **Enabling the user-password secret (services-9)** — could change the
  login password on deploy.
- **Keeping `GH_TOKEN` exported** — the repo already rejected that pattern
  for API keys (#1831).

## Risks

- recyclarr's hardening, tailscale-serve and FlareSolverr change p510
  services that cannot be run before your p510 deploy; eval only.
- The `gh` wrapper must cover every `gh` use (shell, scripts, Claude);
  checked by `gh auth status` in a fresh shell on p620 after build.
- hosts-5 can rebuild many packages; it is last and droppable.
- Parallel packages touch shared files (p510 config); the integrator
  resolves cherry-pick conflicts and re-measures the combined tree.

## Verification

Per package: `measure.sh` against `base2` with its stated expectation,
p620 and razer builds, its own checks (bash -n / shellcheck, `just
--list`, actionlint), Codex review. Integrated: re-measure, builds,
`just validate`, agy review. CI green on the PR.
