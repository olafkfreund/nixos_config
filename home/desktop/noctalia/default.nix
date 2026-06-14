{ lib, ... }:
# Noctalia desktop shell (bar, launcher, notifications, lock) for the niri and
# labwc sessions. Deliberately NOT using programs.noctalia.systemd.enable: that
# service binds to the graphical-session target, which GNOME also reaches, so it
# would spawn a second shell on top of gnome-shell. Instead we launch noctalia
# only from the niri/labwc startup hooks, so it runs solely under those sessions.
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

  # niri: launch the shell at session start (inherits the niri session env).
  programs.niri.settings.spawn-at-startup = lib.mkAfter [
    { command = [ "noctalia" ]; }
  ];

  # labwc: launch the shell from its autostart hook.
  xdg.configFile."labwc/autostart".text = ''
    noctalia &
  '';

  # labwc keyboard layout. wlroots compositors don't inherit the system
  # xkb.layout (gb, set in hosts/common/nixos/i18n.nix); labwc reads XKB_*
  # from ~/.config/labwc/environment at startup, before keyboard init.
  xdg.configFile."labwc/environment".text = ''
    XKB_DEFAULT_LAYOUT=gb
  '';
}
