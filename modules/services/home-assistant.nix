{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.features.homeAssistant;
in
{
  options.features.homeAssistant = {
    enable = mkEnableOption "Home Assistant home automation platform";

    port = mkOption {
      type = types.port;
      default = 8123;
      description = "Port for Home Assistant web interface";
    };

    enableCloud = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Home Assistant Cloud (Nabu Casa) integration";
    };

    enableCLI = mkOption {
      type = types.bool;
      default = true;
      description = "Install Home Assistant CLI tool";
    };

    extraComponents = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional Home Assistant components to enable";
    };

    tailscaleIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Configure trusted proxies for Tailscale access";
    };
  };

  config = mkIf cfg.enable {
    # Home Assistant service configuration
    services.home-assistant = {
      enable = true;

      extraPackages = python3Packages: with python3Packages; [
        python-otbr-api
      ];

      # Declarative configuration
      config = {
        # Default configuration includes common integrations
        default_config = { };

        # HTTP configuration
        http = {
          server_host = "0.0.0.0";
          server_port = cfg.port;
          use_x_forwarded_for = cfg.tailscaleIntegration;
          trusted_proxies = mkIf cfg.tailscaleIntegration [
            "127.0.0.1"
            "::1"
            "100.64.0.0/10" # Tailscale CGNAT range
            "192.168.1.0/24" # Local network
          ];
        };

        # Homeassistant configuration
        homeassistant = {
          name = "P510 Home";
          unit_system = "metric";
          time_zone = "UTC"; # Should match system timezone
          external_url = "https://p510.home.freundcloud.com:8123"; # Adjust based on Tailscale hostname
        };
      };

      # Components required for onboarding + optional cloud
      extraComponents = [
        # Required for initial onboarding
        "analytics"
        "met"
        "radio_browser"
        "shopping_list"
      ] ++ optional cfg.enableCloud "cloud"
      ++ cfg.extraComponents;
    };

    # Systemd service hardening
    systemd.services.home-assistant = {
      serviceConfig = {
        # Security hardening
        DynamicUser = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;

        # Resource limits
        MemoryMax = "2G";
        TasksMax = 512;

        # Required paths for Home Assistant
        ReadWritePaths = [
          "/var/lib/hass" # Home Assistant state directory
        ];
      };
    };

    # Home Assistant CLI tool
    environment.systemPackages = mkIf cfg.enableCLI [
      pkgs.home-assistant-cli
    ];

    # Firewall configuration
    networking.firewall = mkIf config.networking.firewall.enable {
      allowedTCPPorts = [ cfg.port ];
    };

    # Assertions
    assertions = [
      {
        assertion = cfg.enableCloud -> elem "cloud" config.services.home-assistant.extraComponents;
        message = "Home Assistant Cloud requires 'cloud' component in extraComponents";
      }
    ];
  };
}
