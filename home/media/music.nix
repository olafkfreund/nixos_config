{ pkgs, spicetify-nix, ... }:
let
  spicePkgs = spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages = [
    # Spotify provided by programs.spicetify below
    pkgs.plexamp
    pkgs.vlc
    pkgs.cava
    pkgs.castero
    pkgs.gnome-podcasts
    pkgs.hypnotix
    pkgs.wiremix
    pkgs.parabolic
    pkgs.musicpod
    pkgs.playerctl
    (pkgs.callPackage ../../pkgs/mpris-album-art { })
  ];

  # Opt out of stylix's auto-generated spicetify theme so the explicit
  # Gruvbox choice below wins (same pattern as stylix.targets.firefox).
  stylix.targets.spicetify.enable = false;

  programs.spicetify = {
    enable = true;
    theme = spicePkgs.themes.text;
    colorScheme = "Gruvbox";
    # Force Xwayland so mutter draws server-side decorations.
    wayland = false;
    enabledExtensions = with spicePkgs.extensions; [
      adblock
      hidePodcasts
      shuffle
      fullAppDisplay
    ];
  };

  # spicetify-nix's spotifyLaunchFlags only writes to config-xpui.ini and
  # never reaches the runtime wrapper. Override the desktop entry instead
  # so Chromium delegates decoration drawing to the compositor (combined
  # with --ozone-platform=x11 from `wayland = false` above).
  xdg.desktopEntries.spotify = {
    name = "Spotify";
    genericName = "Music Player";
    exec = "spotify --enable-features=WaylandWindowDecorations %U";
    icon = "spotify";
    terminal = false;
    type = "Application";
    categories = [ "Audio" "Music" "Player" "AudioVideo" ];
    mimeType = [ "x-scheme-handler/spotify" ];
    settings.StartupWMClass = "Spotify";
  };
}
