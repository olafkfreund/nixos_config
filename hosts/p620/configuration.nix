{
  pkgs,
  lib,
  inputs,
  pkgs-unstable,
  ...
}: let
  vars = import ./variables.nix;
in {
  imports = [
    ./nixos/hardware-configuration.nix
    ./nixos/screens.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/amd.nix
    ./nixos/i18n.nix
    ./nixos/hosts.nix
    ./nixos/envvar.nix
    ./nixos/greetd.nix
    ./nixos/mpd.nix
    ./themes/stylix.nix
    ../../modules/default.nix
    ../../modules/development/default.nix
    # ../../modules/system-tweaks/kernel-tweaks/226GB-SYSTEM/226gb-system.nix
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
      ansible = true;
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
      aws = true;
      azure = true;
      google = true;
      k8s = true;
      terraform = true;
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
      thunderbird = true;
      obsidian = true;
      office = true;
      webcam = true;
      print = true;
    };

    media = {
      droidcam = true;
    };
  };

  # Enable secure DNS with DNS over TLS
  services.secure-dns = {
    enable = false;
    dnssec = "true";
    fallbackProviders = [
      "1.1.1.1#cloudflare-dns.com" # Cloudflare DNS
      "8.8.8.8#dns.google" # Google DNS
    ];
  };

  # AI Ollama-specific configuration that goes beyond simple enabling
  ai.ollama = {
    enableRag = true;
    ragDirectory = "/home/${vars.username}/documents/rag-files";
    allowBrokenPackages = false;
  };

  # Enable Hyprland system configuration
  modules.desktop.hyprland-uwsm.enable = true;

  # Productivity tools
  programs.streamcontroller.enable = lib.mkForce true;

  # Service-specific configurations
  services = {
    xserver = {
      enable = true;
      desktopManager.gnome.enable = true;
      displayManager.xserverArgs = [
        "-nolisten tcp"
        "-dpi 96"
      ];
      videoDrivers = ["${vars.gpu}gpu"]; # Correct way to set the video driver
    };
  };

  # System packages
  environment.systemPackages = [
    inputs.zen-browser.packages."${pkgs.system}".default
    pkgs-unstable.rocmPackages.llvm.libcxx
    pkgs-unstable.via
    pkgs-unstable.looking-glass-client
    pkgs-unstable.scream
  ];

  # Hardware-specific configurations
  services.udev.packages = [pkgs-unstable.via];
  services.udev.extraRules = builtins.concatStringsSep "\n" [
    ''ACTION=="add", SUBSYSTEM=="video4linux", DRIVERS=="uvcvideo", RUN+="${pkgs.v4l-utils}/bin/v4l2-ctl --set-ctrl=power_line_frequency=1"''
    ''KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", TAG+="uaccess"''
  ];
  hardware.keyboard.qmk.enable = true;

  # Network-specific overrides that go beyond the network profile
  systemd.network.wait-online.timeout = 10;
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

  # Using nameservers from variables.nix
  networking.nameservers = vars.nameservers;

  # In case the networking profile doesn't apply all needed settings
  networking.useNetworkd = lib.mkForce true;

  # Configure systemd-networkd for your network interfaces
  systemd.network = {
    enable = true;
    networks = {
      "20-wired" = {
        matchConfig.Name = "en*";
        networkConfig = {
          MulticastDNS = true;
          DHCP = "ipv4";
          IPv6AcceptRA = true;
        };
        # Higher priority for wired connection
        dhcpV4Config = {
          RouteMetric = 10;
        };
      };
      "25-wireless" = {
        matchConfig.Name = "wl*";
        networkConfig = {
          MulticastDNS = true;
          DHCP = "ipv4";
          IPv6AcceptRA = true;
        };
        # Lower priority for wireless
        dhcpV4Config = {
          RouteMetric = 20;
        };
      };
    };
  };

  systemd.user.services.scream-ivshmem = {
    enable = true;
    description = "Scream IVSHMEM";
    serviceConfig = {
      ExecStart = "${pkgs-unstable.scream}/bin/scream-ivshmem-pulse /dev/shm/scream";
      Restart = "always";
    };
    wantedBy = ["multi-user.target"];
    requires = ["pulseaudio.service"];
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

  # File systems and services
  services.nfs.server = lib.mkIf vars.services.nfs.enable {
    enable = true;
    exports = vars.services.nfs.exports;
  };
  fileSystems."/mnt/media" = {
    device = "192.168.1.127:/mnt/media";
    fsType = "nfs";
    options = ["x-systemd.automount" "noauto"];
  };

  # Other hardware configurations
  hardware.flipperzero.enable = true;
  services.playerctld.enable = true;
  services.fwupd.enable = true;
  systemd.services.fwupd.serviceConfig.LimitNOFILE = 524288;

  # Ollama specific configurations for AMD GPU
  services.ollama.acceleration = lib.mkForce vars.acceleration;
  services.ollama.rocmOverrideGfx = lib.mkForce "11.0.0";
  services.ollama.environmentVariables.HCC_AMDGPU_TARGET = lib.mkForce "gfx1100";
  services.ollama.environmentVariables.ROC_ENABLE_PRE_VEGA = lib.mkForce "1";
  services.ollama.environmentVariables.HSA_OVERRIDE_GFX_VERSION = lib.mkForce "11.0.0";

  # Add nix-serve configuration before the system.stateVersion line
  services.nix-serve = {
    enable = true;
    port = 5000; # Default port for nix-serve
    secretKeyFile = "/etc/nix/secret-key"; # Path to the secret key file
    openFirewall = true; # Automatically open the firewall port
  };

  # Ensure nix is configured to allow serving packages
  nix.settings.allowed-users = ["nix-serve"];

  nixpkgs.config.permittedInsecurePackages = ["olm-3.2.16"];
  system.stateVersion = "24.11";
}
