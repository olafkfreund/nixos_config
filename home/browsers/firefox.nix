{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.browsers.firefox;
in {
  options.browsers.firefox = {
    enable = mkEnableOption {
      default = true;
      description = "Enable Firefox support.";
    };
  };
  config = mkIf cfg.enable {
    programs = {
      firefox = {
        enable = true;
        package = pkgs.firefox;

        # Wayland-specific optimizations
        policies = {
          DisableAppUpdate = true;
          DisablePocket = true;
          DisableTelemetry = true;
          NoDefaultBookmarks = true;
          OverrideFirstRunPage = "";
          OverridePostUpdatePage = "";
        };

        # Firefox preferences optimized for Wayland
        profiles.default = {
          id = 0;
          name = "default";
          isDefault = true;
          settings = {
            # Wayland-specific optimizations
            "widget.use-xdg-desktop-portal" = true;
            "widget.use-xdg-desktop-portal.file-picker" = 1;
            "media.ffmpeg.vaapi.enabled" = true;
            "media.hardware-video-decoding.enabled" = true;
            "media.hardware-video-decoding.force-enabled" = true;
            "media.av1.enabled" = true;
            "gfx.webrender.all" = true;
            "layers.acceleration.force-enabled" = true;
            "gfx.x11-egl.force-enabled" = false; # Disable X11 EGL on Wayland

            # Enable native Wayland window decorations
            "widget.wayland.client-side-decoration" = true;

            # Enable smooth scrolling (works better on Wayland)
            "general.smoothScroll" = true;
            "mousewheel.default.delta_multiplier_y" = 100;

            # Better touch support for Wayland
            "apz.allow_zooming" = true;
            "apz.allow_zooming_out" = true;
            "apz.gtk.touchpad_pinch_enabled" = true;

            # Full content process isolation (better security)
            "fission.autostart" = true;

            # Enable GPU acceleration for WebGL
            "webgl.force-enabled" = true;

            # Performance improvements
            "browser.startup.preXulSkeletonUI" = false;
            "browser.sessionstore.interval" = 15000;
            "layout.css.omt-animations.enabled" = true;
            "dom.enable_performance_observer" = false;

            # Disable Firefox studies and telemetry
            "app.shield.optoutstudies.enabled" = false;
            "browser.discovery.enabled" = false;
            "datareporting.healthreport.uploadEnabled" = false;
            "datareporting.policy.dataSubmissionEnabled" = false;
            "toolkit.telemetry.archive.enabled" = false;
            "toolkit.telemetry.enabled" = false;
            "toolkit.telemetry.unified" = false;

            # Enable userChrome.css customization
            "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
            "browser.toolbars.bookmarks.visibility" = "never";
            "browser.compactmode.show" = true;
            "browser.uidensity" = 1;
          };

          userChrome = ''
            /* Gruvbox Dark Theme for Firefox */
            :root {
              --gruvbox-bg: #282828;
              --gruvbox-bg1: #3c3836;
              --gruvbox-fg: #ebdbb2;
              --gruvbox-fg1: #a89984;
              --gruvbox-red: #cc241d;
              --gruvbox-green: #98971a;
              --gruvbox-yellow: #d79921;
              --gruvbox-blue: #458588;
              --gruvbox-purple: #b16286;
              --gruvbox-aqua: #689d6a;
              --gruvbox-orange: #d65d0e;
            }

            /* Main window background */
            #main-window,
            #toolbar-menubar,
            #TabsToolbar,
            #PersonalToolbar,
            #navigator-toolbox,
            #sidebar-box {
              background-color: var(--gruvbox-bg) !important;
              color: var(--gruvbox-fg) !important;
            }

            /* Tabs */
            .tabbrowser-tab {
              background-color: var(--gruvbox-bg1) !important;
              color: var(--gruvbox-fg1) !important;
            }

            .tabbrowser-tab[selected="true"] {
              background-color: var(--gruvbox-bg) !important;
              color: var(--gruvbox-fg) !important;
            }

            /* URL Bar */
            #urlbar-background {
              background-color: var(--gruvbox-bg1) !important;
            }

            #urlbar-input-container {
              color: var(--gruvbox-fg) !important;
            }

            /* Buttons */
            .toolbarbutton-1 {
              color: var(--gruvbox-fg1) !important;
            }

            .toolbarbutton-1:hover {
              background-color: var(--gruvbox-bg1) !important;
            }

            /* Sidebar */
            #sidebar {
              background-color: var(--gruvbox-bg) !important;
              color: var(--gruvbox-fg) !important;
            }

            /* Scrollbar */
            :root {
              scrollbar-color: var(--gruvbox-bg1) var(--gruvbox-bg) !important;
            }
          '';
        };
      };
    };
  };
}
