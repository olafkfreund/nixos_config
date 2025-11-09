{ inputs
, pkgs
, lib
, ...
}:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.system};
in
{
  programs.spicetify = {
    # Temporarily disabled due to upstream syntax error in spicetify-nix
    # Error: simpleBeautifulLyrics extension has syntax error at extensions.nix:197
    # TODO: Re-enable when upstream fixes the issue
    enable = false;

    # Switch from onepunch to Gruvbox theme
    theme = lib.mkDefault spicePkgs.themes.onepunch;
    colorScheme = lib.mkDefault "dark";

    # Spotify wayland configuration
    spotifyPackage = pkgs.spotify;
    spotifyLaunchFlags = "--enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer --ozone-platform=wayland --enable-wayland-ime --enable-gpu-rasterization --enable-zero-copy --force-dark-mode";

    # Useful Spotify extensions
    enabledCustomApps = with spicePkgs.apps; [
      reddit
      lyricsPlus
      newReleases
    ];

    enabledExtensions = with spicePkgs.extensions; [
      fullAppDisplay
      playlistIcons
      adblock
      historyShortcut
      fullAlbumDate
    ];

    # Custom color scheme for Gruvbox
    customColorScheme = {
      text = "ebdbb2";
      subtext = "d5c4a1";
      sidebar-text = "ebdbb2";
      main = "282828";
      sidebar = "282828";
      player = "282828";
      card = "32302f";
      shadow = "1d2021";
      selected-row = "504945";
      button = "98971a";
      button-active = "b8bb26";
      button-disabled = "7c6f64";
      tab-active = "98971a";
      notification = "98971a";
      notification-error = "cc241d";
      misc = "689d6a";
    };
  };
}
