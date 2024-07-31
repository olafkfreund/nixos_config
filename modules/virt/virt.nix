{
  pkgs,
  pkgs-stable,
  ...
}: {
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
    incus = {
      package = pkgs.incus;
      enable = true;
    };
  };
  virtualisation.incus.ui.enable = true;

  environment.sessionVariables.LIBVIRT_DEFAULT_URI = ["qemu:///system"];
  services.spice-vdagentd.enable = true;
  systemd.services.libvirtd.restartIfChanged = false;
  virtualisation.lxd.enable = false;
  # boot.kernelParams = [
  #   "cgroup_enable=cpuset"
  #   "cgroup_memory=1"
  #   "cgroup_enable=memory"
  # ];

  environment.systemPackages = with pkgs; [
    OVMFFull
    ceph
    kvmtool
    libvirt
    #qemu
    multipass
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
    #quickgui
    #quickemu
    #quickgui
    btrfs-progs
  ];
}
