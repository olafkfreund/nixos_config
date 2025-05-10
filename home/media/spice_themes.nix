{
  inputs,
  pkgs,
  lib,
  ...
}: let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.system};
in {
  stylix.targets = {
    spicetify.enable = false;
  };

  programs.spicetify = {
    enable = true;

    # Use the proper theme format directly from spicePkgs
    theme = spicePkgs.themes.onepunch;
    colorScheme = "dark";

    # Spotify wayland configuration is now handled by the module
    # with these settings
    spotifyPackage = pkgs.spotify;
    spotifyLaunchFlags = "--enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer --ozone-platform=wayland --enable-wayland-ime --enable-gpu-rasterization --enable-zero-copy --force-dark-mode";

    # # Environment variables for Wayland
    # spotifyEnv = {
    #   ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    #   NIXOS_OZONE_WL = "1";
    #   GDK_SCALE = "1.0";
    # };

    # Custom apps configuration
    enabledCustomApps = with spicePkgs.apps; [
      reddit
      lyricsPlus
      newReleases
    ];

    # Extensions configuration
    enabledExtensions = with spicePkgs.extensions; [
      fullAppDisplay
      shuffle
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
  };

  # Spicetify is now managed by the module, so we don't need the setup script
  # The CLI is also installed automatically when the module is enabled
  # home.packages = [
  #   pkgs.spicetify-cli
  # ];
}
