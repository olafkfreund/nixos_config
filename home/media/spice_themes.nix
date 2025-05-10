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

    # Wayland optimizations using the wrapper approach
    spotifyPackage = pkgs.symlinkJoin {
      name = "spotify-wayland";
      pname = "spotify-wayland"; # Added pname attribute to satisfy the module's check
      version = pkgs.spotify.version; # Added version attribute from the original Spotify package
      paths = [ pkgs.spotify ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/spotify \
          --add-flags "--enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer" \
          --add-flags "--ozone-platform=wayland" \
          --add-flags "--enable-wayland-ime" \
          --add-flags "--enable-gpu-rasterization" \
          --add-flags "--enable-zero-copy" \
          --add-flags "--force-dark-mode" \
          --set ELECTRON_OZONE_PLATFORM_HINT wayland \
          --set NIXOS_OZONE_WL 1 \
          --set GDK_SCALE 1.0
      '';
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

    # # Custom CSS for better Wayland integration
    # cssTheme = ''
    #   /* Wayland optimization: Fix window dragging in Wayland */
    #   .spotify__os--is-linux .main-topBar-container {
    #     -webkit-app-region: drag;
    #   }

    #   /* Wayland optimization: Smoother animations and transitions */
    #   * {
    #     transition-property: background-color, border-color, color, fill, stroke;
    #     transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
    #     transition-duration: 300ms;
    #   }

    #   /* Wayland optimization: Fix potential blurry text */
    #   body {
    #     text-rendering: optimizeLegibility;
    #     -webkit-font-smoothing: antialiased;
    #   }
    # '';
  };
}
