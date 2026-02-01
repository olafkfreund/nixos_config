{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.ghostty;
in
{
  options.ghostty = {
    enable = mkEnableOption "Ghostty terminal emulator";
  };

  config = mkIf cfg.enable {
    programs.ghostty = {
      enable = true;
      package = pkgs.ghostty;
      settings = {
        # Appearance
        # theme = "GruvboxDark"; # Disabled - let Stylix manage the theme
        font-family = "JetBrainsMono Nerd Font";
        font-size = 12;

        # Window settings
        window-decoration = true;
        window-padding-x = 12;
        window-padding-y = 12;
        window-width = 120;
        window-height = 32;

        # Terminal behavior
        confirm-close-surface = false;
        mouse-hide-while-typing = true;

        # Shell integration
        shell-integration-features = "no-cursor";

        # Cursor settings
        cursor-style = "underline";

        # Clipboard settings
        clipboard-read = "allow";
        clipboard-write = "allow";
        # selection-word-separators = " \t\n()[]{}<>|:;,+=\"'";
        # Keybindings
        # keybind = [
        #   "performable:super+c=copy_to_clipboard"
        #   "super+shift+h=goto_split:left"
        #   "super+shift+j=goto_split:bottom"
        #   "super+shift+k=goto_split:top"
        #   "super+shift+l=goto_split:right"
        #   "ctrl+page_up=jump_to_prompt:-1"
        #   "ctrl+page_down=jump_to_prompt:1"
        #   "ctrl+shift+n=new_window"
        #   "ctrl+shift+t=new_tab"
        #   "ctrl+shift+w=close_surface"
        #   "ctrl+shift+l=next_tab"
        #   "ctrl+shift+h=previous_tab"
        #   "ctrl+equal=increase_font_size"
        #   "ctrl+minus=decrease_font_size"
        #   "ctrl+0=reset_font_size"
        # ];
      };
    };
  };
}
