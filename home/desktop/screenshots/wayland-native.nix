{ config
, pkgs
, lib
, ...
}:
with lib; let
  cfg = config.desktop.screenshots.wayland;
in
{
  options.desktop.screenshots.wayland = {
    enable = mkEnableOption "Native Wayland screenshot tools (grim + swappy)";

    savePath = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/Pictures/screenshots";
      description = "Directory where screenshots will be saved";
    };

    enableAnnotation = mkOption {
      type = types.bool;
      default = true;
      description = "Enable swappy annotation editor";
    };
  };

  config = mkIf cfg.enable {
    # Install Wayland screenshot tools
    home.packages = with pkgs; [
      grim # Screenshot capture from Wayland compositor
      slurp # Interactive region selection
      wl-clipboard # Clipboard integration for Wayland
    ] ++ optionals cfg.enableAnnotation [
      swappy # Screenshot annotation/editing tool
    ];

    # Ensure screenshots directory exists
    home.file."${builtins.replaceStrings ["${config.home.homeDirectory}/"] [""] cfg.savePath}/.keep".text = "";

    # Add convenient shell functions for bash
    programs.bash.initExtra = mkIf config.programs.bash.enable ''
      # Take screenshot of selected region and save to file
      screenshot() {
        local filename="${cfg.savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
        grim -g "$(slurp)" "$filename" && echo "Screenshot saved: $filename"
      }

      # Take screenshot and copy to clipboard
      screenshot-clip() {
        grim -g "$(slurp)" - | wl-copy
        echo "Screenshot copied to clipboard"
      }

      # Take screenshot and open in annotation editor
      screenshot-edit() {
        ${if cfg.enableAnnotation then ''
          local filename="${cfg.savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
          grim -g "$(slurp)" - | swappy -f - -o "$filename"
        '' else ''
          echo "Annotation editor disabled. Enable with desktop.screenshots.wayland.enableAnnotation = true"
          screenshot
        ''}
      }

      # Take full screenshot (all monitors)
      screenshot-full() {
        local filename="${cfg.savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
        grim "$filename" && echo "Full screenshot saved: $filename"
      }

      # Take screenshot of specific monitor
      screenshot-monitor() {
        local monitor=$(slurp -o)
        if [ -n "$monitor" ]; then
          local filename="${cfg.savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
          grim -o "$monitor" "$filename" && echo "Monitor screenshot saved: $filename"
        fi
      }
    '';

    # Add convenient shell functions for zsh
    programs.zsh.initContent = mkIf config.programs.zsh.enable ''
      # Take screenshot of selected region and save to file
      screenshot() {
        local filename="${cfg.savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
        grim -g "$(slurp)" "$filename" && echo "Screenshot saved: $filename"
      }

      # Take screenshot and copy to clipboard
      screenshot-clip() {
        grim -g "$(slurp)" - | wl-copy
        echo "Screenshot copied to clipboard"
      }

      # Take screenshot and open in annotation editor
      screenshot-edit() {
        ${if cfg.enableAnnotation then ''
          local filename="${cfg.savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
          grim -g "$(slurp)" - | swappy -f - -o "$filename"
        '' else ''
          echo "Annotation editor disabled. Enable with desktop.screenshots.wayland.enableAnnotation = true"
          screenshot
        ''}
      }

      # Take full screenshot (all monitors)
      screenshot-full() {
        local filename="${cfg.savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
        grim "$filename" && echo "Full screenshot saved: $filename"
      }

      # Take screenshot of specific monitor
      screenshot-monitor() {
        local monitor=$(slurp -o)
        if [ -n "$monitor" ]; then
          local filename="${cfg.savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
          grim -o "$monitor" "$filename" && echo "Monitor screenshot saved: $filename"
        fi
      }
    '';

    # Configure swappy if enabled
    xdg.configFile."swappy/config" = mkIf cfg.enableAnnotation {
      text = ''
        [Default]
        save_dir=${cfg.savePath}
        save_filename_format=screenshot-%Y%m%d-%H%M%S.png
        show_panel=true
        line_size=5
        text_size=20
        text_font=Inter
        paint_mode=brush
        early_exit=false
        fill_shape=false
      '';
    };
  };
}
