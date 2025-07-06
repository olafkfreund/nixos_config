{
  pkgs,
  inputs,
  lib,
  hostUsers,
  ...
}: let
  vars = import ./variables.nix;
in {
  imports = [
    # inputs.microvm.nixosModules.host

    ./nixos/hardware-configuration.nix # Docker configuration
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/nvidia.nix
    ./nixos/i18n.nix
    ./nixos/envvar.nix
    ./nixos/cpu.nix
    ./nixos/memory.nix
    ./nixos/greetd.nix
    ./nixos/hosts.nix
    #./nixos/mpd.nix
    ./nixos/screens.nix
    ./nixos/plex.nix
    # ./nixos/monitoring.nix # Added monitoring configuration
    ./themes/stylix.nix
    ../../modules/server.nix
    ../../modules/default.nix
    ../../modules/development/default.nix
    ../common/hyprland.nix
  ];

  # Set hostname from variables
  networking.hostName = vars.hostName;

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
      devshell = false; # Temporarily disabled due to patch issue
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
      gemini-cli = true;
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

  # IDIOT-PROOF DNS CONFIGURATION: Prevent Tailscale from breaking DNS
  vpn.tailscale = {
    enable = true;
    acceptDns = lib.mkForce false; # NEVER let Tailscale touch DNS
    netfilterMode = "off"; # Safer default
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
    videoDrivers = ["${vars.gpu}"];
  };

  # programs.sway = {
  #   enable = true;
  #   wrapperFeatures.gtk = true;
  #   extraPackages = with pkgs; [
  #     swaylock
  #     swayidle
  #     swaycons
  #     wl-clipboard
  #     wlr-which-key
  #     wlr-randr
  #     grim
  #     slurp
  #     foot
  #     dmenu
  #   ];
  #   extraSessionCommands = ''
  #     export SDL_VIDEODRIVER=wayland
  #     export QT_QPA_PLATFORM=wayland
  #     export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
  #     export _JAVA_AWT_WM_NONREPARENTING=1
  #     export MOZ_ENABLE_WAYLAND=1
  #   '';
  # };

  # Hardware-specific configurations
  security.wrappers.sunshine = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_admin+p";
    source = "${pkgs.sunshine}/bin/sunshine";
  };

  # Docker configuration
  modules.containers.docker = {
    enable = true;
    users = hostUsers; # Use all users for this host
    rootless = false;
  };

  # Network-specific overrides that go beyond the network profile
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

  # Using nameservers from variables.nix
  networking.nameservers = vars.nameservers;

  # In case the networking profile doesn't apply all needed settings
  networking.useNetworkd = lib.mkForce true;
  networking.useHostResolvConf = false;

  # Configure systemd-networkd for your network interfaces
  # Ensure the interface name matches the output of `ip link` (e.g., eno1)
  systemd.network = {
    enable = true;
    networks = {
      eno1 = {
        name = "eno1";
        DHCP = "ipv4";
        networkConfig = {
          MulticastDNS = false;
          IPv6AcceptRA = true;
        };
        dhcpV4Config = {
          RouteMetric = 10;
        };
      };
    };
  };

  # User-specific configuration from variables
  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.fullName;
    extraGroups = vars.userGroups;
    shell = pkgs.zsh;
    packages = with pkgs; [
      vim
      wally-cli
    ];
  };

  # NVIDIA specific configurations
  hardware.keyboard.zsa.enable = true;
  services.ollama.acceleration = vars.acceleration;
  hardware.nvidia-container-toolkit.enable = true;

  nixpkgs.config.permittedInsecurePackages = ["olm-3.2.16" "dotnet-sdk-6.0.428" "python3.12-youtube-dl-2021.12.17"];
  system.stateVersion = "25.11";
}
