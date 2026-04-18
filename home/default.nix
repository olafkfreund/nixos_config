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

  # Enable Claude Code via home-manager's built-in module.
  #
  # Using pkgs.claude-code-native: pre-built binaries from Anthropic's GCS
  # bucket (no Node.js runtime, faster startup, immune to npm-side
  # repackaging like the 2.1.113 optionalDependencies refactor).
  # Tracks the `latest` channel. Update with:
  #   ./scripts/update-claude-code-native.sh <version>
  #
  # Alternatives (kept for reference, not used):
  #   - pkgs.claude-code  # nixpkgs version, often lags
  #   - inputs.self.packages.${system}.claude-code  # legacy npm package,
  #     stuck at 2.1.112 due to upstream packaging change
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code-native;
  };

  home.packages = [
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.opencode
    (pkgs.callPackage ../pkgs/weather-popup/default.nix { })
  ];
}
