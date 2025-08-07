{
  ...
}: {
  # imports = [
  #   inputs.proxmox-nixos.nixosModules.proxmox-ve
  # ];
  services.proxmox-ve.enable = true;
  # nixpkgs.overlays = [
  #   proxmox-nixos.overlays.x86_64-linux
  # ];

systemd.network.networks."10-lan" = {
    matchConfig.Name = [ "enp8s0f0" ];
    networkConfig = {
    Bridge = "vmbr0";
    };
};

systemd.network.networks."20-lan" = {
    matchConfig.Name = [ "enp8s0f1" ];
    networkConfig = {
    Bridge = "vmbr1";
    };
};

systemd.network.netdevs."vmbr0" = {
    netdevConfig = {
        Name = "vmbr0";
        Kind = "bridge";
    };
};

systemd.network.netdevs."vmbr1" = {
    netdevConfig = {
        Name = "vmbr1";
        Kind = "bridge";
    };
};

systemd.network.networks."10-lan-bridge" = {
    matchConfig.Name = "vmbr0";
    networkConfig = {
    IPv6AcceptRA = true;
    DHCP = "ipv4";
    };
    linkConfig.RequiredForOnline = "routable";
};
systemd.network.networks."20-lan-bridge" = {
    matchConfig.Name = "vmbr1";
    networkConfig = {
    IPv6AcceptRA = true;
    DHCP = "ipv4";
    };
    linkConfig.RequiredForOnline = "routable";
};

}
