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
  networking = {
    useDHCP = false;
    useNetworkd = true;
  };

  systemd.network = {
    networks = {
      "wlp3s0" = {
        name = "wlp3s0";
        DHCP = "ipv4";
        networkConfig = {
          MulticastDNS = true;
        };
      };
    };
  };
  users.users.olafkfreund = {
    isNormalUser = true;
    description = "Olaf K-Freund";
    extraGroups = [ "networkmanager" "openrazer" "wheel" "docker" "video" "scanner" "lp"];
    packages = with pkgs; [
      kate
      kitty
      neovim
      vim
      polychromatic
      ];
    };
  networking.firewall.enable = false;
  system.stateVersion = "23.11"; # Did you read the comment?
}
