{ pkgs
, inputs
, ...
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
  ];

  home.packages = [
    inputs.self.packages.${pkgs.system}.claude-code
    inputs.self.packages.${pkgs.system}.opencode
    (pkgs.callPackage ../pkgs/weather-popup/default.nix { })
  ];
}
