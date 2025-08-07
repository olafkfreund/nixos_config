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
      networking.networkmanager = {
        enable = true;
        # Add connection configuration for stability
        connectionConfig = mkIf config.networking.stableConnection.enable {
          "connection.stable-id" = "\${CONNECTION}/\${BOOT}";
          "connection.wait-device-timeout" = config.networking.stableConnection.interfaceSwitchDelayMs;
          "connection.mdns" = 2; # Enable mDNS
        };
      };
      networking.useDHCP = false;
      networking.useNetworkd = false;
      networking.firewall.enable = false;
      networking.nftables.enable = true;
      networking.timeServers = [ "pool.ntp.org" ];

      # Better integration with systemd-resolved when using NetworkManager
      networking.networkmanager.dns = mkIf config.services.resolved.enable "systemd-resolved";
    })

    (mkIf (config.networking.profile == "server") {
      # Server networking with systemd-networkd
      networking.networkmanager.enable = false;
      networking.useDHCP = false;
      networking.useNetworkd = true;
      networking.useHostResolvConf = false;
      networking.firewall.enable = false;
      networking.nftables.enable = true;
      networking.timeServers = [ "pool.ntp.org" ];

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
      systemd.network.wait-online.timeout = 10;
      systemd.services.NetworkManager-wait-online.enable = mkForce false;
      systemd.services.systemd-networkd-wait-online.enable = mkForce false;
    })

    (mkIf (config.networking.profile == "minimal") {
      # Minimal networking configuration with just DHCP
      networking.useDHCP = true;
      networking.firewall.enable = false;
      networking.timeServers = [ "pool.ntp.org" ];
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
