{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  inherit (config.lib.stylix) colors;
  c = colors.withHashtag;
  cfg = config.wave;

  # Stylix has no waveterm target, so the 16 ANSI slots are wired from the
  # active base16 scheme by hand. Trade-off (same as the GNOME Terminal
  # palette in home/desktop/gnome/theme.nix): base16 defines only one tone per
  # accent, so the normal and bright slots share a value.
  alienHud = {
    "display:name" = "Alien HUD";
    "display:order" = 8;
    black = c.base00;
    red = c.base08;
    green = c.base0B;
    yellow = c.base0A;
    blue = c.base0D;
    magenta = c.base0E;
    cyan = c.base0C;
    white = c.base05;
    brightBlack = c.base03;
    brightRed = c.base08;
    brightGreen = c.base0B;
    brightYellow = c.base0A;
    brightBlue = c.base0D;
    brightMagenta = c.base0E;
    brightCyan = c.base0C;
    brightWhite = c.base07;
    gray = c.base04;
    cmdtext = c.base05;
    foreground = c.base05;
    background = c.base00;
    cursor = c.base05;
    selectionBackground = c.base02;
  };
in
{
  options.wave = {
    enable = mkEnableOption "Wave terminal emulator";
  };

  config = mkIf cfg.enable {
    programs.waveterm.enable = true;

    xdg.configFile."waveterm/termthemes.json".text =
      builtins.toJSON { "alien-hud" = alienHud; };

    xdg.configFile."waveterm/settings.json".text =
      builtins.toJSON { "term:theme" = "alien-hud"; };
  };
}
