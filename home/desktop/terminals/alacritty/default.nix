{ pkgs, config, lib, inputs, ... }:
{
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        normal.family = "JetBrains Mono Nerd Font";
        size = 14;
        bold = { style = "Bold"; };
      };

      colors = with config.colorScheme.palette; {
        primary = {
          #background = "0x282828";
          #foreground = "0xebdbb2";
          background = "0x${base00}";
          foreground = "0x${base06}";
        };
        normal = {
          black = "0x${base00}";
          blue = "0x${base0D}";
          cyan = "0x${base0C}";
          green = "0x${base0B}";
          magenta = "0x${base0E}";
          red = "0x${base08}";
          white = "0x${base06}";
          yellow = "0x${base0A}";
          #black = "0x282828";
          #red = "0xcc241d";
          #green = "0x98971a";
          #yellow = "0xd79921";
          #blue = "0x458588";
          #magenta = "0xb16286";
          #cyan = "0x689d6a";
          #white = "0xa89984";
        };
      };
    };
  };
}
