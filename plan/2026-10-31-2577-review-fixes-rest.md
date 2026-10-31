---
status: approved
issue: 2577
spec: spec/2026-10-31-2577-review-fixes-rest.md
coders:
  default: coder   # Sonnet coder agent per work package, driven by a Workflow
reviewers:
  - codex   # every work package, codex review --uncommitted, read-only: user asked for Codex
  - agy     # the integrated result, --agent module-refactor --mode plan: user asked for agy
---

# Plan: Fix the remaining review findings

All spec decisions apply as written; finding ids refer to the table in issue
2577 (file:line there). Branch `fix/2577-review-bugs-security-simplify`,
stacked on `chore/2577-repo-review-fixes` (#2579), worktree
`~/.config/nixos-2577r`.

## How it runs

0. Baseline: `measure.sh base2` on the branch (all three drvPaths and the
   package names). `measure.sh` lives in the session scratchpad
   (`…/scratchpad/measure/`); `BASE=base2 measure.sh <label> <tree>`
   compares against it.
1. Work packages WP1–WP10 run in parallel, each in its own worktree
   branched from this plan's approval commit. Each package does its items
   in order, **one commit per finding**. After each item: measure against
   the previous item, check the expectation below, build p620 and razer.
   Codex reviews the package's full diff before the package is handed over;
   a real finding gets one fix round.
2. Integrate: cherry-pick the packages in WP order onto the branch,
   resolve conflicts keeping both sides, re-measure against `base2`, build,
   `just validate`.
3. WP11 (hosts-5) runs alone on the integrated branch; dropped if its
   expectation fails.
4. agy reviews the integrated diff; real findings fixed.
5. Push, PR stacked on #2579. No deploy.

Every expectation: **SAME** = all three drvPaths identical; **CHANGED(h,…)**
= only those hosts change and nix-diff shows only the named derivations
(plus their parents: system-path, units, etc, activate, toplevel). An
unexplained change fails the item.

Traps for every package: work only in your worktree; no backticks in
commit messages (use `git commit -F`); setters go with their options;
markdownlint lints whole touched files at push; `git add -A` before
measuring (flake eval ignores untracked files); p510 is never built.

## Work packages

**WP1 — update scripts** (`scripts/update-commit-deploy.sh`,
`scripts/preview-updates.sh`, `scripts/check-nixos-updates.sh`)

- tooling-1: `splice_nixpkgs_node "$(jq -r '.nodes.root.inputs.nixpkgs' flake.lock)"`
  and the same for `nixpkgs-unstable` (resolve to the node name; handle a
  `follows` list). Test on a copy of `flake.lock`: the root's node gets the
  new rev, agenix's `nixpkgs` node does not.
- tooling-3: `if ! NEW_SYSTEM=$(nix build …); then mv flake.lock.backup flake.lock; exit 1; fi`;
  rev via `.nodes[.nodes.root.inputs.nixpkgs].locked.rev`.
- tooling-10: `nix flake update --output-lock-file "$TEMP_DIR/flake.lock.new"`
  instead of copying the tree; drop the dead `$?` check.
- Expect SAME. Check: `bash -n`, `shellcheck -S warning` (no new warnings).

**WP2 — Justfile and pre-commit** (`Justfile`, `.pre-commit-config.yaml`)

- tooling-2: every `$$` → `$`.
- tooling-4: `set -uo pipefail` after the shebang in recipes that pipe
  into `tee` (test-build-all, test-build-all-parallel, check-syntax, summary).
- tooling-11: `deploy-all-parallel` without the inner `&`.
- tooling-9: `files: '^[Jj]ustfile$'`.
- Expect SAME. Check: `just --list`; `just -n gc-aggressive` shows `$confirm`;
  `pre-commit run just-validate --files Justfile` runs (not skipped).

**WP3 — CI** (`.github/workflows/ci.yml`, `update-flake.yml`)

- tooling-5: delete the four openclaw grep/exit-0 carve-outs and the comment.
- tooling-12: run `pre-commit run --all-files` locally; if it passes, drop
  `|| true`; else delete the job.
- Expect SAME. Check: `actionlint`.

**WP4 — p620/razer hosts** (`hosts/p620/configuration.nix`,
`hosts/razer/configuration.nix`, `modules/common/features.nix`,
`modules/common/features-impl.nix`, new `hosts/common/nixos/interactive-desktop.nix`)

- hosts-1: delete `greetd.restartIfChanged` + comments.
  Expect CHANGED(p620, razer): the greetd stub unit leaves.
- hosts-6: delete `user.services.scream-ivshmem`. CHANGED(p620): that unit.
- services-9: delete the always-false `hashedPasswordFile` mkIf blocks. SAME.
- modules-rest-12: delete `features.ai.providers` and its copy block;
  set the same values under `ai.providers` in p620. SAME.
- hosts-14: move the blocks shared byte-for-byte by p620 and razer
  (users genAttrs, GStreamer list, shared features, etc.) into
  `hosts/common/nixos/interactive-desktop.nix`, imported by both. SAME —
  if a block cannot move with SAME, leave it.

**WP5 — p510** (`hosts/p510/configuration.nix`, `hosts/p510/nixos/tailscale-serve.nix`,
`hosts/p510/flaresolverr.nix`, `hosts/p510/nixos/recyclarr.nix` →
`modules/services/recyclarr.nix`, `Users/olafkfreund/p510_home.nix`,
`Users/common/base-home.nix`, `home/profiles/developer/default.nix`,
`home/shell/direnv/`)

- hosts-2 (p510 file): `set -euo pipefail`, bounded loop
  (`for i in $(seq 60); do …; sleep 5; done` then fail), `TimeoutStartSec`,
  `after`/`requires` tailscaled. CHANGED(p510): that unit.
- hosts-8: delete the cosmic + cosmic-remote-desktop blocks. SAME or
  CHANGED(p510) only if those disabled options produced output; report.
- hosts-9: delete CPUSchedulingPolicy/Priority/Nice. CHANGED(p510): unit.
- hosts-13: recyclarr to `modules/services/recyclarr.nix` as
  `features.recyclarr` with DynamicUser/ProtectSystem=strict/ProtectHome/
  NoNewPrivileges (check it only needs its EnvironmentFile and network);
  import + enable in p510. CHANGED(p510): the recyclarr unit only.
- nodejs: `nix eval .#nixosConfigurations.p510.pkgs.nodejs.version`; if 24.x,
  delete the packageOverrides. Expect SAME, else keep it.
- home-12: delete `log.oneline`. CHANGED(p510): HM gitconfig only.
- home-13, home-11: direnv/git core defined once (base-home); p510_home
  imports one profile and drops restated values/packages. Expect SAME on
  all hosts; if not reachable, keep the minimal version that is SAME.

**WP6 — storage and nix modules** (`modules/storage/garbage-collection.nix`,
`modules/storage/performance-optimization.nix`, `modules/system/fstrim-optimization.nix`,
`modules/core.nix`, and only the matching option blocks in host configs)

- services-3: `before = [ "nix-gc.service" ]`. CHANGED(p510): that unit.
- modules-rest-11: drop the module's `nix.gc`/`nix.optimise` and their
  options; delete p510's setters. CHANGED(p510): gc/optimise timers.
- modules-rest-6: delete fstrim-optimization; `services.fstrim` on the
  hosts that enabled it. CHANGED(those hosts): fstrim units.
- modules-rest-8: dirty_* into `boot.kernel.sysctl` with mkDefault, drop
  the echo block. CHANGED(p620): optimizer script + sysctl.
- Traps: host config edits are limited to these option blocks (WP4/WP5
  own the rest of those files).

**WP7 — secrets** (`modules/secrets/api-keys.nix`, `modules/services/ollama.nix`,
`home/shell/splashboard/default.nix`, `pkgs/obsidian-mcp-rest/`, the npx/docker MCP wrappers)

- services-6: `api-ollama` mode `0440` (root:users); ollama
  `LoadCredential = "api-ollama:${cfg.cloudApiKeyFile}"` and preStart reads
  `$CREDENTIALS_DIRECTORY/api-ollama`. Confirm `omarchy-meetingai` still
  reads it as a group member. CHANGED(hosts with ollama/api-ollama).
- home-2: remove the GH_TOKEN export from shell init; add a `gh` wrapper
  (HM `home.packages` writeShellScriptBin `gh` that sets GH_TOKEN from the
  file if unset and `exec`s the real gh, higher priority than gh) and let
  the splashboard widgets read the file at call time. CHANGED(all): HM.
- pkgs-11: obsidian-mcp-rest pipefail + split export; pin `@latest`/tags
  to the current exact versions (`npm view <pkg> version`, image digest).
  CHANGED: those wrapper scripts.

**WP8 — option docs and base tools** (`modules/virt/{virt,incus,spice,podman}.nix`,
`modules/services/print/default.nix`, `home/desktop/kdeconnect/default.nix`,
`modules/system-utils/system_util.nix`)

- services-2, home-10: `mkEnableOption "<name>"`; quote the kdeconnect
  device id. Expect SAME or changes in option docs/manual only.
- modules-rest-1: add lsof, usbutils, inetutils (skip any already in the
  closure). CHANGED(all): system-path gains them.

**WP9 — packages** (`pkgs/claude-code-native/`, `pkgs/whatsapp-mcp/`,
`pkgs/mpris-album-art/`, `pkgs/atlassian-mcp/`, `pkgs/claude-code-mods/nix-flavour/`,
`pkgs/README.md`, `home/media/music.nix`, the weather-popup consumer,
`flake.nix` packages block only)

- pkgs-2: writeShellScriptBin. CHANGED: claude-code-native.
- pkgs-3: pin commit SHA, version `0-unstable-<date>`; output hash unchanged.
- pkgs-10, pkgs-12, pkgs-13: as the spec says. CHANGED: those packages.
- pkgs-8, pkgs-9: one definition each. Expect SAME (packages list unchanged).
- pkgs-14: README rewrite of the list section.

**WP10 — shell and desktop HM** (`home/shell/bash.nix`, `home/shell/zsh.nix`,
`home/desktop/com.nix`)

- home-15: shared aliases to `home.shellAliases`. CHANGED: rc files,
  same alias set (check by grepping the built rc files).
- home-14: gate com.nix on `features.desktop.enable`; keep its packages.
  Expect SAME (all importers are desktops); report otherwise.

### WP11 — nixpkgs-unstable (hosts-5), after integration

- Delete the input and `pkgsUnstable`; one module sets
  `_module.args.pkgs-unstable = pkgs` and the HM `extraSpecialArgs`
  equivalent; `nix flake lock`. Measure, build p620/razer. Keep only if
  builds pass and the rebuilt set is limited to the call sites' packages;
  otherwise drop the step and report.

**WP12 — AGENTS.md** (hosts-15), done by the integrator: point the
"Adding a user" step at `hostUsers` in `flake.nix`.

## Tests

Per item: measure + expectation, p620/razer build. Per package: Codex.
Integrated: `BASE=base2 measure.sh integrated-R`, builds, `just validate`,
`markdownlint` on touched .md, agy review, CI on the PR. After build on
p620: `bash -lc 'unset GH_TOKEN; gh auth status'` through the new wrapper
works.

## Rollback

One commit per finding; `git revert <sha>`. Nothing is deployed.

## Outcome and deviations

Committed: every finding in WP1–WP9 and WP11, plus WP12, except the five
below. Each was dropped because its own check failed, as the plan
requires; none is committed.

- hosts-14: moving the shared blocks reorders `systemPackages`
  (GStreamer list), so drvPaths cannot stay identical. Left in place.
- home-11 + home-13: collapsing p510's profiles would drop packages and git
  settings from p510 that the developer profile does not supply.
- home-14: HM `features.desktop.enable` is false on p510 although p510 is a
  desktop, so the gate would strip its apps. Needs that flag fixed first.
- home-15: `gl` is `glab` in the GitLab module and a git alias in the
  shell files; merging into `home.shellAliases` conflicts.
- modules-rest-8: `vm.dirty_writeback_centisecs` is also defined by the
  nixarchy input; moving it to `boot.kernel.sysctl` fails to evaluate.

Follow-ups after integration, each measured:

- agy: nhs still spliced the removed `nixpkgs-unstable` (would write a
  `null` lock node); fixed. The p510 tailscale-serve `set -e` would let one
  failing serve or funnel call fail the unit; now `set -uo pipefail`. The
  p620 unit got the bounded wait hosts-2 asked for.
- validate: `modules/system/default.nix` restored (structure check),
  `mkPkgs` dropped (deadnix).
- WP2 tooling-4 touched only the recipes that pipe into tee
  (`check-syntax` and `summary` do not).
