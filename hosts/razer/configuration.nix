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
    # ./razer-laptop.nix
    ./greetd.nix
    ../../modules/default.nix
    ../../modules/laptops.nix
  ];
  
  services = {
    xserver = {
      enable = true;
      desktopManager.gnome.enable = true;
      displayManager.xserverArgs = [
        "-nolisten tcp"
        "-dpi 96"
      ];
      videoDrivers = [ "nvidia" ];
    };
    # desktopManager = {
    #   cosmic = {
    #     enable = false;
    #   };
    # };
    # displayManager = {
    #   cosmic-greeter = {
    #     enable = false;
    #   };
    # };
  };
  # services.desktopManager.cosmic.enable = true;
  # services.displayManager.cosmic-greeter.enable = true;


  # Disable network wait services to improve boot time
  systemd.services = {
    NetworkManager-wait-online = {
      enable = lib.mkForce false;
      wantedBy = lib.mkForce [];
    };
    systemd-networkd-wait-online = {
      enable = lib.mkForce false;
      wantedBy = lib.mkForce [];
    };
  };

  # Set a timeout for network-online.target to prevent long delays
  systemd.network.wait-online.timeout = 10;
  
  networking.networkmanager.enable = true;
  networking.hostName = "razer";
  networking = {
    useDHCP = false;
    useNetworkd = true;
  };

  # Stylix theming
  stylix = {
    enable = true;
    polarity = "dark";
    autoEnable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
    image = ./gruv-abstract-maze.png;

    # Font configuration
    fonts = {
      monospace = {
        package = pkgs.nerdfonts.override { fonts = ["JetBrainsMono"]; };
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

    # Font sizes (adjust as needed)
    fonts.sizes = {
      applications = 12;
      terminal = 13;  # Slightly larger for better readability in terminal
      desktop = 12;
      popups = 11;    # Slightly smaller for popups
    };

    # Opacity settings
    opacity = {
      applications = 1.0;
      terminal = 0.95;  # Slight transparency for terminal
      desktop = 1.0;
      popups = 0.98;    # Slight transparency for popups
    };

    # Cursor settings
    cursor = {
      name = "Bibata-Modern-Ice";
      size = 26;
    };

    # Exclude specific targets
    targets.chromium.enable = false;  # Exclude browser theming
  };

  # Network configuration
  systemd.network = {
    networks = {
      "20-wired" = {
        matchConfig.Name = "en*";
        networkConfig = {
          DHCP = "yes";
          MulticastDNS = true;
        };
      };
      "25-wireless" = {
        matchConfig.Name = "wl*";
        networkConfig = {
          DHCP = "yes";
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
    extraGroups = ["networkmanager" "openrazer" "wheel" "docker" "podman" "video" "scanner" "lp" "lxd" "incus-admin"];
    shell = pkgs.zsh;
    packages = with pkgs; [
      vim
      wally-cli
    ];
  };

  services.playerctld.enable = true;

  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.timeServers = ["pool.ntp.org"];

  system.stateVersion = "24.11";
}