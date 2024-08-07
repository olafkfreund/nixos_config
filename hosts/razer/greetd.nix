{
  config,
  lib,
  username,
  pkgs,
  ...
}: {
  # greetd display manager
  services.greetd = let
    session_hypr = {
      command = "${lib.getExe config.programs.hyprland.package}";
      user = "${username}";
    };
    session_sway = {
      command = "${lib.getExe config.programs.sway.package}";
      user = "${username}";
    };
    session_dwm = {
      command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd startx";
      user = "greeter";
    };

  in {
    enable = true;
    settings = {
      terminal.vt = 1;
      default_session = session_hypr;
      initial_session = session_hypr;
    };
  };

  # unlock GPG keyring on login
  security.pam.services.greetd.enableGnomeKeyring = true;
}
