{config, pkgs, nixpkgs, cosmix, ...}: {
  

services.xrdp.enable = true;
services.xrdp.defaultWindowManager = "plasmawayland";
services.xrdp.openFirewall = true;

services.xserver = {
  enable = true;
  displayManager.defaultSession = "plasmawayland";
  displayManager.sddm.enable = true;
  #displayManager.sddm.settings.Wayland.SessionDir = "${pkgs.plasma5Packages.plasma-workspace}/share/wayland-sessions";
  displayManager.sddm.wayland.enable = true;
  displayManager.sddm.theme = "sugar-dark";
  displayManager.xserverArgs = [
    "-nolisten tcp" 
    "-dpi 96"
  ];
  displayManager.sddm.enableHidpi = true;
  desktopManager.plasma5.enable = true;
  desktopManager.plasma5.useQtScaling = true;
  # desktopManager.cosmic.enable = true;
  # desktopManager.plasma6.enable = true;
  
  videoDrivers = [ "nvidia" ]; 
};


environment.systemPackages = let themes = pkgs.callPackage ./sddm-themes.nix {}; in [ 
    pkgs.sddm-kcm
    themes.sddm-sugar-dark 
  ];
}
