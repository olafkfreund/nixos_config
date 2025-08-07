{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.monitoring;

  # Loki configuration

  # Minimal Loki configuration that works with current version
  lokiConfigFile = pkgs.writeText "loki.yaml" ''
    auth_enabled: false

    server:
      http_listen_port: ${toString cfg.network.lokiPort}
      grpc_listen_port: ${toString cfg.network.lokiGrpcPort}
      log_level: info

    common:
      path_prefix: /var/lib/loki
      storage:
        filesystem:
          chunks_directory: /var/lib/loki/chunks
          rules_directory: /var/lib/loki/rules
      replication_factor: 1
      ring:
        instance_addr: 127.0.0.1
        kvstore:
          store: inmemory

    query_range:
      results_cache:
        cache:
          embedded_cache:
            enabled: true
            max_size_mb: 100

    schema_config:
      configs:
        - from: 2020-10-24
          store: tsdb
          object_store: filesystem
          schema: v13
          index:
            prefix: index_
            period: 24h

    limits_config:
      retention_period: ${cfg.logRetention}
      ingestion_rate_mb: 4
      ingestion_burst_size_mb: 6
      max_streams_per_user: 10000
      max_line_size: 256000
      max_entries_limit_per_query: 5000

    ingester:
      lifecycler:
        address: 127.0.0.1
        ring:
          kvstore:
            store: inmemory
          replication_factor: 1
      chunk_idle_period: 1h
      max_chunk_age: 1h
      chunk_target_size: 1048576
      chunk_retain_period: 30s

    storage_config:
      tsdb_shipper:
        active_index_directory: /var/lib/loki/tsdb-shipper-active
        cache_location: /var/lib/loki/tsdb-shipper-cache
        cache_ttl: 24h
      filesystem:
        directory: /var/lib/loki/chunks
  '';

in
{
  config = mkIf (cfg.enable && cfg.features.logging && (cfg.mode == "server" || cfg.mode == "standalone")) {
    # Loki service
    systemd.services.loki = {
      description = "Loki log aggregation system";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        User = "loki";
        Group = "loki";
        ExecStart = "${pkgs.grafana-loki}/bin/loki -config.file=${lokiConfigFile}";
        Restart = "always";
        RestartSec = "10s";

        # Security settings
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/loki" "/var/log/loki" ];

        # Resource limits
        MemoryMax = "512M";
        CPUQuota = "50%";
      };

      preStart = ''
        # Create necessary directories
        mkdir -p /var/lib/loki/{chunks,rules,tsdb-shipper-active,tsdb-shipper-cache,retention}
        chown -R loki:loki /var/lib/loki
        chmod -R 755 /var/lib/loki

        # Create log directory
        mkdir -p /var/log/loki
        chown loki:loki /var/log/loki
        chmod 755 /var/log/loki
      '';
    };

    # Create loki user and group
    users.groups.loki = { };
    users.users.loki = {
      isSystemUser = true;
      group = "loki";
      description = "Loki service user";
      home = "/var/lib/loki";
      createHome = false;
    };

    # Create data directories
    systemd.tmpfiles.rules = [
      "d /var/lib/loki 0755 loki loki -"
      "d /var/lib/loki/chunks 0755 loki loki -"
      "d /var/lib/loki/rules 0755 loki loki -"
      "d /var/lib/loki/tsdb-shipper-active 0755 loki loki -"
      "d /var/lib/loki/tsdb-shipper-cache 0755 loki loki -"
      "d /var/lib/loki/retention 0755 loki loki -"
      "d /var/log/loki 0755 loki loki -"
    ];

    # Open firewall ports for Loki
    networking.firewall.allowedTCPPorts = [
      cfg.network.lokiPort
      cfg.network.lokiGrpcPort
    ];

    # Install Loki CLI tools
    environment.systemPackages = with pkgs; [
      grafana-loki
      # logcli is included in grafana-loki package

      # Loki management script
      (pkgs.writeShellScriptBin "loki-status" ''
        echo "Loki Status"
        echo "==========="
        echo "Loki server: http://localhost:${toString cfg.network.lokiPort}"
        echo "Loki gRPC: http://localhost:${toString cfg.network.lokiGrpcPort}"
        echo ""
        echo "Service status:"
        systemctl status loki --no-pager -l || true
        echo ""
        echo "Loki API status:"
        ${pkgs.curl}/bin/curl -s http://localhost:${toString cfg.network.lokiPort}/ready || echo "Loki API: Not available"
        echo ""
        echo "Log retention: ${cfg.logRetention}"
        echo "Data directory: /var/lib/loki"
        echo "Disk usage:"
        du -sh /var/lib/loki/* 2>/dev/null || echo "No data yet"
      '')
    ];
  };
}
