{ lib, ... }:
{
  services.resolved = {
    enable = lib.mkForce true;
    settings.Resolve = {
      FallbackDNS = [
        "1.1.1.1"
        "9.9.9.9"
        "1.0.0.1"
      ];
      Domains = [ "~." ];
      DNSOverTLS = "opportunistic";
      MulticastDNS = "no";
    };
  };

  networking.networkmanager.dns = lib.mkForce "systemd-resolved";
}
