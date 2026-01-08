{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, dbus
, openssl
, libxkbcommon
, wayland
, just
}:

rustPlatform.buildRustPackage rec {
  pname = "cosmic-ext-applet-music-player";
  version = "1.0.0-unstable-2026-01-08";

  src = fetchFromGitHub {
    owner = "Ebbo";
    repo = "cosmic-applet-music-player";
    rev = "1fe94a89a85be34b867ee94268e46e7fd72e88b8"; # Latest commit as of 2026-01-08
    hash = "sha256-GAIzV/BdU4SOV6P+qNGWmPzF5mvNym9D99/7Hg5/Amc=";
  };

  # BLOCKER: Upstream Cargo.lock has duplicate package entries
  # The upstream Cargo.lock contains 4 duplicate [[package]] entries for packages
  # from the libcosmic git repository due to inconsistent URL formats:
  #   - Some entries use: git+https://github.com/pop-os/libcosmic.git#52b802a...
  #   - Other entries use: git+https://github.com/pop-os/libcosmic.git?rev=52b802a#52b802a...
  #
  # This causes Nix's cargo vendoring to fail with FileExistsError when trying to
  # create the same vendor directory twice for packages like:
  #   - cosmic-config-0.1.0
  #   - cosmic-client-toolkit-0.1.0
  #   - clipboard_macos-0.1.0
  #   - clipboard_wayland-0.2.2
  #
  # Attempted fixes:
  #   1. postPatch with sed to unify URLs - doesn't work (vendoring happens before patch)
  #   2. Custom deduplicated Cargo.lock - doesn't work (cargoHash uses original Cargo.lock)
  #
  # Resolution: Report upstream to https://github.com/Ebbo/cosmic-applet-music-player
  # Request: Run `cargo update` to regenerate Cargo.lock with unified git URLs
  #
  # NOTE: This derivation is work-in-progress and CANNOT be built until upstream
  # fixes their Cargo.lock file.

  cargoHash = "sha256-Cs9g2w480jquSNyEG41WqOEMPQ/BJKcOgN8VnCfZBLQ=";

  # Build the specific workspace member
  buildAndTestSubdir = "music-player";

  nativeBuildInputs = [
    pkg-config # Required for finding system libraries
    just # Build tool used upstream
  ];

  buildInputs = [
    dbus # MPRIS D-Bus protocol
    openssl # HTTPS for album artwork fetching
    libxkbcommon # Wayland keyboard support
    wayland # Wayland display protocol
  ];

  strictDeps = true;

  # Disable tests that may require D-Bus session
  doCheck = false;

  # Use just for installation to match upstream build process
  dontUseJustInstall = false;
  justFlags = [
    "--set"
    "prefix"
    (placeholder "out")
    "--set"
    "rootdir"
    ""
  ];

  meta = with lib; {
    description = "Music Player applet with MPRIS integration for the COSMIC desktop";
    longDescription = ''
      A modern music player applet for the COSMIC desktop with MPRIS integration.

      Features:
      - Play/Pause, track navigation (previous/next)
      - Real-time status display with song metadata
      - Album artwork rendering with HTTPS fetching
      - Volume adjustment via precision slider
      - Auto-discovery of MPRIS-compatible players
      - Works with Spotify, VLC, MPD, Rhythmbox, and more

      The applet integrates seamlessly with the COSMIC panel, providing
      middle-click play/pause and scroll wheel track navigation.
    '';
    homepage = "https://github.com/Ebbo/cosmic-applet-music-player";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
    mainProgram = "cosmic-ext-applet-music-player";
  };
}
