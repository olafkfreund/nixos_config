{ config
, lib
, ...
}:
# let
#   tuigreet = "${pkgs.greetd.tuigreet}/bin/tuigreet";
#   hyprland-session = "${inputs.hyprland.packages.${pkgs.system}.hyprland}/share/wayland-sessions";
# in {
#   services.greetd = {
#     enable = true;
#     settings = rec {
#       initial_session = {
#         command = "${tuigreet} --time --remember --remember-session --sessions ${hyprland-session}";
#         user = "olafkfreund";
#       };
#       default_session = initial_session;
#     };
#   };
#   security.pam.services.greetd.enableGnomeKeyring = true;
# }
{
  # greetd display manager
  services.greetd =
    let
      session = {
        command = "${lib.getExe config.programs.hyprland.package}";
        user = "olafkfreund";
      };
    in
    {
      enable = true;
      settings = {
        terminal.vt = 1;
        default_session = session;
        initial_session = session;
      };
    };

  # unlock GPG keyring on login
  security.pam.services.greetd.enableGnomeKeyring = true;
}
