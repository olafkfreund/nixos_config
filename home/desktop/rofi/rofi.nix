{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.desktop.rofi;
in {
  options.desktop.rofi = {
    enable = mkEnableOption {
      default = false;
      description = "rofi";
    };
  };
  config = mkIf cfg.enable {
    home.file = {
      ".config/rofi/rofi-powermenu-gruvbox-config.rasi".source = ../config/rofi/rofi-powermenu-gruvbox-config.rasi;
      ".config/rofi/rofi.rasi".source = ../config/rofi/rofi.rasi;
      ".config/rofi/gruvbox.rasi".source = ../config/rofi/gruvbox.rasi;
    };
    programs.rofi = {
      enable = true;
      package = pkgs.rofi-wayland;
      extraConfig = {
        bw = 1;
        modi = "drun,window,filebrowser,run";
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
  };
}
