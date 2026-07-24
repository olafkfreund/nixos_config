# Network Configuration Module
# Provides network profile management and stability enhancements
{ config
, lib
, pkgs
, ...
}:
let inherit (lib) mkOption mkIf mkEnableOption mkForce mkMerge types; in {
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
    # Switch-time DNS stability (all hosts). systemd-resolved / NetworkManager
    # restarting mid-`nixos-rebuild switch` briefly kills DNS, causing transient
    # "no such host" failures during activation (the ollama model-pull was the
    # visible symptom). Keep them running across a switch; new DNS config applies
    # at next boot/logout. Root fix — supersedes the per-service ollama guard.
    {
      systemd.services.systemd-resolved.restartIfChanged =
        mkIf config.services.resolved.enable false;
      systemd.services.NetworkManager.restartIfChanged =
        mkIf config.networking.networkmanager.enable false;
    }

    # TCP / qdisc baseline for the high-jitter Starlink uplink (all hosts).
    # BBR + fq handle satellite jitter/random-loss far better than CUBIC; the
    # latency sysctls pair with BBR on the long-RTT CGNAT path. mkDefault so any
    # host keeps its own override — this closes the razer gap (was kernel-default
    # CUBIC) and makes the CLAUDE.md "applied everywhere" claim actually true.
    {
      boot.kernel.sysctl = {
        "net.core.default_qdisc" = lib.mkDefault "fq";
        "net.ipv4.tcp_congestion_control" = lib.mkDefault "bbr";
        "net.ipv4.tcp_notsent_lowat" = lib.mkDefault 16384; # cut local send-queue latency
        "net.ipv4.tcp_mtu_probing" = lib.mkDefault 1; # survive PMTU black holes on CGNAT
        "net.ipv4.tcp_fastopen" = lib.mkDefault 3; # shave 1 RTT on new connections
      };
    }

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
