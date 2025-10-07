{ config
, lib
, pkgs
, pkgs-stable
, ...
}:
with lib; let
  cfg = config.services.libvirt;
in
{
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
          package = pkgs.qemu;
          runAsRoot = false;
        };
      };
      spiceUSBRedirection.enable = true;
      containerd = {
        enable = true;
      };
    };

    # Fix libvirt SSH config permission issue (permanent solution)
    # Recent OpenSSH versions reject libvirt-provided client config drop-ins in Nix store
    # due to tightened ownership/permission checks
    # Solution: Replace /etc/ssh/ssh_config entirely and prevent libvirt drop-in inclusion

    # Replace /etc/ssh/ssh_config and drop the default Include line
    environment.etc."ssh/ssh_config".text = lib.mkForce ''
      Host *
        SendEnv LANG LC_*
        HashKnownHosts yes
        ServerAliveInterval 60
        ServerAliveCountMax 3

        # Additional security and performance settings
        StrictHostKeyChecking ask
        UserKnownHostsFile ~/.ssh/known_hosts
        Compression yes
        ConnectTimeout 10
    '';

    # Make sure the problematic libvirt drop-in isn't picked up anymore
    systemd.tmpfiles.rules = [
      "r /etc/ssh/ssh_config.d/30-libvirt-ssh-proxy.conf"
      "L+ /var/lib/qemu/firmware - - - - ${pkgs.qemu}/share/qemu/firmware"
    ];
    environment.sessionVariables.LIBVIRT_DEFAULT_URI = [ "qemu:///system" ];
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
      pkgs-stable.multipass
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
      pkgs-stable.virtualbox # Using stable version to avoid libcurl proxy enum build errors in unstable
      pkgs.btrfs-progs
      pkgs.quickemu
      # pkgs.vmware-workstation
      pkgs.quickgui
    ];
  };
}
