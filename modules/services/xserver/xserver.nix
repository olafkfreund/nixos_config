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
<<<<<<< HEAD
=======
services = {
  displayManager.sddm.enable = false;
  displayManager.sddm.wayland.enable = true;
  displayManager.sddm.theme = "astronaut";
  displayManager.sddm.enableHidpi = true;
};
>>>>>>> 6f826e2188d86f7d0c76929d56e6cedb6863fd9d

##Cosmic
#services.displayManager.cosmic-greeter.enable = true;
#services.desktopManager.cosmic.enable = true;
<<<<<<< HEAD
=======

environment.systemPackages = let themes = pkgs.callPackage ./sddm-themes.nix {}; in [ 
  pkgs.sddm-kcm
  #pkgs.kdePackages.sddm-kcm
  themes.sddm-astronaut
];

>>>>>>> 6f826e2188d86f7d0c76929d56e6cedb6863fd9d
}
