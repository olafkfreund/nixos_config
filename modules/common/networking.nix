# Network Configuration Module
# Provides network profile management and stability enhancements
{ config
, lib
, pkgs
, ...
}:
with lib; {
  options.networking.profile = mkOption {
    type = types.enum [ "desktop" "server" "minimal" ];
    default = "desktop";
    description = "Network profile to use";
  };

  options.networking.stableConnection = {
    enable = mkEnableOption "Network stability enhancements to prevent connection changes";

    interfaceSwitchDelayMs = mkOption {
      type = types.int;
      default = 5000;
      description = "Delay in milliseconds before switching network interfaces";
      example = 3000;
    };
  };

  config = mkMerge [
    (mkIf (config.networking.profile == "desktop") {
      # Desktop networking configuration with NetworkManager
      networking = {
        networkmanager = {
          enable = true;
          dns = "default"; # Use NetworkManager's built-in DNS instead of systemd-resolved
          # Add connection configuration for stability
          settings = mkIf config.networking.stableConnection.enable {
            main = {
              dns = "default";
            };
            connection = {
              stable-id = "\${CONNECTION}/\${BOOT}";
              wait-device-timeout = toString config.networking.stableConnection.interfaceSwitchDelayMs;
            };
          };
        };
        useDHCP = false;
        useNetworkd = false;
        useHostResolvConf = false;
        firewall.enable = lib.mkDefault true; # Allow hosts to override
        timeServers = [ "pool.ntp.org" ];
      };

      # Disable systemd-resolved for desktop profile - NetworkManager handles DNS
      services.resolved.enable = lib.mkDefault false;

      # Disable network wait services for faster boot
      systemd.services = {
        NetworkManager-wait-online.enable = lib.mkDefault false;
      };
    })

    (mkIf (config.networking.profile == "server") {
      # Server networking with systemd-networkd
      networking = {
        networkmanager.enable = false;
        useDHCP = false;
        useNetworkd = true;
        useHostResolvConf = false;
        firewall.enable = lib.mkDefault true; # Allow hosts to override
        timeServers = [ "pool.ntp.org" ];
      };

      # Enable systemd-resolved for DNS resolution with systemd-networkd
      services.resolved = {
        enable = true;
        dnssec = "true";
        domains = [ "~." ]; # Use systemd-resolved for all domains
        fallbackDns = [
          "1.1.1.1"
          "8.8.8.8"
        ];
        extraConfig = ''
          DNSOverTLS=yes
          MulticastDNS=no
        '';
      };

      # Systemd network wait settings
      systemd = {
        network.wait-online.timeout = 10;
        services = {
          NetworkManager-wait-online.enable = mkForce false;
          systemd-networkd-wait-online.enable = mkForce false;
        };
      };
    })

    (mkIf (config.networking.profile == "minimal") {
      # Minimal networking configuration with just DHCP
      networking = {
        useDHCP = true;
        firewall.enable = lib.mkDefault true; # Allow hosts to override
        timeServers = [ "pool.ntp.org" ];
      };
    })

    # Fix for duplicate systemd.network: Only add link configuration enhancements,
    # don't override existing network configurations
    (mkIf (config.networking.stableConnection.enable && config.systemd.network.enable) {
      # Directly define network configurations for wired and wireless interfaces
      # without depending on existing values
      systemd.network.networks = {
        # Wired interface enhancement with valid systemd-networkd options
        "20-wired" = {
          linkConfig = {
            # Valid stability-focused options
            RequiredForOnline = "routable";
            ActivationPolicy = "always-up";
            MTUBytes = 1500;
          };
          # Use networkConfig for options not available in linkConfig
          networkConfig = {
            ConfigureWithoutCarrier = true;
            KeepConfiguration = "yes";
          };
        };

        # Wireless interface enhancement
        "25-wireless" = {
          linkConfig = {
            RequiredForOnline = "routable";
            ActivationPolicy = "always-up";
            MTUBytes = 1500;
          };
          # Use networkConfig for options not available in linkConfig
          networkConfig = {
            ConfigureWithoutCarrier = true;
            KeepConfiguration = "yes";
          };
        };
      };

      # Global network stabilization service to allow applications to wait for a stable connection
      systemd.user.services.network-stabilize = {
        description = "Wait for network to stabilize";
        wantedBy = [ "default.target" ];
        before = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash -c 'sleep 3'";
          Restart = "no";
        };
      };
    })
  ];
}
