final: _prev: {
  glim = final.callPackage ./glim { };
  intune-portal = final.callPackage ../pkgs/intune-portal { };
  zsh-ai-cmd = final.callPackage ../pkgs/zsh-ai-cmd { };
  claude-code-native = final.callPackage ../pkgs/claude-code-native { };
  warp-terminal = final.callPackage ../pkgs/warp-terminal { };
  gemini-cli = final.callPackage ../home/development/gemini-cli { };

  # splashboard — Rust TUI splash screen for shell startup. Needs rustc
  # 1.95+ (sysinfo 0.39 transitive), which nixpkgs doesn't ship yet, so
  # we build with the latest stable from rust-overlay via a custom
  # rustPlatform.
  splashboard =
    let
      rustToolchain = final.rust-bin.stable.latest.default;
      rustPlatform = final.makeRustPlatform {
        cargo = rustToolchain;
        rustc = rustToolchain;
      };
    in
    final.callPackage ../pkgs/splashboard { inherit rustPlatform; };
}
