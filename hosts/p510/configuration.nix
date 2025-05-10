{
  pkgs,
  inputs,
  lib,
  ...
}: {
  imports = [
    # inputs.microvm.nixosModules.host

    ./nixos/hardware-configuration.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/nvidia.nix
    ./nixos/i18n.nix
    ./nixos/envvar.nix
    ./nixos/greetd.nix
    ./nixos/hosts.nix
    ./nixos/mpd.nix
    ./themes/stylix.nix
    ./nixos/plex.nix
    ../../modules/server.nix
    ../../modules/default.nix
    ../../modules/development/default.nix
  ];

  # Set hostname
  networking.hostName = "p510";

  # Choose networking profile: "desktop", "server", or "minimal"
  networking.profile = "server";

  # Use the new features system instead of multiple lib.mkForce calls
  features = {
    development = {
      enable = true;
      ansible = false;
      cargo = true;
      github = true;
      go = true;
      java = true;
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
      enable = true;
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
      enable = true;
      ollama = true;
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

  # Enable secure DNS with DNS over TLS
  services.secure-dns = {
    enable = true;
    dnssec = "true";
    fallbackProviders = [
      "1.1.1.1#cloudflare-dns.com" # Cloudflare DNS
      "8.8.8.8#dns.google" # Google DNS
    ];
  };

  # Specific service configurations
  programs.streamdeck-ui = {
    enable = true;
    autoStart = true;
  };

  services.xserver = {
    enable = true;
    displayManager.xserverArgs = [
      "-nolisten tcp"
      "-dpi 96"
    ];
    videoDrivers = ["nvidia"];
  };

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      swaylock
      swayidle
      swaycons
      wl-clipboard
      wlr-which-key
      wlr-randr
      grim
      slurp
      foot
      dmenu
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

  # Network-specific overrides that go beyond the network profile
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

  # Since we're using the "server" networking profile, we only need to override specific settings
  networking.nameservers = [
    "8.8.8.8"
    "8.8.4.4"
  ];
  # In case the networking profile doesn't apply all needed settings
  networking.useNetworkd = lib.mkForce true;
  networking.useHostResolvConf = false;

  # Configure systemd-networkd for your network interfaces
  systemd.network = {
    enable = true;
    networks = {
      "eno1" = {
        name = "eno1";
        DHCP = "ipv4";
        networkConfig = {
          MulticastDNS = true;
          DHCP = "ipv4";
          IPv6AcceptRA = true;
        };
        dhcpV4Config = {
          RouteMetric = 10;
        };
      };
      "wlp8s" = {
        name = "wlp8s*";
        DHCP = "ipv4";
        networkConfig = {
          MulticastDNS = true;
          IPv6AcceptRA = true;
        };
        dhcpV4Config = {
          RouteMetric = 20;
        };
      };
    };
  };

  # User-specific configuration
  users.users.olafkfreund = {
    isNormalUser = true;
    description = "Olaf K-Freund";
    extraGroups = ["openrazer" "wheel" "docker" "video" "scanner" "lp" "lxd" "incus-admin"];
    shell = pkgs.zsh;
    packages = with pkgs; [
      vim
      wally-cli
    ];
  };

  # NVIDIA specific configurations
  hardware.keyboard.zsa.enable = true;
  services.ollama.acceleration = "cuda";
  hardware.nvidia-container-toolkit.enable = true;

  nixpkgs.config.permittedInsecurePackages = ["olm-3.2.16" "dotnet-sdk-6.0.428"];
  system.stateVersion = "24.11";
}
