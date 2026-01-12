{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.rescreenshot-mcp;

  # Wrapper script to ensure environment variables are set
  wrapperScript = pkgs.writeShellScript "rescreenshot-mcp-wrapper" ''
    # Debug: Log environment for troubleshooting
    if [ "${cfg.logLevel}" = "debug" ] || [ "${cfg.logLevel}" = "trace" ]; then
      echo "Environment check:" >&2
      echo "  WAYLAND_DISPLAY=$WAYLAND_DISPLAY" >&2
      echo "  DISPLAY=$DISPLAY" >&2
      echo "  XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" >&2
      echo "  XDG_SESSION_TYPE=$XDG_SESSION_TYPE" >&2
    fi

    # Set required environment variables if not already set
    # Use runtime directory based on actual user
    if [ -z "$XDG_RUNTIME_DIR" ]; then
      export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    fi

    # Set Wayland display if we're in a Wayland session
    if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_SESSION_TYPE" = "wayland" ]; then
      export WAYLAND_DISPLAY="wayland-0"
    fi

    # Set X11 display if we're in an X11 session
    if [ -z "$DISPLAY" ] && [ "$XDG_SESSION_TYPE" = "x11" ]; then
      export DISPLAY=":0"
    fi

    # Set default DISPLAY if nothing else is set (fallback)
    if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ]; then
      # Try to detect which display server is available
      if [ -e "$XDG_RUNTIME_DIR/wayland-0" ]; then
        export WAYLAND_DISPLAY="wayland-0"
      else
        export DISPLAY=":0"
      fi
    fi

    export RUST_LOG=${cfg.logLevel}

    # Launch the actual rescreenshot-mcp binary
    exec ${cfg.package}/bin/rescreenshot-mcp "$@"
  '';

  claudeDesktopConfig = {
    mcpServers.screenshot = {
      command = toString wrapperScript;
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

    # Note: xdg-desktop-portal service is automatically managed by xdg.portal.enable
    # No need for manual systemd service definition

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
