---
status: draft
issue: 1967
intent: intent/2026-09-22-1967-hyprflip-hy3-containers.md
---

# Spec: load the hy3 container provider for Hyprflip on p620

Builds on PR #1969 (#1968), which commits the `programs.hyprflip` wiring that p620
already runs. This branch is stacked on it and merges after it.

## Design

**One new module, `hosts/common/nixos/omarchy-hyprflip.nix`**, imported by
`hosts/p620/nixos/nixarchy.nix` next to the other `omarchy-*.nix` fragments. It
follows `omarchy-meet-binds.nix`: it writes a Lua file through
`home-manager.users.olafkfreund.home.file`, guarded by the feature it serves:

```nix
{ config, lib, ... }:
let
  cfg = lib.attrByPath [ "programs" "hyprflip" ] { enable = false; } config;
in
{
  config = lib.mkIf cfg.enable {
    home-manager.users.olafkfreund.home.file.".config/hypr/hyprflip.lua".text =
      ''<core loader>'' + lib.optionalString cfg.containers.enable ''<hy3 block>'';
  };
}
```

`attrByPath` rather than `config.programs.hyprflip.enable`: razer and p510 import
the shared `omarchy-*` modules but not the hyprflip NixOS module, so the option
does not exist there and a direct reference fails evaluation. This is the same
reasoning as `omarchy-meet-binds.nix`.

**One file, not two.** Upstream splits the loader into `hyprflip.lua` plus
`hyprflip-containers.lua` and requires both, in that order, from `hyprland.lua`.
Here a single generated `hyprflip.lua` puts the hy3 block after the core block,
which gives the ordering hy3 needs ("after hypr.hyprflip") by construction, with
no second `require` to keep in order.

**Core loader: the current hand-written `~/.config/hypr/hyprflip.lua`, verbatim**
(41 lines: optional `hypr.hyprflip-shortcuts`,
`hl.plugin.load("/etc/hyprflip/hyprflip.so")`, the plugin config, and the
M/S/F/U/Escape binds with this repo's P→S remap), plus a "managed by" header.
Nothing in the working core behaviour changes.

**hy3 block**, adapted from upstream `examples/containers-trial.lua` (identical in
the pinned fork):

- `hl.plugin.load("/etc/hyprflip/libhy3.so")`, the store-backed path the NixOS
  module installs, not upstream's `~/.local/lib/hyprflip/containers/libhy3.so`.
- `if hl.plugin.hy3 then hl.workspace_rule({ workspace = "8", layout = "hy3" }) end`:
  hy3 on workspace 8 only, as the approved intent recommends. Every other
  workspace keeps its current layout.
- Super+Ctrl+Alt+H/V/E (+O when `unfold` exists), each resolved at press time and
  guarded on `hl.plugin.hyprflip.attach`, as upstream does. None is bound on p620
  today (checked: none of the 15 existing Super+Ctrl+Alt binds uses them).

**`autostart.lua` becomes `pcall(require, "hypr.hyprflip")`.** Today it is a bare
`require`. Once Home Manager owns `hyprflip.lua`, a generation without
`programs.hyprflip` removes the file. A bare `require` of a missing module fails
the whole Hyprland config and drops the session into the error overlay (the
warning in `omarchy-meet-binds.nix`). `autostart.lua` is user-owned and outside
the repo, so this is a documented one-line hand edit, made before the switch.

**Taking over the existing file.** `~/.config/hypr/hyprflip.lua` is a regular
file today. `flake.nix` sets Home Manager's `backupCommand`, which moves a
clobbered regular file into `~/.hm-backups/` instead of failing the activation.
It applies to regular files, not symlinks, and this is a regular file.

**When it takes effect: at the next re-login, not at the switch.** The switch only
writes the file. The running compositor re-reads config on `hyprctl reload`, which
is ruled out: it killed every Omarchy shell keybinding on p620 on 2026-09-22.
Loading `libhy3.so` live with `hyprctl plugin load` would load the library, but
not the workspace rule or the binds. So the switch is harmless to the running
session, and the re-login applies everything at once. It also loads the pending
shell fix from nixarchy issue 894.

**The OmaCards helper stays out of scope**, per the approved intent. It gets its
own issue.

## Alternatives rejected

- **Two files (`hyprflip.lua` plus `hyprflip-containers.lua`), as upstream does.**
  Two requires to keep ordered in a user-owned file, for no gain here.
- **hy3 on every workspace** (upstream's `trial_workspace = nil`). This changes
  the layout of every workspace the owner uses daily. The intent chose workspace 8.
- **Load live with `hyprctl reload`.** It killed the shell keybindings once today.
- **Load live with `hyprctl plugin load` alone.** It loads a library with no
  workspace rule and no binds: a half-configured state that the next login
  replaces anyway.
- **The fork's Home Manager module** (`hyprflip.homeManagerModules`). It loads
  plugins through Home Manager's `wayland.windowManager.hyprland` plugin list,
  which the Omarchy Lua session never reads, because its `hyprland.lua` comes
  from the Omarchy store tree.
- **Keep `hyprflip.lua` hand-written and only append hy3 to it by hand.** That
  leaves the whole loader outside the repo, which the approved intent rejected.

## Risks

- **The patched hy3 (`12a73ab`) has never been loaded next to this Hyprflip build
  on Hyprland `23118f9f`.** A crash in either plugin takes down the compositor.
  Mitigation: the nested-session proof (Verification step 3) runs before any
  real login loads it.
- **A bad first login.** If the session fails anyway, the GNOME session is still
  offered at the greeter. From it (or a TTY), switch to the previous generation,
  or set `programs.hyprflip.containers.enable = false` and rebuild.
- **The bare `require` trap** is covered by the `pcall` edit. If that edit were
  skipped, removing `programs.hyprflip` later would break the session config.
- **Workspace 8 has windows at login.** hy3 takes over the layout of whatever is
  there. It is empty today, and upstream advises separating native groups on it
  first.
- **Only p620 changes.** The module is imported only there and does nothing where
  `programs.hyprflip` is absent. razer and p510 are not built or deployed.

## Verification

1. **Evaluation and build:** `nix build .#nixosConfigurations.p620.config.system.build.toplevel`
   succeeds. razer and p510 still evaluate, which proves the `attrByPath` guard.
2. **Generated file:** in the built Home Manager files, `.config/hypr/hyprflip.lua`
   contains the core block unchanged (a diff against the current hand file shows
   only the header and the appended hy3 block), with hy3 loaded after
   `hyprflip.so`.
3. **Nested-session proof, before any real login:** run upstream's
   `tests/nested_session.py --containers` in a short `/tmp` directory, with its
   `build/containers/{core/hyprflip.so,provider/upstream/libhy3.so}` pointing at
   the built system's `/etc/hyprflip/` libraries and the same `Hyprland`
   (`23118f9f`). Pass: both plugins listed in the nested `hyprctl -j plugin list`,
   and nested `hyprctl hyprflip status` shows `container_provider: true` and
   `container_max_panes: 3`, with no crash. It is disposable: its own config,
   runtime and state dirs, and no effect on the parent session.
4. **Live, after the owner re-logs in:** `hyprctl -j plugin list` shows `hyprflip`
   and `hy3`; `hyprctl hyprflip status` shows provider true and max panes 3;
   `hyprctl configerrors` is empty; the OmaCards helper `snapshot` reports
   `containers: true`; and the existing M/S/F/U flips and Omarchy shell
   keybindings (Super+Space) still work.
