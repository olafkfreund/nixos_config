{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.wave;

  gruvboxDark = {
    "display:name" = "Gruvbox Dark";
    "display:order" = 8;
    black = "#282828";
    red = "#cc241d";
    green = "#98971a";
    yellow = "#d79921";
    blue = "#458588";
    magenta = "#b16286";
    cyan = "#689d6a";
    white = "#a89984";
    brightBlack = "#928374";
    brightRed = "#fb4934";
    brightGreen = "#b8bb26";
    brightYellow = "#fabd2f";
    brightBlue = "#83a598";
    brightMagenta = "#d3869b";
    brightCyan = "#8ec07c";
    brightWhite = "#ebdbb2";
    gray = "#7c6f64";
    cmdtext = "#ebdbb2";
    foreground = "#ebdbb2";
    background = "#282828";
    cursor = "#ebdbb2";
    selectionBackground = "#504945";
  };
in
{
  options.wave = {
    enable = mkEnableOption "Wave terminal emulator";
  };

  config = mkIf cfg.enable {
    programs.waveterm.enable = true;

    xdg.configFile."waveterm/termthemes.json".text =
      builtins.toJSON { "gruvbox-dark" = gruvboxDark; };

    xdg.configFile."waveterm/settings.json".text =
      builtins.toJSON { "term:theme" = "gruvbox-dark"; };
  };
}
