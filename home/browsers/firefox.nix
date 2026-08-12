{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  inherit (config.lib.stylix) colors;
  c = colors.withHashtag;
  cfg = config.browsers.firefox;
in
{
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
            /* Browser chrome, coloured from the active base16 scheme.
               Stylix's firefox target only themes the new-tab page, not
               userChrome, so these are wired by hand. */
            :root {
              --hud-bg: ${c.base00};
              --hud-bg1: ${c.base01};
              --hud-fg: ${c.base05};
              --hud-fg1: ${c.base04};
              --hud-red: ${c.base08};
              --hud-green: ${c.base0B};
              --hud-yellow: ${c.base0A};
              --hud-blue: ${c.base0D};
              --hud-purple: ${c.base0E};
              --hud-aqua: ${c.base0C};
              --hud-orange: ${c.base09};
            }

            /* Main window background */
            #main-window,
            #toolbar-menubar,
            #TabsToolbar,
            #PersonalToolbar,
            #navigator-toolbox,
            #sidebar-box {
              background-color: var(--hud-bg) !important;
              color: var(--hud-fg) !important;
            }

            /* Tabs */
            .tabbrowser-tab {
              background-color: var(--hud-bg1) !important;
              color: var(--hud-fg1) !important;
            }

            .tabbrowser-tab[selected="true"] {
              background-color: var(--hud-bg) !important;
              color: var(--hud-fg) !important;
            }

            /* URL Bar */
            #urlbar-background {
              background-color: var(--hud-bg1) !important;
            }

            #urlbar-input-container {
              color: var(--hud-fg) !important;
            }

            /* Buttons */
            .toolbarbutton-1 {
              color: var(--hud-fg1) !important;
            }

            .toolbarbutton-1:hover {
              background-color: var(--hud-bg1) !important;
            }

            /* Sidebar */
            #sidebar {
              background-color: var(--hud-bg) !important;
              color: var(--hud-fg) !important;
            }

            /* Scrollbar */
            :root {
              scrollbar-color: var(--hud-bg1) var(--hud-bg) !important;
            }
          '';
        };
      };
    };
  };
}
