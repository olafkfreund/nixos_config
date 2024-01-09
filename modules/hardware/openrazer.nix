{ pkgs, lib, config, ... }: {

  hardware.openrazer.enable =true;
  hardware.openrazer.users = [ "olafkfreund" ];

  environment.systemPackages = with pkgs; [
    razergenie
    polychromatic
  ];
}


