{
  config,
  lib,
  username,
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

  in {
    enable = true;
    settings = {
      terminal.vt = 1;
      default_session = session_sway;
      initial_session = session_sway;
    };
  };

  # unlock GPG keyring on login
  security.pam.services.greetd.enableGnomeKeyring = true;
}
