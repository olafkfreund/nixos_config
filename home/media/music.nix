{ pkgs,  pkgs-stable, ... }: {

home.packages = with pkgs; [
  #spotify
  #spicetify-cli
  ncspot # Spotify
  plexamp # Plex
  vlc # video player
  cava # audio visualizer
  spotify-player # Spotify
  sptlrx # Spotify Lyrics

];

}
