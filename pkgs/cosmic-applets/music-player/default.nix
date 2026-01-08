{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, dbus
, openssl
, libpulseaudio
, libxkbcommon
, wayland
}:

# NOTE: This package currently has a known build issue due to duplicate Cargo.lock entries
# in the upstream libcosmic dependencies. See: https://github.com/olafkfreund/nixos_config/issues/128
#
# The issue is that Cargo.lock contains duplicate package entries for cosmic-config, iced_core,
# iced_futures, and cosmic-config-derive due to inconsistent git URL formatting in libcosmic.
# This causes cargo vendor to fail with FileExistsError during vendoring.
#
# The package is disabled by default in the COSMIC module until this upstream issue is resolved.

rustPlatform.buildRustPackage rec {
  pname = "cosmic-ext-applet-music-player";
  version = "1.0.0-unstable-2026-01-08";

  src = fetchFromGitHub {
    owner = "olafkfreund";
    repo = "cosmic-applet-music-player";
    rev = "0aa17bd7e1cfde219657c434b334c0c39ca530cb"; # Latest commit as of 2026-01-08
    hash = "sha256-MxwxJHxdg44B6rvoDpIERoiP4TA6AAU/LdCTxF2G+PA=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    outputHashes = {
      # All libcosmic dependencies use the same commit, consolidate to single hash
      "cosmic-client-toolkit-0.1.0" = "sha256-Brmxt10B7aRoISDbxX1ORIj76ygVi5kVgUJGW9hXGwY=";
      "cosmic-config-0.1.0" = "sha256-Brmxt10B7aRoISDbxX1ORIj76ygVi5kVgUJGW9hXGwY=";
      "cosmic-config-derive-0.1.0" = "sha256-Brmxt10B7aRoISDbxX1ORIj76ygVi5kVgUJGW9hXGwY=";
      "iced_core-0.14.0" = "sha256-Brmxt10B7aRoISDbxX1ORIj76ygVi5kVgUJGW9hXGwY=";
      "iced_futures-0.14.0" = "sha256-Brmxt10B7aRoISDbxX1ORIj76ygVi5kVgUJGW9hXGwY=";
    };
  };

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    dbus # MPRIS D-Bus communication
    openssl # HTTPS album artwork fetching
    libpulseaudio # PulseAudio/PipeWire volume control
    libxkbcommon # Keyboard input
    wayland # Wayland support
  ];

  # This is a workspace project, we need to build the music-player member
  buildAndTestSubdir = "music-player";

  strictDeps = true;

  meta = with lib; {
    description = "COSMIC panel applet for controlling MPRIS-compatible music players with album artwork";
    longDescription = ''
      A music player applet for the COSMIC desktop panel that provides integrated
      music controls using the MPRIS D-Bus protocol.

      Features:
      - Play/pause, track navigation (previous/next)
      - Real-time status display with song metadata
      - Album artwork rendering with HTTPS fetching
      - Volume adjustment via precision slider
      - Auto-discovery of MPRIS-compatible players
      - Player selection via radio buttons
      - Toggleable auto-detection for newly-launched apps

      Compatible with: Spotify, VLC, MPD, ncspot, plexamp, spotify-player,
      musicpod, and any other MPRIS-compatible media player.

      Note: Requires MPRIS-compatible music players to be installed.
    '';
    homepage = "https://github.com/Ebbo/cosmic-applet-music-player";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
    mainProgram = "cosmic-ext-applet-music-player";
  };
}
