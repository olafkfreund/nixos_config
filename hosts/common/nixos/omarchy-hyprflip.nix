# Hyprflip's Lua loader for the Omarchy session (#1967).
#
# programs.hyprflip (the nixarchy-hyprflip NixOS module) only installs the
# libraries under /etc/hyprflip/. Nothing loads them unless this file does:
# ~/.config/hypr/hyprflip.lua, required from the user-owned autostart.lua. The
# core block is the loader that p620 ran by hand until now, byte for byte. The
# hy3 block adds the container provider when containers.enable is set.
#
# attrByPath, not config.programs.hyprflip.enable: razer and p510 import the
# shared omarchy-* fragments but not the hyprflip module, so the option does
# not exist there and a direct reference fails evaluation.
#
# autostart.lua is user-owned and outlives any generation that stops providing
# this file, so it must load it with
#   pcall(require, "hypr.hyprflip")
# A bare require of a missing file fails the WHOLE Hyprland config and drops
# the session into the error overlay (same caveat as omarchy-meet-binds.nix).
{ config, lib, ... }:
let
  cfg = lib.attrByPath [ "programs" "hyprflip" ] { enable = false; } config;
in
{
  config = lib.mkIf cfg.enable {
    home-manager.users.olafkfreund.home.file.".config/hypr/hyprflip.lua".text =
      ''
        -- Managed by hosts/common/nixos/omarchy-hyprflip.nix -- edits here are overwritten on the next deploy.

        -- Hyprflip: two windows as the faces of a rotating card.
        -- Installed by programs.hyprflip (hosts/p620/nixos/nixarchy.nix), built against
        -- the exact Hyprland this session runs. Loaded from autostart.lua.
        local ok_shortcuts, shortcuts = pcall(require, "hypr.hyprflip-shortcuts")
        if not ok_shortcuts then shortcuts = hl end

        -- Keep this declaration on every parse: it is Hyprland's desired plugin list,
        -- not an immediate load operation. Guarding it would unload on the next parse.
        hl.plugin.load("/etc/hyprflip/hyprflip.so")

        if hl.plugin.hyprflip then
            hl.config({
                -- A native Hyprflip pair is a Hyprland group; hide its tab strip.
                -- Global: ordinary groups lose their title tabs too.
                group = { groupbar = { enabled = false } },
                plugin = {
                    hyprflip = {
                        duration_ms = 420,
                        enabled = true,
                        notifications = true,
                        perspective = 5.0,
                        retreat = 0.02,
                    },
                },
            })

            -- Resolve each function when pressed, so unloading the plugin does not
            -- leave a keybind holding a function pointer into an unloaded library.
            local function run(action)
                return function()
                    local plugin = hl.plugin.hyprflip
                    if plugin and plugin[action] then plugin[action]() end
                end
            end
            shortcuts.bind("SUPER + CTRL + ALT + M", run("mark"), { description = "Hyprflip: mark first side" })
            -- S, not the upstream P: SUPER+CTRL+ALT+P is GitLab Pipelines here.
            shortcuts.bind("SUPER + CTRL + ALT + S", run("pair"), { description = "Hyprflip: attach second side" })
            shortcuts.bind("SUPER + CTRL + ALT + F", run("flip"), { description = "Hyprflip: turn window over" })
            shortcuts.bind("SUPER + CTRL + ALT + U", run("unpair"), { description = "Hyprflip: separate windows" })
            shortcuts.bind("SUPER + CTRL + ALT + Escape", run("cancel"), { description = "Hyprflip: cancel pairing" })
        end
      ''
      + lib.optionalString cfg.containers.enable ''

      -- hy3 container provider (programs.hyprflip.containers.enable), after the core
      -- plugin above as it requires. Adapted from Hyprflip's
      -- examples/containers-trial.lua: the provider comes from /etc/hyprflip, and hy3
      -- takes workspace 8 only, so every other workspace keeps its layout.
      hl.plugin.load("/etc/hyprflip/libhy3.so")

      if hl.plugin.hy3 then
          hl.workspace_rule({ workspace = "8", layout = "hy3" })
      end

      if hl.plugin.hyprflip and hl.plugin.hyprflip.attach then
          -- Resolve at press time so unloading a plugin leaves no stale function.
          local function run_arg(action, argument)
              return function()
                  local plugin = hl.plugin.hyprflip
                  if plugin and plugin[action] then plugin[action](argument) end
              end
          end
          shortcuts.bind("SUPER + CTRL + ALT + H", run_arg("attach", "horizontal"), { description = "Hyprflip: attach pane beside" })
          shortcuts.bind("SUPER + CTRL + ALT + V", run_arg("attach", "vertical"), { description = "Hyprflip: attach pane below" })
          shortcuts.bind("SUPER + CTRL + ALT + E", run_arg("release"), { description = "Hyprflip: release focused pane" })
          if hl.plugin.hyprflip.unfold then
              shortcuts.bind("SUPER + CTRL + ALT + O", run_arg("unfold"), { description = "Hyprflip: unfold or fold both faces" })
          end
      end
      '';
  };
}
