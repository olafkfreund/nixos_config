{ pkgs, config, lib, inputs, ... }:
{
  programs.alacritty = {
    enable = true;
    settings = {
      keyboard.bindings = [
        { key = "V";  mods = "Control"; action = "Paste"; }
        { key = "C";  mods = "Control"; action = "Copy"; }
        { key = "N";  mods = "Control|Shift"; action = "CreateNewWindow"; }
      ];

      window.startup_mode = "Windowed";
      window.decorations = "none";
      window.blur = true;
      scrolling.history = 10000;
      selection.save_to_clipboard = false;
      terminal.osc52 = "CopyPaste";
      # font = {
      #   normal.family = "JetBrains Mono Nerd Font";
      #   size = 14;
      #   bold = { style = "Bold"; };
      # };

      # colors = with config.colorScheme.palette; {
      #   primary = {
      #     #background = "0x282828";
      #     #foreground = "0xebdbb2";
      #     background = "0x${base00}";
      #     foreground = "0x${base06}";
      #   };
      #   normal = {
      #     black = "0x${base00}";
      #     blue = "0x${base0D}";
      #     cyan = "0x${base0C}";
      #     green = "0x${base0B}";
      #     magenta = "0x${base0E}";
      #     red = "0x${base08}";
      #     white = "0x${base06}";
      #     yellow = "0x${base0A}";
      #     #black = "0x282828";
      #     #red = "0xcc241d";
      #     #green = "0x98971a";
      #     #yellow = "0xd79921";
      #     #blue = "0x458588";
      #     #magenta = "0xb16286";
      #     #cyan = "0x689d6a";
      #     #white = "0xa89984";
      #   };
      #   bright = {
      #     black = "0x${base01}";
      #     blue = "0x${base0D}";
      #     cyan = "0x${base0C}";
      #     green = "0x${base0B}";
      #     magenta = "0x${base0E}";
      #     red = "0x${base08}";
      #     white = "0x${base06}";
      #     yellow = "0x${base0A}";
      #     #black = "0x928374";
      #     #red = "0xfb4934";
      #     #green = "0xb8bb26";
      #     #yellow = "0xfabd2f";
      #     #blue = "0x83a598";
      #     #magenta = "0xd3869b";
      #     #cyan = "0x8ec07c";
      #     #white = "0xebdbb2";
      #     };
      # };
    };
  };
}
