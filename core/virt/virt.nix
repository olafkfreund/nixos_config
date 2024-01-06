{ config, lib, pkgs, ... }:  with lib; {

  virtualisation = {
    podman = {
      enable = true;
      #dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };
  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };
  #---------------------------------------------------------------------
  # Manage the virtualisation services : Libvirt stuff
  #---------------------------------------------------------------------
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
  };

  environment.sessionVariables.LIBVIRT_DEFAULT_URI = [ "qemu:///system" ];
  services.spice-vdagentd.enable = true;
  systemd.services.libvirtd.restartIfChanged = false;
  virtualisation.lxd.enable = true; 

  environment.systemPackages = with pkgs; [
    podman-compose
    podman-tui
    podman
    pods
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

  ];

}
