{
  pkgs,
  config,
  ...
}: {
  # Bootloader for VM environment
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # VM-specific kernel parameters
  boot.kernelParams = [];

  boot.kernel.sysctl = {
    "vm.max_map_count" = 1048576;
  };
}
