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

  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
  
  stylix.image = ./gruvbox-rainbow-nix.png;
  #Exclude Browser.. just make more sence
  stylix.targets.chromium.enable = false;
  
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
    terminal = 14;
    desktop = 12;
    popups = 14;
  };

  stylix.opacity = {
    applications = 0.8;
    terminal = 1.0;
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

  environment.sessionVariables.NIXOS_OZONE_WL = "1"; 
  
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
  system.stateVersion = "24.11"; # Did you read the comment?
}
