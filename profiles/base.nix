{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.base;
in {
  options.custom.base = {
    enable = lib.mkEnableOption "base system configuration";

    locale = lib.mkOption {
      type = lib.types.str;
      default = "en_GB.UTF-8";
      description = "System locale";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "Europe/London";
      description = "System timezone";
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["olafkfreund"];
      description = "List of users to create";
    };
  };

  config = lib.mkIf cfg.enable {
    # Core system configuration
    time.timeZone = cfg.timezone;
    i18n.defaultLocale = cfg.locale;

    # Enable flakes and new nix command
    nix.settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
    };

    # Basic system packages
    environment.systemPackages = with pkgs; [
      # Essential utilities
      wget
      curl
      git
      vim
      nano
      htop
      btop
      tree
      file
      which
      unzip
      zip
      gzip
      tar

      # Network tools
      dig
      nmap
      nettools

      # System monitoring
      lsof
      pciutils
      usbutils
    ];

    # Enable NetworkManager
    networking.networkmanager.enable = true;

    # Basic firewall
    networking.firewall = {
      enable = true;
      allowPing = true;
    };

    # Enable SSH with key-only authentication
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    # Create users
    users.users = builtins.listToAttrs (map (username: {
        name = username;
        value = {
          isNormalUser = true;
          group = username;
          extraGroups = ["wheel" "networkmanager"];
          shell = pkgs.zsh;
        };
      })
      cfg.users);

    # Create corresponding groups for users
    users.groups = builtins.listToAttrs (map (username: {
        name = username;
        value = {};
      })
      cfg.users);

    # Enable zsh
    programs.zsh.enable = true;

    # Security settings
    security = {
      sudo.wheelNeedsPassword = false;
      rtkit.enable = true;
    };
  };
}
