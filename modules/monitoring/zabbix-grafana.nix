# Zabbix-Grafana Integration Module
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.zabbix-monitoring.grafana;
in {
  options.services.zabbix-monitoring.grafana = {
    enable = mkEnableOption "Enable Zabbix-Grafana integration";
    
    datasourceName = mkOption {
      type = types.str;
      default = "Zabbix";
      description = "Name for Zabbix data source in Grafana";
    };
    
    zabbixUrl = mkOption {
      type = types.str;
      default = "http://127.0.0.1:8080";
      description = "URL to Zabbix web interface";
    };
    
    username = mkOption {
      type = types.str;
      default = "Admin";
      description = "Zabbix username for Grafana connection";
    };
    
    password = mkOption {
      type = types.str;
      default = "zabbix";
      description = "Zabbix password for Grafana connection";
    };
  };

  config = mkIf cfg.enable {
    # Grafana data source configuration (requires manual plugin installation)
    # After plugin installation, configure via UI or add to datasources
    # services.grafana.provision.datasources.settings.datasources = [
    #   {
    #     name = cfg.datasourceName;
    #     type = "alexanderzobnin-zabbix-datasource";
    #     url = cfg.zabbixUrl;
    #     access = "proxy";
    #     basicAuth = false;
    #     isDefault = false;
    #     jsonData = {
    #       username = cfg.username;
    #       trends = true;
    #       trendsFrom = "7d";
    #       trendsRange = "4h";
    #       cacheTTL = "1h";
    #       timeout = 30;
    #       directDBConnection = false;
    #     };
    #     secureJsonData = {
    #       password = cfg.password;
    #     };
    #   }
    # ];

    # Install Zabbix plugin for Grafana (manual installation required)
    # Note: Plugins need to be manually installed via Grafana UI or CLI
    # grafana-cli plugins install alexanderzobnin-zabbix-app

    # Create default Zabbix dashboards (after plugin installation)
    # services.grafana.provision.dashboards.settings.providers = [
    #   {
    #     name = "Zabbix Dashboards";
    #     type = "file";
    #     options.path = "/var/lib/grafana/dashboards/zabbix";
    #   }
    # ];

    # Create dashboard directory and files
    # systemd.tmpfiles.rules = [
    #   "d /var/lib/grafana/dashboards/zabbix 0755 grafana grafana -"
    # ];

    # Dashboard creation commented out for initial deployment
    # Manual setup required after Zabbix plugin installation
  };
}