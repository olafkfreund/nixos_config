{ pkgs, ... }:

pkgs.writeShellScriptBin "album_art" ''
  album_art=$(playerctl -p spotify metadata mpris:artUrl)
  if [[ -z $album_art ]]
  then
     exit
  fi
  curl -s  "''${album_art}" --output "/tmp/cover.jpeg"
  echo "/tmp/cover.jpeg"
''

