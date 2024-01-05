{...}: {
  imports = [
    ./boot.nix
    ./nix.nix
    ./i18n.nix
    ./xserver.nix
    ./nvidia.nix
    ./virt.nix
    ./bluetooth.nix
    ./sound.nix
    ./openrazer.nix
    ./hypr.nix
    ./hosts.nix
    ./xdg-portal.nix
    ./system-tweaks/storage-tweaks/SSD/SSD-tweak.nix
    ./system-tweaks/kernel-tweaks/32GB-SYSTEM/32GB-SYSTEM.nix
    ./laptop-related/autorandr.nix
    #./udev.nix
    ./fonts.nix
    ./earlyoom.nix
    ./zram.nix
    ./1password.nix
    ./steam.nix
    ./programs.nix
    ./envvar.nix
    ./services.nix
  ];


}
