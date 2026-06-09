final: _prev: {
  aerion = final.callPackage ../pkgs/aerion { };
  glim = final.callPackage ./glim { };
  intune-portal = final.callPackage ../pkgs/intune-portal { };
  zsh-ai-cmd = final.callPackage ../pkgs/zsh-ai-cmd { };
  claude-code-native = final.callPackage ../pkgs/claude-code-native { };
  warp-terminal = final.callPackage ../pkgs/warp-terminal { };
  waveterm = final.callPackage ../pkgs/waveterm { };
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

  gemini-cli = final.callPackage ../home/development/gemini-cli { };

  # gogcli — Google Workspace CLI (`gog`). Built from the canonical openclaw
  # repo at the latest tag rather than nixpkgs' older steipete 0.11.0.
  gogcli = final.callPackage ../pkgs/gogcli { };

  # GNOME Shell extensions not packaged in nixpkgs. Pinned to the
  # extensions.gnome.org ZIP for the exact version currently active on
  # p620, so the snapshot is byte-stable. Source-of-truth for the UUID +
  # version is the metadata.json inside each zip.
  gnome-ext-claude-code-usage = final.callPackage ../pkgs/gnome-ext-claude-code-usage { };
  gnome-ext-otp-keys = final.callPackage ../pkgs/gnome-ext-otp-keys { };
  gnome-ext-rudra = final.callPackage ../pkgs/gnome-ext-rudra { };
  gnome-ext-spotify-controller = final.callPackage ../pkgs/gnome-ext-spotify-controller { };
  gnome-ext-accent-directories = final.callPackage ../pkgs/gnome-ext-accent-directories { };
  gnome-ext-allow-locked-remote-desktop = final.callPackage ../pkgs/gnome-ext-allow-locked-remote-desktop { };
  # gnome-ext-forge — pinned to master commit (see pkgs/gnome-ext-forge
  # for rationale). Source-of-truth for UUID + version is the metadata.json
  # baked into the upstream commit we pin.
  gnome-ext-forge = final.callPackage ../pkgs/gnome-ext-forge { };

  # YAMIS — monochrome icon theme with FollowsColorScheme + multi-theme
  # fallback chain. Wired via Stylix in modules/desktop/stylix-theme.nix
  # so it applies wherever Stylix's GTK / GNOME targets are enabled.
  yet-another-monochrome-icons = final.callPackage ../pkgs/yet-another-monochrome-icons { };
}
