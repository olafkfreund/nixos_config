{pkgs, ...}: {
  imports = [
    ./browsers/default.nix
    ./desktop/default.nix
    # ./games/steam.nix
    ./shell/default.nix
    ./development/default.nix
    ./media/music.nix
    ./media/spice_themes.nix
    ./files.nix
    ./chat/default.nix
  ];

  home.packages = [
    (import ../development/claude-code/default.nix {
      inherit (pkgs) lib buildNpmPackage fetchurl nodejs makeWrapper writeShellScriptBin;
    })
  ];
}
