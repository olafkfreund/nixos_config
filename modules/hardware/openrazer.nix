{ pkgs, lib, config, ... }: {

  hardware.openrazer.enable = true;
  hardware.openrazer.users = [ "olafkfreund" ];

  environment.systemPackages = with pkgs; [
    razergenie
    polychromatic
    gobject-introspection
    wrapGAppsHook3 
    python311Packages.wrapPython
    python311Packages.openrazer-daemon
  ];
  
}


