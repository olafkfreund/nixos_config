{ pkgs, ... }:
{
  home.packages = [
    pkgs.spotify
    pkgs.plexamp
    pkgs.vlc
    pkgs.cava
    pkgs.castero
    pkgs.gnome-podcasts
    pkgs.hypnotix
    pkgs.wiremix
    pkgs.parabolic
    pkgs.musicpod
    pkgs.pear-desktop # YouTube Music desktop client (formerly th-ch/youtube-music)
    pkgs.playerctl
    (pkgs.callPackage ../../pkgs/mpris-album-art { })
  ];

  # Native Spotify runs under Xwayland so mutter draws server-side
  # decorations; delegate decoration drawing to the compositor.
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
