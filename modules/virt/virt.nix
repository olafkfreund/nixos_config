{ config, lib, pkgs, ... }:  with lib; {

  virtualisation = {
    libvirtd = {
      enable = true;
      onBoot = "ignore";

      qemu = {
        swtpm.enable = true;
        ovmf.enable = true;
        ovmf.packages = [ pkgs.OVMFFull.fd ];
        package = pkgs.qemu_kvm;
        runAsRoot = false;
      };

    };
    spiceUSBRedirection.enable = true;

    containerd = {
      enable = true;
    };
  };

  environment.sessionVariables.LIBVIRT_DEFAULT_URI = [ "qemu:///system" ];
  services.spice-vdagentd.enable = true;
  systemd.services.libvirtd.restartIfChanged = false;
  virtualisation.lxd.enable = true; 
  boot.kernelParams = [
    "cgroup_enable=cpuset" "cgroup_memory=1" "cgroup_enable=memory"
  ];

  environment.systemPackages = with pkgs; [
    quickemu
    OVMFFull
    gnome.adwaita-icon-theme
    kvmtool
    libvirt
    qemu
    spice
    spice-gtk
    spice-protocol
    spice-vdagent
    swtpm
    virt-manager
    virt-viewer
    win-spice
    win-virtio
    virtualbox
    quickgui
    quickemu
    quickgui

  ];

}

