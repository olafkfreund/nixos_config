{ pkgs, lib, config, ... }: {

  hardware.openrazer.enable = true;
  hardware.openrazer.users = [ "olafkfreund" ];
  hardware.openrazer.batteryNotifier.enable = false;

  environment.systemPackages = with pkgs; [
    razergenie
    gobject-introspection
    wrapGAppsHook3 
    python312Packages.wrapPython
    python312Packages.openrazer-daemon
  ];
  
}


