{ pkgs, ... }: {
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  # Bound by the ESP, not by taste. The installer writes the new kernel+initrd
  # BEFORE pruning old ones, so the partition must hold limit + 1 generations:
  #
  #   511 MiB ESP, ~69 MiB per initrd, ~28 MiB kernels
  #   peak = (limit + 1) x 69 + 28;  limit = 5 -> ~442 MiB, fits
  #   limit = 10 would peak at ~787 MiB and fail mid-install
  #
  # razer hit exactly that failure twice (see hosts/razer/nixos/boot.nix).
  # Raising this needs a bigger ESP, not a bigger number.
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest; # Use the beta kernel for better hardware support
  boot.plymouth.enable = true;

  # /tmp in RAM, sized for what actually gets built here.
  #
  # 32G was generous once and is not any more: nix builds in $TMPDIR, `max-jobs
  # = auto` on 128 threads runs a dozen unpacks at a time, and several packages
  # in this closure are large on their own -- cef-binary is ~1.9G unpacked,
  # ctranslate2 and antigravity-ide are the same order. A full rebuild put four
  # of them in flight together and every one died with ENOSPC (#1635), which
  # reads as a disk problem and is not: / had 289G free throughout.
  #
  # 128G against 251G of RAM. tmpfs is lazily allocated, so this is a ceiling
  # rather than a reservation and costs nothing when /tmp is near-empty, which
  # is almost always.
  boot.tmp = {
    useTmpfs = true;
    tmpfsSize = "128G";
  };
  # OBS Virtual Cam Support - v4l2loopback setup
  boot.kernelModules = [ "v4l2loopback" ];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.blacklistedKernelModules = [ "nvidia" "nouveau" "nova_core" ];
  boot.kernelParams = [
    "amdgpu.gpu_recovery=1"
    "amd_iommu=on"
    "processor.max_cstate=1" # Prevent deep sleep states for better responsiveness
    "rcu_nocbs=0-127" # Optimize RCU callbacks
    "numa_balancing=disable" # Can improve performance for some workloads
  ];
  # v4l2loopback for OBS Virtual Camera support
  boot.extraModulePackages = with pkgs.linuxPackages_latest; [ v4l2loopback ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=3 video_nr=1,2,10 card_label="OBS Virtual Cam 1","OBS Virtual Cam 2","COSMIC Camera" exclusive_caps=1,1,1
  '';
  systemd.tmpfiles.rules = [
    "f /dev/shm/scream 0660 olafkfreund qemu-libvirtd -"
    "f /dev/shm/looking-glass 0660 olafkfreund qemu-libvirtd -"
  ];
}
