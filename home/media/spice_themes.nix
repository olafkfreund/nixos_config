{
  inputs,
  pkgs,
  ...
}: let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.system};
in {
  programs.spicetify = {
    enable = true;
    theme = spicePkgs.themes.onepunch;
    colorScheme = "dark";

    # Wayland optimizations
    spotifyPackage = pkgs.spotify.override {
      # Enable hardware acceleration for better Wayland performance
      deviceScaleFactor = 1.0;
      commandLineArgs = [
        "--enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer"
        "--ozone-platform=wayland"
        "--enable-wayland-ime"
        "--enable-gpu-rasterization"
        "--enable-zero-copy"
        "--force-dark-mode"
      ];
    };

    enabledCustomApps = with spicePkgs.apps; [
      reddit
      lyricsPlus
      newReleases
    ];

    enabledExtensions = with spicePkgs.extensions; [
      fullAppDisplay
      shuffle # shuffle+ (special characters are sanitized out of ext names)
      playlistIcons
      hidePodcasts
      adblock
      historyShortcut
      bookmark
      fullAlbumDate
      groupSession
      lastfm
      popupLyrics
    ];

    # Custom CSS for better Wayland integration
    cssPatcher = cssData: ''
      ${cssData}

      /* Wayland optimization: Fix window dragging in Wayland */
      .spotify__os--is-linux .main-topBar-container {
        -webkit-app-region: drag;
      }

      /* Wayland optimization: Smoother animations and transitions */
      * {
        transition-property: background-color, border-color, color, fill, stroke;
        transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
        transition-duration: 300ms;
      }

      /* Wayland optimization: Fix potential blurry text */
      body {
        text-rendering: optimizeLegibility;
        -webkit-font-smoothing: antialiased;
      }
    '';
  };
}
