# Network Performance Tuning Module
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.networking.performanceTuning;
in
{
  options.networking.performanceTuning = {
    enable = mkEnableOption "Enable network performance tuning";

    profile = mkOption {
      type = types.enum [ "latency" "throughput" "balanced" ];
      default = "balanced";
      description = "Network optimization profile";
    };

    tcpOptimization = {
      enable = mkEnableOption "Enable TCP optimization";

      congestionControl = mkOption {
        type = types.str;
        default = "bbr";
        description = "TCP congestion control algorithm";
      };

      windowScaling = mkOption {
        type = types.bool;
        default = true;
        description = "Enable TCP window scaling";
      };

      fastOpen = mkOption {
        type = types.bool;
        default = true;
        description = "Enable TCP Fast Open";
      };

      lowLatency = mkOption {
        type = types.bool;
        default = false;
        description = "Enable low latency TCP settings";
      };
    };

    bufferOptimization = {
      enable = mkEnableOption "Enable buffer optimization";

      receiveBuffer = mkOption {
        type = types.int;
        default = 16777216; # 16MB
        description = "Maximum receive buffer size";
      };

      sendBuffer = mkOption {
        type = types.int;
        default = 16777216; # 16MB
        description = "Maximum send buffer size";
      };

      autotuning = mkOption {
        type = types.bool;
        default = true;
        description = "Enable buffer autotuning";
      };
    };

    interHostOptimization = {
      enable = mkEnableOption "Enable inter-host communication optimization";

      hosts = mkOption {
        type = types.listOf types.str;
        default = [ "p620" "p510" "razer" ];
        description = "Hosts to optimize communication between";
      };

      jumboFrames = mkOption {
        type = types.bool;
        default = false;
        description = "Enable jumbo frames for inter-host communication";
      };

      routeOptimization = mkOption {
        type = types.bool;
        default = true;
        description = "Enable route optimization";
      };
    };

    dnsOptimization = {
      enable = mkEnableOption "Enable DNS optimization";

      caching = mkOption {
        type = types.bool;
        default = true;
        description = "Enable DNS caching";
      };

      parallelQueries = mkOption {
        type = types.bool;
        default = true;
        description = "Enable parallel DNS queries";
      };

      customServers = mkOption {
        type = types.listOf types.str;
        default = [ "1.1.1.1" "8.8.8.8" ];
        description = "Custom DNS servers for better performance";
      };
    };

    monitoringOptimization = {
      enable = mkEnableOption "Enable monitoring traffic optimization";

      compression = mkOption {
        type = types.bool;
        default = true;
        description = "Enable monitoring data compression";
      };

      batchingInterval = mkOption {
        type = types.int;
        default = 10; # seconds
        description = "Metrics batching interval";
      };

      prioritization = mkOption {
        type = types.bool;
        default = true;
        description = "Prioritize monitoring traffic";
      };
    };
  };

  config = mkIf cfg.enable {
    # Network Performance Optimization Service
    systemd.services.network-performance-optimizer = {
      description = "Network Performance Optimization Service";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      # Add proper PATH for required tools
      path = with pkgs; [
        iproute2 # ip, tc commands
        inetutils # ping command
        systemd # systemctl command
        coreutils # basic utilities
        gawk # awk command
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        ExecStart = pkgs.writeShellScript "network-performance-optimizer" ''
          #!/bin/bash

          LOG_FILE="/var/log/network-tuning/optimizer.log"
          mkdir -p "$(dirname "$LOG_FILE")"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1

          echo "[$(date)] Starting network performance optimization..."
          echo "[$(date)] Profile: ${cfg.profile}"

          # TCP optimization
          ${optionalString cfg.tcpOptimization.enable ''
            echo "[$(date)] Applying TCP optimizations..."

            # Set congestion control algorithm
            echo "${cfg.tcpOptimization.congestionControl}" > /proc/sys/net/ipv4/tcp_congestion_control
            echo "[$(date)] TCP congestion control set to ${cfg.tcpOptimization.congestionControl}"

            # TCP window scaling
            echo ${
              if cfg.tcpOptimization.windowScaling
              then "1"
              else "0"
            } > /proc/sys/net/ipv4/tcp_window_scaling

            # TCP Fast Open
            echo ${
              if cfg.tcpOptimization.fastOpen
              then "3"
              else "0"
            } > /proc/sys/net/ipv4/tcp_fastopen

            ${optionalString cfg.tcpOptimization.lowLatency ''
              # Low latency TCP settings
              echo 1 > /proc/sys/net/ipv4/tcp_low_latency
              echo 1 > /proc/sys/net/ipv4/tcp_no_delay_ack
              echo 0 > /proc/sys/net/ipv4/tcp_slow_start_after_idle
            ''}

            # Profile-specific TCP settings
            ${
              if cfg.profile == "latency"
              then ''
                echo 1 > /proc/sys/net/ipv4/tcp_timestamps
                echo 1 > /proc/sys/net/ipv4/tcp_sack
                echo 1 > /proc/sys/net/ipv4/tcp_fack
                echo 0 > /proc/sys/net/ipv4/tcp_tw_recycle
                echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
                echo "[$(date)] Applied latency-optimized TCP settings"
              ''
              else if cfg.profile == "throughput"
              then ''
                echo 1 > /proc/sys/net/ipv4/tcp_timestamps
                echo 1 > /proc/sys/net/ipv4/tcp_sack
                echo 1 > /proc/sys/net/ipv4/tcp_fack
                echo 262144 > /proc/sys/net/core/netdev_max_backlog
                echo "[$(date)] Applied throughput-optimized TCP settings"
              ''
              else ''
                echo 1 > /proc/sys/net/ipv4/tcp_timestamps
                echo 1 > /proc/sys/net/ipv4/tcp_sack
                echo 1 > /proc/sys/net/ipv4/tcp_fack
                echo "[$(date)] Applied balanced TCP settings"
              ''
            }
          ''}

          # Buffer optimization
          ${optionalString cfg.bufferOptimization.enable ''
            echo "[$(date)] Optimizing network buffers..."

            # Set buffer sizes
            echo ${toString cfg.bufferOptimization.receiveBuffer} > /proc/sys/net/core/rmem_max
            echo ${toString cfg.bufferOptimization.sendBuffer} > /proc/sys/net/core/wmem_max

            ${optionalString cfg.bufferOptimization.autotuning ''
              # Enable autotuning
              echo "4096 87380 ${toString cfg.bufferOptimization.receiveBuffer}" > /proc/sys/net/ipv4/tcp_rmem
              echo "4096 65536 ${toString cfg.bufferOptimization.sendBuffer}" > /proc/sys/net/ipv4/tcp_wmem
              echo "[$(date)] Network buffer autotuning enabled"
            ''}
          ''}

          # Inter-host optimization
          ${optionalString cfg.interHostOptimization.enable ''
            echo "[$(date)] Optimizing inter-host communication..."

            ${optionalString cfg.interHostOptimization.routeOptimization ''
              # Optimize routes to known hosts
              ${concatStringsSep "\n" (map (host: ''
                  if ping -c 1 -W 1 ${host} &>/dev/null; then
                    # Get current route
                    ROUTE_INFO=$(${pkgs.iproute2}/bin/ip route get ${host} 2>/dev/null | head -1)
                    if [ -n "$ROUTE_INFO" ]; then
                      echo "[$(date)] Route to ${host}: $ROUTE_INFO"

                      # Optimize route metrics if needed
                      INTERFACE=$(echo "$ROUTE_INFO" | ${pkgs.gawk}/bin/awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')
                      if [ -n "$INTERFACE" ]; then
                        # Increase interface queue length for better performance
                        ${pkgs.iproute2}/bin/ip link set dev "$INTERFACE" txqueuelen 10000 2>/dev/null || true
                      fi
                    fi
                  fi
                '')
                cfg.interHostOptimization.hosts)}
            ''}

            ${optionalString cfg.interHostOptimization.jumboFrames ''
              # Enable jumbo frames on appropriate interfaces
              for interface in $(${pkgs.iproute2}/bin/ip link show | grep "state UP" | ${pkgs.gawk}/bin/awk -F: '{print $2}' | grep -E "^(eth|ens|enp)" | tr -d ' '); do
                if [ -n "$interface" ]; then
                  ${pkgs.iproute2}/bin/ip link set dev "$interface" mtu 9000 2>/dev/null || true
                  echo "[$(date)] Jumbo frames enabled on $interface"
                fi
              done
            ''}
          ''}

          # DNS optimization
          ${optionalString cfg.dnsOptimization.enable ''
            echo "[$(date)] Optimizing DNS performance..."

            ${optionalString cfg.dnsOptimization.caching ''
                  # Configure systemd-resolved for better caching
                  if systemctl is-active systemd-resolved &>/dev/null; then
                    mkdir -p /etc/systemd/resolved.conf.d
                    cat > /etc/systemd/resolved.conf.d/performance.conf << EOF
              [Resolve]
              DNS=${concatStringsSep " " cfg.dnsOptimization.customServers}
              Cache=yes
              CacheFromLocalhost=yes
              MulticastDNS=yes
              LLMNR=yes
              EOF
                    systemctl reload-or-restart systemd-resolved
                    echo "[$(date)] DNS caching optimized"
                  fi
            ''}
          ''}

          # Monitoring traffic optimization
          ${optionalString cfg.monitoringOptimization.enable ''
            echo "[$(date)] Optimizing monitoring traffic..."

            ${optionalString cfg.monitoringOptimization.prioritization ''
              # Set up traffic prioritization for monitoring
              tc qdisc add dev lo root handle 1: htb default 30 2>/dev/null || true
              tc class add dev lo parent 1: classid 1:1 htb rate 1gbit 2>/dev/null || true
              tc class add dev lo parent 1:1 classid 1:10 htb rate 100mbit ceil 1gbit prio 1 2>/dev/null || true  # High priority
              tc class add dev lo parent 1:1 classid 1:20 htb rate 500mbit ceil 1gbit prio 2 2>/dev/null || true  # Medium priority
              tc class add dev lo parent 1:1 classid 1:30 htb rate 300mbit ceil 1gbit prio 3 2>/dev/null || true  # Default

              # Prioritize monitoring ports
              tc filter add dev lo protocol ip parent 1:0 prio 1 u32 match ip dport 9090 0xffff flowid 1:10 2>/dev/null || true  # Prometheus
              tc filter add dev lo protocol ip parent 1:0 prio 1 u32 match ip dport 3001 0xffff flowid 1:10 2>/dev/null || true  # Grafana
              tc filter add dev lo protocol ip parent 1:0 prio 1 u32 match ip dport 9093 0xffff flowid 1:10 2>/dev/null || true  # Alertmanager
              tc filter add dev lo protocol ip parent 1:0 prio 2 u32 match ip dport 9100 0xffff flowid 1:20 2>/dev/null || true  # Node exporter

              echo "[$(date)] Monitoring traffic prioritization configured"
            ''}
          ''}

          echo "[$(date)] Network performance optimization completed"
        '';
      };
    };

    # Network Performance Monitor
    systemd.services.network-performance-monitor = {
      description = "Network Performance Monitor";
      after = [ "network-performance-optimizer.service" ];
      wants = [ "network-performance-optimizer.service" ];
      wantedBy = [ "multi-user.target" ];

      # Add proper PATH to avoid "command not found" errors
      path = with pkgs; [
        gawk # awk command
        iproute2 # ss, ip commands
        coreutils # basic utilities
        gnugrep # grep command
        inetutils # ping command
        time # time command
      ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Restart = "always";
        RestartSec = "30s";
        ExecStart = pkgs.writeShellScript "network-performance-monitor" ''
          #!/bin/bash

          METRICS_FILE="/var/lib/network-tuning/metrics.json"
          mkdir -p "$(dirname "$METRICS_FILE")"

          while true; do
            TIMESTAMP=$(date -Iseconds)

            # Network interface statistics
            NETWORK_STATS=$(cat /proc/net/dev | tail -n +3 | while read line; do
              IFACE=$(echo "$line" | ${pkgs.gawk}/bin/awk -F: '{print $1}' | tr -d ' ')
              if [[ "$IFACE" != "lo" ]]; then
                RX_BYTES=$(echo "$line" | ${pkgs.gawk}/bin/awk '{print $2}')
                TX_BYTES=$(echo "$line" | ${pkgs.gawk}/bin/awk '{print $10}')
                echo "\"$IFACE\": {\"rx_bytes\": $RX_BYTES, \"tx_bytes\": $TX_BYTES}"
              fi
            done | paste -sd, -)

            # TCP connection statistics
            TCP_STATS=$(${pkgs.iproute2}/bin/ss -s | grep TCP | head -1 | ${pkgs.gawk}/bin/awk '{print $2}')

            # Network latency to configured hosts
            LATENCY_STATS=$(
              {
                ${concatStringsSep "\n" (map (host: ''
              LATENCY=$(ping -c 1 -W 1 ${host} 2>/dev/null | grep "time=" | sed 's/.*time=//;s/ ms//' || echo "timeout")
              echo "\"${host}\": \"$LATENCY\""
            '')
            cfg.interHostOptimization.hosts)}
              } | paste -sd, -
            )

            # DNS resolution time
            DNS_TIME=$(time (nslookup google.com >/dev/null 2>&1) 2>&1 | grep real | ${pkgs.gawk}/bin/awk '{print $2}' | sed 's/[^0-9.]//g' || echo "0")

            # Congestion control algorithm
            CONGESTION_CONTROL=$(cat /proc/sys/net/ipv4/tcp_congestion_control)

            # Create metrics JSON
            cat > "$METRICS_FILE" << EOF
            {
              "timestamp": "$TIMESTAMP",
              "interfaces": { $NETWORK_STATS },
              "tcp_connections": $TCP_STATS,
              "latency": { $LATENCY_STATS },
              "dns_resolution_time": "$DNS_TIME",
              "congestion_control": "$CONGESTION_CONTROL",
              "profile": "${cfg.profile}"
            }
          EOF

            sleep 60
          done
        '';
      };
    };

    # Network tuning based on profile
    boot.kernel.sysctl = mkIf cfg.enable {
      # Core network settings (only set if not already defined by other modules)
      "net.core.rmem_max" = mkDefault cfg.bufferOptimization.receiveBuffer;
      "net.core.wmem_max" = mkDefault cfg.bufferOptimization.sendBuffer;
      "net.core.netdev_max_backlog" = mkDefault (
        if cfg.profile == "throughput"
        then 30000
        else 5000
      );
      "net.core.netdev_budget" = mkDefault 600;

      # TCP settings
      "net.ipv4.tcp_congestion_control" = mkDefault cfg.tcpOptimization.congestionControl;
      "net.ipv4.tcp_window_scaling" = mkDefault (
        if cfg.tcpOptimization.windowScaling
        then 1
        else 0
      );
      "net.ipv4.tcp_timestamps" = mkDefault 1;
      "net.ipv4.tcp_sack" = mkDefault 1;
      "net.ipv4.tcp_fack" = mkDefault 1;
      "net.ipv4.tcp_fastopen" = mkDefault (
        if cfg.tcpOptimization.fastOpen
        then 3
        else 0
      );

      # Buffer autotuning
      "net.ipv4.tcp_rmem" = mkDefault (
        if cfg.bufferOptimization.autotuning
        then "4096 87380 ${toString cfg.bufferOptimization.receiveBuffer}"
        else "4096 65536 16777216"
      );
      "net.ipv4.tcp_wmem" = mkDefault (
        if cfg.bufferOptimization.autotuning
        then "4096 65536 ${toString cfg.bufferOptimization.sendBuffer}"
        else "4096 65536 16777216"
      );

      # Profile-specific optimizations
      "net.ipv4.tcp_slow_start_after_idle" = mkDefault (
        if cfg.profile == "latency"
        then 0
        else 1
      );
      "net.ipv4.tcp_tw_reuse" = mkDefault (
        if cfg.profile == "latency"
        then 1
        else 0
      );
      "net.ipv4.tcp_fin_timeout" = mkDefault (
        if cfg.profile == "latency"
        then 10
        else 60
      );

      # Connection tracking
      "net.netfilter.nf_conntrack_max" = mkDefault 262144;
      "net.ipv4.ip_local_port_range" = mkDefault "1024 65535";

      # DNS optimization
      "net.ipv4.tcp_keepalive_time" = mkDefault 600;
      "net.ipv4.tcp_keepalive_intvl" = mkDefault 60;
      "net.ipv4.tcp_keepalive_probes" = mkDefault 3;
    };

    # Network performance packages
    environment.systemPackages = with pkgs; [
      iproute2 # ip, tc commands
      ethtool # Ethernet tool
      iperf3 # Network performance testing
      nettools # Basic network tools
      tcpdump # Packet capture
      wireshark-cli # Network analysis
      mtr # Network diagnostic tool
      bandwhich # Bandwidth monitoring
    ];

    # DNS configuration
    services.resolved = mkIf cfg.dnsOptimization.enable {
      enable = true;
      dnssec = "false"; # Disable for performance
      llmnr = "true";
      fallbackDns = cfg.dnsOptimization.customServers;
      extraConfig = ''
        Cache=yes
        CacheFromLocalhost=yes
        DNSStubListener=yes
        MulticastDNS=yes
      '';
    };

    # Create directories
    systemd.tmpfiles.rules = [
      "d /var/lib/network-tuning 0755 root root -"
      "d /var/log/network-tuning 0755 root root -"
    ];
  };
}
