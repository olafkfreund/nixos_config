{
  inputs,
  config,
  lib,
  pkgs,
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
    environment.systemPackages = with pkgs; [
      OVMFFull
      kvmtool
      libvirt
      multipass
      spice
      spice-gtk
      spice-protocol
      spice-vdagent
      spice-autorandr
      swtpm
      virt-manager
      virt-viewer
      win-spice
      win-virtio
      virtualbox
      btrfs-progs
    ];
  };
}
