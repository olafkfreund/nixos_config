{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.network-stability;

  # Create a wrapped script with proper dependencies
  stabilityScript = pkgs.writeShellScriptBin "network-stability-helper" (builtins.readFile (toString cfg.scriptPath));
in {
  # This module doesn't declare options of its own
  # It uses the options declared in network-stability.nix

  config = mkIf (cfg.enable && cfg.helperService.enable) {
    # Create the systemd service
    systemd.services.network-stability-helper = {
      description = "Network Stability Helper Service";
      documentation = ["https://github.com/olafkfreund/nixos-config/blob/main/doc/network-stability-guide.md"];
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target" "NetworkManager.service" "systemd-networkd.service"];

      path = with pkgs; [
        iproute2
        inetutils
        systemd
        coreutils
        gnugrep
      ];

      serviceConfig = {
        Type = "simple";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep ${toString cfg.helperService.startDelay}";
        ExecStart = "${stabilityScript}/bin/network-stability-helper";
        Restart = "on-failure";
        RestartSec = "${toString cfg.helperService.restartSec}";

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

    # Make the helper script available in system path
    environment.systemPackages = [stabilityScript];

    # Create a sync point for network stability events
    systemd.tmpfiles.rules = [
      "d /run/network-stability 0755 root root -"
      "f /run/network-stability-event 0644 root root -"
    ];
  };
}
