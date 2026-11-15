---
status: draft
issue: 2934
spec: spec/2026-11-15-2934-features-bridge.md
coders:
  1: codex  # each slice: rewrite the module gate, drop the bridge line, iterate against the .drv check
  2: codex
  3: codex
  4: codex
  5: codex
  6: codex
  7: codex
  8: codex
reviewers:
  - codex
  - agy
---

# Plan: one option layer for fleet features

Approved decisions: every module reads `config.features.<group>` directly with `mkIf (f.enable && f.<x>)`; private
`options.<old>.enable` and the bridge lines go; hosts/users that set an old path are moved in the same slice; custom
options under upstream roots move to `features.*`; both `features-impl.nix` files are deleted. One commit per slice;
after each, `SNAP_NO_BUILD=1 scripts/config-snapshot.sh snap /tmp/s6-<n>` and `diff <baseline> /tmp/s6-<n>` must be
`IDENTICAL` for p620, razer and p510, else revert the slice and report. Baseline: `main` at this branch's merge base,
taken by the lead after #2932 and #2933 merge (rebase first). `SNAP_NO_BUILD=1` arrives with #2932's
`scripts/config-snapshot.sh`; until it is on this branch, evaluate with that branch's copy of the script.

## Traps per slice (Codex and agy reviews; read before each slice)

- Groups with no `enable` (`features.programs`, `features.media`): gate on the flag alone,
  `mkIf config.features.programs.obsidian`, never `f.enable && f.x`.
- `lib.mkEnableOption { default = true; ... }` defaults to **false** (the attrset is ignored). That pattern is in
  `home/browsers/firefox.nix`, `home/shell/{bat,direnv,fzf,starship,yazi,zoxide,tmux}/default.nix`: gate them
  `f.enable && f.x`. Only `home/development/vscode.nix` (`mkEnableOption "..." // { default = true; }`) really
  defaults true: its gate is `!f.editors.enable || f.editors.vscode`.
- When a module's option tree goes, every sub-option the module itself reads becomes a `let` binding with the
  same default: `modules/ai/antigravity-cli.nix` (`environmentVariables = { }`, `enableShellIntegration = true`),
  `home/desktop/screenshots/wayland-native.nix` (`savePath`, `enableAnnotation`, `enableDesktopEntries`), unused
  `packages` options (go keeps its list).
- `home/desktop/terminals/default.nix`: only `:14-16` (`config.{foot,kitty,alacritty}.enable` → `features.terminals`)
  and the `options` block `:82-86` change; its `home.packages` (`:360-381`) stays unconditional.
- Slice 8 deletes `Users/common/features-impl.nix` and only its imports (`Users/common/imports.nix:9`,
  `Users/common/default.nix:6`); `Users/common/features.nix` stays imported (`imports.nix:8`).
- Out of scope: `modules.containers.docker` (custom `modules.*` root, read by `modules/containers/k3d.nix:894`;
  hosts set it and `features.virtualization.docker`), and unbridged `services.*`/HM `programs.*` modules not listed
  below. Slice 4 does not touch docker.
- Slice 5: `programs.{lazygit,thunderbird}.enable` (impl :69-70) are upstream options; move those two lines into
  `modules/common/features.nix`'s `config` unchanged (same condition).
- Slice 6 targets: `system.logging.enableFiltering` → `features.logging.enableFiltering`; `networking.profile` →
  `features.networking.profile` (same enum and default); `networking.stableConnection.{enable,interfaceSwitchDelayMs}`
  → `features.networking.stableConnection.*`; `programs.winboat.enable` → `features.winboat.enable` (only commented
  setters exist). Slice 4: `services.spice.guestAgent` → `features.virtualization.spiceGuestAgent`. Slice 8:
  `programs.aerion.package` → `features.desktop.aerionPackage`.

## Steps

1. Slice 1 (spec Design 1). Files: `modules/development/{cargo,github,go,java,lua,nix,shell,nodejs,devbox}.nix`,
   `modules/common/features-impl.nix:27,29-36` (leave :28, copilot-cli, for slice 2).
2. Slice 2. `modules/development/python.nix`, `modules/development/copilot-cli.nix`, `modules/ai/antigravity-cli.nix`,
   impl :28, :40, :42.
3. Slice 3. `modules/cloud/packages.nix`, impl :55-59, :101.
4. Slice 4. `modules/virt/{podman,incus,spice,virt}.nix`, impl :47-50 (docker untouched, see traps).
5. Slice 5. `modules/programs/{gnupg,1password,droidcam}.nix`, `modules/services/print/default.nix`,
   `modules/{obsidian,office,webcam}/default.nix`, impl :51, :62-63, :69-73, :77.
6. Slice 6. `modules/system/logging.nix`, `modules/common/networking.nix` (incl. `stableConnection`),
   `modules/windows/winboat.nix` and their host setters.
7. Slice 7. Delete `modules/common/features-impl.nix` and its import in `modules/common/default.nix:7`; move :20-24.
8. Slice 8. `Users/common/features-impl.nix` targets in `home/desktop/terminals/**`, `home/development/{cursor-code,nvim,vscode,zed-editor}.nix`,
   `home/browsers/*.nix`, `home/desktop/*/default.nix`, `home/desktop/screenshots/wayland-native.nix`,
   `home/shell/*/default.nix`, `home/shell/tmux/default.nix`;
   then delete `Users/common/features-impl.nix` and its two imports (`Users/common/default.nix:5-6`,
   `Users/common/imports.nix:8-9`). p510's four direct terminal enables (#2933) become
   `features.terminals = { enable = true; ghostty = true; foot = true; kitty = true; alacritty = true; }`.
9. Docs (Claude): `docs/PATTERNS.md` and `AGENTS.md` "Module shape" say modules read `features.*` directly; no bridge.

## Tests

Per slice: `IDENTICAL` on all three hosts. Final: full snapshot with builds `IDENTICAL`; `git grep` for every removed
option path prints nothing; deadnix/statix on changed files; `just check-syntax`; CI; `@codex review`.

## Rollback

Revert the squash commit (or a single slice commit).
