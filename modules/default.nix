{...}: {
  imports = [
    ./nix/nix.nix
    ./fonts/fonts.nix
    ./programs/hyprland/hypr.nix
    ./programs/1password/1password.nix
    ./programs/steam/steam.nix
    ./programs/gnupg/gnupg.nix
    ./programs/dconf/dconf.nix
    ./services/mtr/mtr.nix
    ./services/printing/print.nix
    ./services/flatpak/flatpak.nix
    ./services/xserver/xdg-portal.nix
    ./services/xserver/xserver.nix
    ./services/bluetooth/bluetooth.nix
    ./services/sound/sound.nix
    ./services/openssh/openssh.nix
    ./virt/virt.nix
  ];


}
