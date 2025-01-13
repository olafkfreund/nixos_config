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
          package = pkgs.qemu;
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
    systemd.services.libvirtd.restartIfChanged = false;
    boot.kernelParams = [
      "cgroup_enable=cpuset"
      "cgroup_memory=1"
      "cgroup_enable=memory"
    ];
    environment.systemPackages = [
      pkgs.OVMFFull
      pkgs.kvmtool
      pkgs.libvirt
      # multipass
      pkgs.spice
      pkgs.spice-gtk
      pkgs.spice-protocol
      pkgs.spice-vdagent
      pkgs.spice-autorandr
      pkgs.swtpm
      pkgs.virt-manager
      pkgs.virt-viewer
      pkgs.win-spice
      pkgs.win-virtio
      pkgs.virtualbox
      pkgs.btrfs-progs
      pkgs.quickemu
      # pkgs-unstable.vmware-workstation
      # quickgui
    ];
  };
}
