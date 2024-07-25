{gpu, ...}: let
  inherit (import ../../../hosts/${host}/variables.nix) gpu;
in {
  services.xserver = {
    enable = true;
    desktopManager.gnome.enable = true;
    displayManager.xserverArgs = [
      "-nolisten tcp"
      "-dpi 96"
    ];
    videoDrivers = ["${gpu}"];
    updateDbusEnvironment = true;
  };
}
