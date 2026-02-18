# Live USB Image Configurations
# Extracted from flake.nix for better performance and organization
{ nixpkgs
, inputs
, hostUsers
,
}:
let
  # Common live system configuration
  baseLiveConfig =
    { config
    , lib
    , modulesPath
    , host
    , hostUsers
    , ...
    }: {
      imports = [
        "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
      ];

      # Basic system configuration
      time.timeZone = lib.mkDefault "Europe/Oslo";
      i18n.defaultLocale = lib.mkDefault "en_GB.UTF-8";

      # Network configuration
      networking = {
        hostName = lib.mkDefault "${host}-installer";
        networkmanager.enable = true;
        wireless.enable = lib.mkForce false; # Disable wpa_supplicant in favor of NetworkManager
        firewall.enable = false; # Disable for installation convenience
      };

      # User configuration
      users.users = builtins.listToAttrs
        (map
          (username: {
            name = username;
            value = {
              isNormalUser = true;
              description = "Live system user ${username}";
              extraGroups = [ "wheel" "networkmanager" ];
              # Default password for live system
              password = "nixos";
            };
          })
          hostUsers) // {
        # Root user configuration
        root = {
          password = "nixos";
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILeccj+vW/qyKepgXK0oXZfVFMf1kwmqj4uBHmjU2fz8 olafkfreund"
          ];
        };
      };

      # Enable sudo without password for installation
      security.sudo = {
        enable = true;
        wheelNeedsPassword = false;
      };

      # SSH configuration for remote installation
      services.openssh = {
        enable = true;
        settings = {
          PermitRootLogin = "yes";
          PasswordAuthentication = true;
          PubkeyAuthentication = true;
        };
      };

      # System configuration
      nixpkgs.config = {
        allowUnfree = true;
        allowInsecure = true; # Live systems need maximum compatibility
      };

      # Enable flakes
      nix.settings = {
        experimental-features = [ "nix-command" "flakes" ];
        substituters = [
          "https://cache.nixos.org/"
          "https://nix-community.cachix.org"
        ];
      };

      # Essential packages for installation
      environment.systemPackages = with config.boot.kernelPackages; [
        # Hardware tools
        inputs.nixpkgs.legacyPackages.x86_64-linux.lshw
        inputs.nixpkgs.legacyPackages.x86_64-linux.dmidecode
        inputs.nixpkgs.legacyPackages.x86_64-linux.util-linux
        inputs.nixpkgs.legacyPackages.x86_64-linux.usbutils
        inputs.nixpkgs.legacyPackages.x86_64-linux.pciutils

        # Network tools
        inputs.nixpkgs.legacyPackages.x86_64-linux.curl
        inputs.nixpkgs.legacyPackages.x86_64-linux.wget
        inputs.nixpkgs.legacyPackages.x86_64-linux.networkmanager
        inputs.nixpkgs.legacyPackages.x86_64-linux.dhcpcd

        # Disk utilities
        inputs.nixpkgs.legacyPackages.x86_64-linux.parted
        inputs.nixpkgs.legacyPackages.x86_64-linux.gptfdisk
        inputs.nixpkgs.legacyPackages.x86_64-linux.cryptsetup
        inputs.nixpkgs.legacyPackages.x86_64-linux.dosfstools
        inputs.nixpkgs.legacyPackages.x86_64-linux.e2fsprogs
        inputs.nixpkgs.legacyPackages.x86_64-linux.xfsprogs
        inputs.nixpkgs.legacyPackages.x86_64-linux.ntfs3g

        # Text editors
        inputs.nixpkgs.legacyPackages.x86_64-linux.neovim
        inputs.nixpkgs.legacyPackages.x86_64-linux.nano
        inputs.nixpkgs.legacyPackages.x86_64-linux.micro

        # System utilities
        inputs.nixpkgs.legacyPackages.x86_64-linux.tmux
        inputs.nixpkgs.legacyPackages.x86_64-linux.htop
        inputs.nixpkgs.legacyPackages.x86_64-linux.iotop
        inputs.nixpkgs.legacyPackages.x86_64-linux.git
        inputs.nixpkgs.legacyPackages.x86_64-linux.rsync
        inputs.nixpkgs.legacyPackages.x86_64-linux.unzip

        # Development tools
        inputs.nixpkgs.legacyPackages.x86_64-linux.python3
        inputs.nixpkgs.legacyPackages.x86_64-linux.jq
        inputs.nixpkgs.legacyPackages.x86_64-linux.bc

        # Monitoring tools
        inputs.nixpkgs.legacyPackages.x86_64-linux.iftop
        inputs.nixpkgs.legacyPackages.x86_64-linux.nethogs
        inputs.nixpkgs.legacyPackages.x86_64-linux.powertop
      ];

      # Include custom installation scripts
      environment.etc = {
        "nixos-config/flake.nix".source = ../flake.nix;
        "nixos-config/hosts".source = ../hosts;
        "nixos-config/modules".source = ../modules;
        "nixos-config/lib".source = ../lib;
        "nixos-config/scripts".source = ../scripts;
        "nixos-config/secrets.nix".source = ../secrets.nix;
      };

      # Installation tools
      systemd.services."install-${host}" = {
        description = "NixOS installation script for ${host}";
        path = with config.environment.systemPackages; [
          inputs.nixpkgs.legacyPackages.x86_64-linux.nixos-install-tools
          inputs.nixpkgs.legacyPackages.x86_64-linux.git
          inputs.nixpkgs.legacyPackages.x86_64-linux.parted
        ];
        script = ''
          #!/bin/bash
          echo "Starting NixOS installation for ${host}..."
          cd /etc/nixos-config
          bash scripts/install-helpers/install-wizard.sh ${host}
        '';
        serviceConfig = {
          Type = "simple";
          User = "root";
        };
      };
    };

  # Host-specific live configurations
  hostSpecificConfigs = {
    p620 =
      _: {
        # AMD-specific drivers and tools
        boot.kernelModules = [ "amdgpu" ];
        services.xserver.videoDrivers = [ "amdgpu" ];
        environment.systemPackages = with inputs.nixpkgs.legacyPackages.x86_64-linux; [
          radeontop
          rocm-opencl-icd
        ];
      };

    razer =
      _: {
        # Intel/NVIDIA hybrid graphics
        boot.kernelModules = [ "i915" "nvidia" ];
        services.xserver.videoDrivers = [ "nvidia" ];
        hardware.nvidia.modesetting.enable = true;
        hardware.nvidia.open = true; # Required for >= 560 drivers, Razer has RTX GPU
      };

    p510 =
      _: {
        # Intel Xeon with NVIDIA
        boot.kernelModules = [ "nvidia" ];
        services.xserver.videoDrivers = [ "nvidia" ];
      };

    dex5550 =
      _: {
        # Intel integrated graphics
        boot.kernelModules = [ "i915" ];
        services.xserver.videoDrivers = [ "intel" ];
      };

    samsung =
      _: {
        # Intel integrated graphics (laptop)
        boot.kernelModules = [ "i915" ];
        services.xserver.videoDrivers = [ "intel" ];
      };
  };

  # Function to create a live image for a specific host
  mkLiveImage = hostName:
    let
      hostConfig = hostUsers.${hostName} or [ "olafkfreund" ];
      hostSpecific = hostSpecificConfigs.${hostName} or { };
      system = "x86_64-linux";
    in
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs system;
        host = hostName;
        hostUsers = hostConfig;
      };
      modules = [
        baseLiveConfig
        hostSpecific
      ];
    };
in
{
  # Export the function
  inherit mkLiveImage;

  # Create all live images
  liveImages = builtins.listToAttrs (map
    (hostName: {
      name = "live-iso-${hostName}";
      value = mkLiveImage hostName;
    }) [ "p620" "razer" "p510" "dex5550" "samsung" ]);
}
