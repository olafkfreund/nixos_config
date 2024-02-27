{ config
, lib
, pkgs
, ...
}: {
  home.file = {
    ".config/rofi/rofi-powermenu-gruvbox-config.rasi".source = ../config/rofi/rofi-powermenu-gruvbox-config.rasi;
    ".config/rofi/rofi-launcher-gruvbox-config.rasi".source = ../config/rofi/rofi-launcher-gruvbox-config.rasi;
    ".config/rofi/gruvbox.rasi".source = ../config/rofi/gruvbox.rasi;
  };
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    font = "JetBrainsMono Nerd Font Medium 8";
    theme = ../config/rofi/rofi-launcher-gruvbox-config.rasi;
    extraConfig = {
      bw = 1;
      # border = "10px solid";
      border-radius = "10px solid";
      scrollbar = false;
      show-icons = true;
      display-drun = "  ";
      drun-display-format = "{name}";
      icon-theme = "gruvbox-dark";
    };
  };
}
