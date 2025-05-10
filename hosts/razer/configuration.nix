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

  # Set hostname
  networking.hostName = "razer";

  # Choose networking profile: "desktop", "server", or "minimal"
  networking.profile = "desktop";

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
    enable = true;
    dnssec = "true";
    fallbackProviders = [
      "1.1.1.1#cloudflare-dns.com" # Cloudflare DNS
      "8.8.8.8#dns.google" # Google DNS
    ];
  };

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

  # Use NetworkManager for this laptop (desktop profile uses NetworkManager by default)
  # So we don't need to override anything here, just add specific configs if needed
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  # Disable network wait services to improve boot time regardless of network manager
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;

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

  # Hardware and service specific configurations
  services.playerctld.enable = true;
  services.fwupd.enable = true;
  services.ollama.acceleration = "cuda";
  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /extdisk         192.168.1.*(rw,fsid=0,no_subtree_check)
  '';
  hardware.nvidia-container-toolkit.enable = true;

  nixpkgs.config.permittedInsecurePackages = ["olm-3.2.16"];
  system.stateVersion = "24.11";
}
