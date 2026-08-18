{ config, lib, pkgs, osConfig, ... }:
# mango session: colours, keybinds and the autostart hook.
let
  inherit (import ./common.nix { inherit pkgs osConfig; })
    wallpaper isLaptop lockCmd geo gtkSchemas;
in
{
  # ── mango ──────────────────────────────────────────────────────────────
  # mango (dwl-based) session config. Gated on the host enabling the compositor
  # because the mango home-manager module pulls the mango package into
  # home.packages — without the gate it would compile mango on headless p510,
  # which also evaluates this shared profile. Same Super-based keybinds,
  # colours and companion daemons as niri/labwc; mango's native
  # `env=` directive (applied via setenv in the compositor) is its equivalent
  # of niri's environment block, so Electron apps get NIXOS_OZONE_WL=1.
  wayland.windowManager.mango = lib.mkIf (osConfig.desktop.mangowm.enable or false) (
    let
      inherit (config.lib.stylix) colors;
      c = n: "0x${colors.${n}}ff"; # mango wants 0xRRGGBBAA
    in
    {
      enable = true;
      # Reuse the system mango (nixpkgs, via programs.mango) so the HM side
      # doesn't build the mango flake's own package on top of it.
      package = osConfig.programs.mango.package;

      extraConfig = ''
        # Electron apps → Wayland (same fix as niri/labwc).
        env=NIXOS_OZONE_WL,1
        env=ELECTRON_OZONE_PLATFORM_HINT,auto
        # GTK GSettings schemas so GTK apps (GIMP, darktable) don't abort.
        env=GSETTINGS_SCHEMA_DIR,${gtkSchemas}

        # UK keyboard
        xkb_rules_layout=gb

        # Appearance — via Stylix (active border = accent base0B).
        borderpx=2
        rootcolor=${c "base00"}
        bordercolor=${c "base01"}
        focuscolor=${c "base0B"}
        urgentcolor=${c "base08"}
        gappih=4
        gappiv=4
        gappoh=4
        gappov=4

        # Keys are kept in lockstep with the niri binds above. niri-only actions
        # with no mango equivalent are intentionally absent:
        #   Mod+Comma/Period (consume/expel into column), Mod+Minus/Equal (width
        #   nudge — use Mod+R presets), Mod+P (mirror), Mod+Shift+Slash (hotkey
        #   overlay), Mod+WheelScroll (workspace). Per-WM natural focus is kept,
        #   so arrows/hjkl are directional focus here (niri uses Up/Down=workspace).

        # Apps
        bind=SUPER,Return,spawn,ghostty
        bind=SUPER,t,spawn,ghostty
        bind=SUPER,d,spawn,noctalia msg panel-toggle launcher
        bind=SUPER,space,spawn,noctalia msg panel-toggle launcher
        bind=SUPER,c,spawn,noctalia msg panel-toggle control-center
        bind=SUPER,BackSpace,spawn,noctalia msg session lock
        bind=SUPER,e,spawn,nautilus
        bind=SUPER,q,killclient,
        bind=SUPER+SHIFT,e,quit

        # Focus (arrows + vim hjkl)
        bind=SUPER,Left,focusdir,left
        bind=SUPER,Right,focusdir,right
        bind=SUPER,Up,focusdir,up
        bind=SUPER,Down,focusdir,down
        bind=SUPER,h,focusdir,left
        bind=SUPER,l,focusdir,right
        bind=SUPER,j,focusdir,down
        bind=SUPER,k,focusdir,up

        # Move / swap
        bind=SUPER+SHIFT,Left,exchange_client,left
        bind=SUPER+SHIFT,Right,exchange_client,right
        bind=SUPER+SHIFT,Up,exchange_client,up
        bind=SUPER+SHIFT,Down,exchange_client,down
        bind=SUPER+SHIFT,h,exchange_client,left
        bind=SUPER+SHIFT,l,exchange_client,right
        bind=SUPER+SHIFT,j,exchange_client,down
        bind=SUPER+SHIFT,k,exchange_client,up

        # Window state (aligned with niri)
        bind=SUPER,f,togglemaximizescreen,
        bind=SUPER+SHIFT,f,togglefullscreen,
        # Mod+Ctrl+Shift+F → windowed/"fake" fullscreen (niri toggle-windowed-fullscreen)
        bind=SUPER+CTRL+SHIFT,f,togglefakefullscreen,
        bind=SUPER,v,togglefloating,
        bind=SUPER,o,toggleoverview,
        # Mod+R → cycle preset column widths (niri switch-preset-column-width);
        # mango's scroller_proportion_preset=0.5,0.8,1.0 mirrors niri's presets.
        bind=SUPER,r,switch_proportion_preset,
        bind=SUPER,n,switch_layout

        # Tags 1-5: view (switch) / tag (move window to)
        bind=SUPER,1,view,1,0
        bind=SUPER,2,view,2,0
        bind=SUPER,3,view,3,0
        bind=SUPER,4,view,4,0
        bind=SUPER,5,view,5,0
        bind=SUPER+SHIFT,1,tag,1,0
        bind=SUPER+SHIFT,2,tag,2,0
        bind=SUPER+SHIFT,3,tag,3,0
        bind=SUPER+SHIFT,4,tag,4,0
        bind=SUPER+SHIFT,5,tag,5,0

        # Screenshots: Mod+S region, Mod+Ctrl+S whole output (Print kept as alias).
        # niri's Mod+Shift+S (per-window) has no noctalia equivalent — use Mod+S.
        bind=SUPER,s,spawn,noctalia msg screenshot-region
        bind=SUPER+CTRL,s,spawn,noctalia msg screenshot-fullscreen
        bind=none,Print,spawn,noctalia msg screenshot-region
        # Region recording (re-press to stop). Mod+Alt+R matches niri's region key;
        # Mod+Shift+R kept as alias (niri's Mod+Shift+R focused-output is niri-only).
        bind=SUPER+ALT,r,spawn,screenrecord region
        bind=SUPER+SHIFT,r,spawn,screenrecord region

        # Media / brightness
        bind=none,XF86AudioRaiseVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
        bind=none,XF86AudioLowerVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        bind=none,XF86AudioMute,spawn,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        bind=none,XF86MonBrightnessUp,spawn,brightnessctl set 5%+
        bind=none,XF86MonBrightnessDown,spawn,brightnessctl set 5%-
      '';

      # Companion daemons (same as niri/labwc). mango has no native DPMS action,
      # so swayidle drives wlopm for screen-off, like labwc. Suspend on laptops.
      autostart_sh = ''
        swaybg -m fill -i ${wallpaper} &
        gammastep -l ${geo} &
        swayidle -w \
          timeout 300 '${lockCmd}' \
          timeout 600 "wlopm --off '*'" resume "wlopm --on '*'" \
          ${lib.optionalString isLaptop "timeout 1800 'systemctl suspend' \\\n      "}before-sleep '${lockCmd}' &
        ''${DESK_SHELL:-noctalia} &
      '';
    }
  );
}
