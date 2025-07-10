# Zabbix Server Module
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.zabbix-monitoring.server;
in {
  options.services.zabbix-monitoring.server = {
    enable = mkEnableOption "Enable Zabbix server";
    
    database = {
      type = mkOption {
        type = types.enum ["sqlite" "postgresql" "mysql"];
        default = "sqlite";
        description = "Database type for Zabbix server";
      };
      
      path = mkOption {
        type = types.str;
        default = "/var/lib/zabbix/zabbix.db";
        description = "Path to SQLite database file";
      };
    };
    
    web = {
      enable = mkEnableOption "Enable Zabbix web interface";
      
      port = mkOption {
        type = types.port;
        default = 8080;
        description = "Port for Zabbix web interface";
      };
    };
    
    snmpDevices = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Device name";
          };
          ip = mkOption {
            type = types.str;
            description = "Device IP address";
          };
          community = mkOption {
            type = types.str;
            default = "public";
            description = "SNMP community string";
          };
          template = mkOption {
            type = types.str;
            default = "Template Net Network Generic Device SNMP";
            description = "Zabbix template to use";
          };
        };
      });
      default = [];
      description = "SNMP devices to monitor";
    };
  };

  config = mkIf cfg.enable {
    # Zabbix Server
    services.zabbix-server = {
      enable = true;
      package = pkgs.zabbix.server-sqlite;
      
      database = {
        type = "sqlite3";
        name = cfg.database.path;
      };
      
      settings = {
        ListenPort = 10051;
        ListenIP = "0.0.0.0";
        DBName = cfg.database.path;
        
        # Performance settings for small installation
        StartPollers = 8;
        StartTrappers = 3;
        StartPingers = 3;
        StartDiscoverers = 2;
        StartHTTPPollers = 3;
        StartPreprocessors = 3;
        StartHistoryPollers = 3;
        
        # Cache settings
        CacheSize = "64M";
        HistoryCacheSize = "32M";
        HistoryIndexCacheSize = "16M";
        TrendCacheSize = "16M";
        ValueCacheSize = "32M";
        
        # Timeouts
        Timeout = 30;
        TrapperTimeout = 300;
        UnreachablePeriod = 45;
        UnavailableDelay = 60;
        UnreachableDelay = 15;
        
        # Logging
        LogFile = "/var/log/zabbix/zabbix_server.log";
        LogFileSize = 50;
        DebugLevel = 3;
        
        # SNMP settings
        SNMPTrapperFile = "/tmp/zabbix_traps.tmp";
        StartSNMPTrapper = mkIf (length cfg.snmpDevices > 0) 1;
      };
    };

    # Zabbix Web Interface
    services.zabbix-web = mkIf cfg.web.enable {
      enable = true;
      package = pkgs.zabbix.web-sqlite;
      
      database = {
        type = "sqlite3";
        name = cfg.database.path;
      };
      
      settings = {
        "DB[TYPE]" = "SQLITE3";
        "DB[DATABASE]" = cfg.database.path;
        
        # PHP settings
        "max_execution_time" = "300";
        "memory_limit" = "128M";
        "post_max_size" = "16M";
        "upload_max_filesize" = "8M";
        "max_input_time" = "300";
        "max_input_vars" = "10000";
        "date.timezone" = "Europe/Oslo";
      };
      
      virtualHost = {
        listen = [
          {
            ip = "127.0.0.1";
            port = cfg.web.port;
          }
        ];
      };
    };

    # Create Zabbix user and group
    users.users.zabbix = {
      isSystemUser = true;
      group = "zabbix";
      home = "/var/lib/zabbix";
      createHome = true;
      shell = pkgs.bash;
      extraGroups = mkIf config.virtualisation.docker.enable [ "docker" ];
    };
    
    users.groups.zabbix = {};

    # Database initialization
    systemd.services.zabbix-db-init = {
      description = "Initialize Zabbix SQLite database";
      wantedBy = [ "zabbix-server.service" ];
      before = [ "zabbix-server.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "zabbix";
        Group = "zabbix";
        RemainAfterExit = true;
      };
      script = ''
        if [ ! -f "${cfg.database.path}" ]; then
          echo "Initializing Zabbix SQLite database..."
          
          mkdir -p $(dirname "${cfg.database.path}")
          
          ${pkgs.sqlite}/bin/sqlite3 "${cfg.database.path}" < ${pkgs.zabbix.server-sqlite}/share/zabbix/database/sqlite3/schema.sql
          ${pkgs.sqlite}/bin/sqlite3 "${cfg.database.path}" < ${pkgs.zabbix.server-sqlite}/share/zabbix/database/sqlite3/images.sql
          ${pkgs.sqlite}/bin/sqlite3 "${cfg.database.path}" < ${pkgs.zabbix.server-sqlite}/share/zabbix/database/sqlite3/data.sql
          
          chmod 660 "${cfg.database.path}"
          chown zabbix:zabbix "${cfg.database.path}"
          
          echo "Zabbix database initialized successfully"
        fi
      '';
    };

    # SNMP tools
    environment.systemPackages = with pkgs; [
      zabbix-cli
      net-snmp
      snmp-mibs-downloader
    ];

    # Firewall
    networking.firewall.allowedTCPPorts = [ 10051 cfg.web.port ];

    # Backup service
    systemd.services.zabbix-backup = {
      description = "Backup Zabbix SQLite database";
      serviceConfig = {
        Type = "oneshot";
        User = "zabbix";
        Group = "zabbix";
      };
      script = ''
        backup_dir="/var/lib/zabbix/backups"
        mkdir -p "$backup_dir"
        
        timestamp=$(date +%Y%m%d_%H%M%S)
        backup_file="$backup_dir/zabbix_backup_$timestamp.db"
        
        ${pkgs.sqlite}/bin/sqlite3 "${cfg.database.path}" ".backup '$backup_file'"
        ${pkgs.gzip}/bin/gzip "$backup_file"
        
        find "$backup_dir" -name "zabbix_backup_*.db.gz" -mtime +7 -delete
        
        echo "Backup completed: $backup_file.gz"
      '';
    };

    # Daily backup timer
    systemd.timers.zabbix-backup = {
      description = "Daily Zabbix database backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30min";
      };
    };

    # Log rotation
    services.logrotate.settings.zabbix = {
      files = [ "/var/log/zabbix/*.log" ];
      frequency = "daily";
      rotate = 7;
      compress = true;
      delayCompress = true;
      missingok = true;
      notifempty = true;
      create = "640 zabbix zabbix";
      postrotate = ''
        systemctl reload zabbix-server 2>/dev/null || true
      '';
    };
  };
}