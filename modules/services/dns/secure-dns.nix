{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.secure-dns;
in {
  options.services.secure-dns = {
    enable = mkEnableOption "Secure DNS with enhanced stability";

    dnssec = mkOption {
      type = types.enum ["true" "false" "allow-downgrade"];
      default = "true";
      description = "Whether to enable DNSSEC validation";
      example = "allow-downgrade";
    };

    useStubResolver = mkOption {
      type = types.bool;
      default = true;
      description = "Use systemd-resolved's stub resolver";
      example = true;
    };

    fallbackProviders = mkOption {
      type = types.listOf types.str;
      default = [
        "1.1.1.1#cloudflare-dns.com"
        "8.8.8.8#dns.google"
      ];
      description = "List of fallback DNS providers to use";
      example = ["9.9.9.9#dns.quad9.net"];
    };

    cacheSize = mkOption {
      type = types.int;
      default = 4096;
      description = "Size of DNS cache in entries";
      example = 8192;
    };

    dnsOverTls = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable DNS-over-TLS";
      example = true;
    };

    networkManagerIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to integrate with NetworkManager";
      example = true;
    };
  };

  config = mkIf cfg.enable {
    # Enable systemd-resolved
    services.resolved = {
      enable = true;
      dnssec = cfg.dnssec;
      domains = ["~."]; # Use systemd-resolved for all domains
      fallbackDns = cfg.fallbackProviders;
      extraConfig = ''
        DNSOverTLS=${
          if cfg.dnsOverTls
          then "yes"
          else "no"
        }
        Cache=${toString cfg.cacheSize}
        StaleRetentionSec=86400
        ReadEtcHosts=yes
      '';
    };

    # Use systemd-resolved stub resolver if enabled
    networking = mkIf cfg.useStubResolver {
      nameservers = ["127.0.0.53"];

      # Ensure NetworkManager uses systemd-resolved if both are enabled
      networkmanager = mkIf (config.networking.networkmanager.enable && cfg.networkManagerIntegration) {
        dns = "systemd-resolved";
      };
    };

    # Configuration for systemd-networkd
    systemd.network = mkIf config.systemd.network.enable {
      # Apply DNS settings to all networks that use DHCP
      networks = {
        "10-dns-settings" = {
          matchConfig.Name = "*";
          linkConfig.RequiredForOnline = "no";
          networkConfig = {
            DNS = ["127.0.0.53"];
            DNSOverTLS =
              if cfg.dnsOverTls
              then "yes"
              else "no";
          };
          dhcpV4Config = {
            UseDNS = !cfg.useStubResolver;
          };
        };
      };
    };

    # Ensure host resolv.conf is properly managed
    environment.etc."resolv.conf".source =
      mkIf cfg.useStubResolver
      (mkForce "${pkgs.systemd}/lib/systemd/resolv.conf");

    # Add service to monitor DNS resolution stability
    systemd.services.dns-stability-monitor = {
      description = "Monitor DNS resolution stability";
      after = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = pkgs.writeShellScript "dns-monitor" ''
          #!/bin/sh
          while true; do
            # Check if DNS resolution is working
            if ! ${pkgs.inetutils}/bin/host -W 2 cloudflare.com >/dev/null 2>&1; then
              echo "DNS resolution failed, restarting systemd-resolved" | ${pkgs.systemd}/bin/systemd-cat -t dns-monitor -p warning
              ${pkgs.systemd}/bin/systemctl restart systemd-resolved.service
              sleep 10
            fi
            sleep 120
          done
        '';
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };
  };
}
