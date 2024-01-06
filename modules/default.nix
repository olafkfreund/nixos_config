{...}: {
  imports = [
    ../core/boot/default.nix
    ./nix/default.nix
    ./bluetooth/default.nix
    ./audio/default.nix
    ./fonts/default.nix
    ./multi-threading
    ./zram
    ./envvar.nix
    ./services
    ./programs
  ];


}
