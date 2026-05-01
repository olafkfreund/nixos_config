{ config
, lib
, pkgs
, pkgs-stable
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
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
    environment = {
      etc."ssh/ssh_config".text = lib.mkForce ''
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

      sessionVariables.LIBVIRT_DEFAULT_URI = [ "qemu:///system" ];
    };

    # Make sure the problematic libvirt drop-in isn't picked up anymore
    systemd = {
      tmpfiles.rules = [
        "r /etc/ssh/ssh_config.d/30-libvirt-ssh-proxy.conf"
        "L+ /var/lib/qemu/firmware - - - - ${pkgs.qemu}/share/qemu/firmware"
      ];
      services.libvirtd.restartIfChanged = false;
      # Fix virt-secret-init-encryption on hosts without working TPM2.
      # Upstream runs `systemd-creds encrypt` which defaults to TPM2+host and
      # fails when TPM2 is unavailable/broken. Force --with-key=host so the
      # key is encrypted with /var/lib/systemd/credential.secret only.
      # The libvirtd unit uses LoadCredentialEncrypted= which requires this
      # file to be in systemd-creds encrypted format (not raw bytes).
      services.virt-secret-init-encryption.serviceConfig.ExecStart = lib.mkForce
        (
          let
            script = pkgs.writeShellScript "virt-secret-init-encryption" ''
              set -eu
              umask 0077
              mkdir -p /var/lib/libvirt/secrets
              out=/var/lib/libvirt/secrets/secrets-encryption-key
              if [ ! -s "$out" ] || ! ${pkgs.systemd}/bin/systemd-creds --with-key=host decrypt --name=secrets-encryption-key "$out" /dev/null >/dev/null 2>&1; then
                tmp=$(${pkgs.coreutils}/bin/mktemp)
                ${pkgs.coreutils}/bin/dd if=/dev/random of="$tmp" bs=32 count=1 status=none
                ${pkgs.systemd}/bin/systemd-creds --with-key=host encrypt --name=secrets-encryption-key "$tmp" "$out"
                ${pkgs.coreutils}/bin/rm -f "$tmp"
              fi
            '';
          in
          "${script}"
        );
    };
    boot.kernelParams = [
      "cgroup_enable=cpuset"
      "cgroup_memory=1"
      "cgroup_enable=memory"
    ];
    environment.systemPackages = [
      pkgs.OVMFFull
      pkgs.kvmtool
      pkgs.libvirt
      pkgs.virtiofsd # virtio-fs daemon for host/VM file sharing
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
      pkgs.virtio-win
      pkgs-stable.virtualbox # Using stable version to avoid libcurl proxy enum build errors in unstable
      pkgs.btrfs-progs
      pkgs.quickemu
      # pkgs.vmware-workstation
      pkgs.quickgui
    ];
  };
}
