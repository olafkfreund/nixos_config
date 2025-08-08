_: {
  services = {
    grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "0.0.0.0";
          http_port = 3000;
          domain = "p510";
          root_url = "http://p510:3000/";
        };
        auth.anonymous = false;
        security = {
          admin_user = "admin";
          admin_password = "$__file{/var/lib/grafana/password}";
        };
      };
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Loki";
            type = "loki";
            url = "http://localhost:3100";
          }
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://localhost:9090";
            isDefault = true;
          }
        ];
      };
    };

    loki = {
      enable = true;
      configuration = {
        server.http_listen_port = 3100;
        auth_enabled = false;
        analytics.reporting_enabled = false;

        ingester = {
          lifecycler = {
            address = "127.0.0.1";
            ring = {
              kvstore.store = "inmemory";
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
              from = "2023-01";
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

        limits_config = {
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
          ingestion_rate_mb = 30;
          ingestion_burst_size_mb = 60;
        };

        chunk_store_config = {
          max_look_back_period = "0s";
        };

        table_manager = {
          retention_deletes_enabled = true;
          retention_period = "672h";
        };

        compactor = {
          working_directory = "/var/lib/loki";
          shared_store = "filesystem";
        };
      };
    };

    prometheus = {
      enable = true;
      port = 9090;

      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" "processes" ];
          port = 9100;
        };
      };

      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            {
              targets = [ "localhost:9100" ];
            }
          ];
        }
        {
          job_name = "plex";
          static_configs = [
            {
              targets = [ "localhost:32400" ];
            }
          ];
          metrics_path = "/metrics";
        }
        {
          job_name = "sonarr";
          static_configs = [
            {
              targets = [ "localhost:8989" ];
            }
          ];
          metrics_path = "/metrics";
        }
        {
          job_name = "radarr";
          static_configs = [
            {
              targets = [ "localhost:7878" ];
            }
          ];
          metrics_path = "/metrics";
        }
        {
          job_name = "tautulli";
          static_configs = [
            {
              targets = [ "localhost:8181" ];
            }
          ];
          metrics_path = "/metrics";
        }
      ];
    };

    promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 28183;
          grpc_listen_port = 0;
        };
        positions = {
          filename = "/tmp/positions.yaml";
        };
        clients = [
          {
            url = "http://127.0.0.1:3100/loki/api/v1/push";
          }
        ];
        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = "p510";
              };
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
            ];
          }
        ];
      };
    };
  };

  # Open required ports in the firewall
  networking.firewall.allowedTCPPorts = [
    3000 # Grafana
    3100 # Loki
    9090 # Prometheus
    9100 # Node Exporter
    28183 # Promtail
  ];

  # Create required directories with correct permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/grafana 0700 grafana grafana -"
    "d /var/lib/loki 0700 loki loki -"
    "d /var/lib/prometheus2 0700 prometheus prometheus -"
  ];
}
