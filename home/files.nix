{ pkgs, config, ... }:

{
  # Place Files Inside Home Directory
  home.file.".emoji".source = ./files/emoji;
  home.file.".base16-themes".source = ./files/base16-themes;
  # home.file.".local/share/fonts" = {
  #   source = ./files/fonts;
  #   recursive = true;
  # };
}
