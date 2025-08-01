# n8n Workflow Automation Configuration
# Production setup with PostgreSQL database for DEX5550 monitoring server
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  # PostgreSQL database configuration for n8n
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_15;
    
    # Configure authentication for n8n user
    authentication = pkgs.lib.mkOverride 10 ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             postgres                                peer
      local   all             all                                     peer
      host    all             all             127.0.0.1/32            scram-sha-256
      host    all             all             ::1/128                 scram-sha-256
      local   n8n             n8n                                     peer
      host    n8n             n8n             127.0.0.1/32            scram-sha-256
    '';
    
    # Ensure n8n database and user exist
    ensureDatabases = [ "n8n" ];
    ensureUsers = [
      {
        name = "n8n";
        ensureDBOwnership = true;
      }
    ];
    
    # PostgreSQL performance tuning for n8n workloads
    settings = {
      # Memory configuration
      shared_buffers = "256MB";
      effective_cache_size = "1GB";
      work_mem = "16MB";
      maintenance_work_mem = "128MB";
      
      # Checkpoint and WAL configuration
      wal_buffers = "16MB";
      checkpoint_completion_target = "0.9";
      
      # Query planner
      random_page_cost = "1.1";  # SSD optimization
      effective_io_concurrency = "200";
      
      # Logging for monitoring
      log_destination = "stderr";
      logging_collector = true;
      log_directory = "/var/log/postgresql";
      log_filename = "postgresql-%Y-%m-%d_%H%M%S.log";
      log_min_duration_statement = "1000";  # Log slow queries (1s+)
    };
  };

  # n8n workflow automation service
  services.n8n = {
    enable = true;
    openFirewall = false;  # We'll manage firewall manually
    
    settings = {
      # Server configuration
      N8N_HOST = "0.0.0.0";
      N8N_PORT = 5678;
      N8N_PROTOCOL = "http";
      N8N_LISTEN_ADDRESS = "0.0.0.0";
      
      # Database configuration (PostgreSQL)
      DB_TYPE = "postgresdb";
      DB_POSTGRESDB_HOST = "127.0.0.1";
      DB_POSTGRESDB_PORT = 5432;
      DB_POSTGRESDB_DATABASE = "n8n";
      DB_POSTGRESDB_USER = "n8n";
      DB_POSTGRESDB_SCHEMA = "public";
      DB_POSTGRESDB_SSL_ENABLED = false;  # Local connection
      
      # Execution configuration
      N8N_EXECUTE_IN_PROCESS = true;  # Execute workflows in main process
      EXECUTIONS_TIMEOUT = 3600;      # 1 hour timeout
      EXECUTIONS_TIMEOUT_MAX = 7200;  # 2 hour max timeout
      EXECUTIONS_DATA_SAVE_ON_ERROR = "all";
      EXECUTIONS_DATA_SAVE_ON_SUCCESS = "all";
      EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS = true;
      
      # Security and user management
      N8N_USER_MANAGEMENT_JWT_SECRET = "n8n-jwt-secret-change-me";
      N8N_ENCRYPTION_KEY = "n8n-encryption-key-change-me-32chars";
      N8N_USER_MANAGEMENT_DISABLED = false;  # Enable user management
      
      # Webhook configuration
      N8N_WEBHOOK_URL = "https://home.freundcloud.com/n8n";
      WEBHOOK_URL = "https://home.freundcloud.com/n8n";
      
      # Logging and diagnostics
      N8N_LOG_LEVEL = "info";
      N8N_LOG_OUTPUT = "console,file";
      N8N_LOG_FILE_LOCATION = "/var/lib/n8n/logs/n8n.log";
      N8N_DIAGNOSTICS_ENABLED = false;  # Disable telemetry
      
      # Performance and resource limits
      N8N_MAX_EXECUTION_TIMEOUT = 7200;  # 2 hours
      N8N_BINARY_DATA_TTL = 2880;        # 48 hours in minutes
      N8N_BINARY_DATA_MANAGER_MODE = "filesystem";
      
      # Editor and UI configuration
      N8N_DISABLE_UI = false;
      N8N_HIDE_USAGE_PAGE = true;
      N8N_TEMPLATES_ENABLED = true;
      N8N_TEMPLATES_HOST = "https://api.n8n.io/api/";
      
      # External service integrations
      N8N_VERSION_NOTIFICATIONS_ENABLED = false;
      N8N_DEFAULT_LOCALE = "en";
      N8N_METRICS = true;  # Enable metrics for Prometheus
      
      # File system paths
      N8N_USER_FOLDER = "/var/lib/n8n";
      N8N_NODES_BASE_DIR = "/var/lib/n8n/nodes";
      
      # Development and debugging
      NODE_ENV = "production";
    };
  };

  # Create necessary directories
  systemd.tmpfiles.rules = [
    "d /var/lib/n8n/logs 0755 n8n n8n -"
    "d /var/lib/n8n/nodes 0755 n8n n8n -"
    "d /var/log/postgresql 0755 postgres postgres -"
  ];

  # Configure n8n user and group
  users.users.n8n = {
    isSystemUser = true;
    group = "n8n";
    home = "/var/lib/n8n";
    createHome = true;
    extraGroups = [ "postgres" ];
  };
  
  users.groups.n8n = {};

  # Firewall configuration for internal network access
  networking.firewall.interfaces."eno1" = {
    allowedTCPPorts = [
      5678  # n8n web interface (internal network only)
    ];
  };

  # Traefik reverse proxy configuration for n8n
  services.traefik.dynamicConfigOptions.http = {
    # Add n8n router to existing routers
    routers = {
      n8n = {
        rule = "Host(`home.freundcloud.com`) && PathPrefix(`/n8n`)";
        middlewares = [ "n8n-stripprefix" "n8n-headers" "secure-headers" ];
        service = "n8n";
        tls.certResolver = "letsencrypt";
      };
    };
    
    # Add n8n-specific middlewares to existing middlewares
    middlewares = {
      n8n-stripprefix = {
        stripPrefix.prefixes = [ "/n8n" ];
      };
      n8n-headers = {
        headers = {
          customRequestHeaders = {
            "X-Forwarded-Proto" = "https";
            "X-Forwarded-Host" = "home.freundcloud.com";
            "X-Forwarded-Prefix" = "/n8n";
          };
        };
      };
    };
    
    # Add n8n service to existing services
    services = {
      n8n = {
        loadBalancer.servers = [{
          url = "http://127.0.0.1:5678";
        }];
      };
    };
  };

  # PostgreSQL backup configuration
  services.postgresqlBackup = {
    enable = true;
    databases = [ "n8n" ];
    compression = "gzip";
    compressionLevel = 6;
    location = "/var/backup/postgresql";
    startAt = "*-*-* 03:00:00";  # Daily backup at 3 AM
  };

  # Monitoring integration - Prometheus scraping for n8n metrics
  services.prometheus.scrapeConfigs = lib.mkAfter [
    {
      job_name = "n8n";
      static_configs = [
        {
          targets = [ "127.0.0.1:5678" ];
          labels = {
            instance = "dex5550";
            service = "n8n";
          };
        }
      ];
      metrics_path = "/metrics";
      scrape_interval = "30s";
    }
  ];

  # Log rotation for n8n logs
  services.logrotate.settings = {
    "/var/lib/n8n/logs/n8n.log" = {
      frequency = "daily";
      rotate = 14;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      create = "644 n8n n8n";
      postrotate = "systemctl reload n8n.service";
    };
    "/var/log/postgresql/*.log" = {
      frequency = "daily";
      rotate = 7;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      create = "640 postgres postgres";
      postrotate = "systemctl reload postgresql.service";
    };
  };

  # Systemd service overrides for better reliability
  systemd.services.n8n = {
    wants = [ "postgresql.service" ];
    after = [ "postgresql.service" "network-online.target" ];
    
    serviceConfig = {
      # Resource limits for monitoring server
      MemoryMax = "1G";
      CPUQuota = "100%";  # Allow full CPU usage when needed
      
      # Security hardening
      NoNewPrivileges = lib.mkForce true;
      ProtectSystem = "strict";
      ProtectHome = lib.mkForce "read-only";
      ReadWritePaths = [ "/var/lib/n8n" ];
      
      # Restart policy
      Restart = "always";
      RestartSec = "10s";
      
      # Health monitoring
      WatchdogSec = "300s";  # 5-minute watchdog timeout
    };
    
    # Health check script
    preStart = ''
      # Wait for PostgreSQL to be ready
      until ${pkgs.postgresql}/bin/pg_isready -h 127.0.0.1 -p 5432 -U n8n -d n8n; do
        echo "Waiting for PostgreSQL to be ready..."
        sleep 2
      done
      echo "PostgreSQL is ready, starting n8n..."
    '';
  };

  # Environment packages for n8n workflows
  environment.systemPackages = with pkgs; [
    # HTTP tools for workflow testing
    curl
    httpie
    jq
    
    # Database tools
    postgresql
    
    # Process monitoring
    htop
    iotop
  ];
}