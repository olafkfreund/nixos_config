{ config, lib, ... }:
# Noctalia desktop shell + niri/labwc session config (keybinds, layout, UK
# keyboard) for the niri and labwc sessions. Noctalia is launched only from the
# niri/labwc startup hooks (NOT via its systemd service, which binds to the
# graphical-session target that GNOME also reaches → would spawn a second shell
# over gnome-shell).
#
# Theming: builtin Catppuccin for now. TODO (fast-follow): bridge Stylix's
# base16 palette into programs.noctalia.customPalettes + theme.source="custom".
{
  programs.noctalia = {
    enable = true;
    systemd.enable = false;
    settings = {
      shell.font = "JetBrainsMono Nerd Font";
      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Catppuccin";
      };
    };
  };

  # ── niri ───────────────────────────────────────────────────────────────
  # UK keyboard for the niri session (wlroots compositors don't inherit the
  # system xkb.layout).
  programs.niri.settings.input.keyboard.xkb.layout = "gb";

  # Launch the shell at session start (inherits the niri session env).
  programs.niri.settings.spawn-at-startup = lib.mkAfter [
    { command = [ "noctalia" ]; }
  ];

  # Keybinds. Mod = Super/logo. Press Mod+Shift+/ for niri's hotkey overlay.
  programs.niri.settings.binds = with config.lib.niri.actions; {
    "Mod+Return".action = spawn "ghostty";
    "Mod+T".action = spawn "ghostty";
    "Mod+D".action = spawn "noctalia" "msg" "panel-toggle" "launcher";
    "Mod+Space".action = spawn "noctalia" "msg" "panel-toggle" "launcher";
    "Mod+C".action = spawn "noctalia" "msg" "panel-toggle" "control-center";
    "Mod+Backspace".action = spawn "noctalia" "msg" "session" "lock";
    "Mod+E".action = spawn "nautilus";
    "Mod+Q".action = close-window;
    "Mod+Shift+E".action = quit; # niri asks for confirmation

    # Focus (arrows + vim hjkl)
    # Super+Left/Right = move between columns; Super+Up/Down = switch workspace.
    "Mod+Left".action = focus-column-left;
    "Mod+Right".action = focus-column-right;
    "Mod+Up".action = focus-workspace-up;
    "Mod+Down".action = focus-workspace-down;
    # vim keys: h/l columns, j/k window-within-column
    "Mod+H".action = focus-column-left;
    "Mod+L".action = focus-column-right;
    "Mod+J".action = focus-window-down;
    "Mod+K".action = focus-window-up;

    # Move
    "Mod+Shift+Left".action = move-column-left;
    "Mod+Shift+Right".action = move-column-right;
    "Mod+Shift+H".action = move-column-left;
    "Mod+Shift+L".action = move-column-right;
    "Mod+Shift+J".action = move-window-down;
    "Mod+Shift+K".action = move-window-up;

    # Workspaces (niri uses dynamic workspaces; focus by index, move relative)
    "Mod+1".action = focus-workspace 1;
    "Mod+2".action = focus-workspace 2;
    "Mod+3".action = focus-workspace 3;
    "Mod+4".action = focus-workspace 4;
    "Mod+5".action = focus-workspace 5;
    "Mod+Page_Down".action = focus-workspace-down;
    "Mod+Page_Up".action = focus-workspace-up;
    "Mod+Shift+Page_Down".action = move-column-to-workspace-down;
    "Mod+Shift+Page_Up".action = move-column-to-workspace-up;

    # Window/column sizing & state
    "Mod+F".action = maximize-column;
    "Mod+Shift+F".action = fullscreen-window;
    "Mod+R".action = switch-preset-column-width;
    "Mod+V".action = toggle-window-floating;
    "Mod+Comma".action = consume-window-into-column;
    "Mod+Period".action = expel-window-from-column;

    # Screenshots (via Noctalia) + overlay (Mod+Shift+/ lists all binds)
    "Print".action = spawn "noctalia" "msg" "screenshot-region";
    "Mod+Shift+S".action = spawn "noctalia" "msg" "screenshot-region";
    "Mod+Print".action = spawn "noctalia" "msg" "screenshot-fullscreen";
    "Mod+Shift+Slash".action = show-hotkey-overlay;

    # Media / brightness keys
    "XF86AudioRaiseVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+";
    "XF86AudioLowerVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-";
    "XF86AudioMute".action = spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle";
    "XF86MonBrightnessUp".action = spawn "brightnessctl" "set" "5%+";
    "XF86MonBrightnessDown".action = spawn "brightnessctl" "set" "5%-";
  };

  # ── labwc ──────────────────────────────────────────────────────────────
  # Launch the shell from labwc's autostart hook.
  xdg.configFile."labwc/autostart".text = ''
    noctalia &
  '';

  # UK keyboard (read at labwc startup, before keyboard init).
  xdg.configFile."labwc/environment".text = ''
    XKB_DEFAULT_LAYOUT=gb
  '';

  # Keybinds (labwc ships only sparse compiled-in defaults). W = Super/logo.
  xdg.configFile."labwc/rc.xml".text = ''
    <?xml version="1.0"?>
    <labwc_config>
      <desktops>
        <number>4</number>
      </desktops>
      <keyboard>
        <keybind key="W-Return"><action name="Execute" command="ghostty"/></keybind>
        <keybind key="W-d"><action name="Execute" command="noctalia msg panel-toggle launcher"/></keybind>
        <keybind key="W-c"><action name="Execute" command="noctalia msg panel-toggle control-center"/></keybind>
        <keybind key="W-BackSpace"><action name="Execute" command="noctalia msg session lock"/></keybind>
        <keybind key="Print"><action name="Execute" command="noctalia msg screenshot-region"/></keybind>
        <keybind key="W-e"><action name="Execute" command="nautilus"/></keybind>
        <keybind key="W-q"><action name="Close"/></keybind>
        <keybind key="A-Tab"><action name="NextWindow"/></keybind>
        <keybind key="A-S-Tab"><action name="PreviousWindow"/></keybind>
        <keybind key="W-f"><action name="ToggleMaximize"/></keybind>
        <keybind key="W-S-f"><action name="ToggleFullscreen"/></keybind>
        <keybind key="W-Space"><action name="ShowMenu" menu="client-menu"/></keybind>
        <keybind key="W-Left"><action name="GoToDesktop" to="left" wrap="yes"/></keybind>
        <keybind key="W-Right"><action name="GoToDesktop" to="right" wrap="yes"/></keybind>
        <keybind key="W-Up"><action name="GoToDesktop" to="left" wrap="yes"/></keybind>
        <keybind key="W-Down"><action name="GoToDesktop" to="right" wrap="yes"/></keybind>
        <keybind key="W-1"><action name="GoToDesktop" to="1"/></keybind>
        <keybind key="W-2"><action name="GoToDesktop" to="2"/></keybind>
        <keybind key="W-3"><action name="GoToDesktop" to="3"/></keybind>
        <keybind key="W-4"><action name="GoToDesktop" to="4"/></keybind>
        <keybind key="W-S-1"><action name="SendToDesktop" to="1"/></keybind>
        <keybind key="W-S-2"><action name="SendToDesktop" to="2"/></keybind>
        <keybind key="W-S-3"><action name="SendToDesktop" to="3"/></keybind>
        <keybind key="W-S-4"><action name="SendToDesktop" to="4"/></keybind>
        <keybind key="W-S-e"><action name="Exit"/></keybind>
        <keybind key="XF86_AudioRaiseVolume"><action name="Execute" command="wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"/></keybind>
        <keybind key="XF86_AudioLowerVolume"><action name="Execute" command="wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"/></keybind>
        <keybind key="XF86_AudioMute"><action name="Execute" command="wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"/></keybind>
        <keybind key="XF86_MonBrightnessUp"><action name="Execute" command="brightnessctl set 5%+"/></keybind>
        <keybind key="XF86_MonBrightnessDown"><action name="Execute" command="brightnessctl set 5%-"/></keybind>
      </keyboard>
    </labwc_config>
  '';
}
