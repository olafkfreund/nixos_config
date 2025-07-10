# Zabbix Monitoring Main Module - Imports and Configuration
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.modules.monitoring.zabbix;
in {
  imports = [
    ./zabbix-server.nix
    ./zabbix-agent.nix
    ./zabbix-grafana.nix
  ];

  options.modules.monitoring.zabbix = {
    enable = mkEnableOption "Enable Zabbix monitoring system";
    
    mode = mkOption {
      type = types.enum ["server" "agent" "both"];
      default = "agent";
      description = "Whether to run as Zabbix server, agent, or both";
    };
    
    serverHost = mkOption {
      type = types.str;
      default = "dex5550";
      description = "Hostname of the Zabbix server";
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
      description = "SNMP devices to monitor (server mode only)";
    };
    
    grafanaIntegration = {
      enable = mkEnableOption "Enable Grafana integration";
    };
  };

  config = mkIf cfg.enable {
    # Enable Zabbix server if mode is server or both
    services.zabbix-monitoring.server = mkIf (cfg.mode == "server" || cfg.mode == "both") {
      enable = true;
      snmpDevices = cfg.snmpDevices;
      web.enable = true;
    };

    # Enable Zabbix agent if mode is agent or both
    services.zabbix-monitoring.agent = mkIf (cfg.mode == "agent" || cfg.mode == "both") {
      enable = true;
      serverHost = cfg.serverHost;
      hostMetadata = "nixos,${config.networking.hostName}";
    };

    # Enable Grafana integration if requested and server mode
    services.zabbix-monitoring.grafana = mkIf (cfg.grafanaIntegration.enable && (cfg.mode == "server" || cfg.mode == "both")) {
      enable = true;
    };

    # Common packages
    environment.systemPackages = with pkgs; [
      zabbix-cli
    ];
  };
}