{ pkgs, ... }: {

home.packages = with pkgs; [
  #spotify
  #spicetify-cli
  ncspot
  plexamp
  vlc
  cava
];

}
