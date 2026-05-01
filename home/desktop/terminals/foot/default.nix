{ pkgs
, config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.foot;
in
{
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
        # foot deprecated [colors] in favor of [colors-dark]
        # Stylix injects colors.alpha and the include file uses [colors]
        # This is an upstream issue in Stylix/tinted-theming templates
      };
    };
  };
}
