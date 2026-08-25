{ config, lib, pkgs, osConfig, ... }:
# Hyprland session config — the DMS/Noctalia counterpart to home/desktop/wayland.
#
# Hyprland 0.55+ replaced hyprlang with an embedded Lua runtime, so home-manager
# writes ~/.config/hypr/hyprland.lua (configType = "lua"): `settings.<name>`
# renders as `hl.<name>(...)`, `extraConfig` is appended verbatim as Lua.
#
# DankMaterialShell is started directly from the hyprland.start hook. It used
# to go through a ${DESK_SHELL:-noctalia} switch so the session could pick
# between two shells; Noctalia was removed 2026-08-21 and DMS is the only one
# left, so the indirection went with it.
#
# Binds mirror the niri session (home/desktop/wayland) wherever Hyprland has
# an equivalent action; the divergences are commented at the bind (#1367).
let
  inherit (lib.generators) mkLuaInline;
  inherit (import ./common.nix { inherit pkgs osConfig; }) wallpaper isLaptop geo;

  c = n: "rgb(${config.lib.stylix.colors.${n}})";
in
{
  # Stylix's hyprland target writes hyprlang-shaped keys ("col.active_border")
  # even in lua mode, where the API nests them (general.col.active_border), and
  # its hyprpaper sub-target would start a second wallpaper daemon next to
  # swaybg. We set the same base16 colours by hand below instead.
  stylix.targets.hyprland.enable = false;

  # grimblast: Hyprland-aware grim/slurp/wl-copy wrapper behind the screenshot
  # binds (niri has a native screenshot UI, Hyprland does not). Everything else
  # the binds and the startup hook call — swaybg, gammastep, swayidle, slurp,
  # wl-screenrec, the shared `screenrecord` script — comes from
  # home/desktop/wayland, which every session here shares.
  home.packages = [ pkgs.grimblast ];

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
      # home/desktop/wayland: 1px borders, active base0B, inactive base03,
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
              hl.exec_cmd("dms run")
              hl.exec_cmd("swaybg -m fill -i ${wallpaper}")
              hl.exec_cmd("gammastep -l ${geo}")
              hl.exec_cmd("swayidle -w timeout 300 'dms ipc call lock lock' timeout 600 'hyprctl dispatch dpms off' resume 'hyprctl dispatch dpms on' ${lib.optionalString isLaptop "timeout 1800 'systemctl suspend' "}before-sleep 'dms ipc call lock lock'")
            end
          '')
        ];
      };
    };

    # Binds as plain Lua: hl.bind() calls read better here than nested
    # _args/mkLuaInline attrsets, and this is the form the DMS docs use.
    #
    # Ported 1:1 from the niri binds block in home/desktop/wayland where the
    # action exists in Hyprland. niri is scrollable-tiling and Hyprland is
    # dwindle, so the column actions have no direct equivalent — the mapping is
    # recorded per bind below (#1367).
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
      hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())

      -- niri maximize-column / fullscreen-window / windowed-fullscreen.
      hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
      hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
      hl.bind(mod .. " + CTRL + SHIFT + F", hl.dsp.window.fullscreen_state({ internal = 2, client = 0, action = "toggle" }))

      -- niri switch-preset-column-width has no dwindle equivalent; togglesplit
      -- is the nearest "change how this window is laid out" action.
      hl.bind(mod .. " + R", hl.dsp.layout("togglesplit"))

      -- niri set-column-width +-10%. Hyprland resizes in pixels.
      hl.bind(mod .. " + EQUAL", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
      hl.bind(mod .. " + MINUS", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))

      -- niri consume-window-into-column / expel-window-from-column. Groups are
      -- the closest concept: toggle creates or dissolves one, next cycles
      -- through its members.
      hl.bind(mod .. " + COMMA", hl.dsp.group.toggle())
      hl.bind(mod .. " + PERIOD", hl.dsp.group.next())

      -- Focus / move. HJKL is pure directional focus, as on niri.
      for key, dir in pairs({ H = "left", L = "right", J = "down", K = "up" }) do
        hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }))
        hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
      end

      -- Arrows keep niri's split: left/right move focus, up/down change
      -- workspace (niri stacks workspaces vertically and columns horizontally).
      hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }))
      hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
      hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
      hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
      hl.bind(mod .. " + down", hl.dsp.focus({ workspace = "e+1" }))
      hl.bind(mod .. " + up", hl.dsp.focus({ workspace = "e-1" }))
      hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ workspace = "e+1" }))
      hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ workspace = "e-1" }))

      -- Workspaces
      for i = 1, 5 do
        hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
        hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
      end
      hl.bind(mod .. " + Page_Down", hl.dsp.focus({ workspace = "e+1" }))
      hl.bind(mod .. " + Page_Up", hl.dsp.focus({ workspace = "e-1" }))
      hl.bind(mod .. " + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "e+1" }))
      hl.bind(mod .. " + SHIFT + Page_Up", hl.dsp.window.move({ workspace = "e-1" }))
      -- niri throttles wheel workspace switching with cooldown-ms=150; Hyprland
      -- has no equivalent knob.
      hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
      hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

      -- Screenshots. niri has a native screenshot UI; grimblast is the
      -- Hyprland-aware grim/slurp wrapper. copysave = clipboard + ~/Pictures.
      hl.bind(mod .. " + S", hl.dsp.exec_cmd("grimblast copysave area"))
      hl.bind(mod .. " + CTRL + S", hl.dsp.exec_cmd("grimblast copysave output"))
      hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("grimblast copysave active"))

      -- Screen recording (shared script, see home/desktop/wayland)
      hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("screenrecord"))
      hl.bind(mod .. " + ALT + R", hl.dsp.exec_cmd("screenrecord region"))

      -- Shell actions — DankMaterialShell. The overview and the keybind
      -- cheatsheet go through DMS's Hyprland-specific `hypr` IPC target
      -- (`dms ipc call hypr ...`), not the niri one.
      hl.bind(mod .. " + D", hl.dsp.exec_cmd("dms ipc call spotlight toggle"))
      hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("dms ipc call spotlight toggle"))
      hl.bind(mod .. " + C", hl.dsp.exec_cmd("dms ipc call control-center toggle"))
      hl.bind(mod .. " + N", hl.dsp.exec_cmd("dms ipc call notifications toggle"))
      hl.bind(mod .. " + X", hl.dsp.exec_cmd("dms ipc call powermenu toggle"))
      hl.bind(mod .. " + O", hl.dsp.exec_cmd("dms ipc call hypr toggleOverview"))
      hl.bind(mod .. " + TAB", hl.dsp.exec_cmd("dms ipc call hypr toggleOverview"))
      hl.bind(mod .. " + SHIFT + SLASH", hl.dsp.exec_cmd("dms ipc call hypr toggleBinds"))
      hl.bind(mod .. " + BACKSPACE", hl.dsp.exec_cmd("dms ipc call lock lock"), { locked = true })
      hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("dms ipc call clipboard toggle"))

      -- Media / brightness (locked so they work on the lock screen)
      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
      hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
      hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
      hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

      -- Media transport. services.playerctld.enable is true on p620 and razer and
      -- playerctl ships in modules/system-utils, but nothing was bound to it in
      -- either session, so these keys did nothing.
      hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
      hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
      hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
      hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
      hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true })
    '';
  };
}
