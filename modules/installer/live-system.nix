# Live USB System Configuration for NixOS Installation
{ lib
, pkgs
, host ? null
, ...
}:
with lib; {
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
    ./installer-tools.nix
  ];

  # Basic system configuration
  time.timeZone = mkDefault "Europe/Oslo";
  i18n.defaultLocale = mkDefault "en_GB.UTF-8";

  # Network configuration
  networking = {
    hostName = mkDefault "nixos-installer";
    networkmanager.enable = true;
    wireless.enable = false;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  # SSH configuration for remote installation
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
    };
  };

  # Set root password for SSH access (change after installation)
  users.users.root = {
    password = lib.mkForce "nixos";
    initialHashedPassword = lib.mkForce null;
    hashedPassword = lib.mkForce null;
    hashedPasswordFile = lib.mkForce null;
    initialPassword = lib.mkForce null;
  };

  # Environment configuration
  environment = {
    # Include git and networking tools
    systemPackages = with pkgs; [
      git
      curl
      wget
      rsync
      tailscale

      # Add host-specific flake configuration
      (writeScriptBin "install-${
          if host != null
          then host
          else "host"
        }" ''
        #!/bin/bash
        exec /etc/nixos-config/scripts/install-helpers/install-wizard.sh "${
          if host != null
          then host
          else ""
        }" "$@"
      '')
    ];

    # Configuration files
    etc = {
      "nixos-config" = {
        source = ../../.;
        target = "nixos-config";
      };

      # Welcome message
      "issue".text = ''

        Welcome to NixOS Live Installer${optionalString (host != null) " for ${host}"}

        To install NixOS${optionalString (host != null) " on ${host}"}:
        ${optionalString (host != null) "  sudo install-${host}"}
        ${optionalString (host == null) "  sudo /etc/nixos-config/scripts/install-helpers/install-wizard.sh <hostname>"}

        For SSH access:
          - Username: root
          - Password: nixos (CHANGE AFTER INSTALLATION!)
          - IP: $(ip route get 1.1.1.1 | head -1 | awk '{print $7}')

        Configuration available at: /etc/nixos-config

      '';
    };
  };

  # ISO configuration
  isoImage = {
    isoName = mkDefault "nixos-${
      if host != null
      then host
      else "installer"
    }-live.iso";
    volumeID = mkDefault "NIXOS_${lib.toUpper (
      if host != null
      then host
      else "INSTALLER"
    )}";

    # 4GB image size
    # isoBaseName has been moved to image.baseName
    makeEfiBootable = true;
    makeUsbBootable = true;

    # Include extra space for tools and configs
    # Note: squashfsCompression option removed in recent NixOS versions
  };

  # Boot configuration
  boot = {
    supportedFilesystems = [ "ext4" "vfat" "ntfs" "exfat" ];
    kernelParams = [ "boot.shell_on_fail" ];

    # Include common drivers
    initrd.availableKernelModules = [
      "xhci_pci"
      "ehci_pci"
      "ahci"
      "usb_storage"
      "sd_mod"
      "nvme"
      "sdhci_pci"
      "rtsx_pci_sdmmc"
    ];
  };

  # System configuration
  nixpkgs.config = {
    allowUnfree = true;
    allowInsecure = true;
  };

  # Enable flakes in live environment
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };

  # Console configuration
  console = {
    keyMap = mkDefault "us";
    font = "Lat2-Terminus16";
    useXkbConfig = false;
  };

  # No GUI services
  services.xserver.enable = false;

  # Set MOTD
  users.motd = builtins.readFile /etc/issue;
}
