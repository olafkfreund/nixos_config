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
          # Terminal configuration
          pad = "12x12";
          term = "xterm-256color";
          selection-target = "clipboard";
          shell = "${pkgs.zsh}/bin/zsh";
        };
        # Mouse bindings
        mouse-bindings = {
          primary-paste = "BTN_MIDDLE";
          select-begin = "BTN_LEFT";
          select-begin-block = "Control+BTN_LEFT";
          select-word = "BTN_LEFT-2";
          select-word-whitespace = "Control+BTN_LEFT-2";
        };
        key-bindings = {
          # Custom key bindings
          scrollback-up-page = "Shift+Page_Up";
          scrollback-down-page = "Shift+Page_Down";
          clipboard-copy = "Control+Shift+c XF86Copy";
          clipboard-paste = "Control+Shift+v XF86Paste";
          font-increase = "Control+plus Control+equal Control+KP_Add";
          font-decrease = "Control+minus Control+KP_Subtract";
          font-reset = "Control+0 Control+KP_0";
        };

        search-bindings = {
          cancel = "Control+g Control+c Escape";
          find-prev = "Control+r";
          find-next = "Control+s";
        };
        # Color scheme
        colors = {
          foreground = "${config.colorScheme.palette.base06}";
          background = "${config.colorScheme.palette.base00}";
          ## Normal/regular colors (color palette 0-7)
          regular0 = "${config.colorScheme.palette.base00}"; # black
          regular1 = "${config.colorScheme.palette.base08}";
          regular2 = "${config.colorScheme.palette.base0B}";
          regular3 = "${config.colorScheme.palette.base09}";
          regular4 = "${config.colorScheme.palette.base0D}";
          regular5 = "${config.colorScheme.palette.base0E}";
          regular6 = "${config.colorScheme.palette.base0C}";
          regular7 = "${config.colorScheme.palette.base06}";

          # Bright colors (color palette 8-15)
          bright0 = "${config.colorScheme.palette.base01}"; # bright black
          bright1 = "${config.colorScheme.palette.base08}"; # bright red
          bright2 = "${config.colorScheme.palette.base0B}"; # bright green
          bright3 = "${config.colorScheme.palette.base09}"; # bright yellow
          bright4 = "${config.colorScheme.palette.base0D}"; # bright blue
          bright5 = "${config.colorScheme.palette.base0E}"; # bright magenta
          bright6 = "${config.colorScheme.palette.base0C}"; # bright cyan
          bright7 = "${config.colorScheme.palette.base07}"; # bright white
        };
      };
    };
  };
}
