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
    enable = mkEnableOption {
      type = types.bool;
      default = false;
      description = "Enable DNS over TLS/HTTPS using systemd-resolved";
    };

    dnssec = mkOption {
      type = types.str;
      default = "true";
      description = "Enable DNSSEC validation (true, false, or allow-downgrade)";
    };

    fallbackProviders = mkOption {
      type = types.listOf types.str;
      default = [
        "1.1.1.1#cloudflare-dns.com"
        "8.8.8.8#dns.google"
      ];
      description = "Fallback DNS providers with TLS hostnames";
    };

    useStubResolver = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to point system nameservers to the systemd-resolved stub resolver";
    };
  };

  config = mkIf cfg.enable {
    services.resolved = {
      enable = true;
      dnssec = cfg.dnssec;
      domains = ["~."]; # Use systemd-resolved for all domains
      fallbackDns = cfg.fallbackProviders;
      extraConfig = ''
        DNSOverTLS=yes
      '';
    };

    # Use systemd-resolved stub resolver if enabled
    networking = mkIf cfg.useStubResolver {
      nameservers = ["127.0.0.53"];

      # Ensure NetworkManager uses systemd-resolved if both are enabled
      networkmanager = mkIf config.networking.networkmanager.enable {
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
            DNSOverTLS = "yes";
          };
        };
      };
    };

    environment.systemPackages = with pkgs; [
      # Include useful tools for debugging
      dnsutils
    ];
  };
}
