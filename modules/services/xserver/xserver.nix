{ config, pkgs, nixpkgs, ...}: {
  

#services.xrdp.enable = true;
#services.xrdp.defaultWindowManager = "plasmawayland";
#services.xrdp.openFirewall = true;

services.xserver = {
  enable = true;
  #displayManager.defaultSession = "plasmawayland";
  #displayManager.defaultSession = "plasma";
  displayManager.sddm.enable = true;
  #displayManager.sddm.settings.Wayland.SessionDir = "${pkgs.plasma5Packages.plasma-workspace}/share/wayland-sessions";
  displayManager.sddm.wayland.enable = true;
  displayManager.sddm.theme = "astronaut";
  displayManager.xserverArgs = [
     "-nolisten tcp" 
     "-dpi 96"
   ];
  displayManager.sddm.enableHidpi = true;
  desktopManager.gnome.enable = false;
  #desktopManager.plasma5.enable = true;
  videoDrivers = [ "nvidia" ]; 
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
