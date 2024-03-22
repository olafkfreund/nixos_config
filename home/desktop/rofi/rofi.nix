{ config
, lib
, pkgs
, ...
}: {
  home.file = {
    ".config/rofi/rofi-powermenu-gruvbox-config.rasi".source = ../config/rofi/rofi-powermenu-gruvbox-config.rasi;
    ".config/rofi/rofi.rasi".source = ../config/rofi/rofi.rasi;
    ".config/rofi/gruvbox.rasi".source = ../config/rofi/gruvbox.rasi;
  };
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    font = "JetBrains Mono Nerd Font 16px";
    theme = ../config/rofi/rofi.rasi;
    extraConfig = {
      bw = 1;
      modi ="drun,window,filebrowser,run";
      show-icons = true;
      terminal = "kitty";
      display-drun = " ";
      display-run = " ";
      display-filebrowser = " ";
      display-window = " ";
      drun-display-format = "{name}";
      window-format = "{w}{c}";
      display-emoji = "🔎 ";
      icon-theme = "gruvbox-dark";
    };
  };
  home.packages = with pkgs; [
  
  rofi-wayland
  rofimoji
  rofi-emoji
  rofi-power-menu
  rofi-top
  rofi-systemd
  rofi-bluetooth
  rofi-screenshot
  rofi-file-browser
  ];
}
