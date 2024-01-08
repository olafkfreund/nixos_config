{config, pkgs, nixpkgs, ...}: {
  
services.xserver.enable = true; 
services.xrdp.enable = true;
services.xrdp.defaultWindowManager = "startplasma-x11";
services.xrdp.openFirewall = true;
services.xserver.displayManager.defaultSession = "plasmawayland";
services.xserver.displayManager.sddm.enable = true;
services.xserver.displayManager.sddm.theme = "sugar-dark";
services.xserver.displayManager.xserverArgs = [
  "-nolisten tcp" 
  "-dpi 96"
];
services.xserver.displayManager.sddm.enableHidpi = true;
services.xserver.desktopManager.plasma5.enable = true;
services.xserver.desktopManager.plasma5.useQtScaling = true;
services.xserver.videoDrivers = [ "nvidia" ]; 

environment.systemPackages = let themes = pkgs.callPackage ./sddm-themes.nix {}; in [ 
    pkgs.sddm-kcm
    themes.sddm-sugar-dark 
  ];
}
