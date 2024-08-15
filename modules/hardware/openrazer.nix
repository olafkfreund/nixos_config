{ pkgs, lib, config, ... }: {

  hardware.openrazer.enable = true;
  hardware.openrazer.users = [ "olafkfreund" ];

  environment.systemPackages = with pkgs; [
    razergenie
    polychromatic
    gobject-introspection
    wrapGAppsHook3 
    python312Packages.wrapPython
    python312Packages.openrazer-daemon
  ];
  
}


