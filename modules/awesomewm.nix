{ pkgs, config, lib, self, ... }:{

environment.systemPackages = with pkgs; [
    luajit
    lua54Packages.fennel
    awesome
  ];


 services = {
    picom.enable = true;
    redshift.enable = true;
     windowManager.awesome.enable = true;
  };

}
