{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.network-stability;
  scriptPath = "${config.services.network-stability.scriptPath}";
in {
  options.services.network-stability = {
    # Ensure our existing options from network-stability.nix remain compatible
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the network stability service.";
      example = true;
    };

    scriptPath = mkOption {
      type = types.path;
      default = ../../../scripts/network-stability-helper.sh;
      description = "Path to the network stability helper script.";
      example = "/path/to/network-stability-helper.sh";
    };

    startDelay = mkOption {
      type = types.int;
      default = 5;
      description = "Delay in seconds before starting the network stability service.";
      example = 10;
    };

    restartSec = mkOption {
      type = types.int;
      default = 30;
      description = "Time in seconds to wait before restarting the service on failure.";
      example = 60;
    };
  };

  config = mkIf cfg.enable {
    # Create the systemd service
    systemd.services.network-stability-helper = {
      description = "Network Stability Helper Service";
      documentation = ["https://github.com/olafkfreund/nixos-config/blob/main/doc/network-stability-guide.md"];
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target" "NetworkManager.service" "systemd-networkd.service"];

      serviceConfig = {
        Type = "simple";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep ${toString cfg.startDelay}";
        ExecStart = "${pkgs.bash}/bin/bash ${scriptPath}";
        Restart = "on-failure";
        RestartSec = "${toString cfg.restartSec}";

        # Security hardening
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;

        # Resource limits
        LimitNOFILE = 1024;
        CPUSchedulingPolicy = "idle";
        MemoryHigh = "100M";
        MemoryMax = "150M";
      };
    };

    # Create a sync point for network stability events
    systemd.tmpfiles.rules = [
      "d /run/network-stability 0755 root root -"
      "f /run/network-stability-event 0644 root root -"
    ];
  };
}
