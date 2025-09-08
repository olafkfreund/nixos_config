{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.desktop.gnome;
in
{
  config = mkIf (cfg.enable && cfg.apps.enable) {
    # Essential GNOME applications and additional fonts
    home.packages = with pkgs;
      [
        # Core GNOME applications
        gnome-tweaks
        dconf-editor
        gnome-extension-manager

        # GNOME utilities
        gnome-usage # System resource usage
        gnome-font-viewer # Font management
        gnome-characters # Character map
        gnome-logs # System logs viewer
        gnome-system-monitor # Advanced system monitor
        gnome-disk-utility # Disk management
        gnome-connections # Remote desktop client
        gnome-firmware # Firmware updates
        boxbuddy # Manage distrobox containers

        # GNOME productivity
        gnome-calculator # Calculator
        gnome-calendar # Calendar
        gnome-clocks # World clocks, timers, alarms
        gnome-weather # Weather information
        gnome-contacts # Contact manager
        gnome-maps # Maps application
        # gnome-todo # Task management - package not available
        # gnome-schedule # Event scheduling - package not available
        gnome-frog # Clipboard manager
        gnome-feeds # RSS feed reader

        # GNOME multimedia
        eog # Eye of GNOME (image viewer)
        totem # GNOME Videos (video player)
        gnome-music # Music player
        gnome-photos # Photo manager
        gnome-sound-recorder # Audio recording

        # GNOME text and documents
        gedit # Text editor
        evince # PDF viewer
        gnome-text-editor # New text editor (GNOME 42+)

        # File management
        nautilus # File manager
        file-roller # Archive manager

        # GNOME development tools
        gnome-builder # IDE (optional - large package)

        # Fonts for better GNOME app experience
        cantarell-fonts
        source-sans-pro
        source-serif-pro
        dejavu_fonts
        liberation_ttf
        noto-fonts
        noto-fonts-emoji
        noto-fonts-cjk-sans

        # Additional applications from user configuration
      ]
      ++ cfg.apps.packages;

    # GNOME applications configuration via dconf
    dconf.settings = {
      # Nautilus (File Manager) configuration
      "org/gnome/nautilus/preferences" = {
        default-folder-viewer = "list-view";
        search-filter-time-type = "last_modified";
        search-view = "list-view";
        show-create-link = true;
        show-delete-permanently = true;
        show-hidden-files = false;
        thumbnail-limit = 10; # MB
      };

      "org/gnome/nautilus/icon-view" = {
        default-zoom-level = "standard";
      };

      "org/gnome/nautilus/list-view" = {
        default-column-order = [ "name" "size" "type" "owner" "group" "permissions" "where" "date_modified" "date_modified_with_time" "date_accessed" "recency" "starred" ];
        default-visible-columns = [ "name" "size" "date_modified" ];
        default-zoom-level = "standard";
        use-tree-view = false;
      };

      # GNOME Text Editor configuration
      "org/gnome/TextEditor" = {
        auto-save = true;
        auto-save-delay = 300;
        discover-settings = true;
        highlight-current-line = true;
        indent-style = "space";
        restore-session = true;
        show-line-numbers = true;
        show-right-margin = true;
        spellcheck = true;
        tab-width = 2;
        use-system-font = false;
        custom-font = "JetBrainsMono Nerd Font 11";
        wrap-text = true;
      };

      # GNOME Terminal configuration
      "org/gnome/terminal/legacy" = {
        theme-variant = "dark";
        default-show-menubar = false;
        headerbar = "@mb true";
        menu-accelerator-enabled = false;
        shortcuts-enabled = true;
        tab-policy = "automatic";
        tab-position = "top";
      };

      # Calculator configuration
      "org/gnome/calculator" = {
        accuracy = 9;
        angle-units = "degrees";
        base = 10;
        button-mode = "basic"; # "basic", "advanced", "financial", "programming"
        number-format = "automatic";
        show-thousands = true;
        show-zeroes = false;
        source-currency = "EUR";
        source-units = "meter";
        target-currency = "USD";
        target-units = "foot";
        word-size = 64;
      };

      # Weather application configuration
      "org/gnome/Weather" = {
        automatic-location = true;
        locations = [ ]; # Add locations as needed
      };

      # Photos application configuration
      "org/gnome/photos" = {
        window-maximized = false;
        window-position = [ 26 23 ];
        window-size = [ 1200 800 ];
      };

      # Music application configuration
      "org/gnome/Music" = {
        window-maximized = false;
        window-position = [ 26 23 ];
        window-size = [ 1200 800 ];
        repeat-mode = "none"; # "none", "song", "all"
        shuffle-mode = false;
      };

      # Evince (PDF viewer) configuration
      "org/gnome/evince/default" = {
        continuous = true;
        dual-page = false;
        dual-page-odd-left = false;
        enable-spellchecking = true;
        fullscreen = false;
        inverted-colors = false;
        show-sidebar = true;
        sidebar-page = "thumbnails"; # "thumbnails", "links", "attachments"
        sidebar-size = 132;
        sizing-mode = "fit-page"; # "fit-page", "fit-width", "free"
        window-ratio = [ 1.0 0.7071067811865476 ];
        zoom = 1.0;
      };

      # System Monitor configuration
      "org/gnome/gnome-system-monitor" = {
        current-tab = "processes";
        maximized = false;
        show-dependencies = false;
        show-whose-processes = "user"; # "user", "active", "all"
        window-state = [ 700 500 50 50 ];
      };

      "org/gnome/gnome-system-monitor/proctree" = {
        columns-order = [ 0 1 2 3 4 6 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 ];
        sort-col = 15; # CPU column
        sort-order = 0; # Descending
      };

      # Disk Usage Analyzer configuration
      "org/gnome/baobab/ui" = {
        window-size = [ 960 600 ];
        window-state = 87168;
      };

      # Character Map configuration
      "org/gnome/Characters" = {
        recent-characters = [ ];
      };

      # GNOME Tweaks integration (settings that Tweaks would normally handle)
      "org/gnome/desktop/interface" = {
        enable-animations = true;
        gtk-enable-primary-paste = true;
        locate-pointer = false;
        show-battery-percentage = true;
        toolkit-accessibility = false;
      };

      "org/gnome/desktop/sound" = {
        allow-volume-above-100-percent = false;
        event-sounds = true;
        input-feedback-sounds = false;
        theme-name = "freedesktop";
      };

      "org/gnome/desktop/peripherals/touchpad" = {
        tap-to-click = true;
        two-finger-scrolling-enabled = true;
        natural-scroll = true;
        disable-while-typing = true;
      };

      "org/gnome/desktop/peripherals/mouse" = {
        accel-profile = "default";
        natural-scroll = false;
        speed = 0.0;
      };
    };

    # XDG file associations for GNOME apps
    xdg.mimeApps = {
      enable = true;
      defaultApplications = mkMerge [
        {
          # Text files
          "text/plain" = "org.gnome.TextEditor.desktop";
          "text/x-readme" = "org.gnome.TextEditor.desktop";

          # Images
          "image/jpeg" = "org.gnome.eog.desktop";
          "image/png" = "org.gnome.eog.desktop";
          "image/gif" = "org.gnome.eog.desktop";
          "image/bmp" = "org.gnome.eog.desktop";
          "image/tiff" = "org.gnome.eog.desktop";
          "image/webp" = "org.gnome.eog.desktop";

          # Videos
          "video/mp4" = "org.gnome.Totem.desktop";
          "video/x-msvideo" = "org.gnome.Totem.desktop";
          "video/quicktime" = "org.gnome.Totem.desktop";
          "video/webm" = "org.gnome.Totem.desktop";

          # Audio
          "audio/mpeg" = "org.gnome.Music.desktop";
          "audio/ogg" = "org.gnome.Music.desktop";
          "audio/flac" = "org.gnome.Music.desktop";
          "audio/wav" = "org.gnome.Music.desktop";

          # Documents
          "application/pdf" = "org.gnome.Evince.desktop";

          # Archives
          "application/zip" = "org.gnome.FileRoller.desktop";
          "application/x-tar" = "org.gnome.FileRoller.desktop";
          "application/gzip" = "org.gnome.FileRoller.desktop";
          "application/x-7z-compressed" = "org.gnome.FileRoller.desktop";
          "application/x-rar-compressed" = "org.gnome.FileRoller.desktop";
        }
      ];
    };

    # Enable font configuration
    fonts.fontconfig.enable = true;
  };
}
