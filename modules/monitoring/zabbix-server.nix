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
        type = types.enum ["postgresql" "mysql"];
        default = "postgresql";
        description = "Database type for Zabbix server";
      };
      
      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "Database host";
      };
      
      name = mkOption {
        type = types.str;
        default = "zabbix";
        description = "Database name";
      };
      
      user = mkOption {
        type = types.str;
        default = "zabbix";
        description = "Database user";
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
    # Age secret for database password
    age.secrets.zabbix-db-password = {
      file = ../../secrets/zabbix-db-password.age;
      owner = "zabbix";
      group = "zabbix";
      mode = "0400";
    };

    # PostgreSQL database setup
    services.postgresql = {
      enable = true;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = cfg.database.user;
          ensureDBOwnership = true;
        }
      ];
    };

    # Zabbix Server
    services.zabbixServer = {
      enable = true;
      
      database = {
        type = "pgsql";
        host = cfg.database.host;
        name = cfg.database.name;
        user = cfg.database.user;
        passwordFile = "/run/agenix/zabbix-db-password";
        createLocally = false;
      };
      
      settings = {
        ListenPort = 10051;
        ListenIP = "0.0.0.0";
        
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
    services.zabbixWeb = mkIf cfg.web.enable {
      enable = true;
      
      database = {
        type = "pgsql";
        host = cfg.database.host;
        name = cfg.database.name;
        user = cfg.database.user;
        passwordFile = "/run/agenix/zabbix-db-password";
      };
      
      httpd.virtualHost = {
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

    # Database will be automatically initialized by NixOS Zabbix service

    # SNMP tools
    environment.systemPackages = with pkgs; [
      zabbix-cli
      net-snmp
    ];

    # Firewall
    networking.firewall.allowedTCPPorts = [ 10051 cfg.web.port ];

    # Backup service
    systemd.services.zabbix-backup = {
      description = "Backup Zabbix PostgreSQL database";
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        Group = "postgres";
      };
      script = ''
        backup_dir="/var/lib/zabbix/backups"
        mkdir -p "$backup_dir"
        
        timestamp=$(date +%Y%m%d_%H%M%S)
        backup_file="$backup_dir/zabbix_backup_$timestamp.sql"
        
        ${pkgs.postgresql}/bin/pg_dump -h ${cfg.database.host} -U ${cfg.database.user} -d ${cfg.database.name} > "$backup_file"
        ${pkgs.gzip}/bin/gzip "$backup_file"
        
        find "$backup_dir" -name "zabbix_backup_*.sql.gz" -mtime +7 -delete
        
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
        systemctl reload zabbixServer 2>/dev/null || true
      '';
    };
  };
}