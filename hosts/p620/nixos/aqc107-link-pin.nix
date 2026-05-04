# AQC107 (Aquantia/Marvell 10GbE) link-speed pin.
#
# The on-board AQC107 on this host has been emitting bursts of corrected
# PCIe AER errors and currently negotiates at 1 Gb/s anyway. Forcing the
# link to a fixed 1 Gb/s eliminates the auto-neg renegotiation that
# correlates with the AER bursts and the IO-pressure stalls those cause
# (NFS over `/mnt/media` blocks every consumer of the share, which the
# kernel reports as IO pressure even with idle local disks).
#
# Remove this once the NIC is replaced or the cable/slot path is known
# good.
{ pkgs, ... }: {
  systemd.services.aqc107-link-pin = {
    description = "Pin AQC107 (enp1s0) to 1 Gb/s full duplex, autoneg off";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-pre.target" "sys-subsystem-net-devices-enp1s0.device" ];
    bindsTo = [ "sys-subsystem-net-devices-enp1s0.device" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.ethtool}/bin/ethtool -s enp1s0 speed 1000 duplex full autoneg off";
      # ethtool returns 80 ("nothing changed") on no-op; treat as success.
      SuccessExitStatus = [ 0 80 ];
    };
  };
}
