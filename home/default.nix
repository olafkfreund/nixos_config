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
    ./syncthing-stignore.nix
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

  # `claude /doctor` checks the literal path ~/.local/bin/claude and warns
  # if it's missing — independent of whether `claude` is already on PATH.
  # Point the path at the same nix-managed binary so /doctor stays quiet.
  home.file.".local/bin/claude".source = "${pkgs.claude-code-native}/bin/claude";

  # Enable Claude Code "Agent Teams" — experimental feature that lets one
  # Claude session spawn a team of coordinated teammates (separate sessions
  # with their own context windows that can talk to each other).
  # Requires Claude Code v2.1.32+ (we're on 2.1.145). Per the docs, setting
  # this env var or putting it under "env" in settings.json both work; the
  # env-var route lets ~/.claude/settings.json remain runtime-mutable for
  # plugin/theme changes via /config.
  # https://code.claude.com/docs/en/agent-teams
  home.sessionVariables.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";

  home.packages = [
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.opencode
    (pkgs.callPackage ../pkgs/weather-popup/default.nix { })

    # tesseract OCR with explicit language packs only — passing
    # enableLanguages = null bundles all ~130 languages (~500MB).
    # Bokmål covers most Norwegian use; tesseract has no separate Nynorsk.
    (pkgs.tesseract.override {
      enableLanguages = [ "eng" "pol" "nor" ];
    })
  ];
}
