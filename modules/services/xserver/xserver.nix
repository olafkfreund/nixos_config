{ config, pkgs, nixpkgs, ...}: {
  

#services.xrdp.enable = true;
#services.xrdp.defaultWindowManager = "plasmawayland";
#services.xrdp.openFirewall = true;

services.xserver = {
  enable = true;
  #displayManager.defaultSession = "plasmawayland";
  #displayManager.defaultSession = "plasma";
  desktopManager.gnome.enable = false;
  displayManager.xserverArgs = [
    "-nolisten tcp" 
    "-dpi 96"
  ];
  videoDrivers = [ "nvidia" ]; 
};  

##Cosmic
#services.displayManager.cosmic-greeter.enable = true;
#services.desktopManager.cosmic.enable = true;
}
