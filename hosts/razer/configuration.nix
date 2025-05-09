{
  pkgs,
  pkgs-unstable,
  lib,
  inputs,
  username,
  ...
}: {
  imports = [
    ./nixos/hardware-configuration.nix
    ./nixos/screens.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/nvidia.nix
    ./nixos/i18n.nix
    ./nixos/hosts.nix
    ./nixos/envvar.nix
    ./nixos/greetd.nix
    ./themes/stylix.nix
    ../../modules/default.nix
    ../../modules/laptops.nix
    ../../modules/development/default.nix
    # ../../modules/system-tweaks/kernel-tweaks/64GB-SYSTEM/64gb-system.nix
    # ../../modules/system-tweaks/storage-tweaks/SSD/SSD-tweak.nix
  ];

  # Enable secure DNS with DNS over TLS
  services.secure-dns = {
    enable = true;
    dnssec = "true";
    fallbackProviders = [
      "1.1.1.1#cloudflare-dns.com" # Cloudflare DNS
      "8.8.8.8#dns.google" # Google DNS
    ];
  };

  aws.packages.enable = lib.mkForce true;
  azure.packages.enable = lib.mkForce true;
  cloud-tools.packages.enable = lib.mkForce true;
  steampipe.packages.enable = lib.mkForce true;
  google.packages.enable = lib.mkForce true;
  k8s.packages.enable = lib.mkForce true;
  # openshift.packages.enable = true;
  terraform.packages.enable = lib.mkForce true;

  # Development tools
  ansible.development.enable = lib.mkForce true;
  cargo.development.enable = lib.mkForce true;
  github.development.enable = lib.mkForce true;
  go.development.enable = lib.mkForce true;
  java.development.enable = lib.mkForce true;
  lua.development.enable = lib.mkForce true;
  nix.development.enable = lib.mkForce true;
  shell.development.enable = lib.mkForce true;
  devshell.development.enable = lib.mkForce true;
  python.development.enable = lib.mkForce true;
  nodejs.development.enable = lib.mkForce true;

  # Git tools
  programs.lazygit.enable = lib.mkForce true;
  programs.thunderbird.enable = lib.mkForce true;
  programs.obsidian.enable = lib.mkForce true;
  programs.office.enable = lib.mkForce true;
  programs.webcam.enable = lib.mkForce true;

  # Virtualization tools
  services.docker.enable = lib.mkForce true;
  services.incus.enable = lib.mkForce false;
  services.podman.enable = lib.mkForce true;
  services.spice.enable = lib.mkForce true;
  services.libvirt.enable = lib.mkForce true;
  services.sunshine.enable = lib.mkForce true;

  # Password management
  security.onepassword.enable = lib.mkForce true;
  security.gnupg.enable = lib.mkForce true;

  # VPN
  vpn.tailscale.enable = lib.mkForce true;

  # AI
  ai.ollama.enable = lib.mkForce true;

  # Printing
  services.print.enable = lib.mkForce true;

  # # security
  # security.intune-portal.enable = lib.mkForce false;

  services = {
    xserver = {
      enable = true;
      desktopManager.gnome.enable = true;
      displayManager.xserverArgs = [
        "-nolisten tcp"
        "-dpi 96"
      ];
      videoDrivers = ["nvidia"];
    };
  };
  environment.systemPackages = [
    inputs.zen-browser.packages."${pkgs.system}".default
  ];

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

  # Network configuration - using systemd-networkd instead of NetworkManager
  networking = {
    networkmanager.enable = false;
    hostName = "razer";
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];
    useDHCP = false;
    useNetworkd = true;
    # Enable resolved for DNS resolution
    useHostResolvConf = false;
  };

  # Enable systemd-resolved for DNS resolution with systemd-networkd
  services.resolved = {
    enable = true;
    dnssec = "true";
    fallbackDns = [
      "1.1.1.1"
      "8.8.8.8"
    ];
  };

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
  # programs.sway = {
  #   extraSessionCommands = ''
  #     export WLR_RENDERER=vulkan
  #     export WLR_DRM_DEVICES=/dev/dri/card2
  #   '';
  # };

  users.defaultUserShell = pkgs.zsh;

  environment.shells = with pkgs; [zsh];

  programs.zsh.enable = true;

  environment.sessionVariables = {
    NH_FLAKE = "/home/olafkfreund/.config/nixos";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };

  users.users.${username} = {
    isNormalUser = true;
    description = "Olaf K-Freund";
    extraGroups = ["networkmanager" "openrazer" "libvirtd" "wheel" "docker" "podman" "video" "scanner" "lp" "lxd" "incus-admin"];
    shell = pkgs.zsh;
    packages = with pkgs; [
      vim
      wally-cli
    ];
  };

  services.playerctld.enable = true;
  services.fwupd.enable = true;
  # Use either CUDA or ROCm, but not a mix of both
  services.ollama.acceleration = "cuda";
  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /extdisk         192.168.1.*(rw,fsid=0,no_subtree_check)
  '';
  hardware.nvidia-container-toolkit.enable = true;

  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.timeServers = ["pool.ntp.org"];

  nixpkgs.config.permittedInsecurePackages = ["olm-3.2.16"];

  system.stateVersion = "24.11";
}
