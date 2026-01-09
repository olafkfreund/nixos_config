# WhatsApp Bridge Systemd Service
# Persistent background service for WhatsApp Web API connection
# Follows docs/NIXOS-ANTI-PATTERNS.md security patterns

{ config, lib, pkgs, ... }:

let
  # Use options from modules/ai/mcp-servers.nix (features.ai.mcp.whatsapp)
  cfg = config.features.ai.mcp.whatsapp;
in
{
  # Options are defined in modules/ai/mcp-servers.nix
  # This module only provides the systemd service implementation

  config = lib.mkIf cfg.enable {
    # Systemd service for persistent WhatsApp bridge
    systemd.services.whatsapp-bridge = {
      description = "WhatsApp Bridge for MCP Integration";
      documentation = [ "https://github.com/lharries/whatsapp-mcp" ];

      # Start after network is available
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.customPkgs.whatsapp-mcp.whatsappBridge}/bin/whatsapp-bridge";
        Restart = "always";
        RestartSec = "10s";

        # Security hardening (follows NIXOS-ANTI-PATTERNS.md)
        # Creates dedicated user/group automatically
        DynamicUser = true;

        # Persistent data directory with proper permissions
        StateDirectory = "whatsapp-mcp";
        StateDirectoryMode = "0700";

        # Working directory for database
        WorkingDirectory = "/var/lib/whatsapp-mcp";

        # Filesystem protection
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;

        # Process restrictions
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;

        # Network access required for WhatsApp Web API
        PrivateNetwork = false;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];

        # System call filtering
        SystemCallFilter = [ "@system-service" "~@privileged" ];
        SystemCallArchitectures = "native";

        # Resource limits (minimal - Go bridge is lightweight)
        MemoryMax = "256M";
        TasksMax = 100;
      };

      # Notification when authentication expires
      # Session typically lasts ~20 days
      onFailure = [ "whatsapp-auth-expired.service" ];
    };

    # Notification service for session expiry
    systemd.services.whatsapp-auth-expired = {
      description = "WhatsApp Authentication Expired Notification";

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "notify-whatsapp-auth" ''
          echo "WhatsApp MCP authentication has expired or failed"
          echo "Re-authenticate by viewing QR code: journalctl -u whatsapp-bridge -f"
          echo "Then scan QR code with WhatsApp mobile app"
        ''}";
      };
    };

    # Environment packages for WhatsApp MCP
    environment.systemPackages = [
      pkgs.customPkgs.whatsapp-mcp.whatsappBridge
      pkgs.customPkgs.whatsapp-mcp.whatsappMcpServer
    ] ++ lib.optionals cfg.enableVoiceMessages [
      pkgs.ffmpeg
    ];

    # Documentation
    environment.etc."whatsapp-mcp-info.txt".text = ''
      WhatsApp MCP Integration
      ========================

      Status: ${if cfg.enable then "Enabled" else "Disabled"}
      Data Directory: ${cfg.dataDir}
      Voice Messages: ${if cfg.enableVoiceMessages then "Enabled (FFmpeg)" else "Disabled"}

      Authentication:
      ---------------
      Initial setup requires QR code scan from WhatsApp mobile app.

      View QR code:
        journalctl -u whatsapp-bridge -f

      The QR code will be displayed in the console output.
      Open WhatsApp on your phone and scan the QR code.

      Session expires approximately every 20 days.
      You'll need to re-authenticate when the service fails.

      Service Management:
      -------------------
      Status:  systemctl status whatsapp-bridge
      Logs:    journalctl -u whatsapp-bridge -f
      Restart: systemctl restart whatsapp-bridge

      Database:
      ---------
      Location: ${cfg.dataDir}/whatsapp.db
      Backup:   cp ${cfg.dataDir}/whatsapp.db /backup/location/

      Usage:
      ------
      Interact with WhatsApp through Claude Code or Claude Desktop:
      - "Send a message to John saying I'll be late"
      - "Show me recent messages from Sarah"
      - "Find all messages containing 'meeting'"
      - "Send the project document to the team group"

      Documentation:
      --------------
      Full docs: cat /etc/nixos-config/docs/WHATSAPP-MCP.md
    '';
  };
}
