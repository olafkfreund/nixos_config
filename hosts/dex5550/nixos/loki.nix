# Loki Log Aggregation Server Configuration
# Centralized logging for all NixOS hosts
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Loki log aggregation server
  services.loki = {
    enable = true;
    
    configuration = {
      server = {
        http_listen_port = 3100;
        grpc_listen_port = 9096;
        log_level = "info";
      };

      auth_enabled = false;

      ingester = {
        lifecycler = {
          address = "0.0.0.0";
          ring = {
            kvstore = {
              store = "inmemory";
            };
            replication_factor = 1;
          };
        };
        chunk_idle_period = "1h";
        max_chunk_age = "1h";
        chunk_target_size = 1048576;
        chunk_retain_period = "30s";
        max_transfer_retries = 0;
      };

      schema_config = {
        configs = [
          {
            from = "2023-01-01";
            store = "boltdb-shipper";
            object_store = "filesystem";
            schema = "v11";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
      };

      storage_config = {
        boltdb_shipper = {
          active_index_directory = "/var/lib/loki/boltdb-shipper-active";
          cache_location = "/var/lib/loki/boltdb-shipper-cache";
          cache_ttl = "24h";
          shared_store = "filesystem";
        };
        filesystem = {
          directory = "/var/lib/loki/chunks";
        };
      };

      compactor = {
        working_directory = "/var/lib/loki";
        shared_store = "filesystem";
        compaction_interval = "10m";
        retention_enabled = true;
        retention_delete_delay = "2h";
        retention_delete_worker_count = 150;
      };

      limits_config = {
        enforce_metric_name = false;
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
        retention_period = "30d";  # 30 days retention
        ingestion_rate_mb = 4;
        ingestion_burst_size_mb = 6;
        max_line_size = 256000;
        max_streams_per_user = 10000;
        max_global_streams_per_user = 5000;
      };

      chunk_store_config = {
        max_look_back_period = "0s";
      };

      table_manager = {
        retention_deletes_enabled = true;
        retention_period = "30d";
      };

      ruler = {
        storage = {
          type = "local";
          local = {
            directory = "/var/lib/loki/rules";
          };
        };
        rule_path = "/var/lib/loki/rules";
        alertmanager_url = "http://localhost:9093";
        ring = {
          kvstore = {
            store = "inmemory";
          };
        };
        enable_api = true;
      };
    };
  };

  # Create necessary directories
  systemd.tmpfiles.rules = [
    "d /var/lib/loki 0755 loki loki -"
    "d /var/lib/loki/chunks 0755 loki loki -"
    "d /var/lib/loki/boltdb-shipper-active 0755 loki loki -"
    "d /var/lib/loki/boltdb-shipper-cache 0755 loki loki -"
    "d /var/lib/loki/rules 0755 loki loki -"
  ];

  # Firewall ports for Loki are configured in main configuration.nix

  # System packages for debugging
  environment.systemPackages = with pkgs; [
    curl
    jq
  ];

  # Loki user and group
  users.users.loki = {
    isSystemUser = true;
    group = "loki";
    home = "/var/lib/loki";
    createHome = true;
  };
  
  users.groups.loki = {};

  # Systemd service optimizations
  systemd.services.loki = {
    serviceConfig = {
      # Resource limits for monitoring server
      MemoryMax = "2G";
      CPUQuota = "200%";  # Allow up to 2 CPU cores
      
      # Security hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/loki" ];
      
      # Restart policy
      Restart = "always";
      RestartSec = "10s";
      
      # Health monitoring
      WatchdogSec = "300s";
    };
    
    # Wait for filesystem to be ready
    after = [ "local-fs.target" "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}