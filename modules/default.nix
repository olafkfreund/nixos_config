{ ... }: {
  imports = [
    ./nix/nix.nix
    ./fonts/fonts.nix
    ./programs/default.nix
    ./services/default.nix
    ./security/default.nix
    ./virt/default.nix
    ./system-tweaks/storage-tweaks/SSD/SSD-tweak.nix
    ./system-tweaks/kernel-tweaks/32GB-SYSTEM/32GB-SYSTEM.nix
    ./laptop-related/autorandr.nix
    ./laptop-related/earlyoom.nix
    ./laptop-related/zram.nix
    ./hardware/openrazer.nix
    ./pkgs/default.nix
    ./overlays/default.nix
    ./system-scripts/default.nix
    ./nix-index/default.nix

  ];


}
