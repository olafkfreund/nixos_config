{ pkgs
, config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.browsers.chrome;

  # Omarchy's web apps run `omarchy-launch-webapp <url>` with no profile, so
  # Chrome opens them in whichever profile was used last (#1839). This stand-in
  # appends --profile-directory=Default, then hands off to the real launcher
  # found further down PATH.
  webappLauncher = pkgs.writeShellScriptBin "omarchy-launch-webapp" ''
    self=$(dirname "$(readlink -f "$0")")
    PATH=":$PATH:"
    PATH=''${PATH//:$self:/:}
    PATH=''${PATH#:}
    PATH=''${PATH%:}
    case " $* " in
      *" --profile-directory="*) ;;
      *) set -- "$@" --profile-directory=Default ;;
    esac
    exec omarchy-launch-webapp "$@"
  '';

  # The launcher daemon puts Omarchy's bin first on PATH, so the stand-in has to
  # be prepended per launch. HEY and Zoom go through handler scripts that call
  # omarchy-launch-webapp themselves, which this also covers.
  withDefaultProfile = pkgs.writeShellScript "with-default-chrome-profile" ''
    PATH=${webappLauncher}/bin:$PATH exec "$@"
  '';

  # Same desktop-file IDs as Omarchy's own entries: ~/.local/share/applications
  # wins over the profile copy, so each app is listed once.
  omarchyWebapps = {
    Basecamp = { exec = "omarchy-launch-webapp https://launchpad.37signals.com"; icon = "basecamp"; };
    Discord = { exec = "omarchy-launch-webapp https://discord.com/channels/@me"; icon = "omarchy-discord"; };
    "Google Contacts" = { exec = "omarchy-launch-webapp https://contacts.google.com/"; icon = "google-contacts"; };
    "Google Maps" = { exec = "omarchy-launch-webapp https://maps.google.com"; icon = "google-maps"; };
    "Google Messages" = { exec = "omarchy-launch-webapp https://messages.google.com/web/conversations"; icon = "google-messages"; };
    "Google Photos" = { exec = "omarchy-launch-webapp https://photos.google.com/"; icon = "google-photos"; };
    HEY = { exec = "omarchy-webapp-handler-hey %u"; icon = "hey"; mime = "x-scheme-handler/mailto"; };
    WhatsApp = { exec = "omarchy-launch-webapp https://web.whatsapp.com/"; icon = "whatsapp"; };
    X = { exec = "omarchy-launch-webapp https://x.com/"; icon = "x"; };
    YouTube = { exec = "omarchy-launch-webapp https://youtube.com/"; icon = "youtube"; };
    Zoom = { exec = "omarchy-webapp-handler-zoom %u"; icon = "zoom"; mime = "x-scheme-handler/zoommtg;x-scheme-handler/zoomus"; };
  };
in
{
  options.browsers.chrome = {
    enable = mkEnableOption "Google Chrome";
  };

  config = mkIf cfg.enable {
    # Set environment variables for the user session
    # home.sessionVariables = {
    #   # Set GTK theme
    #   GTK_THEME = "Adwaita";
    #   # Use system-provided pixbuf loaders to avoid conflicts
    #   GDK_PIXBUF_MODULE_FILE = "${pkgs.gdk-pixbuf}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache";
    #   # Set cursor theme
    #   XCURSOR_THEME = "Adwaita";
    #   XDG_DATA_DIRS = "${pkgs.adwaita-icon-theme}/share:${pkgs.hicolor-icon-theme}/share:${pkgs.gtk3}/share:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:${pkgs.gtk4}/share";
    # };

    # Configure Chrome with proper Wayland support and screen sharing
    programs.chromium = {
      enable = true;
      package = pkgs.google-chrome;
      commandLineArgs = [
        # Native Wayland support (Chrome 142+ with modern COSMIC Desktop)
        "--ozone-platform-hint=auto"
        "--enable-features=WebRTCPipeWireCapturer"

        # V8 JavaScript engine memory limit (4GB for heavy web apps)
        "--max_old_space_size=4096"
      ];
    };

    xdg.dataFile = lib.mapAttrs'
      (name: app: lib.nameValuePair "applications/omarchy-${name}.desktop" {
        text = ''
          [Desktop Entry]
          Version=1.0
          Name=${name}
          Exec=${withDefaultProfile} ${app.exec}
          Terminal=false
          Type=Application
          Icon=${app.icon}
          StartupNotify=true
        '' + lib.optionalString (app ? mime) "MimeType=${app.mime}\n";
      })
      omarchyWebapps;
  };
}
