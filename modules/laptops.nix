{ ... }: {
  imports = [
    ./system-tweaks/storage-tweaks/SSD/SSD-tweak.nix
    ./system-tweaks/kernel-tweaks/32GB-SYSTEM/32GB-SYSTEM.nix
    ./laptop-related/autorandr.nix
    ./laptop-related/earlyoom.nix
    ./laptop-related/zram.nix
    ./hardware/openrazer.nix
  ];


}

