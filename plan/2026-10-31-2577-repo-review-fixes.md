---
status: approved
issue: 2577
spec: spec/2026-10-31-2577-repo-review-fixes.md
coders:
  default: coder   # Sonnet coder agent, one per step, driven by a Workflow
reviewers:
  - codex   # every step, `codex review --uncommitted`, read-only: the user asked for Codex in the loop
  - agy     # end of each phase, `--agent module-refactor --mode plan`: the user asked for agy in the loop
---

# Plan: Remove dead code, one measured step at a time

## Approved decisions (from the spec)

- Scope: the dead-code group of #2577 only. Not in scope: `services-9`'s
  `hashedPasswordFile`, adding `lsof`/`usbutils`/`inetutils`, the
  `nix.optimise` dedupe, p510's `nodejs` override, and all bug, security and
  simplification findings.
- One commit per step, in the order below.
- Measure every step against the previous one with the drvPath of all three
  host toplevels, plus the `packages.x86_64-linux` attribute names.
  Phase A (steps 1–8): every drvPath byte-identical. Phase B (steps 9–14):
  only the named hosts change, and `nix-diff` shows only what the step names.
- Test build p620 and razer after every step (`just test-host`). p510 is
  eval-only. Nothing is deployed.
- Codex reviews each step before its commit; agy reviews each phase.
- Every deletion is re-checked with `git grep` first; the review was wrong
  about `tfm.nix` (enabled on p620/razer) and `home/development/claude-code`
  (backs a flake package), so neither "nothing imports it" claim is trusted.

## How it runs

Two Workflow runs, one per phase, each strictly sequential (a step's
measurement depends on the one before). Per step: a `coder` agent makes the
edit in `~/.config/nixos-2577`; a verifier agent runs `measure.sh`, the test
builds, the step's extra checks and `codex review --uncommitted`; on pass,
the step is committed; on fail, the step's changes are discarded
(`git checkout -- . && git clean -fd` limited to the step's paths) and the
run stops with the evidence. After the phase, agy reviews the phase diff,
and I check its claims before any follow-up commit.

Each step is a fresh coder agent rather than one coder messaged per step:
a Workflow cannot `SendMessage`, and each step is small and self-contained.

Phase B runs only after I have read phase A's results. Step 11 stops and
reports to you instead of committing if its closure diff removes anything
beyond the Plasma-only packages listed in the step.

## Deviation (2026-10-31, at the user's request: "use more agents if needed to make this faster")

Phase A steps run in parallel, each in its own worktree branched from the
approved-plan commit, each measured against the baseline (`BASE=baseline`)
rather than the step before. An integrator then cherry-picks them onto this
branch in plan order and runs `measure.sh` once more on the combined tree:
all three drvPaths must still equal the baseline, and p620 and razer must
build. That final check is what proves the steps do not interact; one
commit per step and the per-step revert are unchanged.

Two check fixes from the first (sequential) attempt at step 1, which was
clean on drvPaths and builds:
- The per-step grep check covers code only (`*.nix`, `*.sh`, `Justfile`,
  `.github/`). Doc mentions are updated where they instruct the reader and
  listed in the report otherwise; `.gemini/state/` is generated and left.
- Codex runs as `codex review --uncommitted` without a custom prompt: this
  Codex version rejects a prompt combined with `--uncommitted`.

Each step gets one fix round for any failure before it is dropped.

### Phase A results and the second deviation (2026-10-31, approved by the user: "ok to both")

13 of 16 phase A steps passed and were integrated; the combined tree equals
the baseline on all three hosts. Three moved a drvPath and were held back.
The parts of them that are inert stay in phase A; the parts that change a
host move to phase B, where `nix-diff` must show only that change:

- 5a′ (phase A, SAME ×3): `secrets.apiKeys.enableEnvironmentVariables` and
  its three host setters only.
- 5f′ (phase A, SAME ×3): `rebootWindow` only.
- 18 (phase A, SAME ×3): the `flowtube` flake input, orphaned by step 5g;
  `nix flake lock`, lock diff only drops nodes.
- 15 (phase B, all hosts): the `LANGCHAIN_API_KEY` line in `api-keys-status`;
  nix-diff shows only that script and its dependants.
- 16 (phase B, all hosts): `allowUnfreePredicate` in `modules/nix/nix.nix`;
  nix-diff shows only nixarchy-pkg-add's `haspredicate` constant and its
  dependants (that branch only runs with `allowUnfree = false`).
- 17 (phase B, p620 only): `hosts/common/nixos/hosts.nix`, its three
  imports and the `network`/`hostMappings` keys; nix-diff shows only one
  leading blank line leaving p620's extra-hosts file. razer and p510 SAME.

Phase B and these extras run in parallel worktrees like phase A, each
measured against `integrated-A`, then integrated and measured once more:
the combined drvPath changes must be exactly the union of the steps'
expected changes. Step 11 still stops for the user if anything beyond the
listed Plasma packages leaves a closure.

## Steps

1. **Baseline.** Write `measure.sh` to the scratchpad
   (`/tmp/claude-1000/-home-olafkfreund--config-nixos/2bd28a10-a94c-4335-b187-068b4f024b41/scratchpad/measure/`):
   for p620, razer, p510 it runs
   `nix eval --raw .#nixosConfigurations.<h>.config.system.build.toplevel.drvPath`
   and `nix eval --json .#packages.x86_64-linux --apply builtins.attrNames`,
   writes them to `<label>.txt`, and compares with the previous label:
   `SAME`/`CHANGED` per host, `nix-diff --color never <old> <new> | head -200`
   for each changed host, and the added/removed package names. Run it as
   `baseline`, then `just test-host p620` and `just test-host razer`.
   → verify: three drvPaths recorded; both builds succeed. Rebase on
   `origin/main` first; if the rebase brings changes, re-run the baseline.
   Traps: `nix eval` of a dirty worktree includes untracked files only if
   `git add`ed — the coder `git add`s new/removed paths before measuring.

### Phase A — every drvPath must stay identical

1. **network-stability, secure-dns.** Delete
   `modules/services/network-stability.nix`,
   `modules/services/dns/secure-dns.nix`,
   `scripts/network-stability-helper.sh`,
   `hosts/p620/nixos/network-stability.nix` (unimported); remove their
   import lines in `modules/core.nix` and `modules/services/default.nix`,
   `secure-dns.enable = false;` in `hosts/p620/configuration.nix` and
   `hosts/razer/configuration.nix`, and the `network-check` recipe
   (Justfile ~1031). Remove the "network-stability" sections in
   `.claude/commands/nix-network.md` that tell the reader to run the service.
   → verify: measure SAME ×3; `git grep -n 'network-stability\|secure-dns'`
   returns only `intent/`/`spec/`/`plan/`; `just --list` parses.
2. **Unimported module files.** `modules/microvms/` + the three commented
   `microvms.*` lines at `flake.nix:534-536`;
   `modules/services/{github,tabby,power,greetd}/`; `modules/nixos/`;
   `modules/packages/{default,dependency-sets,sets}.nix` (check what else is
   in `modules/packages/`; keep anything imported);
   `modules/desktop/electron-config.nix`, `modules/desktop/plasma/plasma.nix`,
   `modules/programs/stream_deck.nix`; the `electron-config.nix` line in
   `modules/desktop/README.md` and any live comment that claims
   `modules/nixos/packages/core.nix` supplies packages.
   → verify: measure SAME ×3; `git grep` for each deleted path is empty
   outside `docs/archive*`, `.claude/agents/` examples and `intent|spec|plan`.
   Traps: `.gemini/state/topology.json` is generated state; leave it.
3. **Unimported host files.** `hosts/razer/nixos/greetd.nix`,
   `hosts/{p620,razer}/nixos-options.nix`,
   `hosts/{p620,razer}/home-manager-options.nix`,
   `hosts/{p620,razer}/home-manager/mbsync.nix`,
   `hosts/p620/nixos/vfio.nix`, `hosts/p620/nixos/glance.nix`; the lines in
   `hosts/p620/README.md` that list them. Keep `tuigreet` (step 13), keep
   `hosts/common/hardware-profiles/*` and `hosts/templates/`.
   → verify: measure SAME ×3; grep for each path.
4. **Unimported home files.** `home/profiles/default.nix` (+ its paragraph
   in `home/profiles/README.md`), `home/profiles/developer/coder.nix`,
   `home/desktop.nix`, `home/desktop/plasma.nix`, `home/desktop/scripts.nix`
   (not `home/shell/scripts.nix`, which is imported), `home/desktop/wayland/`
   and the `../../home/desktop/wayland` import in
   `Users/olafkfreund/p620_home.nix:7` and `razer_home.nix:9`.
   → verify: measure SAME ×3 (the wayland import is an empty `imports`, so
   removing it must not move a drvPath; if it does, put it back and report).
5. **Unread options**, each with the host lines that set it. Do them as
   sub-commits 5a–5i, measuring after each, because one moving drvPath must
   be traceable:
   a. `secrets.apiKeys.enableEnvironmentVariables` (`modules/secrets/api-keys.nix:19`
      - `hosts/{p620,razer,p510}/configuration.nix`) and the
      `LANGCHAIN_API_KEY` line in `api-keys-status`.
   b. `hostKeys`, `userKeys` (`modules/security/secrets.nix:24` +
      `hosts/p620/configuration.nix:~601`, `hosts/razer/configuration.nix:~540`).
      Leave the commented user-password block and `hashedPasswordFile`.
   c. `features.quickshell` and `features.networking`
      (`modules/common/features.nix:46,125`, `hosts/p620/configuration.nix:~414`).
   d. HM `features.desktop.{cosmic,gnome,lanmouse,quickshell}` and
      `features.gaming.{enable,steam}` (`Users/common/features.nix` + setters
      in `Users/olafkfreund/*_home.nix` and profiles). `grep` each name for
      readers first; keep any that has one.
   e. Storage `nvmeOptimization.queueDepth`,
      `filesystemOptimization.compressionOptimization`,
      `diskCacheOptimization.barrierOptimization`
      (`modules/storage/performance-optimization.nix:58,68,102`) and their
      p620 setters (`hosts/p620/configuration.nix:~866,~875`).
   f. `modules/nix/nix.nix`: `allowUnfreePredicate` (~98-102) and
      `rebootWindow` (~16-19).
   g. The `./flow-desktop.nix` import in `modules/desktop/default.nix` and
      the file, plus the commented `flow-desktop` lines in p620/razer.
      `tfm.nix` stays.
   h. `lib/hostTypes.nix`: drop the `config` blocks and the `lib` argument,
      and `{ inherit (nixpkgs) lib; }` at `flake.nix:405`.
   i. `hosts/common/nixos/hosts.nix`, its three imports
      (p620 ~26, razer ~23, p510 ~33), and the `network`/`hostMappings`
      keys in `hosts/common/shared-variables.nix` and `hosts/*/variables.nix`.
   → verify each: measure SAME ×3.
   Traps: deleting an option that a host still sets is an eval error, so
   remove setter and option together; `with lib;` modules may need nothing
   else changed.
6. **Unused packages.** `pkgs/{linux-command-mcp,add-skill,reddix,neuwaita-icon-theme}/`
   and their lines in `pkgs/default.nix`; in `flake.nix`'s `packages`
   (~556-600) the inline `neuwaita-icon-theme`, the commented line ~568,
   and `claude-code` (~557-559) together with `home/development/claude-code/`
   and `home/development/claude-code-mcp-config.json.backup`;
   `pkgs/citrix-workspace/default.nix` only (its scripts and README stay;
   repoint the two comments to `overlays/citrix-workspace.nix`);
   `pkgs/amd-smi-exporter.nix`; `pkgs/virtualbox-curl-fix.patch`; the
   `lib.optionalString (ffmpeg != null)` wrapper in
   `pkgs/whatsapp-mcp/default.nix:~145` (emit its body unconditionally).
   → verify: measure SAME ×3; package names removed are exactly
   `claude-code`, `neuwaita-icon-theme` and any of the four that appeared;
   `nix build .#whatsapp-mcp --dry-run` (or its attr name) succeeds with an
   unchanged drvPath. Traps: `pkgs/default.nix` may feed an overlay used by
   hosts; the drvPath check covers it.
7. **Unused flake inputs.** `nixpkgs-f2k`, `antigravity-nix`, `flake-utils`
   in `flake.nix` inputs; `antigravity-nix` in the outputs argument pattern
   (~373) and `extraSpecialArgs` (~502). First check
   `jq '.nodes|to_entries[]|select(.value.inputs)'` for any input whose
   `follows` targets one of them; if one does, keep that input. Then
   `nix flake lock` (no `update`).
   → verify: the lock diff only drops nodes; measure SAME ×3.
8. **Tooling.** In `.github/workflows/ci.yml` the "Validate Home Manager
   configurations" step (~71); Justfile recipes `test-home`,
   `test-home-user`, `test-all-users`, `create-host`, `validate-features`,
   `docs` (not `docs-build`), the eleven microvm recipes (~1186-1427),
   `cleanup-dead-code`, `analyze-config`; `scripts/cleanup-dead-code.sh`;
   the `homeConfigurations` block in `scripts/ci-test.sh` (~226). Re-check
   with `git grep` that no remaining recipe calls a deleted one.
   → verify: `just --list` parses; `actionlint .github/workflows/ci.yml`;
   `bash -n scripts/ci-test.sh`; measure SAME ×3 (sanity).

**End of phase A:** agy `--agent module-refactor --mode plan` on
`git diff <baseline>..HEAD` written to a file (trimmed under 100 KB to the
.nix hunks if needed), asking whether any removal could have lost behaviour.

### Phase B — `nix-diff` must show only what the step names

1. **p620 storage monitor.** In `modules/storage/performance-optimization.nix`
   delete the `storage-performance-monitor` unit (~341) and the
   `/var/lib/storage-tuning` tmpfiles rule. → verify: only p620 CHANGED;
   nix-diff shows only that unit and the tmpfiles entry; build p620.
2. **p510 GC pre-check.** In `modules/storage/garbage-collection.nix`
    delete `nix-gc-pre-check` (~81), and the `minFreeSpace` and `keepDays`
    options (~28) with any p510 setter. → verify: only p510 CHANGED,
    nix-diff shows only that unit. (Eval only.)
3. **HM Plasma stack.** Remove `./plasma` from `home/desktop/default.nix:14`,
    delete `home/desktop/plasma/` and `modules/common/plasma-packages.nix`
    (grep first: `hosts/razer/configuration.nix:616` installs
    `polychromatic` itself; qt6ct is installed by all three hosts).
    → verify: nix-diff for each host; the HM `home-manager-path` loses only
    packages from `plasmaCommonPackages`/`plasmaHomePackages`. **Stop and
    report to the user before committing** if any package leaves the
    system closure entirely other than pywal, wpgtk,
    xdg-desktop-portal-kde, polkit-kde-agent-1, qt5/qt6 qtwayland.
4. **COSMIC theme.** Remove `./cosmic-theme.nix` from
    `home/desktop/theme/default.nix:6`, delete the file, and fix the comment
    in `hosts/common/shared-variables.nix:45` that names it.
    → verify: nix-diff shows only HM files under `.config/cosmic`.
5. **razer tuigreet.** Delete the `tuigreet` line and its comment
    (`hosts/razer/configuration.nix:~631-632`). → only razer CHANGED,
    only tuigreet leaves.
6. **p510 GDM leftovers.** `hosts/p510/configuration.nix`: the GDM
    `GI_TYPELIB_PATH`/`GSETTINGS_SCHEMA_DIR` in `environment.sessionVariables`
    (~470-473) and `environment.variables` (~495-496), and `gdm`,
    `gnome-control-center`, `gnome-settings-daemon` in `systemPackages`
    (~476) — but first grep whether p510's GNOME session (`gnome-session`
    is still offered) needs control-center/settings-daemon from elsewhere;
    if GNOME's own module already provides them, they go, otherwise keep
    them and remove only the GDM variables. → only p510 CHANGED.

**End of phase B:** agy review of the phase diff, as in phase A.

## Tests

- After each step: `measure.sh <step>` (SAME/CHANGED as the step says),
  `just test-host p620`, `just test-host razer`, `just check-syntax`,
  the pre-commit hooks at commit, and the step's own checks.
- Codex: `codex review --uncommitted -c sandbox_mode="read-only"` per step.
- Before the PR: `just validate`; then CI on the PR.

## Rollback

Each step is one commit (5 is nine). `git revert <sha>` undoes one without
touching the others. Nothing is deployed, so no host needs rolling back;
after merge, a normal deploy with a bad step is undone by `git revert` and
redeploy, or by booting the previous generation.

## PR

One PR for phase A and B, linking intent, spec and plan. The description
lists each step, its drvPath result, the nix-diff for phase B steps, which
steps the coder did, Codex and agy findings and what was done with them,
and lines removed.
