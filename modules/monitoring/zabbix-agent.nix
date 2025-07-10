# Zabbix Agent Module
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.zabbix-monitoring.agent;
in {
  options.services.zabbix-monitoring.agent = {
    enable = mkEnableOption "Enable Zabbix agent";
    
    serverHost = mkOption {
      type = types.str;
      default = "dex5550";
      description = "Hostname of the Zabbix server";
    };
    
    port = mkOption {
      type = types.port;
      default = 10050;
      description = "Port for Zabbix agent";
    };
    
    hostMetadata = mkOption {
      type = types.str;
      default = "";
      description = "Host metadata for auto-registration";
    };
  };

  config = mkIf cfg.enable {
    # Zabbix Agent 2
    services.zabbix-agent = {
      enable = true;
      package = pkgs.zabbix.agent2;
      
      settings = {
        # Server connection
        Server = cfg.serverHost;
        ServerActive = cfg.serverHost;
        
        # Agent identification
        Hostname = config.networking.hostName;
        HostnameItem = "system.hostname";
        
        # Network settings
        ListenPort = cfg.port;
        ListenIP = "0.0.0.0";
        
        # Performance settings
        BufferSend = 5;
        BufferSize = 100;
        MaxLinesPerSecond = 20;
        
        # Security settings
        AllowRoot = 0;
        User = "zabbix";
        
        # Logging
        LogFile = "/var/log/zabbix/zabbix_agent2.log";
        LogFileSize = 10;
        DebugLevel = 3;
        
        # Timeout settings
        Timeout = 30;
        
        # Auto-registration
        HostMetadata = mkIf (cfg.hostMetadata != "") cfg.hostMetadata;
        
        # Plugin settings for monitoring
        Plugins = {
          "Docker.Endpoint" = "unix:///var/run/docker.sock";
          "SystemRun.LogRemoteCommands" = "1";
        };
      };
    };

    # Create zabbix user for agent
    users.users.zabbix = mkIf (!config.services.zabbix-monitoring.server.enable) {
      isSystemUser = true;
      group = "zabbix";
      shell = pkgs.bash;
    };
    
    users.groups.zabbix = mkIf (!config.services.zabbix-monitoring.server.enable) {};

    # Firewall
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    # Log rotation for agent
    services.logrotate.settings.zabbix-agent = {
      files = [ "/var/log/zabbix/zabbix_agent2.log" ];
      frequency = "daily";
      rotate = 7;
      compress = true;
      delayCompress = true;
      missingok = true;
      notifempty = true;
      create = "640 zabbix zabbix";
      postrotate = ''
        systemctl reload zabbix-agent2 2>/dev/null || true
      '';
    };

    # Add zabbix user to docker group if docker is enabled
    users.users.zabbix.extraGroups = mkIf config.virtualisation.docker.enable [ "docker" ];
  };
}