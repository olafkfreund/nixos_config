# Live ISO Builder Helper Function
{ nixpkgs
, inputs
, host
, hostUsers ? [ ]
, ...
}:
let
  system = "x86_64-linux";
  # Helper to build live ISO for a specific host
  mkLiveISO = hostName: {
    inherit system;
    specialArgs = {
      inherit inputs host system;
      username = builtins.head hostUsers;
      hostUsers = hostUsers;
    };
    modules = [
      # Base live system configuration
      ../modules/installer/live-system.nix

      # Pass host name to the live system
      {
        _module.args.host = hostName;

        # Set the ISO name and volume ID
        isoImage = {
          isoName = "nixos-${hostName}-live.iso";
          volumeID = "NIXOS_${nixpkgs.lib.toUpper hostName}";
        };

        # Include the host-specific installer command
        environment.systemPackages = with nixpkgs.legacyPackages.x86_64-linux; [
          (writeScriptBin "install-${hostName}" ''
            #!/bin/bash
            exec /etc/nixos-config/scripts/install-helpers/install-wizard.sh "${hostName}" "$@"
          '')

          (writeScriptBin "test-${hostName}-config" ''
            #!/bin/bash
            echo "Testing hardware configuration for ${hostName}..."
            /etc/nixos-config/scripts/install-helpers/parse-hardware-config.py "${hostName}"
          '')
        ];

        # Create a welcome script specific to this host
        environment.etc."welcome-${hostName}".text = ''
          ╭─────────────────────────────────────────╮
          │     NixOS Live Installer for ${hostName}       │
          ╰─────────────────────────────────────────╯

          Quick Start:
          1. Connect to network: nmtui
          2. Install NixOS: sudo install-${hostName}
          3. Test config: test-${hostName}-config

          For SSH access:
          - User: root
          - Pass: nixos (CHANGE AFTER INSTALL!)

          Configuration: /etc/nixos-config
          Scripts: /etc/nixos-config/scripts/install-helpers/

          Hardware config will be auto-detected from:
          hosts/${hostName}/nixos/hardware-configuration.nix
        '';

        # Add host info to MOTD
        users.motd = ''

          Welcome to NixOS Live Installer for ${hostName}!

          To install: sudo install-${hostName}
          For help: cat /etc/welcome-${hostName}

        '';
      }

      # Networking and basic services
      {
        # Enable NetworkManager for easy network setup
        networking.networkmanager.enable = true;
        networking.wireless.enable = false;

        # Basic firewall
        networking.firewall = {
          enable = true;
          allowedTCPPorts = [ 22 ];
        };

        # Time zone (can be changed during install)
        time.timeZone = "Europe/Oslo";

        # Locale
        i18n.defaultLocale = "en_GB.UTF-8";

        # Console setup
        console = {
          keyMap = "us";
          font = "Lat2-Terminus16";
        };
      }

      # Essential packages for installation
      {
        environment.systemPackages = with nixpkgs.legacyPackages.x86_64-linux; [
          # System information
          lshw
          hwinfo
          pciutils
          usbutils
          dmidecode

          # Text editors
          neovim
          nano

          # Terminal utilities
          tmux
          htop
          tree

          # Network tools
          wget
          curl

          # Installation tools (already included in installer-tools.nix)
          git
          jq
          python3
          python3Packages.pyyaml

          # File system tools
          parted
          gptfdisk
          util-linux
          dosfstools
          e2fsprogs

          # Archive tools
          unzip
          tar
          gzip
        ];
      }
    ];
  };
in
{
  inherit mkLiveISO;

  # Convenience function to build all live ISOs
  mkAllLiveISOs = hosts:
    nixpkgs.lib.mapAttrs
      (
        hostName: _hostConfig:
          nixpkgs.lib.nixosSystem (mkLiveISO hostName)
      )
      hosts;
}
