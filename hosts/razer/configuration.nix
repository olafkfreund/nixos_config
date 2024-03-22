{ self, config, pkgs, ... }:

{
  imports =
    [ 
      ./hardware-configuration.nix
      ./boot.nix
      ./nvidia.nix
      ./i18n.nix
      ./hosts.nix
      ./envvar.nix
      ../../modules/default.nix
    ];
  networking.networkmanager.enable = true;
  networking.hostName = "razer";
  users.users.olafkfreund = {
    isNormalUser = true;
    description = "Olaf K-Freund";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [
      kate
      kitty
      neovim
      vim
      ];
    };
  networking.firewall.enable = false;
  system.stateVersion = "23.11"; # Did you read the comment?
}
