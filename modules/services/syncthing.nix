{ config, lib, ... }:

with lib;
let
  cfg = config.features.syncthing;

  # Host device IDs - these are generated on first run of Syncthing
  # Run `syncthing --device-id` or check Web UI to get the ID
  # After first deployment, update these with actual device IDs
  defaultDeviceIds = {
    p620 = "SQ6SDI7-NVAXUP2-RN3EEGN-YK7Q7P5-LEXKIJK-QJHJTFR-NJ7WMEQ-HOOSIAX";
    razer = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
    p510 = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
    samsung = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
  };

  # Merge user-provided device IDs with defaults
  deviceIds = cfg.deviceIds // defaultDeviceIds;

  # Get list of other hosts (excluding current host)
  otherHosts = filter (h: h != config.networking.hostName) cfg.syncHosts;

  # Build devices attrset for Syncthing config
  syncDevices = listToAttrs (map
    (host: {
      name = host;
      value = {
        id = deviceIds.${host} or defaultDeviceIds.${host};
        addresses = [ "tcp://${host}.tail1234a.ts.net:22000" "dynamic" ];
      };
    })
    otherHosts);

  # Common ignore patterns for Claude config
  claudeIgnorePatterns = ''
    // Sensitive files - never sync
    .credentials.json

    // Large/runtime files - per machine
    history.jsonl
    stats-cache.json

    // Cache and temporary directories
    cache
    debug
    shell-snapshots
    session-env
    paste-cache
    file-history
    statsig
    telemetry
    todos
    ide

    // Home Manager managed files (symlinks to nix store)
    settings.json
    settings.local.json
    MCP-README.md
    plugins/custom-marketplace

    // Backup files
    *.bak
    *.backup
    *~
    .*.swp
  '';

  # Common ignore patterns for Gemini config
  geminiIgnorePatterns = ''
    // Sensitive files - never sync
    oauth_creds.json
    google_accounts.json

    // Per-machine identifiers
    installation_id
    user_id
    state.json

    // Browser profile and temp
    antigravity-browser-profile
    tmp

    // Backup files
    *.bak
    *.backup
    *~
    .*.swp
  '';

in
{
  options.features.syncthing = {
    enable = mkEnableOption "Syncthing file synchronization";

    user = mkOption {
      type = types.str;
      default = "olafkfreund";
      description = "User to run Syncthing as";
    };

    syncHosts = mkOption {
      type = types.listOf types.str;
      default = [ "p620" "razer" "p510" "samsung" ];
      description = "List of hosts to sync with";
    };

    deviceIds = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Device IDs for each host. Get these by running `syncthing --device-id`
        on each host after initial Syncthing setup.
      '';
      example = {
        p620 = "ABCDEFG-HIJKLMN-OPQRSTU-VWXYZ12-3456789-ABCDEFG-HIJKLMN-OPQRSTU";
      };
    };

    masterHost = mkOption {
      type = types.str;
      default = "p620";
      description = "Primary host for conflict resolution (introducer)";
    };

    syncClaude = mkOption {
      type = types.bool;
      default = true;
      description = "Sync ~/.claude directory";
    };

    syncGemini = mkOption {
      type = types.bool;
      default = true;
      description = "Sync ~/.gemini directory";
    };

    guiAddress = mkOption {
      type = types.str;
      default = "127.0.0.1:8384";
      description = "Address for Syncthing Web UI";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall ports for Syncthing";
    };
  };

  config = mkIf cfg.enable {
    # Syncthing service configuration
    services.syncthing = {
      enable = true;
      inherit (cfg) user;
      group = "users";
      dataDir = "/home/${cfg.user}";
      configDir = "/home/${cfg.user}/.config/syncthing";
      openDefaultPorts = cfg.openFirewall;
      inherit (cfg) guiAddress;

      # Declarative configuration
      overrideDevices = true;
      overrideFolders = true;

      settings = {
        # Configure peer devices
        devices = syncDevices;

        # Configure folders to sync
        folders = {
          # Claude configuration sync
          "claude-config" = mkIf cfg.syncClaude {
            path = "/home/${cfg.user}/.claude";
            devices = otherHosts;
            id = "claude-config";
            label = "Claude Code Config";

            # Sync options
            type = "sendreceive";
            rescanIntervalS = 60;
            fsWatcherEnabled = true;
            fsWatcherDelayS = 1;

            # Versioning - keep old versions for 30 days
            versioning = {
              type = "staggered";
              params = {
                cleanInterval = "3600";
                maxAge = "2592000"; # 30 days in seconds
              };
            };
          };

          # Gemini configuration sync
          "gemini-config" = mkIf cfg.syncGemini {
            path = "/home/${cfg.user}/.gemini";
            devices = otherHosts;
            id = "gemini-config";
            label = "Gemini CLI Config";

            # Sync options
            type = "sendreceive";
            rescanIntervalS = 60;
            fsWatcherEnabled = true;
            fsWatcherDelayS = 1;

            # Versioning - keep old versions for 30 days
            versioning = {
              type = "staggered";
              params = {
                cleanInterval = "3600";
                maxAge = "2592000"; # 30 days in seconds
              };
            };
          };
        };

        # Global options
        options = {
          urAccepted = -1; # Disable usage reporting
          globalAnnounceEnabled = false; # We use Tailscale, no need for global discovery
          localAnnounceEnabled = true;
          relaysEnabled = false; # Direct connection via Tailscale
          natEnabled = false; # Not needed with Tailscale
        };
      };
    };

    # Create .stignore files for each synced folder
    systemd.services.syncthing-stignore = {
      description = "Create Syncthing ignore files";
      wantedBy = [ "multi-user.target" ];
      after = [ "syncthing.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = "users";
      };
      script = ''
        # Create .stignore for Claude config
        ${optionalString cfg.syncClaude ''
          cat > /home/${cfg.user}/.claude/.stignore << 'EOF'
        ${claudeIgnorePatterns}
        EOF
        ''}

        # Create .stignore for Gemini config
        ${optionalString cfg.syncGemini ''
          cat > /home/${cfg.user}/.gemini/.stignore << 'EOF'
        ${geminiIgnorePatterns}
        EOF
        ''}
      '';
    };

    # Firewall configuration
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ 22000 ]; # Syncthing transfer
      allowedUDPPorts = [ 22000 21027 ]; # Transfer + discovery
    };

    # Ensure directories exist
    systemd.tmpfiles.rules = [
      "d /home/${cfg.user}/.claude 0755 ${cfg.user} users -"
      "d /home/${cfg.user}/.gemini 0755 ${cfg.user} users -"
      "d /home/${cfg.user}/.config/syncthing 0700 ${cfg.user} users -"
    ];
  };
}
