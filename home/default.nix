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

  # Enable Claude Code via home-manager's built-in module
  # Options for package:
  #   - inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.claude-code  # Our npm package (latest: 2.1.19)
  #   - pkgs.claude-code-native  # Native binary (faster startup, version: 2.1.19)
  #   - pkgs.claude-code  # nixpkgs version (may be older)
  programs.claude-code = {
    enable = true;
    # Use our npm package for the latest version
    package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
  };

  home.packages = [
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.opencode
    (pkgs.callPackage ../pkgs/weather-popup/default.nix { })
  ];
}
