{ config, lib, pkgs, osConfig, ... }:
# labwc session: autostart hook, environment, themerc colours and rc.xml
# keybinds.
let
  inherit (import ./common.nix { inherit pkgs osConfig; })
    wallpaper isLaptop lockCmd geo gtkSchemas;
in
{
  # ── labwc ──────────────────────────────────────────────────────────────
  # Launch the shell + companion daemons from labwc's autostart hook. labwc has
  # no native DPMS action, so swayidle drives wlopm for screen-off. Same idle
  # timings as niri; suspend only on laptops.
  xdg.configFile."labwc/autostart".text = ''
    swaybg -m fill -i ${wallpaper} &
    gammastep -l ${geo} &
    swayidle -w \
      timeout 300 '${lockCmd}' \
      timeout 600 "wlopm --off '*'" resume "wlopm --on '*'" \
      ${lib.optionalString isLaptop "timeout 1800 'systemctl suspend' \\\n      "}before-sleep '${lockCmd}' &
    ''${DESK_SHELL:-noctalia} &
  '';

  # Session environment, read at labwc startup. XKB layout for the keyboard,
  # plus NIXOS_OZONE_WL=1 so Electron apps (claude-desktop, VS Code, …) use the
  # Wayland backend rather than XWayland — greetd's `exec labwc` doesn't source
  # the system environment.sessionVariables, so labwc exports them from here.
  xdg.configFile."labwc/environment".text = ''
    XKB_DEFAULT_LAYOUT=gb
    NIXOS_OZONE_WL=1
    ELECTRON_OZONE_PLATFORM_HINT=auto
    GSETTINGS_SCHEMA_DIR=${gtkSchemas}
  '';

  # OSD theming for labwc (window-switcher / workspace overlays
  # are white by default), window borders, and menus. themerc-override patches
  # the active theme's colors without needing a full theme. Colors come from
  # the system Stylix base16 scheme, so this matches GNOME/tmux.
  xdg.configFile."labwc/themerc-override".text =
    let inherit (config.lib.stylix) colors; in ''
      # Window decorations
      window.active.border.color: #${colors.base0B}
      window.active.title.bg.color: #${colors.base00}
      window.active.label.text.color: #${colors.base05}
      window.inactive.border.color: #${colors.base01}
      window.inactive.title.bg.color: #${colors.base01}
      window.inactive.label.text.color: #${colors.base04}

      # Right-click / client menus
      menu.items.bg.color: #${colors.base00}
      menu.items.text.color: #${colors.base05}
      menu.items.active.bg.color: #${colors.base02}
      menu.items.active.text.color: #${colors.base05}

      # OSD overlays (the white window-switcher / workspace popups)
      osd.bg.color: #${colors.base00}
      osd.border.color: #${colors.base0B}
      osd.border.width: 2
      osd.label.text.color: #${colors.base05}
      osd.window-switcher.item.active.border.color: #${colors.base0B}
      osd.workspace-switcher.boxes.active.bg.color: #${colors.base0B}
      osd.workspace-switcher.boxes.inactive.bg.color: #${colors.base02}
    '';

  # Keybinds — kept in lockstep with the niri binds above (W = Super/logo) so
  # the same keys do the same thing across WMs. labwc is a *stacking* compositor,
  # so niri's tiling-only binds have no equivalent and are intentionally absent:
  #   Mod+H/L/J/K (column/window focus) → use A-Tab; arrows switch desktops
  #   Mod+R, Mod+Comma/Period, Mod+Minus/Equal (columns)  — N/A (no tiling)
  #   Mod+V (float, labwc windows always float), Mod+O (overview)  — N/A
  #   Mod+Ctrl+Shift+F (windowed-fullscreen), Mod+P (mirror),
  #   Mod+Shift+Slash (hotkey overlay), Mod+Shift+S (window shot)  — niri-only
  xdg.configFile."labwc/rc.xml".text = ''
    <?xml version="1.0"?>
    <labwc_config>
      <desktops>
        <number>5</number>
      </desktops>
      <keyboard>
        <!-- Apps / system (identical keys to niri) -->
        <keybind key="W-Return"><action name="Execute" command="ghostty"/></keybind>
        <keybind key="W-t"><action name="Execute" command="ghostty"/></keybind>
        <keybind key="W-d"><action name="Execute" command="noctalia msg panel-toggle launcher"/></keybind>
        <keybind key="W-Space"><action name="Execute" command="noctalia msg panel-toggle launcher"/></keybind>
        <keybind key="W-c"><action name="Execute" command="noctalia msg panel-toggle control-center"/></keybind>
        <keybind key="W-BackSpace"><action name="Execute" command="noctalia msg session lock"/></keybind>
        <keybind key="W-e"><action name="Execute" command="nautilus"/></keybind>
        <keybind key="W-q"><action name="Close"/></keybind>
        <keybind key="W-S-e"><action name="Exit"/></keybind>
        <!-- Window focus/switching (stacking-native: A-Tab + desktop arrows) -->
        <keybind key="A-Tab"><action name="NextWindow"/></keybind>
        <keybind key="A-S-Tab"><action name="PreviousWindow"/></keybind>
        <keybind key="W-Left"><action name="GoToDesktop" to="left" wrap="yes"/></keybind>
        <keybind key="W-Right"><action name="GoToDesktop" to="right" wrap="yes"/></keybind>
        <keybind key="W-Up"><action name="GoToDesktop" to="left" wrap="yes"/></keybind>
        <keybind key="W-Down"><action name="GoToDesktop" to="right" wrap="yes"/></keybind>
        <!-- Window state (Mod+F maximize, Mod+Shift+F fullscreen — same as niri) -->
        <keybind key="W-f"><action name="ToggleMaximize"/></keybind>
        <keybind key="W-S-f"><action name="ToggleFullscreen"/></keybind>
        <!-- Desktops 1-5 (identical to niri Mod+1..5) -->
        <keybind key="W-1"><action name="GoToDesktop" to="1"/></keybind>
        <keybind key="W-2"><action name="GoToDesktop" to="2"/></keybind>
        <keybind key="W-3"><action name="GoToDesktop" to="3"/></keybind>
        <keybind key="W-4"><action name="GoToDesktop" to="4"/></keybind>
        <keybind key="W-5"><action name="GoToDesktop" to="5"/></keybind>
        <keybind key="W-S-1"><action name="SendToDesktop" to="1"/></keybind>
        <keybind key="W-S-2"><action name="SendToDesktop" to="2"/></keybind>
        <keybind key="W-S-3"><action name="SendToDesktop" to="3"/></keybind>
        <keybind key="W-S-4"><action name="SendToDesktop" to="4"/></keybind>
        <keybind key="W-S-5"><action name="SendToDesktop" to="5"/></keybind>
        <!-- Screenshots: Mod+S region, Mod+Ctrl+S whole output (+ Print alias) -->
        <keybind key="W-s"><action name="Execute" command="noctalia msg screenshot-region"/></keybind>
        <keybind key="W-C-s"><action name="Execute" command="noctalia msg screenshot-fullscreen"/></keybind>
        <keybind key="Print"><action name="Execute" command="noctalia msg screenshot-region"/></keybind>
        <!-- Screen recording (region; re-press to stop). Mod+Alt+R matches niri's
             region key; Mod+Shift+R kept as an alias. screenrecord's region
             branch is compositor-agnostic (slurp + wl-screenrec). -->
        <keybind key="W-A-r"><action name="Execute" command="screenrecord region"/></keybind>
        <keybind key="W-S-r"><action name="Execute" command="screenrecord region"/></keybind>
        <!-- Media / brightness (identical to niri) -->
        <keybind key="XF86_AudioRaiseVolume"><action name="Execute" command="wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"/></keybind>
        <keybind key="XF86_AudioLowerVolume"><action name="Execute" command="wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"/></keybind>
        <keybind key="XF86_AudioMute"><action name="Execute" command="wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"/></keybind>
        <keybind key="XF86_MonBrightnessUp"><action name="Execute" command="brightnessctl set 5%+"/></keybind>
        <keybind key="XF86_MonBrightnessDown"><action name="Execute" command="brightnessctl set 5%-"/></keybind>
      </keyboard>
    </labwc_config>
  '';
}
