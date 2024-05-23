{ self, lib, config, pkgs, ... }:

{
  imports =
    [ 
      ./hardware-configuration.nix
      ./screens.nix
      ./power.nix
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

  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
  
  stylix.image = ./gruvbox-rainbow-nix.png;
  
  stylix.fonts = {
    monospace = {
      package = pkgs.nerdfonts.override {fonts = ["JetBrainsMono"];};
      name = "JetBrainsMono Nerd Font Mono";
    };
     sansSerif = {
       package = pkgs.dejavu_fonts;
       name = "DejaVu Sans";
     };
     serif = {
       package = pkgs.dejavu_fonts;
       name = "DejaVu Serif";
     };
  };
  stylix.fonts.sizes = {
    applications = 12;
    terminal = 16;
    desktop = 12;
    popups = 12;
  };

  stylix.opacity = {
    applications = 0.8;
    terminal = 0.7;
    desktop = 1.0;
    popups = 1.0;
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
  
  users.defaultUserShell = pkgs.zsh;
  environment.shells = with pkgs; [ zsh ];
  programs.zsh.enable = true;
  
  users.users.olafkfreund = {
    isNormalUser = true;
    description = "Olaf K-Freund";
    extraGroups = [ "networkmanager" "openrazer" "wheel" "docker" "video" "scanner" "lp"];
    shell = pkgs.zsh;
    packages = with pkgs; [
      kitty
      vim
      ];
    };
  networking.firewall.enable = false;
  system.stateVersion = "24.05"; # Did you read the comment?
}
