{pkgs, lib, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./screens.nix
    ./power.nix
    ./boot.nix
    ./nvidia.nix
    ./i18n.nix
    ./hosts.nix
    ./envvar.nix
    ./razer-laptop.nix
    ./greetd.nix
    ../../modules/default.nix
    ../../modules/laptops.nix
  ];
  
  services.xserver = {
    enable = true;
    desktopManager.gnome.enable = true;
    displayManager.xserverArgs = [
      "-nolisten tcp"
      "-dpi 96"
    ];
    videoDrivers = [ "nvidia" ];
  };

  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;
  
  networking.networkmanager.enable = true;
  networking.hostName = "razer";
  networking = {
    useDHCP = false;
    useNetworkd = true;
  };

  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";

  stylix.image = ./003.png;
  stylix.enable = true;
  stylix.polarity = "dark";
  stylix.autoEnable = true;

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
    terminal = 12;
    desktop = 12;
    popups = 12;
  };

  stylix.opacity = {
    applications = 1.0;
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

  environment.shells = with pkgs; [zsh];

  programs.zsh.enable = true;

  environment.sessionVariables = {
    FLAKE = "/home/olafkfreund/.config/nixos";
      GBM_BACKEND = "nvidia-drm";
       __GLX_VENDOR_LIBRARY_NAME = "nvidia";
       NVD_BACKEND = "direct";

  };

  users.users.olafkfreund = {
    isNormalUser = true;
    description = "Olaf K-Freund";
    extraGroups = ["networkmanager" "openrazer" "wheel" "docker" "video" "scanner" "lp" "lxd" "incus-admin"];
    shell = pkgs.zsh;
    packages = with pkgs; [
      vim
      wally-cli
    ];
  };
  hardware.keyboard.zsa.enable = true;
  services.playerctld.enable = true;
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.timeServers = ["pool.ntp.org"];
  system.stateVersion = "24.11";
}
