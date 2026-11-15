{ config
, pkgs
, lib
, ...
}:
let
  inherit (lib) mkIf optionals;
  cfg = config.features.desktop;
  savePath = "${config.home.homeDirectory}/Pictures/Screenshots";
  enableAnnotation = true;
  enableDesktopEntries = true;
in
{
  config = mkIf (cfg.enable && cfg.waylandScreenshots) {
    # Install Wayland screenshot tools
    home.packages = with pkgs; [
      grim # Screenshot capture from Wayland compositor
      slurp # Interactive region selection
      wl-clipboard # Clipboard integration for Wayland
    ] ++ optionals enableAnnotation [
      swappy # Screenshot annotation/editing tool
    ] ++ [
      # Create executable scripts for desktop entries
      (pkgs.writeShellScriptBin "screenshot" ''
        filename="${savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
        ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" "$filename" && echo "Screenshot saved: $filename"
      '')

      (pkgs.writeShellScriptBin "screenshot-clip" ''
        filename="${savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
        ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" "$filename" && ${pkgs.wl-clipboard}/bin/wl-copy < "$filename" && echo "Screenshot saved: $filename (copied to clipboard)"
      '')

      (pkgs.writeShellScriptBin "screenshot-full" ''
        filename="${savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
        ${pkgs.grim}/bin/grim "$filename" && echo "Full screenshot saved: $filename"
      '')

      (pkgs.writeShellScriptBin "screenshot-monitor" ''
        monitor=$(${pkgs.slurp}/bin/slurp -o)
        if [ -n "$monitor" ]; then
          filename="${savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
          ${pkgs.grim}/bin/grim -o "$monitor" "$filename" && echo "Monitor screenshot saved: $filename"
        fi
      '')

      (pkgs.writeShellScriptBin "screenshot-edit" ''
        ${if enableAnnotation then ''
          filename="${savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
          ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - | ${pkgs.swappy}/bin/swappy -f - -o "$filename"
        '' else ''
          echo "Annotation editor disabled."
          filename="${savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
          ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" "$filename" && echo "Screenshot saved: $filename"
        ''}
      '')
    ];

    # Ensure screenshots directory exists
    home.file."${builtins.replaceStrings ["${config.home.homeDirectory}/"] [""] savePath}/.keep".text = "";

    # Add convenient shell functions for bash
    programs.bash.initExtra = mkIf config.programs.bash.enable ''
      # Take screenshot of selected region and save to file
      screenshot() {
        local filename="${savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
        grim -g "$(slurp)" "$filename" && echo "Screenshot saved: $filename"
      }

      # Take screenshot, save to file, and copy to clipboard
      screenshot-clip() {
        local filename="${savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
        grim -g "$(slurp)" "$filename" && wl-copy < "$filename" && echo "Screenshot saved: $filename (copied to clipboard)"
      }

      # Take screenshot and open in annotation editor
      screenshot-edit() {
        ${if enableAnnotation then ''
          local filename="${savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
          grim -g "$(slurp)" - | swappy -f - -o "$filename"
        '' else ''
          echo "Annotation editor disabled."
          screenshot
        ''}
      }

      # Take full screenshot (all monitors)
      screenshot-full() {
        local filename="${savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
        grim "$filename" && echo "Full screenshot saved: $filename"
      }

      # Take screenshot of specific monitor
      screenshot-monitor() {
        local monitor=$(slurp -o)
        if [ -n "$monitor" ]; then
          local filename="${savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
          grim -o "$monitor" "$filename" && echo "Monitor screenshot saved: $filename"
        fi
      }
    '';

    # Add convenient shell functions for zsh
    programs.zsh.initContent = mkIf config.programs.zsh.enable ''
      # Take screenshot of selected region and save to file
      screenshot() {
        local filename="${savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
        grim -g "$(slurp)" "$filename" && echo "Screenshot saved: $filename"
      }

      # Take screenshot, save to file, and copy to clipboard
      screenshot-clip() {
        local filename="${savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
        grim -g "$(slurp)" "$filename" && wl-copy < "$filename" && echo "Screenshot saved: $filename (copied to clipboard)"
      }

      # Take screenshot and open in annotation editor
      screenshot-edit() {
        ${if enableAnnotation then ''
          local filename="${savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
          grim -g "$(slurp)" - | swappy -f - -o "$filename"
        '' else ''
          echo "Annotation editor disabled."
          screenshot
        ''}
      }

      # Take full screenshot (all monitors)
      screenshot-full() {
        local filename="${savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
        grim "$filename" && echo "Full screenshot saved: $filename"
      }

      # Take screenshot of specific monitor
      screenshot-monitor() {
        local monitor=$(slurp -o)
        if [ -n "$monitor" ]; then
          local filename="${savePath}/screenshot-$(date +%Y%m%d-%H%M%S).png"
          grim -o "$monitor" "$filename" && echo "Monitor screenshot saved: $filename"
        fi
      }
    '';

    # Configure swappy if enabled
    xdg.configFile."swappy/config" = mkIf enableAnnotation {
      text = ''
        [Default]
        save_dir=${savePath}
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

    # Create desktop entries for screenshot commands
    xdg.desktopEntries = mkIf enableDesktopEntries {
      screenshot = {
        name = "Screenshot (Region)";
        genericName = "Take Screenshot";
        comment = "Capture a screenshot of a selected region";
        exec = "screenshot";
        icon = "camera-photo";
        terminal = false;
        type = "Application";
        categories = [ "Graphics" "Utility" ];
      };

      screenshot-clip = {
        name = "Screenshot to Clipboard";
        genericName = "Screenshot to Clipboard";
        comment = "Capture screenshot, save to file and copy to clipboard";
        exec = "screenshot-clip";
        icon = "edit-copy";
        terminal = false;
        type = "Application";
        categories = [ "Graphics" "Utility" ];
      };

      screenshot-full = {
        name = "Screenshot (Full Screen)";
        genericName = "Full Screen Screenshot";
        comment = "Capture a screenshot of all monitors";
        exec = "screenshot-full";
        icon = "camera-photo";
        terminal = false;
        type = "Application";
        categories = [ "Graphics" "Utility" ];
      };

      screenshot-edit = {
        name = "Screenshot & Edit";
        genericName = "Screenshot with Editor";
        comment = "Capture screenshot and open in annotation editor";
        exec = "screenshot-edit";
        icon = "image-x-generic";
        terminal = false;
        type = "Application";
        categories = [ "Graphics" "Utility" ];
      };

      screenshot-monitor = {
        name = "Screenshot (Monitor)";
        genericName = "Monitor Screenshot";
        comment = "Capture a screenshot of a specific monitor";
        exec = "screenshot-monitor";
        icon = "video-display";
        terminal = false;
        type = "Application";
        categories = [ "Graphics" "Utility" ];
      };
    };
  };
}
