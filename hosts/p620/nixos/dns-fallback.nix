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

  # A stray, non-Nix-managed
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
