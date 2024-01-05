{ config, lib, pkgs, ... }: {

virtualisation = {
  podman = {
    enable = true;
    #dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };
};
virtualisation.docker.enable = true;
virtualisation.docker.rootless = {
  enable = true;
  setSocketVariable = true;
};
virtualisation.libvirtd.enable =true;
virtualisation.lxd.enable = true; 
users.extraGroups.docker.members = [ "olafkfreund" ];

environment.systemPackages = with pkgs; [
  podman-compose
  podman-tui
  podman
  pods
  quickemu
  ];

}
