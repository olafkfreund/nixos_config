---
status: draft
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

1. Dev languages: `{cargo,github,go,java,lua,nix,shell,nodejs,devshell}.development` (impl :27-36).
2. Python `modules.development.python` (:40), copilot-cli (:28), antigravity-cli (:42); their `package` options move
   under `features.development.<x>.package` / `features.ai.<x>.package` only if a host sets them, else `let`.
3. Cloud `<x>.packages` (:55-59); drop the unbridged, unset `cloud-tools.packages`.
4. Virtualisation `services.{podman,incus,libvirt,spice}` (:47-50) and docker: drop `features.virtualization.docker`
   and :41; `modules.containers.docker` (set directly by all hosts with `users`/`dataRoot`) becomes
   `features.virtualization.docker` with the same sub-options (host edit).
5. Security `security.{gnupg,onepassword}` (:62-63); programs `services.print`, `programs.{obsidian,office,webcam}`
   (:51, :71-73), `media.droidcam` (:77), and the upstream `programs.{lazygit,thunderbird}` lines (:69-70) move into
   a small module unchanged.
6. Remaining custom roots: `nix.development`, `system.logging` → `features.logging`, `networking.profile` →
   `features.networking.profile`, `programs.winboat` → `features.winboat` (host edits on p620/razer).
7. Delete `modules/common/features-impl.nix`; its git/curl/jq block (:20-24) moves into `modules/common/features.nix`.
8. Home Manager, same recipe: terminals (`alacritty/foot/kitty/wezterm/ghostty/warp/wave`), editors (keep VS Code's
   default-true semantics: it is only false when `editors.enable` is on and `vscode` off), browsers, desktop, cli,
   multiplexers; then delete `Users/common/features-impl.nix` and its double import.

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
