{
  inputs,
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
with lib; let
  cfg = config.services.libvirt;
in {
  options.services.libvirt = {
    enable = mkEnableOption {
      default = false;
      description = "Enable libvirt";
    };
  };
  config = mkIf cfg.enable {
    virtualisation = {
      libvirtd = {
        enable = true;
        onBoot = "ignore";
        qemu = {
          swtpm.enable = true;
          ovmf.enable = true;
          ovmf.packages = [pkgs.OVMFFull.fd];
          package = pkgs-unstable.qemu;
          runAsRoot = false;
        };
      };
      spiceUSBRedirection.enable = true;
      containerd = {
        enable = true;
      };
    };
    environment.sessionVariables.LIBVIRT_DEFAULT_URI = ["qemu:///system"];
    services.spice-vdagentd.enable = true;
    systemd.tmpfiles.rules = ["L+ /var/lib/qemu/firmware - - - - ${pkgs-unstable.qemu}/share/qemu/firmware"];
    systemd.services.libvirtd.restartIfChanged = false;
    boot.kernelParams = [
      "cgroup_enable=cpuset"
      "cgroup_memory=1"
      "cgroup_enable=memory"
    ];
    environment.systemPackages = [
      pkgs-unstable.OVMFFull
      pkgs-unstable.kvmtool
      pkgs-unstable.libvirt
      pkgs-unstable.multipass
      pkgs-unstable.spice
      pkgs-unstable.spice-gtk
      pkgs-unstable.spice-protocol
      pkgs-unstable.spice-vdagent
      pkgs-unstable.spice-autorandr
      pkgs-unstable.swtpm
      pkgs-unstable.virt-manager
      pkgs-unstable.virt-viewer
      pkgs-unstable.win-spice
      pkgs-unstable.win-virtio
      pkgs-unstable.virtualbox
      pkgs-unstable.btrfs-progs
      pkgs-unstable.quickemu
      # pkgs-unstable.vmware-workstation
      pkgs-unstable.quickgui
    ];
  };
}
