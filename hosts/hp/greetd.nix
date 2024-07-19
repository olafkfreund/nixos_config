{
  config,
  lib,
  ...
}: {
  # greetd display manager
  services.greetd = let
    session_hypr = {
      command = "${lib.getExe config.programs.hyprland.package}";
      user = "olafkfreund";
    };
    session_sway = {
      command = "${lib.getExe config.programs.sway.package}";
      user = "olafkfreund";
    };
    session_dwm = {
      command = "startx $HOME/.config/chadwm/scripts/run.sh";
      user = "olafkfreund";
    };
  in {
    enable = true;
    settings = {
      terminal.vt = 1;
      default_session = session_dwm;
      initial_session = session_dwm;
    };
  };

  # unlock GPG keyring on login
  security.pam.services.greetd.enableGnomeKeyring = true;
}
