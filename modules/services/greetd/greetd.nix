{ config
, lib
, pkgs
, ...
}: {
  # greetd display manager
  services.greetd =
    let
      session_gnome = {
        command = "${pkgs.gnome-session}/bin/gnome-session";
        user = "olafkfreund";
      };
    in
    {
      enable = true;
      settings = {
        terminal.vt = 1;
        default_session = session_gnome;
        initial_session = session_gnome;
      };
    };

  # unlock GPG keyring on login
  security.pam.services.greetd.enableGnomeKeyring = true;
}
