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
services = {
  displayManager.sddm.enable = true;
  displayManager.sddm.wayland.enable = true;
  displayManager.sddm.theme = "astronaut";
  displayManager.sddm.enableHidpi = true;
};

##Cosmic
#services.displayManager.cosmic-greeter.enable = true;
services.desktopManager.cosmic.enable = true;

environment.systemPackages = let themes = pkgs.callPackage ./sddm-themes.nix {}; in [ 
  pkgs.sddm-kcm
  #pkgs.kdePackages.sddm-kcm
  themes.sddm-astronaut
];

}
