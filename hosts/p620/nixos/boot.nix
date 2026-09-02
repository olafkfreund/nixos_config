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

  # /tmp on disk, not in RAM.
  #
  # This was a 32G tmpfs, then a 128G one, and a full rebuild exhausted both
  # (#1635). Raising the number was the wrong shape of fix: tmpfs is RAM, RAM is
  # finite, and `max-jobs = auto` across 128 threads will unpack as much as you
  # give it -- cef-binary alone is ~1.9G, and a dozen of those land together.
  # The 128G cap also meant half of this machine's memory could disappear into
  # a build directory.
  #
  # / is a 916G NVMe with 300G+ free, so builds get somewhere effectively
  # unbounded and fast, and ENOSPC stops being a thing that looks like a full
  # disk while `df /` says otherwise. cleanOnBoot keeps the clear-on-restart
  # behaviour tmpfs gave for free.
  boot.tmp = {
    useTmpfs = false;
    cleanOnBoot = true;
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
