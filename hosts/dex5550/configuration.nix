{
  pkgs,
  lib,
  username,
  ...
}: {
  imports = [
    ./nixos/hardware-configuration.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/i18n.nix
    ./themes/stylix.nix
    ./nixos/greetd.nix
    ./nixos/intel.nix
    ../../modules/default.nix
    ../../modules/development/default.nix
    ../../modules/system-tweaks/kernel-tweaks/32GB-SYSTEM/32GB-SYSTEM.nix
  ];

  # Set hostname
  networking.hostName = "dex5550";

  # Choose networking profile: "server", "desktop", or "minimal"
  networking.profile = "server";

  # Use the new features system instead of multiple lib.mkForce calls
  features = {
    development = {
      enable = true;
      ansible = false;
      cargo = true;
      github = true;
      go = true;
      java = false;
      lua = true;
      nix = true;
      shell = true;
      devshell = true;
      python = true;
      nodejs = true;
    };

    virtualization = {
      enable = true;
      docker = true;
      incus = false;
      podman = true;
      spice = true;
      libvirt = true;
      sunshine = true;
    };

    cloud = {
      enable = false;
      aws = false;
      azure = false;
      google = false;
      k8s = false;
      terraform = false;
    };

    security = {
      enable = true;
      onepassword = true;
      gnupg = true;
    };

    networking = {
      enable = true;
      tailscale = true;
    };

    ai = {
      enable = false;
      ollama = false;
    };

    programs = {
      lazygit = true;
      thunderbird = false;
      obsidian = false;
      office = false;
      webcam = true;
      print = false;
    };

    media = {
      droidcam = true;
    };
  };

  # Specific service configurations
  services.xserver = {
    enable = true;
    desktopManager.gnome.enable = true;
    displayManager.xserverArgs = [
      "-nolisten tcp"
      "-dpi 96"
    ];
  };

  # Network-specific overrides that go beyond the network profile
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;
  systemd.network.wait-online.timeout = 10;

  # Since we're using the "server" networking profile, we only need to override specific settings
  networking.nameservers = [
    "8.8.8.8"
    "8.8.4.4"
  ];
  # In case the networking profile doesn't apply all needed settings
  networking.useNetworkd = lib.mkForce true;
  networking.useHostResolvConf = false;

  # Wayland configuration
  programs.sway = {
    enable = true;
    xwayland.enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      swaylock
      swayidle
      swaycons
      wl-clipboard
      wf-recorder
      wlr-which-key
      wlr-randr
      grim
      slurp
      dmenu
      foot
    ];
    extraSessionCommands = ''
      export SDL_VIDEODRIVER=wayland
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
      export _JAVA_AWT_WM_NONREPARENTING=1
      export MOZ_ENABLE_WAYLAND=1
    '';
  };

  # Hardware-specific configurations
  security.wrappers.sunshine = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_admin+p";
    source = "${pkgs.sunshine}/bin/sunshine";
  };

  # Bridge network configuration
  systemd.network = {
    netdevs."br0" = {
      netdevConfig = {
        Name = "br0";
        Kind = "bridge";
      };
    };
    networks = {
      "enp1s0" = {
        name = "enp1s0";
        DHCP = "ipv4";
        networkConfig = {
          MulticastDNS = true;
        };
      };
      "wlp2s0" = {
        name = "wlp2s0";
        DHCP = "ipv4";
        networkConfig = {
          MulticastDNS = true;
        };
      };
      "10-lan" = {
        matchConfig.Name = ["enp1s0" "vm-*"];
        networkConfig = {
          Bridge = "br0";
        };
      };
      "10-lan-bridge" = {
        matchConfig.Name = "br0";
        networkConfig = {
          Address = ["192.168.1.222/24"];
          Gateway = "192.168.1.254";
          DNS = ["8.8.8.8" "8.8.4.4"];
          IPv6AcceptRA = false;
        };
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };

  # User-specific configuration
  users.users.${username} = {
    isNormalUser = true;
    description = "Olaf K-Freund";
    extraGroups = ["openrazer" "wheel" "docker" "podman" "video" "scanner" "lp" "lxd" "incus-admin"];
    shell = pkgs.zsh;
    packages = with pkgs; [
      vim
      wally-cli
    ];
  };

  # Other hardware/service configurations
  hardware.keyboard.zsa.enable = true;
  services.ollama.acceleration = "cpu";
  hardware.nvidia-container-toolkit.enable = false;

  system.stateVersion = "24.11";
}
