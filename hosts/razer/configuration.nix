{ self, config, pkgs, ... }:

{
  imports =
    [ 
      ./hardware-configuration.nix
      ../../modules/default.nix
      ../../home/containers/default.nix
    ];
networking.networkmanager.enable = true;
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
security.sudo.wheelNeedsPassword = false;
networking.firewall.enable = false;
system.stateVersion = "23.11"; # Did you read the comment?
}
