# Description: Printing and scanning support with network printer discovery
# Category: hardware (Printing Module)
{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.hardware.printing = {
    enable = lib.mkEnableOption "printing and scanning support";

    drivers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["gutenprint" "hplip" "epson" "canon"];
      description = "Printer driver packages to install";
      example = ["hplip" "epson-escpr2"];
    };

    scanning = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable scanning support";
      };

      networkScanners = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Network scanners to configure";
        example = ["192.168.1.100" "scanner.local"];
      };
    };

    networkDiscovery = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable automatic network printer discovery";
      };

      browseDomains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["local"];
        description = "Domains to browse for network printers";
      };
    };

    defaultPrinter = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default printer name";
      example = "HP_LaserJet_P1102w";
    };

    paperSize = lib.mkOption {
      type = lib.types.str;
      default = "a4";
      description = "Default paper size";
      example = "letter";
    };

    avahi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Avahi for printer discovery";
    };
  };

  config = lib.mkIf config.modules.hardware.printing.enable {
    # Enable CUPS printing
    services.printing = {
      enable = true;
      browsing = config.modules.hardware.printing.networkDiscovery.enable;
      browsedConf = lib.mkIf config.modules.hardware.printing.networkDiscovery.enable ''
        BrowseDNSSDSubTypes _cups,_print
        BrowseLocalProtocols all
        BrowseRemoteProtocols all
        CreateIPPPrinterQueues All
        CreateIPPPrinterQueues Driverless
      '';

      # CUPS configuration
      extraConf = ''
        # Basic security
        DefaultAuthType Basic
        DefaultEncryption Never

        # Web interface
        WebInterface Yes

        # Default paper size
        DefaultPaperSize ${config.modules.hardware.printing.paperSize}

        # Auto-configuration
        AutoPurgeJobs Yes
        MaxJobs 100

        # Network settings
        ${lib.optionalString config.modules.hardware.printing.networkDiscovery.enable ''
          Browsing On
          BrowseProtocols cups dnssd
          ${lib.concatMapStringsSep "\n" (domain: "BrowseDNSSDSubTypes _cups,_print._tcp.${domain}") config.modules.hardware.printing.networkDiscovery.browseDomains}
        ''}
      '';

      # Install printer drivers
      drivers = with pkgs;
        lib.flatten [
          (lib.optional (builtins.elem "gutenprint" config.modules.hardware.printing.drivers) gutenprint)
          (lib.optional (builtins.elem "hplip" config.modules.hardware.printing.drivers) hplipWithPlugin)
          (lib.optional (builtins.elem "epson" config.modules.hardware.printing.drivers) epson-escpr)
          (lib.optional (builtins.elem "epson2" config.modules.hardware.printing.drivers) epson-escpr2)
          (lib.optional (builtins.elem "canon" config.modules.hardware.printing.drivers) cnijfilter2)
          (lib.optional (builtins.elem "brother" config.modules.hardware.printing.drivers) brlaser)
        ];
    };

    # Enable Avahi for network discovery
    services.avahi = lib.mkIf config.modules.hardware.printing.avahi {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      publish = {
        enable = true;
        userServices = true;
      };
    };

    # Scanning support
    hardware.sane = lib.mkIf config.modules.hardware.printing.scanning.enable {
      enable = true;
      extraBackends = with pkgs; [
        sane-airscan # Network scanners
        hplipWithPlugin
        epkowa
      ];

      # Network scanner configuration
      extraConfig = lib.mkIf (config.modules.hardware.printing.scanning.networkScanners != []) {
        "net.conf" = lib.concatMapStringsSep "\n" (scanner: "connect_timeout = 3\n${scanner}") config.modules.hardware.printing.scanning.networkScanners;
      };
    };

    # System packages for printing utilities
    environment.systemPackages = with pkgs;
      [
        cups
        system-config-printer # GUI printer configuration
        simple-scan # Simple scanning application

        # Command-line utilities
        ghostscript # PostScript interpreter
        poppler_utils # PDF utilities

        # Additional drivers based on configuration
      ]
      ++ lib.optionals (builtins.elem "hplip" config.modules.hardware.printing.drivers) [
        hplip # HP printer utilities
      ]
      ++ lib.optionals config.modules.hardware.printing.scanning.enable [
        sane-frontends # Scanning utilities
        xsane # Advanced scanning GUI
      ];

    # User groups for printing and scanning
    users.groups = {
      lp = {}; # Printing group
      scanner = {}; # Scanning group
    };

    # Add users to printing groups automatically
    users.users =
      lib.genAttrs
      (builtins.attrNames config.users.users)
      (username: {
        extraGroups =
          lib.mkIf (config.users.users.${username}.isNormalUser or false) [
            "lp"
          ]
          ++ lib.optionals config.modules.hardware.printing.scanning.enable [
            "scanner"
          ];
      });

    # Firewall configuration for printing
    networking.firewall = {
      allowedTCPPorts = [
        631 # CUPS
      ];
      allowedUDPPorts = [
        631 # CUPS browsing
        5353 # mDNS
      ];
    };

    # Systemd service for HP printer maintenance
    systemd.services.hp-printer-maintenance = lib.mkIf (builtins.elem "hplip" config.modules.hardware.printing.drivers) {
      description = "HP Printer Maintenance";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.hplip}/bin/hp-clean -p all";
      };
    };

    # Timer for periodic printer maintenance
    systemd.timers.hp-printer-maintenance = lib.mkIf (builtins.elem "hplip" config.modules.hardware.printing.drivers) {
      description = "HP Printer Maintenance Timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
    };

    # Default printer configuration
    systemd.services.set-default-printer = lib.mkIf (config.modules.hardware.printing.defaultPrinter != null) {
      description = "Set Default Printer";
      after = ["cups.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "set-default-printer" ''
          # Wait for CUPS to be ready
          while ! ${pkgs.cups}/bin/lpstat -r >/dev/null 2>&1; do
            sleep 1
          done

          # Set default printer if it exists
          if ${pkgs.cups}/bin/lpstat -p "${config.modules.hardware.printing.defaultPrinter}" >/dev/null 2>&1; then
            ${pkgs.cups}/bin/lpoptions -d "${config.modules.hardware.printing.defaultPrinter}"
            echo "Default printer set to: ${config.modules.hardware.printing.defaultPrinter}"
          else
            echo "Printer ${config.modules.hardware.printing.defaultPrinter} not found"
          fi
        '';
      };
    };

    # Assertions for configuration validation
    assertions = [
      {
        assertion = config.modules.hardware.printing.drivers != [];
        message = "At least one printer driver must be specified";
      }
      {
        assertion =
          !config.modules.hardware.printing.scanning.enable
          || config.hardware.sane.enable;
        message = "SANE must be enabled for scanning support";
      }
    ];
  };
}
