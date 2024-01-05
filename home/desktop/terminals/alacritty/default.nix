{ pkgs, config, ... }:

{
    programs.alacritty = {
      enable = true;
      settings = {
        font = {
          normal.family = "JetBrains Mono Nerd Font";
          size = 11;
          bold = { style = "Bold"; };
        };

        cursor = {
          text= "0x000000";
          cursor= "0xe0e0e0";
        };

        colors = {
          primary = {
            background = "0x282828";
            foreground = "0xebdbb2";
          };
          normal = {
            black = "0x282828";
            red = "0xcc241d";
            green = "0x98971a";
            yellow = "0xd79921";
            blue = "0x458588";
            magenta = "0xb16286";
            cyan = "0x689d6a";
            white = "0xa89984";
          };
        };
      };
    };
}
