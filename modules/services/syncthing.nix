{ config, lib, ... }:

let
  inherit (lib) mkOption mkIf mkEnableOption types listToAttrs filter;
  cfg = config.features.syncthing;

  # Host device IDs - obtained from each host's Syncthing installation
  # (via REST API /rest/system/status "myID"). Override per-host via
  # features.syncthing.deviceIds if needed.
  defaultDeviceIds = {
    p620 = "SQ6SDI7-NVAXUP2-RN3EEGN-YK7Q7P5-LEXKIJK-QJHJTFR-NJ7WMEQ-HOOSIAX";
    razer = "3DBBL3V-HEBXQBY-JIGONAD-YPLTHXH-D755LG7-2YQY6P6-3YVSXL2-D57YUQA";
    p510 = "YTQD3GO-4XDKZ7E-MXDSOID-7VYSTGY-BTNOIVB-SQAFZ6Q-XGUOQVD-4AWMLQX";
  };

  # Merge defaults with user-provided IDs (user overrides win)
  deviceIds = defaultDeviceIds // cfg.deviceIds;

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
      default = [ "p620" "razer" "p510" ];
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

    # NOTE: .stignore files are now managed declaratively by Home Manager
    # via home/syncthing-stignore.nix — no oneshot writer here.

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
