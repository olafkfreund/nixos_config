---
status: approved
issue: 2934
intent: intent/2026-11-15-2934-features-bridge.md
---

# Spec: one option layer for fleet features

## Design

Recipe per slice: the implementing module reads `config.features.<group>` with
`mkIf (f.enable && f.<x>)` (the same boolean the bridge computed over a default-false option), its private
`options.<old>.enable` is removed, and the bridge line is deleted. Unused `packages` options become `let` bindings
(go keeps its default list). Where a host or user file sets the old path, that line moves to the `features.*` path in
the same slice. Slices (map: Fable review on `40559a899`, `modules/common/features-impl.nix` line numbers):

1. Dev languages: impl lines :27, :29-36 exactly (`cargo,github,go,java,lua,nix,shell,nodejs,devshell`); **not** :28
   (copilot-cli, slice 2). `nix.development` is migrated here and only here.
2. Python `modules.development.python` (:40), copilot-cli (:28), antigravity-cli (:42); their `package` options move
   under `features.development.<x>.package` / `features.ai.<x>.package` only if a host sets them, else `let`.
3. Cloud `<x>.packages` (:55-59); drop the unbridged, unset `cloud-tools.packages`.
4. Virtualisation `services.{podman,incus,libvirt,spice}` (:47-50). Docker is out of scope: `modules.containers.docker`
   is a custom root, not upstream, is read by `modules/containers/k3d.nix:894`, and hosts set it directly.
5. Security `security.{gnupg,onepassword}` (:62-63); programs `services.print`, `programs.{obsidian,office,webcam}`
   (:51, :71-73), `media.droidcam` (:77), and the upstream `programs.{lazygit,thunderbird}` lines (:69-70) move into
   a small module unchanged.
6. Remaining custom roots: `system.logging` → `features.logging`, `networking.profile` →
   `features.networking.profile`, `programs.winboat` → `features.winboat` (host edits on p620/razer).
7. Delete `modules/common/features-impl.nix`; its git/curl/jq block (:20-24) moves into `modules/common/features.nix`.
8. Home Manager, same recipe: terminals (`alacritty/foot/kitty/wezterm/ghostty/warp/wave`), editors (keep VS Code's
   default-true semantics: it is only false when `editors.enable` is on and `vscode` off), browsers, desktop, cli,
   multiplexers; then delete `Users/common/features-impl.nix` and its double import.

Groups without an `enable` (`features.programs`, `features.media`) keep their direct per-flag condition
(`mkIf cfg.programs.obsidian`), exactly as the bridge applied them ungated. Every other option a touched module
declares under an upstream root moves with it in the same slice: `networking.stableConnection.{enable,interfaceSwitchDelayMs}`
→ `features.networking.stableConnection` (slice 6), `services.spice.guestAgent` → `features.virtualization.spiceGuestAgent`
(slice 4), `programs.aerion.package` → `features.desktop.aerionPackage` (slice 8), each reader updated.

Slice 8 details: VS Code keeps `enable = !f.editors.enable || f.editors.vscode` (its option defaulted true and the
bridge only set it while `editors.enable` was on). `home/desktop/screenshots/wayland-native.nix:8` reads an old
option and is migrated in this slice. p510 (after #2933) enables ghostty/foot/kitty/alacritty directly with the
terminals group off; those four setters become `features.terminals = { enable = true; ghostty = true; foot = true;
kitty = true; alacritty = true; };` (wezterm/warp/wave stay false), which is the same set.

Each slice is one commit.

## Alternatives rejected

- A new `my.*` root: renames every switch for no behaviour gain; `features.*` is the documented house pattern.
- Keep the bridge and only rename the shadowing options: leaves the two-hop indirection.

## Risks

- A `mkIf` condition that is not equivalent (e.g. an option whose default is true, like VS Code): caught by the
  identical `.drv` check per slice.
- Removing an option a host still sets: evaluation error, fixed in the same slice.

## Verification

After every slice: `SNAP_NO_BUILD=1 scripts/config-snapshot.sh snap` + `diff` against the `main` baseline: p620,
razer, p510 `IDENTICAL`. Final: full build snapshot `IDENTICAL`; `git grep` shows no reader of a removed option.
