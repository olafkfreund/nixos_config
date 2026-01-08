{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.rescreenshot-mcp;

  claudeDesktopConfig = {
    mcpServers.screenshot = {
      command = "${cfg.package}/bin/rescreenshot-mcp";
      env = {
        RUST_LOG = cfg.logLevel;
      };
    };
  };

  configDir = "${config.users.users.${cfg.user}.home}/.config/Claude";
  configFile = "${configDir}/claude_desktop_config.json";

in
{
  options.services.rescreenshot-mcp = {
    enable = mkEnableOption "rescreenshot-mcp MCP server for Claude Desktop";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../../pkgs/rescreenshot-mcp { };
      description = "The rescreenshot-mcp package to use";
    };

    user = mkOption {
      type = types.str;
      default = "olafkfreund";
      description = "User to configure Claude Desktop for";
    };

    logLevel = mkOption {
      type = types.str;
      default = "info";
      example = "debug";
      description = "Log level for rescreenshot-mcp (trace, debug, info, warn, error)";
    };

    autoConfigureClaudeDesktop = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically configure Claude Desktop with rescreenshot-mcp";
    };
  };

  config = mkIf cfg.enable {
    # Add the package to system packages
    environment.systemPackages = [ cfg.package ];

    # Ensure required runtime dependencies are available
    services.pipewire.enable = mkDefault true;

    xdg.portal = {
      enable = mkDefault true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
      ];
    };

    # Configure Claude Desktop for the user
    systemd.user.services.configure-rescreenshot-mcp = mkIf cfg.autoConfigureClaudeDesktop {
      description = "Configure Claude Desktop with rescreenshot-mcp";
      wantedBy = [ "default.target" ];
      after = [ "graphical-session.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = cfg.user;
      };

      script = ''
        mkdir -p ${configDir}

        # Read existing config or create empty JSON
        if [ -f ${configFile} ]; then
          existing_config=$(cat ${configFile})
        else
          existing_config='{}'
        fi

        # Merge with rescreenshot-mcp config using jq
        echo "$existing_config" | ${pkgs.jq}/bin/jq \
          --argjson screenshot '${builtins.toJSON claudeDesktopConfig.mcpServers.screenshot}' \
          '.mcpServers.screenshot = $screenshot' \
          > ${configFile}.tmp

        mv ${configFile}.tmp ${configFile}
        chmod 600 ${configFile}

        echo "Claude Desktop configured with rescreenshot-mcp at ${configFile}"
      '';
    };

    # Add a user service to ensure portal is running
    systemd.user.services.xdg-desktop-portal = {
      description = "Portal service for desktop integration";
      wantedBy = [ "default.target" ];
      after = [ "graphical-session.target" ];

      serviceConfig = {
        Type = "dbus";
        BusName = "org.freedesktop.portal.Desktop";
        ExecStart = "${pkgs.xdg-desktop-portal}/libexec/xdg-desktop-portal";
        Restart = "on-failure";
      };
    };

    # Security hardening for any potential helper services
    # (Currently rescreenshot-mcp doesn't need a daemon, but following best practices)
    assertions = [
      {
        assertion = config.services.pipewire.enable;
        message = "rescreenshot-mcp requires PipeWire for Wayland screen capture";
      }
    ];
  };
}
