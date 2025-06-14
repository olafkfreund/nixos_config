{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.virtualization.qemu = {
    enable = lib.mkEnableOption "QEMU/KVM virtualization";

    vfio = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable VFIO for GPU passthrough";
    };

    ovmf = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable OVMF UEFI firmware";
    };

    spice = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable SPICE protocol support";
    };
  };

  config = lib.mkIf config.modules.virtualization.qemu.enable {
    virtualisation = {
      libvirtd = {
        enable = true;
        qemu = {
          package = pkgs.qemu_kvm;
          ovmf.enable = config.modules.virtualization.qemu.ovmf;
          ovmf.packages = lib.mkIf config.modules.virtualization.qemu.ovmf [
            pkgs.OVMFFull.fd
          ];
        };
      };

      spiceUSBRedirection.enable = config.modules.virtualization.qemu.spice;
    };

    environment.systemPackages = with pkgs; [
      qemu
      qemu_kvm
      virt-manager
      virt-viewer
      spice
      spice-gtk
      spice-protocol
      win-virtio
      win-spice
    ];

    # VFIO configuration
    boot = lib.mkIf config.modules.virtualization.qemu.vfio {
      kernelModules = ["vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd"];
      kernelParams = ["intel_iommu=on" "amd_iommu=on"];
    };

    users.users = lib.mkMerge [
      (lib.mkIf (config.users.users ? "olafkfreund") {
        olafkfreund.extraGroups = ["libvirtd" "qemu-libvirtd"];
      })
    ];
  };
}
