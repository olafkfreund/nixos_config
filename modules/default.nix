{...}: {
  imports = [
    ./nix/nix.nix
    ./services/xserver/xserver.nix
    ./virt/virt.nix
    ./services/bluetooth/bluetooth.nix
    ./services/sound/sound.nix
    ./services/openssh/openssh.nix
    ./programs/hyprland/hypr.nix
    ./services/xserver/xdg-portal.nix
    ./fonts/fonts.nix
    ./programs/1password/1password.nix
    ./programs/steam/steam.nix
    ./programs/gnupg/gnupg.nix
    ./programs/dconf/dconf.nix
    ./services/mtr/mtr.nix
    ./services/printing/print.nix
    ./services/flatpak/flatpak.nix
  ];


}
