{...}: {
  imports = [
    # ./system-tweaks/storage-tweaks/SSD/SSD-tweak.nix
    # ./system-tweaks/kernel-tweaks/64GB-SYSTEM/64gb-system.nix
    ./laptop-related/earlyoom.nix
    ./laptop-related/zram.nix
    ./hardware/openrazer.nix
    ./laptop-related/udev.nix
  ];
}
