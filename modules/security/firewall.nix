# Centralized Firewall Configuration Module
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.security.firewall;

  # Define service port groups for better organization
  servicePortGroups = {
    ssh = {
      tcp = [ 22 ];
      udp = [ ];
    };
    dns = {
      tcp = [ 53 ];
      udp = [ 53 ];
    };
    web = {
      tcp = [ 80 443 ];
      udp = [ ];
    };
    monitoring = {
      tcp = [ 3000 3001 3100 9090 9093 9096 9100 9101 9102 9103 9104 28183 ];
      udp = [ ];
    };
    media = {
      tcp = [ 5055 6789 8181 8989 7878 9117 9696 32400 ];
      udp = [ ];
    };
    development = {
      tcp = [ 3000 8080 8081 5000 ];
      udp = [ ];
    };
  };

  # Host type configurations
  hostProfiles = {
    workstation = {
      allowedServices = [ "ssh" "development" ];
      trustedInterfaces = [ "lo" ];
      restrictedAccess = false;
    };

    server = {
      allowedServices = [ "ssh" "web" "dns" ];
      trustedInterfaces = [ "lo" ];
      restrictedAccess = true;
    };

    mediaServer = {
      allowedServices = [ "ssh" "media" "monitoring" ];
      trustedInterfaces = [ "lo" ];
      restrictedAccess = true;
    };

    monitoringServer = {
      allowedServices = [ "ssh" "web" "dns" "monitoring" ];
      trustedInterfaces = [ "lo" ];
      restrictedAccess = true;
    };
  };

  # Get ports for enabled services
  getServicePorts = services: protocol:
    flatten (map
      (
        service:
        if hasAttr service servicePortGroups
        then getAttr protocol (getAttr service servicePortGroups)
        else [ ]
      )
      services);

  # Build firewall rules based on profile
  buildFirewallConfig = profile:
    let
      profileConfig = getAttr profile hostProfiles;
      tcpPorts = getServicePorts profileConfig.allowedServices "tcp";
      udpPorts = getServicePorts profileConfig.allowedServices "udp";
    in
    {
      allowedTCPPorts = tcpPorts ++ cfg.extraTcpPorts;
      allowedUDPPorts = udpPorts ++ cfg.extraUdpPorts;
      interfaces = cfg.interfaceRules;
      trustedInterfaces = profileConfig.trustedInterfaces ++ cfg.extraTrustedInterfaces;
    };
in
{
  options.security.firewall = {
    enable = mkEnableOption "Centralized firewall configuration";

    profile = mkOption {
      type = types.enum [ "workstation" "server" "mediaServer" "monitoringServer" "custom" ];
      default = "workstation";
      description = "Firewall profile to use";
    };

    extraTcpPorts = mkOption {
      type = types.listOf types.port;
      default = [ ];
      description = "Additional TCP ports to allow";
    };

    extraUdpPorts = mkOption {
      type = types.listOf types.port;
      default = [ ];
      description = "Additional UDP ports to allow";
    };

    extraTrustedInterfaces = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional trusted interfaces";
    };

    interfaceRules = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          allowedTCPPorts = mkOption {
            type = types.listOf types.port;
            default = [ ];
            description = "TCP ports allowed on this interface";
          };
          allowedUDPPorts = mkOption {
            type = types.listOf types.port;
            default = [ ];
            description = "UDP ports allowed on this interface";
          };
        };
      });
      default = { };
      description = "Per-interface firewall rules";
    };

    enableAdvancedRules = mkOption {
      type = types.bool;
      default = true;
      description = "Enable advanced iptables rules for enhanced security";
    };

    enableLogging = mkOption {
      type = types.bool;
      default = true;
      description = "Enable firewall logging for dropped packets";
    };

    trustedNetworks = mkOption {
      type = types.listOf types.str;
      default = [ "192.168.1.0/24" "10.0.0.0/8" "172.16.0.0/12" ];
      description = "Trusted network CIDRs";
    };

    blockCountries = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "CN" "RU" "KP" ];
      description = "ISO country codes to block (requires GeoIP)";
    };

    rateLimiting = {
      enable = mkEnableOption "Rate limiting for connections";

      sshLimit = mkOption {
        type = types.int;
        default = 4;
        description = "SSH connection attempts per minute";
      };

      httpLimit = mkOption {
        type = types.int;
        default = 100;
        description = "HTTP connection attempts per minute";
      };
    };
  };

  config = mkIf cfg.enable {
    # Disable nftables to use iptables-based firewall consistently
    networking.nftables.enable = mkForce false;

    # Main firewall configuration
    networking.firewall = mkMerge [
      {
        enable = mkForce true;

        # Default settings
        allowPing = true;
        pingLimit = "--limit 5/minute --limit-burst 10";

        # Apply profile-based configuration
        inherit
          (buildFirewallConfig cfg.profile)
          allowedTCPPorts
          allowedUDPPorts
          interfaces
          trustedInterfaces
          ;
      }

      # Advanced iptables rules
      (mkIf cfg.enableAdvancedRules {
        extraCommands = ''
          # Rate limiting for SSH connections
          ${optionalString cfg.rateLimiting.enable ''
            iptables -I INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name SSH_LIMIT
            iptables -I INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount ${toString cfg.rateLimiting.sshLimit} --name SSH_LIMIT -j DROP
          ''}

          # Rate limiting for HTTP/HTTPS
          ${optionalString cfg.rateLimiting.enable ''
            iptables -I INPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW -m recent --set --name HTTP_LIMIT
            iptables -I INPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount ${toString cfg.rateLimiting.httpLimit} --name HTTP_LIMIT -j DROP
          ''}

          # Drop invalid packets
          iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

          # Allow established and related connections
          iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

          # Trusted network access
          ${concatMapStringsSep "\n" (network: ''
              iptables -A INPUT -s ${network} -j ACCEPT
            '')
            cfg.trustedNetworks}

          # Anti-scan protection
          iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
          iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
          iptables -A INPUT -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP
          iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP
          iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
          iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP

          # Log dropped packets (if enabled)
          ${optionalString cfg.enableLogging ''
            iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "FIREWALL-DROP: " --log-level 4
          ''}
        '';

        extraStopCommands = ''
          # Clean up rate limiting rules
          ${optionalString cfg.rateLimiting.enable ''
            iptables -D INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name SSH_LIMIT 2>/dev/null || true
            iptables -D INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount ${toString cfg.rateLimiting.sshLimit} --name SSH_LIMIT -j DROP 2>/dev/null || true
            iptables -D INPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW -m recent --set --name HTTP_LIMIT 2>/dev/null || true
            iptables -D INPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount ${toString cfg.rateLimiting.httpLimit} --name HTTP_LIMIT -j DROP 2>/dev/null || true
          ''}
        '';
      })
    ];

    # Firewall monitoring and management tools
    environment.systemPackages = with pkgs; [
      iptables
      nftables # Keep available as backup
      (writeShellScriptBin "firewall-status" ''
        #!/bin/bash

        echo "=== Firewall Status ==="
        echo

        # Service status
        echo "Firewall Service Status:"
        systemctl status firewall --no-pager -l
        echo

        # Active rules
        echo "Active IPtables Rules:"
        iptables -L -n -v
        echo

        # Rate limiting status
        echo "Rate Limiting Status:"
        iptables -L -n -v | grep -E "(SSH_LIMIT|HTTP_LIMIT)" || echo "No rate limiting active"
        echo

        # Connection tracking
        echo "Connection Tracking:"
        cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo "Connection tracking not available"
        cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo "Connection tracking not available"
        echo

        # Recent connection attempts (if logging enabled)
        ${optionalString cfg.enableLogging ''
          echo "Recent Dropped Connections (last 20):"
          journalctl -k | grep "FIREWALL-DROP" | tail -20 || echo "No recent drops logged"
          echo
        ''}

        # Open ports
        echo "Listening Ports:"
        ss -tlnp | grep LISTEN
        echo

        # Active connections by service
        echo "Active Connections by Port:"
        ss -tn | grep ESTAB | awk '{print $4}' | cut -d: -f2 | sort | uniq -c | sort -nr | head -10
      '')

      (writeShellScriptBin "firewall-test" ''
        #!/bin/bash

        if [ $# -eq 0 ]; then
          echo "Usage: $0 <host> <port> [protocol]"
          echo "Test if a port is accessible from this host"
          exit 1
        fi

        HOST="$1"
        PORT="$2"
        PROTOCOL="''${3:-tcp}"

        echo "Testing connection to $HOST:$PORT ($PROTOCOL)..."

        if [ "$PROTOCOL" = "tcp" ]; then
          if timeout 5 bash -c "echo >/dev/tcp/$HOST/$PORT" 2>/dev/null; then
            echo "✅ Port $PORT is OPEN on $HOST"
          else
            echo "❌ Port $PORT is CLOSED or filtered on $HOST"
          fi
        elif [ "$PROTOCOL" = "udp" ]; then
          if command -v nc &> /dev/null; then
            if timeout 5 nc -u -z "$HOST" "$PORT" 2>/dev/null; then
              echo "✅ UDP port $PORT appears open on $HOST"
            else
              echo "❌ UDP port $PORT appears closed on $HOST"
            fi
          else
            echo "⚠️  netcat (nc) not available for UDP testing"
          fi
        else
          echo "❌ Unknown protocol: $PROTOCOL"
          exit 1
        fi
      '')

      (writeShellScriptBin "firewall-analyze" ''
        #!/bin/bash

        echo "=== Firewall Security Analysis ==="
        echo

        # Check for common security issues
        echo "Security Analysis:"

        # Check if SSH is rate limited
        if iptables -L | grep -q "SSH_LIMIT"; then
          echo "✅ SSH rate limiting: ENABLED"
        else
          echo "⚠️  SSH rate limiting: DISABLED"
        fi

        # Check for trusted network restrictions
        TRUSTED_RULES=$(iptables -L | grep -c "192.168\|10\.\|172\.")
        if [ "$TRUSTED_RULES" -gt 0 ]; then
          echo "✅ Trusted network rules: $TRUSTED_RULES rules active"
        else
          echo "⚠️  Trusted network rules: NOT CONFIGURED"
        fi

        # Check for invalid packet dropping
        if iptables -L | grep -q "ctstate INVALID"; then
          echo "✅ Invalid packet dropping: ENABLED"
        else
          echo "⚠️  Invalid packet dropping: DISABLED"
        fi

        # Check open ports
        echo
        echo "Port Security Analysis:"
        OPEN_PORTS=$(ss -tln | grep LISTEN | wc -l)
        echo "Total listening ports: $OPEN_PORTS"

        # Check for potentially risky open ports
        RISKY_PORTS=(21 23 25 53 139 445 1433 3306 5432 6379)
        for port in "''${RISKY_PORTS[@]}"; do
          if ss -tln | grep -q ":$port "; then
            echo "⚠️  Potentially risky port open: $port"
          fi
        done

        # Firewall rule count
        RULE_COUNT=$(iptables -L | wc -l)
        echo "Total firewall rules: $RULE_COUNT"

        if [ "$RULE_COUNT" -lt 20 ]; then
          echo "⚠️  Consider adding more specific firewall rules"
        else
          echo "✅ Comprehensive firewall rules in place"
        fi
      '')
    ];

    # Firewall monitoring service
    systemd.services.firewall-monitor = {
      description = "Firewall Monitoring Service";
      after = [ "network.target" "firewall.service" ];
      wants = [ "firewall.service" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "firewall-monitor" ''
          #!/bin/bash

          LOG_FILE="/var/log/firewall-monitor.log"
          TIMESTAMP=$(date -Iseconds)

          # Count current connections
          CONNECTIONS=$(ss -tn | grep ESTAB | wc -l)

          # Count firewall rules
          RULES=$(iptables -L | wc -l)

          # Check for recent attacks (high rate of drops)
          RECENT_DROPS=$(journalctl -k --since="5 minutes ago" | grep -c "FIREWALL-DROP" || echo 0)

          # Log status
          echo "[$TIMESTAMP] Connections: $CONNECTIONS, Rules: $RULES, Recent drops: $RECENT_DROPS" >> "$LOG_FILE"

          # Alert on suspicious activity
          if [ "$RECENT_DROPS" -gt 50 ]; then
            logger -t firewall-monitor "HIGH: $RECENT_DROPS firewall drops in last 5 minutes"
            echo "[$TIMESTAMP] ALERT - High drop rate: $RECENT_DROPS drops" >> "$LOG_FILE"
          fi

          # Clean up old log entries (keep last 1000 lines)
          tail -1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
        '';
      };
    };

    # Timer for firewall monitoring
    systemd.timers.firewall-monitor = {
      description = "Firewall Monitor Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/5"; # Every 5 minutes
        Persistent = true;
      };
    };
  };
}
