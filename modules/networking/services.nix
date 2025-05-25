# Description: Network services including DNS, DHCP, and network monitoring
# Category: networking (Network Services Module)
{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.networking.services = {
    enable = lib.mkEnableOption "network services";

    dns = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable DNS server";
      };

      forwarders = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["1.1.1.1" "8.8.8.8"];
        description = "DNS forwarders to use";
      };

      zones = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "DNS zones to serve";
        example = lib.literalExpression ''
          {
            "example.local" = '''
              $TTL 300
              @   IN  SOA ns1.example.local. admin.example.local. (
                      2023010101  ; serial
                      3600        ; refresh
                      1800        ; retry
                      604800      ; expire
                      300         ; minimum
                  )
              @   IN  NS  ns1.example.local.
              ns1 IN  A   192.168.1.1
            ''';
          }
        '';
      };
    };

    dhcp = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable DHCP server";
      };

      interface = lib.mkOption {
        type = lib.types.str;
        default = "eth0";
        description = "Interface to serve DHCP on";
      };

      range = {
        start = lib.mkOption {
          type = lib.types.str;
          default = "192.168.1.100";
          description = "DHCP range start";
        };

        end = lib.mkOption {
          type = lib.types.str;
          default = "192.168.1.200";
          description = "DHCP range end";
        };
      };

      gateway = lib.mkOption {
        type = lib.types.str;
        default = "192.168.1.1";
        description = "Default gateway for DHCP clients";
      };

      nameservers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["192.168.1.1"];
        description = "DNS servers for DHCP clients";
      };

      staticLeases = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Static DHCP leases";
        example = lib.literalExpression ''
          {
            "00:11:22:33:44:55" = "192.168.1.10";
            "aa:bb:cc:dd:ee:ff" = "192.168.1.11";
          }
        '';
      };
    };

    monitoring = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable network monitoring";
      };

      targets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["1.1.1.1" "8.8.8.8"];
        description = "Targets to monitor for connectivity";
      };

      alertWebhook = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Webhook URL for network alerts";
      };
    };

    ntp = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable NTP server";
      };

      servers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "0.nixos.pool.ntp.org"
          "1.nixos.pool.ntp.org"
          "2.nixos.pool.ntp.org"
          "3.nixos.pool.ntp.org"
        ];
        description = "NTP servers to sync with";
      };
    };
  };

  config = lib.mkIf config.modules.networking.services.enable {
    # DNS Server (using BIND)
    services.bind = lib.mkIf config.modules.networking.services.dns.enable {
      enable = true;

      forwarders = config.modules.networking.services.dns.forwarders;

      zones =
        lib.mapAttrs (name: content: {
          master = true;
          file = pkgs.writeText "${name}.zone" content;
        })
        config.modules.networking.services.dns.zones;

      extraConfig = ''
        options {
          listen-on { any; };
          listen-on-v6 { any; };
          recursion yes;
          allow-recursion { any; };
          dnssec-validation auto;
        };
      '';
    };

    # DHCP Server (using ISC DHCP)
    services.dhcpd4 = lib.mkIf config.modules.networking.services.dhcp.enable {
      enable = true;
      interfaces = [config.modules.networking.services.dhcp.interface];

      extraConfig = ''
        option domain-name-servers ${lib.concatStringsSep ", " config.modules.networking.services.dhcp.nameservers};
        option routers ${config.modules.networking.services.dhcp.gateway};

        subnet ${lib.head (lib.splitString "." config.modules.networking.services.dhcp.range.start)}.${lib.elemAt (lib.splitString "." config.modules.networking.services.dhcp.range.start) 1}.${lib.elemAt (lib.splitString "." config.modules.networking.services.dhcp.range.start) 2}.0 netmask 255.255.255.0 {
          range ${config.modules.networking.services.dhcp.range.start} ${config.modules.networking.services.dhcp.range.end};

          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (mac: ip: ''
            host static-${lib.replaceStrings [":"] ["-"] mac} {
              hardware ethernet ${mac};
              fixed-address ${ip};
            }
          '')
          config.modules.networking.services.dhcp.staticLeases)}
        }
      '';
    };

    # NTP Server
    services.ntp = lib.mkIf config.modules.networking.services.ntp.enable {
      enable = true;
      servers = config.modules.networking.services.ntp.servers;
    };

    # Network Monitoring
    systemd.services.network-monitor = lib.mkIf config.modules.networking.services.monitoring.enable {
      description = "Network Connectivity Monitor";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "30s";
        ExecStart = pkgs.writeShellScript "network-monitor" ''
          set -euo pipefail

          TARGETS=(${lib.concatStringsSep " " config.modules.networking.services.monitoring.targets})
          WEBHOOK_URL="${config.modules.networking.services.monitoring.alertWebhook or ""}"
          FAILURE_COUNT=0
          MAX_FAILURES=3

          log() {
            echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
          }

          send_alert() {
            local status="$1"
            local message="$2"

            if [ -n "$WEBHOOK_URL" ]; then
              ${pkgs.curl}/bin/curl -X POST "$WEBHOOK_URL" \
                -H "Content-Type: application/json" \
                -d "{\"status\":\"$status\",\"message\":\"$message\",\"hostname\":\"$(hostname)\"}" || true
            fi
          }

          check_connectivity() {
            local success=0

            for target in "''${TARGETS[@]}"; do
              if ${pkgs.iputils}/bin/ping -c 1 -W 5 "$target" >/dev/null 2>&1; then
                success=1
                break
              fi
            done

            return $((1 - success))
          }

          log "Starting network monitoring for targets: ''${TARGETS[*]}"

          while true; do
            if check_connectivity; then
              if [ $FAILURE_COUNT -ge $MAX_FAILURES ]; then
                log "Network connectivity restored"
                send_alert "recovery" "Network connectivity restored"
              fi
              FAILURE_COUNT=0
            else
              FAILURE_COUNT=$((FAILURE_COUNT + 1))
              log "Network check failed ($FAILURE_COUNT/$MAX_FAILURES)"

              if [ $FAILURE_COUNT -ge $MAX_FAILURES ]; then
                log "Network connectivity lost"
                send_alert "failure" "Network connectivity lost - all targets unreachable"
              fi
            fi

            sleep 30
          done
        '';
      };
    };

    # Network statistics collection
    systemd.services.network-stats = lib.mkIf config.modules.networking.services.monitoring.enable {
      description = "Network Statistics Collection";
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "network-stats" ''
          set -euo pipefail

          STATS_FILE="/var/log/network-stats.log"

          # Create log directory
          mkdir -p "$(dirname "$STATS_FILE")"

          # Collect network statistics
          {
            echo "=== Network Statistics - $(date) ==="
            echo "Active connections:"
            ${pkgs.nettools}/bin/netstat -tuln | head -20
            echo ""

            echo "Interface statistics:"
            ${pkgs.iproute2}/bin/ip -s link show
            echo ""

            echo "Routing table:"
            ${pkgs.iproute2}/bin/ip route show
            echo ""

            echo "DNS resolution test:"
            ${pkgs.dnsutils}/bin/nslookup google.com || echo "DNS resolution failed"
            echo ""
          } >> "$STATS_FILE"

          # Keep only last 1000 lines
          tail -n 1000 "$STATS_FILE" > "$STATS_FILE.tmp" && mv "$STATS_FILE.tmp" "$STATS_FILE"
        '';
      };
    };

    # Network stats timer
    systemd.timers.network-stats = lib.mkIf config.modules.networking.services.monitoring.enable {
      description = "Network Statistics Timer";
      wantedBy = ["timers.target"];

      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };

    # Firewall configuration for network services
    networking.firewall = {
      allowedTCPPorts = lib.flatten [
        (lib.optional config.modules.networking.services.dns.enable 53)
        (lib.optional config.modules.networking.services.ntp.enable 123)
      ];

      allowedUDPPorts = lib.flatten [
        (lib.optional config.modules.networking.services.dns.enable 53)
        (lib.optional config.modules.networking.services.dhcp.enable 67)
        (lib.optional config.modules.networking.services.ntp.enable 123)
      ];
    };

    # System packages for network administration
    environment.systemPackages = with pkgs; [
      bind # DNS utilities
      dhcp # DHCP utilities
      ntp # NTP utilities
      tcpdump # Network packet capture
      wireshark-cli # Network analysis
      iftop # Network bandwidth monitoring
      nethogs # Per-process network usage
      nmap # Network scanning
      dnsutils # DNS utilities (nslookup, dig)
      nettools # Network tools (netstat, etc.)
    ];

    # Assertions for configuration validation
    assertions = [
      {
        assertion =
          !config.modules.networking.services.dhcp.enable
          || config.modules.networking.services.dhcp.interface != "";
        message = "DHCP interface must be specified when DHCP is enabled";
      }
      {
        assertion =
          !config.modules.networking.services.dns.enable
          || config.modules.networking.services.dns.forwarders != [];
        message = "DNS forwarders must be specified when DNS server is enabled";
      }
    ];
  };
}
