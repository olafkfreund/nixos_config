---
status: approved
issue: 2577
intent: intent/2026-10-31-2577-repo-review-fixes.md
---

# Spec: Remove dead code, one measured step at a time

Scope is the dead-code group of #2577 only. Bugs, security and
simplification get their own specs afterwards.

## Design

### The measure

"Nothing broke and nothing was lost" is checked mechanically, not argued.
Before the first step, record a baseline in the scratchpad:

- `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`
  for p620, razer and p510 (about a minute each, eval only, nothing built).
  Home Manager is part of each toplevel, so this covers `home/` and `Users/`.
- `nix eval --json .#packages.x86_64-linux --apply builtins.attrNames`.
- A built p620 and razer toplevel (`just test-host p620`, `just test-host razer`),
  so later builds of an unchanged system are instant.

After every step the same evals run again and are compared with the
baseline from the step before:

- **Phase A (inert)** steps must leave all three drvPaths byte-identical.
  An identical drvPath means the deployed system is unchanged, so nothing
  can have been lost. A step that changes any drvPath is wrong by
  definition: stop, find what was not dead, put it back.
- **Phase B (live but useless)** steps are expected to change a drvPath.
  `nix-diff` between the old and new `.drv` must show only the units,
  files or packages the step names, on only the hosts it names. Anything
  else in the diff stops the step.
- The `packages` attribute list may only lose the names the step removes.
- Then the test build: `just test-host p620` and `just test-host razer`
  (razer builds on p620, as usual). p510 is eval-only unless you allow a
  build; nothing is deployed to any host in this task.
- Plus `just check-syntax`, the pre-commit hooks at commit time, and for
  Justfile/CI/script steps: `just --list` parses, `actionlint` passes,
  `git grep` finds no reference left to anything removed.

### Codex and agy in the loop

- Every step, before its commit: `codex review --uncommitted` read-only
  (`-c sandbox_mode="read-only"`, subscription login). Each finding is
  either fixed in the step or answered in the commit body.
- End of each phase: agy `--agent module-refactor --mode plan` reviews the
  phase's diff, named as a file. Agreement is advice, not approval; a
  claim gets checked against the code before anything changes.

### Steps

One commit per step, in this order, so a step that fails reverts alone.

#### Phase A — inert; all three drvPaths must stay identical

1. `network-stability` and `secure-dns`: delete
   `modules/services/network-stability.nix`,
   `modules/services/dns/secure-dns.nix`,
   `scripts/network-stability-helper.sh`,
   the unimported `hosts/p620/nixos/network-stability.nix`, their imports in
   `modules/core.nix` and `modules/services/default.nix`, the two
   `secure-dns.enable = false;` host lines and the `network-check` Justfile
   recipe (services-1).
2. Unimported module files: `modules/microvms/` (plus three commented
   lines in `flake.nix`), `modules/services/{github,tabby,power,greetd}/`,
   `modules/nixos/`, `modules/packages/{default,dependency-sets,sets}.nix`,
   `modules/desktop/electron-config.nix`, `modules/desktop/plasma/plasma.nix`,
   `modules/programs/stream_deck.nix`, and the stale comments and README
   lines pointing at them (services-7, -8, modules-rest-1, -7).
3. Unimported host files: `hosts/razer/nixos/greetd.nix`,
   `hosts/{p620,razer}/{nixos-options,home-manager-options}.nix`,
   `hosts/{p620,razer}/home-manager/mbsync.nix`,
   `hosts/p620/nixos/{vfio,glance}.nix` (hosts-7). Not
   `hosts/common/hardware-profiles/*` or `hosts/templates/`, which AGENTS.md
   documents.
4. Unimported home files: `home/profiles/default.nix`,
   `home/profiles/developer/coder.nix`, `home/desktop.nix`,
   `home/desktop/plasma.nix`, `home/desktop/scripts.nix`, and
   `home/desktop/wayland/` with its two empty imports in
   `p620_home.nix`/`razer_home.nix` (home-6, -7, -9). The wezterm
   `colors.nix` from home-9 does not exist and is dropped.
5. Options nothing reads, with the host lines that set them:
   `secrets.apiKeys.enableEnvironmentVariables` (+ the stale
   `LANGCHAIN_API_KEY` status line), `security.secrets.{hostKeys,userKeys}`,
   `features.quickshell`, `features.networking`, HM
   `features.desktop.{cosmic,gnome,lanmouse,quickshell}` and
   `features.gaming.{enable,steam}`, the storage
   `queueDepth`/`compressionOptimization`/`barrierOptimization` options,
   `nix.nix`'s dead `allowUnfreePredicate` and `rebootWindow`, the
   `flow-desktop` import (tfm stays: p620/razer enable it),
   the unused `config` blocks in `lib/hostTypes.nix`, and
   `hosts/common/nixos/hosts.nix` with its `network`/`hostMappings` keys
   (services-9 options part, -10, modules-rest-5, -9, -13, home-1, hosts-4, -10).
   Large step: it may be split per option during the plan if a drvPath moves.
6. Unused packages: `pkgs/{linux-command-mcp,add-skill,reddix,neuwaita-icon-theme}/`
   and their `pkgs/default.nix` lines, the broken inline
   `neuwaita-icon-theme` and the `claude-code` entries in `flake.nix`'s
   `packages`, `home/development/claude-code/` and the `.backup` files,
   `pkgs/citrix-workspace/default.nix` (the overlay and its scripts stay),
   `pkgs/amd-smi-exporter.nix`, `pkgs/virtualbox-curl-fix.patch`, and the
   always-true `ffmpeg != null` guard in `whatsapp-mcp` (pkgs-4..7, home-8,
   hosts-3/pkgs-1 by deletion).
7. Unused flake inputs: `nixpkgs-f2k`, `antigravity-nix`, `flake-utils`
   (each checked for `follows` from other inputs first), then
   `nix flake lock` (hosts-11). The lock changes; drvPaths must not.
8. Tooling: the phantom `homeConfigurations` CI step, `test-home`,
   `test-home-user`, `test-all-users`, `create-host`, `validate-features`,
   `docs`, the eleven microvm recipes, `cleanup-dead-code` and
   `analyze-config` with `scripts/cleanup-dead-code.sh`, and the matching
   block in `scripts/ci-test.sh` (tooling-6, -7, -8).

#### Phase B — live but useless; drvPath changes, `nix-diff` must show only this

1. p620: the `storage-performance-monitor` unit (a root `while true` loop
   writing a file nothing reads) and its `/var/lib/storage-tuning` tmpfiles
   rule (services-5).
2. p510: the `nix-gc-pre-check` unit, which nothing pulls in, with its
    `minFreeSpace` and `keepDays` options (services-4, modules-rest-2).
3. All hosts: the ungated HM Plasma stack `home/desktop/plasma/default.nix`
    and the now-orphaned `modules/common/plasma-packages.nix` (home-3).
    `polychromatic` and `qt6ct` stay: razer and all three hosts install them
    system-wide already. The closure diff lists every package that leaves.
4. All hosts: `home/desktop/theme/cosmic-theme.nix`, which writes COSMIC
    palette files no host reads (home-4).
5. razer: the `tuigreet` package left over from the dead greetd setup
    (hosts-7).
6. p510: the GDM typelib/schema variables and the `gdm`,
    `gnome-control-center`, `gnome-settings-daemon` packages kept after GDM
    was removed (hosts-12). The `nodejs` override is not in this step.

### Out of scope here

`services-9`'s `hashedPasswordFile` (a security decision), adding
`lsof`/`usbutils`/`inetutils` (an addition: nothing was lost, they were never
installed), deduplicating `nix.optimise` (changes p510's schedule), the
`nodejs` override, and everything in the bug, security and simplification
groups.

## Alternatives rejected

- **One big deletion commit** — one drvPath change could not be traced to
  its cause, and a revert would take everything with it.
- **Build every host after every step without the drvPath check** — a
  successful build proves only that the result builds, not that it is the
  same system. An identical drvPath proves both, and costs a minute.
- **`nvd`/`diff-closures` instead of `nix-diff`** — they need both closures
  built, which p510 cannot be without your permission; `nix-diff` works on
  the `.drv`s from eval alone.
- **Trusting the review's "nothing imports it"** — every step re-checks
  with `git grep` before deleting, because the review was wrong twice
  (tfm, claude-code).

## Risks

- **A file is reached by a path the grep misses** (string-built path,
  `readDir`, a script). The drvPath check catches it for anything that
  reaches a host; the `packages` list check catches flake outputs.
- **Phase B removes something you use** — mainly step 11 (pywal, wpgtk,
  the KDE portal and polkit agent from HM). Its closure diff is shown to
  you before the step is committed if anything other than Plasma-only
  packages leaves.
- **Justfile/CI edits are invisible to drvPath.** Covered by
  `just --list`, `actionlint` and the grep check, and by CI on the PR.
- **Rebase conflicts with other agents** on `flake.nix`, the Justfile and
  host configs. The branch rebases on `origin/main` before each phase and
  re-runs the baseline after a rebase.

## Verification

Done when: steps 1–8 each left all three drvPaths identical to the step
before; steps 9–14 each changed only what they name (nix-diff kept per step
in the PR description); p620 and razer test builds pass after every step;
Codex reviewed every step and agy every phase; CI is green on the PR; and
the PR description reports the lines removed and every drvPath change.
