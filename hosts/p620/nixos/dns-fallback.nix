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

  # DHCP advertises 192.168.1.222 (p620's OWN IP, nothing listening on :53) as a
  # DNS server — a dead primary that every cold lookup times out on before
  # falling back. Ignore DHCP-provided DNS and pin fast public resolvers (Quad9
  # measured fastest here ~18ms, Cloudflare next). Tier 1 will prepend the p510
  # LAN cache (192.168.1.175) in front of these as the fallback.
  networking.networkmanager.connectionConfig = {
    "ipv4.ignore-auto-dns" = true;
    "ipv4.dns" = "9.9.9.9;1.1.1.1;";
  };

  # Root cause of the mitigation above not taking effect: a stray, non-Nix-managed
  # file /etc/systemd/resolved.conf.d/performance.conf (dated Oct 2025, no module
  # in this repo produces it) sets global `DNS=192.168.1.222 1.1.1.1` directly.
  # systemd-resolved reads conf.d drop-ins *after* the main /etc/systemd/resolved.conf
  # (which this file manages via services.resolved.settings and leaves DNS unset), so
  # that leftover drop-in's DNS= wins and re-injects p620's own dead IP as the global
  # primary resolver — independent of the NetworkManager settings above. Claiming the
  # same path here makes activation replace it with an empty, Nix-managed drop-in.
  environment.etc."systemd/resolved.conf.d/performance.conf".text = ''
    [Resolve]
  '';
}
