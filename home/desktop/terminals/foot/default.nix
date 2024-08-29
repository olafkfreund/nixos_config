{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.foot;
in {
  options.foot = {
    enable = mkEnableOption {
      default = false;
      description = "foot terminal emulator";
    };
  };
  config = mkIf cfg.enable {
    programs.foot = {
      enable = true;
      package = pkgs.foot;
      settings = {
        main = {
          pad = "12x12";
          term = "xterm-256color";
          selection-target = "clipboard";
        };
        colors = {
          foreground = "${config.colorScheme.palette.base06}";
          background = "${config.colorScheme.palette.base00}";
          ## Normal/regular colors (color palette 0-7)
          regular0 = "${config.colorScheme.palette.base00}"; # black
          regular1 = "${config.colorScheme.palette.base08}";
          regular2 = "${config.colorScheme.palette.base0B}";
          regular3 = "${config.colorScheme.palette.base09}";
          regular4 = "${config.colorScheme.palette.base0D}";
          regular5 = "${config.colorScheme.palette.base0D}";
          regular6 = "${config.colorScheme.palette.base0C}";
          regular7 = "${config.colorScheme.palette.base06}";

          bright0 = "393a4d"; # bright black
          bright1 = "e95678"; # bright red
          bright2 = "29d398"; # bright green
          bright3 = "efb993"; # bright yellow
          bright4 = "26bbd9";
          bright5 = "b072d1"; # bright magenta
          bright6 = "59e3e3"; # bright cyan
          bright7 = "d9e0ee"; # bright white
        };
      };
    };
  };
}
