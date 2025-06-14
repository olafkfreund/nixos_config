{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  # Boot configuration
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    # Clean /tmp on boot
    tmp.cleanOnBoot = true;
  };

  # Network configuration
  networking = {
    hostName = "minimal-host"; # Change this
    networkmanager.enable = true;

    # Basic firewall
    firewall = {
      enable = true;
      allowPing = true;
    };
  };

  # Internationalization
  time.timeZone = "Europe/London"; # Change as needed
  i18n.defaultLocale = "en_GB.UTF-8";

  # User configuration
  users.users.username = {
    # Change 'username'
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"];
    shell = pkgs.zsh;
    # openssh.authorizedKeys.keys = [ "your-ssh-key" ];
  };

  # Enable sudo without password for wheel group
  security.sudo.wheelNeedsPassword = false;

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Essential packages
  environment.systemPackages = with pkgs; [
    # System utilities
    wget
    curl
    git
    vim
    htop
    tree
    file
    which
    unzip
    zip
    tar
    gzip

    # Network tools
    dig
    nmap

    # System monitoring
    lsof
    pciutils
    usbutils
  ];

  # Enable Nix flakes
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    auto-optimise-store = true;
  };

  # Enable zsh
  programs.zsh.enable = true;

  # System state version
  system.stateVersion = "24.11";
}
