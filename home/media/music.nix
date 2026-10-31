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
    pkgs.customPkgs.mpris-album-art
  ];

  # MPRIS for every mpv (media keys, playerctl, the Omarchy media widget).
  xdg.configFile."mpv/scripts/mpris.so".source = "${pkgs.mpvScripts.mpris}/share/mpv/scripts/mpris.so";

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
