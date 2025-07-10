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
    # Grafana data source configuration
    services.grafana.provision.datasources.settings.datasources = [
      {
        name = cfg.datasourceName;
        type = "alexanderzobnin-zabbix-datasource";
        url = cfg.zabbixUrl;
        access = "proxy";
        basicAuth = false;
        isDefault = false;
        jsonData = {
          username = cfg.username;
          trends = true;
          trendsFrom = "7d";
          trendsRange = "4h";
          cacheTTL = "1h";
          timeout = 30;
          directDBConnection = false;
        };
        secureJsonData = {
          password = cfg.password;
        };
      }
    ];

    # Install Zabbix plugin for Grafana
    services.grafana.provision.plugins = [
      "alexanderzobnin-zabbix-app"
    ];

    # Create default Zabbix dashboards
    services.grafana.provision.dashboards.settings.providers = [
      {
        name = "Zabbix Dashboards";
        type = "file";
        options.path = "/var/lib/grafana/dashboards/zabbix";
      }
    ];

    # Create dashboard directory and files
    systemd.tmpfiles.rules = [
      "d /var/lib/grafana/dashboards/zabbix 0755 grafana grafana -"
    ];

    # Create network overview dashboard
    environment.etc."grafana/dashboards/zabbix/network-overview.json".text = builtins.toJSON {
      dashboard = {
        id = null;
        title = "Network Overview - Zabbix";
        tags = ["zabbix" "network"];
        style = "dark";
        timezone = "browser";
        panels = [
          {
            id = 1;
            title = "Network Devices Status";
            type = "stat";
            targets = [
              {
                datasource = cfg.datasourceName;
                queryType = "";
                refId = "A";
              }
            ];
            fieldConfig = {
              defaults = {
                color = {
                  mode = "thresholds";
                };
                thresholds = {
                  steps = [
                    { color = "green"; value = null; }
                    { color = "red"; value = 1; }
                  ];
                };
              };
            };
            gridPos = { h = 8; w = 12; x = 0; y = 0; };
          }
          {
            id = 2;
            title = "Network Traffic";
            type = "timeseries";
            targets = [
              {
                datasource = cfg.datasourceName;
                queryType = "";
                refId = "A";
              }
            ];
            fieldConfig = {
              defaults = {
                color = {
                  mode = "palette-classic";
                };
                unit = "bps";
              };
            };
            gridPos = { h = 8; w = 12; x = 12; y = 0; };
          }
        ];
        time = {
          from = "now-6h";
          to = "now";
        };
        refresh = "30s";
      };
    };

    # Create hosts overview dashboard
    environment.etc."grafana/dashboards/zabbix/hosts-overview.json".text = builtins.toJSON {
      dashboard = {
        id = null;
        title = "Hosts Overview - Zabbix";
        tags = ["zabbix" "hosts"];
        style = "dark";
        timezone = "browser";
        panels = [
          {
            id = 1;
            title = "Host Availability";
            type = "stat";
            targets = [
              {
                datasource = cfg.datasourceName;
                queryType = "";
                refId = "A";
              }
            ];
            fieldConfig = {
              defaults = {
                color = {
                  mode = "thresholds";
                };
                thresholds = {
                  steps = [
                    { color = "red"; value = null; }
                    { color = "green"; value = 1; }
                  ];
                };
              };
            };
            gridPos = { h = 8; w = 24; x = 0; y = 0; };
          }
          {
            id = 2;
            title = "CPU Usage";
            type = "timeseries";
            targets = [
              {
                datasource = cfg.datasourceName;
                queryType = "";
                refId = "A";
              }
            ];
            fieldConfig = {
              defaults = {
                color = {
                  mode = "palette-classic";
                };
                unit = "percent";
                max = 100;
              };
            };
            gridPos = { h = 8; w = 12; x = 0; y = 8; };
          }
          {
            id = 3;
            title = "Memory Usage";
            type = "timeseries";
            targets = [
              {
                datasource = cfg.datasourceName;
                queryType = "";
                refId = "A";
              }
            ];
            fieldConfig = {
              defaults = {
                color = {
                  mode = "palette-classic";
                };
                unit = "percent";
                max = 100;
              };
            };
            gridPos = { h = 8; w = 12; x = 12; y = 8; };
          }
        ];
        time = {
          from = "now-6h";
          to = "now";
        };
        refresh = "30s";
      };
    };
  };
}