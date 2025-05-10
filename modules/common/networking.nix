{
  config,
  lib,
  ...
}:
with lib; {
  options.networking.profile = mkOption {
    type = types.enum ["desktop" "server" "minimal"];
    default = "desktop";
    description = "Network profile to use";
  };

  config = mkMerge [
    (mkIf (config.networking.profile == "desktop") {
      # Desktop networking configuration with NetworkManager
      networking.networkmanager.enable = true;
      networking.useDHCP = false;
      networking.useNetworkd = false;
      networking.firewall.enable = false;
      networking.nftables.enable = true;
      networking.timeServers = ["pool.ntp.org"];
    })

    (mkIf (config.networking.profile == "server") {
      # Server networking with systemd-networkd
      networking.networkmanager.enable = false;
      networking.useDHCP = false;
      networking.useNetworkd = true;
      networking.useHostResolvConf = false;
      networking.firewall.enable = false;
      networking.nftables.enable = true;
      networking.timeServers = ["pool.ntp.org"];

      # Enable systemd-resolved for DNS resolution with systemd-networkd
      services.resolved = {
        enable = true;
        dnssec = "true";
        fallbackDns = [
          "1.1.1.1"
          "8.8.8.8"
        ];
      };

      # Systemd network wait settings
      systemd.network.wait-online.timeout = 10;
      systemd.services.NetworkManager-wait-online.enable = mkForce false;
      systemd.services.systemd-networkd-wait-online.enable = mkForce false;
    })

    (mkIf (config.networking.profile == "minimal") {
      # Minimal networking configuration with just DHCP
      networking.useDHCP = true;
      networking.firewall.enable = false;
      networking.timeServers = ["pool.ntp.org"];
    })
  ];
}
