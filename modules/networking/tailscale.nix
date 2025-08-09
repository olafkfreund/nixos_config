# Tailscale VPN Configuration Module
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.networking.tailscale;
in
{
  options.networking.tailscale = {
    enable = mkEnableOption "Enable Tailscale VPN";

    authKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to file containing Tailscale auth key";
    };

    exitNode = mkOption {
      type = types.bool;
      default = false;
      description = "Enable this host as a Tailscale exit node";
    };

    subnet = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Subnet to advertise (e.g., '192.168.1.0/24')";
    };

    hostname = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Custom hostname for this Tailscale node";
    };

    acceptRoutes = mkOption {
      type = types.bool;
      default = true;
      description = "Accept routes from other Tailscale nodes";
    };

    acceptDns = mkOption {
      type = types.bool;
      default = true;
      description = "Accept DNS configuration from Tailscale";
    };

    ssh = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Tailscale SSH";
    };

    shields = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Tailscale shields (firewall)";
    };

    extraUpFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional flags to pass to tailscale up";
    };

    useRoutingFeatures = mkOption {
      type = types.enum [ "none" "client" "server" "both" ];
      default = "client";
      description = "Enable routing features for subnet routing or exit node";
    };

    interfaceName = mkOption {
      type = types.str;
      default = "tailscale0";
      description = "Name of the Tailscale network interface";
    };

    port = mkOption {
      type = types.port;
      default = 41641;
      description = "UDP port for Tailscale";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall for Tailscale";
    };
  };

  config = mkIf cfg.enable {
    # Enable Tailscale service
    services.tailscale = {
      enable = true;
      port = cfg.port;
      interfaceName = cfg.interfaceName;
      openFirewall = cfg.openFirewall;
      useRoutingFeatures = cfg.useRoutingFeatures;
    };

    # Tailscale up service with authentication
    systemd.services.tailscale-autoconnect = {
      description = "Automatic connection to Tailscale";
      after = [ "network-pre.target" "tailscale.service" ];
      wants = [ "network-pre.target" "tailscale.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "tailscale-autoconnect" ''
          #!/bin/bash

          # Wait for tailscaled to be ready
          sleep 2

          # Check if already authenticated
          if ${pkgs.tailscale}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -e '.BackendState == "Running"' >/dev/null 2>&1; then
            echo "Tailscale already authenticated and running"
            exit 0
          fi

          # Build tailscale up command
          UP_ARGS=""

          ${optionalString (cfg.authKeyFile != null) ''
            if [ -f "${cfg.authKeyFile}" ]; then
              AUTH_KEY=$(cat "${cfg.authKeyFile}")
              UP_ARGS="$UP_ARGS --authkey=$AUTH_KEY"
            else
              echo "Warning: Auth key file ${cfg.authKeyFile} not found"
            fi
          ''}

          ${optionalString cfg.exitNode ''
            UP_ARGS="$UP_ARGS --advertise-exit-node"
          ''}

          ${optionalString (cfg.subnet != null) ''
            UP_ARGS="$UP_ARGS --advertise-routes=${cfg.subnet}"
          ''}

          ${optionalString (cfg.hostname != null) ''
            UP_ARGS="$UP_ARGS --hostname=${cfg.hostname}"
          ''}

          ${optionalString cfg.acceptRoutes ''
            UP_ARGS="$UP_ARGS --accept-routes"
          ''}

          ${optionalString cfg.acceptDns ''
            UP_ARGS="$UP_ARGS --accept-dns"
          ''}

          ${optionalString cfg.ssh ''
            UP_ARGS="$UP_ARGS --ssh"
          ''}

          ${optionalString cfg.shields ''
            UP_ARGS="$UP_ARGS --shields-up"
          ''}

          # Add extra flags
          ${concatStringsSep "\n" (map (flag: ''
              UP_ARGS="$UP_ARGS ${flag}"
            '')
            cfg.extraUpFlags)}

          echo "Connecting to Tailscale with args: $UP_ARGS"
          ${pkgs.tailscale}/bin/tailscale up $UP_ARGS

          # Wait a moment and check status
          sleep 3
          ${pkgs.tailscale}/bin/tailscale status
        '';
      };
    };

    # Tailscale status monitoring service
    systemd.services.tailscale-monitor = {
      description = "Tailscale Status Monitor";
      after = [ "tailscale-autoconnect.service" ];
      wants = [ "tailscale-autoconnect.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Restart = "always";
        RestartSec = "30s";
        ExecStart = pkgs.writeShellScript "tailscale-monitor" ''
          #!/bin/bash

          LOG_FILE="/var/log/tailscale/monitor.log"
          mkdir -p "$(dirname "$LOG_FILE")"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1

          echo "[$(date)] Starting Tailscale monitor..."

          while true; do
            # Check Tailscale status
            if ! ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
              echo "[$(date)] Tailscale not responding, attempting restart..."
              systemctl restart tailscale.service
              sleep 10
              systemctl restart tailscale-autoconnect.service
            else
              # Log status periodically
              STATUS=$(${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null || echo '{"BackendState":"Unknown"}')
              BACKEND_STATE=$(echo "$STATUS" | ${pkgs.jq}/bin/jq -r '.BackendState // "Unknown"')

              if [ "$BACKEND_STATE" != "Running" ]; then
                echo "[$(date)] Tailscale backend state: $BACKEND_STATE"
                if [ "$BACKEND_STATE" = "NeedsLogin" ]; then
                  echo "[$(date)] Tailscale needs authentication, restarting autoconnect..."
                  systemctl restart tailscale-autoconnect.service
                fi
              fi
            fi

            sleep 300  # Check every 5 minutes
          done
        '';
      };
    };

    # Tailscale health check script
    environment.systemPackages = with pkgs; [
      tailscale
      (writeShellScriptBin "tailscale-status" ''
        #!/bin/bash

        echo "=== Tailscale Status ==="
        ${pkgs.tailscale}/bin/tailscale status || echo "Tailscale not running"

        echo ""
        echo "=== Tailscale Ping Test ==="
        # Test connectivity to other known Tailscale nodes
        NODES=$(${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.Peer[].TailscaleIPs[0]' 2>/dev/null || echo "")

        if [ -n "$NODES" ]; then
          for NODE in $NODES; do
            if ping -c 1 -W 2 "$NODE" >/dev/null 2>&1; then
              echo "✓ $NODE - reachable"
            else
              echo "✗ $NODE - unreachable"
            fi
          done
        else
          echo "No other Tailscale nodes found"
        fi

        echo ""
        echo "=== Tailscale Service Status ==="
        systemctl status tailscale.service --no-pager -l

        echo ""
        echo "=== Tailscale Logs (last 10 lines) ==="
        journalctl -u tailscale.service -n 10 --no-pager
      '')

      (writeShellScriptBin "tailscale-reconnect" ''
        #!/bin/bash

        echo "Reconnecting Tailscale..."
        systemctl restart tailscale.service
        sleep 5
        systemctl restart tailscale-autoconnect.service

        echo "Waiting for connection..."
        sleep 10

        echo "Current status:"
        ${pkgs.tailscale}/bin/tailscale status
      '')
    ];

    # Firewall configuration
    networking.firewall = mkIf cfg.openFirewall {
      allowedUDPPorts = [ cfg.port ];
      trustedInterfaces = [ cfg.interfaceName ];

      # Allow Tailscale subnet if specified
      extraCommands = mkIf (cfg.subnet != null) ''
        # Allow traffic from Tailscale subnet
        iptables -A INPUT -s ${cfg.subnet} -j ACCEPT
        iptables -A FORWARD -s ${cfg.subnet} -j ACCEPT
        iptables -A FORWARD -d ${cfg.subnet} -j ACCEPT
      '';

      extraStopCommands = mkIf (cfg.subnet != null) ''
        # Remove Tailscale subnet rules
        iptables -D INPUT -s ${cfg.subnet} -j ACCEPT 2>/dev/null || true
        iptables -D FORWARD -s ${cfg.subnet} -j ACCEPT 2>/dev/null || true
        iptables -D FORWARD -d ${cfg.subnet} -j ACCEPT 2>/dev/null || true
      '';
    };

    # Enable IP forwarding if using routing features
    boot.kernel.sysctl = mkIf (cfg.useRoutingFeatures == "server" || cfg.useRoutingFeatures == "both" || cfg.exitNode || cfg.subnet != null) {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    # Create directories
    systemd.tmpfiles.rules = [
      "d /var/log/tailscale 0755 root root -"
    ];

    # Ensure tailscaled starts early in boot process
    systemd.services.tailscale.wantedBy = mkForce [ "multi-user.target" ];
    systemd.services.tailscale.after = mkForce [ "network-pre.target" ];
  };
}
