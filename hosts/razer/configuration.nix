{ self, config, pkgs, ... }:

{
  imports =
    [ 
      ./hardware-configuration.nix
      ./boot.nix
      ../../modules/system-tweaks/storage-tweaks/SSD/SSD-tweak.nix
      ../../modules/system-tweaks/kernel-tweaks/32GB-SYSTEM/32GB-SYSTEM.nix
      ../../modules/laptop-related/autorandr.nix
      ../../modules/laptop-related/earlyoom.nix
      ../../modules/laptop-related/zram.nix
      ../../modules/hardware/openrazer.nix
      ../../modules/default.nix
      ../../home/containers/default.nix
      ./nvidia.nix
      ./i18n.nix
      ./hosts.nix
      ./envvar.nix
    ];
  networking.networkmanager.enable = true;
  networking.hostName = "razer"; # Define your hostname.
  # Define a user account. Don't forget to set a password with ‘passwd’.
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
  programs.git = {
  enable = true;
  userName = "Olaf K-Freund";
  userEmail = "olaf.freund@r3.com";
  };
  security.sudo.wheelNeedsPassword = false;
  networking.firewall.enable = false;
  system.stateVersion = "23.11"; # Did you read the comment?
}
