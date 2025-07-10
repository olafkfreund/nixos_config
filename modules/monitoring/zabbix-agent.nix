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
    services.zabbixAgent = {
      enable = true;
      server = cfg.serverHost;  # Legacy option for compatibility
      
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
      };
    };

    # Create zabbix user for agent (only if not already created by server)
    users.users.zabbix = mkIf (!config.services.zabbix-monitoring.server.enable) {
      isSystemUser = true;
      group = "zabbix";
      shell = pkgs.bash;
      extraGroups = mkIf config.virtualisation.docker.enable [ "docker" ];
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
        systemctl reload zabbixAgent 2>/dev/null || true
      '';
    };
  };
}