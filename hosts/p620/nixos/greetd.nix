{
  config,
  lib,
  username,
  pkgs,
  ...
}: {
  # greetd display manager
  services.greetd = let
    hyprland_wrapper = pkgs.writeShellScript "hyprland-wrapper" ''
      export LIBVA_DRIVER_NAME=radeonsi
      export VDPAU_DRIVER=radeonsi
      export DRI_PRIME=1
      export LIBGL_DRIVERS_PATH=${pkgs.mesa}/lib/dri
      export __GL_SHADER_DISK_CACHE_PATH=/tmp
      exec ${lib.getExe config.programs.hyprland.package}
    '';
    session_hypr = {
      command = "${hyprland_wrapper}";
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
      default_session = session_hypr;
      initial_session = session_hypr;
    };
  };

  # unlock GPG keyring on login
  security.pam.services.greetd.enableGnomeKeyring = true;
}
