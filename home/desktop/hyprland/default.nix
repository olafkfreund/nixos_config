{ config, lib, osConfig, ... }:
# Hyprland session config — the DMS/Noctalia counterpart to home/desktop/noctalia.
#
# Hyprland 0.55+ replaced hyprlang with an embedded Lua runtime, so home-manager
# writes ~/.config/hypr/hyprland.lua (configType = "lua"): `settings.<name>`
# renders as `hl.<name>(...)`, `extraConfig` is appended verbatim as Lua.
#
# Which shell starts is decided by the login session, exactly as for labwc/mango:
# the stock "Hyprland" session leaves DESK_SHELL unset -> Noctalia, the
# "Hyprland (DankMaterialShell)" session sets DESK_SHELL="dms run" -> DMS
# (modules/desktop/dms-shell.nix).
#
# Phase 1 (#1366): session, colours, essential binds. The full 146-bind niri
# parity port, screen recorder and window rules are #1367.
let
  inherit (lib.generators) mkLuaInline;

  # Same wallpaper Stylix uses; swaybg paints it, as on niri/labwc/mango.
  wallpaper = (import ../../../hosts/common/shared-variables.nix).baseTheme.wallpaper;

  # Only laptops auto-suspend on idle; the workstation stays up (RDP / AI host).
  isLaptop = (osConfig.host.class or "") == "laptop";

  # Fixed UK coordinates (London), matching the niri session's gammastep.
  geo = "51.5:-0.13";

  c = n: "rgb(${config.lib.stylix.colors.${n}})";
in
{
  # Stylix's hyprland target writes hyprlang-shaped keys ("col.active_border")
  # even in lua mode, where the API nests them (general.col.active_border), and
  # its hyprpaper sub-target would start a second wallpaper daemon next to
  # swaybg. We set the same base16 colours by hand below instead.
  stylix.targets.hyprland.enable = false;

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";

    # The compositor and its portal come from the NixOS module
    # (modules/desktop/hyprland.nix); home-manager only writes the config.
    package = null;
    portalPackage = null;

    # greetd launches the session directly, like niri/labwc/mango — no
    # hyprland-session.target wiring.
    systemd.enable = false;

    settings = {
      # `hl.env(...)`. greetd does not source environment.sessionVariables, so
      # the Electron apps need these exported from the compositor itself.
      env = [
        { _args = [ "NIXOS_OZONE_WL" "1" ]; }
        { _args = [ "ELECTRON_OZONE_PLATFORM_HINT" "auto" ]; }
      ];

      # `hl.config{...}`. Colours mirror the niri layout block in
      # home/desktop/noctalia: 1px borders, active base0B, inactive base03,
      # 12px outer gaps, base0B-tinted shadow.
      config = {
        general = {
          gaps_in = 6;
          gaps_out = 12;
          border_size = 1;
          col = {
            active_border = c "base0B";
            inactive_border = c "base03";
          };
          layout = "dwindle";
        };

        decoration = {
          rounding = 8;
          shadow = {
            enabled = true;
            range = 14;
            render_power = 2;
            color = "rgba(${config.lib.stylix.colors.base0B}33)";
          };
        };

        dwindle.preserve_split = true;

        input = {
          # Matches programs.niri.settings.input.keyboard.xkb.layout.
          kb_layout = "gb";
          follow_mouse = 1;
        };

        misc = {
          force_default_wallpaper = 0;
          disable_hyprland_logo = true;
        };
      };

      # `hl.on("hyprland.start", function() ... end)`. swaybg/gammastep/swayidle
      # are the same helpers the niri and labwc sessions start.
      on = {
        _args = [
          "hyprland.start"
          (mkLuaInline ''
            function()
              hl.exec_cmd("sh -c 'exec ''${DESK_SHELL:-noctalia}'")
              hl.exec_cmd("swaybg -m fill -i ${wallpaper}")
              hl.exec_cmd("gammastep -l ${geo}")
              hl.exec_cmd("swayidle -w timeout 300 'dms ipc call lock lock' timeout 600 'hyprctl dispatch dpms off' resume 'hyprctl dispatch dpms on' ${lib.optionalString isLaptop "timeout 1800 'systemctl suspend' "}before-sleep 'dms ipc call lock lock'")
            end
          '')
        ];
      };
    };

    # Binds as plain Lua: 30 hl.bind() calls read better here than 30 nested
    # _args/mkLuaInline attrsets, and this is the form the DMS docs use.
    #
    # DMS writes ~/.config/hypr/dms/{colors,layout,outputs}.lua at runtime.
    # Only outputs is required: colours and layout are ours (same reasoning as
    # the excluded dms/colors.kdl + dms/layout.kdl on niri). hyprland.lua is a
    # read-only store symlink, so the require must tolerate a missing file.
    extraConfig = ''
      package.path = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config"))
        .. "/hypr/?.lua;" .. package.path
      pcall(require, "dms.outputs")

      local mod = "SUPER"

      -- Launchers / window management
      hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd("ghostty"))
      hl.bind(mod .. " + T", hl.dsp.exec_cmd("ghostty"))
      hl.bind(mod .. " + E", hl.dsp.exec_cmd("nautilus"))
      hl.bind(mod .. " + Q", hl.dsp.window.close())
      hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
      hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
      hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
      hl.bind(mod .. " + R", hl.dsp.layout("togglesplit"))
      hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())

      -- Focus / move. HJKL and the arrows both move focus; niri's arrow-based
      -- workspace switching lives on Page_Up/Down here (see #1367).
      for key, dir in pairs({ H = "left", L = "right", J = "down", K = "up" }) do
        hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }))
        hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
      end
      for key, dir in pairs({ left = "left", right = "right", down = "down", up = "up" }) do
        hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }))
        hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
      end

      -- Workspaces
      for i = 1, 5 do
        hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
        hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
      end
      hl.bind(mod .. " + Page_Down", hl.dsp.focus({ workspace = "e+1" }))
      hl.bind(mod .. " + Page_Up", hl.dsp.focus({ workspace = "e-1" }))
      hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
      hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

      -- Shell actions — DankMaterialShell
      hl.bind(mod .. " + D", hl.dsp.exec_cmd("dms ipc call spotlight toggle"))
      hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("dms ipc call spotlight toggle"))
      hl.bind(mod .. " + C", hl.dsp.exec_cmd("dms ipc call control-center toggle"))
      hl.bind(mod .. " + N", hl.dsp.exec_cmd("dms ipc call notifications toggle"))
      hl.bind(mod .. " + X", hl.dsp.exec_cmd("dms ipc call powermenu toggle"))
      hl.bind(mod .. " + O", hl.dsp.exec_cmd("dms ipc call overview toggle"))
      hl.bind(mod .. " + TAB", hl.dsp.exec_cmd("dms ipc call overview toggle"))
      hl.bind(mod .. " + BACKSPACE", hl.dsp.exec_cmd("dms ipc call lock lock"), { locked = true })

      -- Media / brightness (locked so they work on the lock screen)
      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
      hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
      hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
    '';
  };
}
