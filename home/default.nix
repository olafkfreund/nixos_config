{
  pkgs,
  inputs,
  ...
}: {
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
    inputs.self.packages.${pkgs.system}.claude-code
    (pkgs.callPackage ../pkgs/weather-popup/default.nix {})
  ];
}
