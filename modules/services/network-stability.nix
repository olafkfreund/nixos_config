{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.network-stability;
in {
  options.services.network-stability = {
    enable = mkEnableOption "Comprehensive network stability improvements";

    monitoring = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable network monitoring";
        example = false;
      };

      interval = mkOption {
        type = types.int;
        default = 30;
        description = "Monitoring interval in seconds";
        example = 60;
      };
    };

    secureDns = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable secure DNS configuration";
        example = false;
      };

      providers = mkOption {
        type = types.listOf types.str;
        default = [
          "1.1.1.1#cloudflare-dns.com"
          "8.8.8.8#dns.google"
        ];
        description = "List of DNS providers to use";
        example = ["9.9.9.9#dns.quad9.net"];
      };
    };

    tailscale = {
      enhance = mkOption {
        type = types.bool;
        default = true;
        description = "Enable enhanced Tailscale configuration";
        example = false;
      };

      acceptDns = mkOption {
        type = types.bool;
        default = false;
        description = "Whether Tailscale should manage DNS";
        example = true;
      };
    };

    electron = {
      improve = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Electron app network stability improvements";
        example = false;
      };
    };

    connectionStability = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable network connection stability enhancements";
        example = false;
      };

      switchDelayMs = mkOption {
        type = types.int;
        default = 5000;
        description = "Delay in milliseconds before switching network interfaces";
        example = 3000;
      };
    };
  };

  config = mkIf cfg.enable {
    # Enable network stability features
    networking.stableConnection = {
      enable = cfg.connectionStability.enable;
      interfaceSwitchDelayMs = cfg.connectionStability.switchDelayMs;
    };

    # Enable secure DNS if configured
    services.secure-dns = mkIf cfg.secureDns.enable {
      enable = true;
      dnssec = "true";
      fallbackProviders = cfg.secureDns.providers;
      useStubResolver = true;
    };

    # Enable network monitoring if configured
    services.network-monitoring = mkIf cfg.monitoring.enable {
      enable = true;
      monitorIntervalSeconds = cfg.monitoring.interval;
    };

    # Enable enhanced Tailscale configuration if configured
    vpn.tailscale = mkIf cfg.tailscale.enhance {
      enable = config.vpn.tailscale.enable;
      acceptDns = cfg.tailscale.acceptDns;
      netfilterMode = "off";
    };

    # Enable Electron network stability improvements if configured
    electron-apps = mkIf cfg.electron.improve {
      enable = config.electron-apps.enable;
      networkStability = true;
    };

    boot.kernel.sysctl = {
      # Improve TCP connection handling
      "net.ipv4.tcp_slow_start_after_idle" = 0;
      "net.ipv4.tcp_fastopen" = 3;

      # More stable IPv4 networking
      "net.ipv4.route.gc_timeout" = 300;

      # Improve network buffer sizes
      "net.core.rmem_max" = 16777216;
      "net.core.wmem_max" = 16777216;
      "net.core.rmem_default" = 1048576;
      "net.core.wmem_default" = 1048576;
    };

    # Ensure the system waits for stable network before starting key services
    systemd.services.network-stability-wait = {
      description = "Wait for network stability";
      before = ["network-online.target"];
      wantedBy = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/sleep 3";
        RemainAfterExit = true;
      };
    };
  };
}
