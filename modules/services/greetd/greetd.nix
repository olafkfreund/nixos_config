{ pkgs
, lib
, ...
}: {
  # greetd display manager
  services.greetd =
    let
      session_gnome = {
        command = lib.mkDefault "${pkgs.gnome-session}/bin/gnome-session";
        user = "olafkfreund";
      };
    in
    {
      enable = lib.mkDefault false;
      settings = {
        terminal.vt = 1;
        default_session = session_gnome;
        initial_session = session_gnome;
      };
    };

  # unlock GPG keyring on login
  security.pam.services.greetd.enableGnomeKeyring = true;
}
