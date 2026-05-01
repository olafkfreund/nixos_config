{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkOption mkIf mkEnableOption types optional optionals;
  cfg = config.features.desktop.cosmic;
in
{
  options.features.desktop.cosmic = {
    enable = mkEnableOption "COSMIC Desktop Environment";

    useCosmicGreeter = mkOption {
      type = types.bool;
      default = true;
      description = "Use COSMIC Greeter as the display manager";
    };

    defaultSession = mkOption {
      type = types.bool;
      default = false;
      description = "Set COSMIC as the default desktop session";
    };

    installAllApps = mkOption {
      type = types.bool;
      default = true;
      description = "Install all COSMIC applications and extensions";
    };

    enableTailscaleApplet = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Tailscale management applet for COSMIC panel. Requires Tailscale to be installed and users to have operator privileges.";
    };

    enableNextMeetingApplet = mkOption {
      type = types.bool;
      default = true;
      description = "Enable next meeting calendar applet for COSMIC panel. Shows upcoming meetings with one-click join for video calls. Requires Evolution Data Server.";
    };

    enableMusicPlayerApplet = mkOption {
      type = types.bool;
      default = true; # Now enabled by default - Cargo.lock issue resolved with Crane
      description = ''
        Enable music player applet for COSMIC panel with MPRIS control.

        Provides play/pause, track navigation, album artwork, and volume control for MPRIS-compatible music players.
        Works with Spotify, VLC, MPD, and other MPRIS-compatible applications.
      '';
    };

    enableSpotifyApplet = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable Spotify applet for COSMIC panel.

        Displays currently playing Spotify track information (artist and title) in the system panel.
        Shows playback status indicators (playing, paused, stopped) with 500ms refresh intervals.
        Requires Spotify with MPRIS support on Wayland.
      '';
    };

    enableForecastApp = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable Forecast weather application for COSMIC desktop.

        Weather app written in Rust and libcosmic providing weather information display.
        Integrates with COSMIC desktop environment for native experience.
      '';
    };

    enableConnect = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable COSMIC Connect for device connectivity (KDE Connect alternative).

        Provides device synchronization, file sharing, clipboard sharing, notifications,
        media control, and remote input capabilities across devices.
        Includes daemon service and panel applet for COSMIC Desktop.
      '';
    };

    connectOpenFirewall = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Open firewall ports for COSMIC Connect device discovery and file transfer.

        Opens TCP/UDP 1814-1864 for discovery and TCP 1739-1764 for file transfer.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Enable COSMIC Desktop Environment and display manager configuration
    services = {
      desktopManager.cosmic.enable = true;

      # Enable cosmic-greeter display manager
      # NixOS's displayManager.cosmic-greeter handles all the complexity:
      #   - Creates cosmic-greeter user automatically
      #   - Configures greetd with cosmic-greeter-start command
      #   - Sets up proper environment variables (XCURSOR_THEME, etc.)
      #   - Manages all dependencies and services
      displayManager = {
        cosmic-greeter.enable = cfg.useCosmicGreeter;
        defaultSession = mkIf cfg.defaultSession "cosmic";
      };
    };

    # Wrap cosmic-comp + the four core apps at the package level so the
    # only copy in the system path has Wayland libs baked in. Listing
    # wrapped variants alongside services.desktopManager.cosmic's unwrapped
    # copies in systemPackages would otherwise collide on /bin/cosmic-*.
    nixpkgs.overlays = mkIf cfg.useCosmicGreeter [
      (_final: prev:
        let
          waylandLibs = lib.makeLibraryPath [ prev.wayland prev.libxkbcommon prev.vulkan-loader prev.libglvnd ];
          wrapCosmicBin = pkg: bin: pkg.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
            postFixup = (old.postFixup or "") + ''
              wrapProgram $out/bin/${bin} \
                --prefix LD_LIBRARY_PATH : "${waylandLibs}"
            '';
          });
        in
        {
          cosmic-comp = prev.cosmic-comp.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
            postInstall = (old.postInstall or "") + ''
              wrapProgram $out/bin/cosmic-comp \
                --prefix LD_LIBRARY_PATH : "${prev.libglvnd}/lib:${prev.mesa}/lib:/run/opengl-driver/lib"
            '';
          });
          cosmic-edit = wrapCosmicBin prev.cosmic-edit "cosmic-edit";
          cosmic-files = wrapCosmicBin prev.cosmic-files "cosmic-files";
          cosmic-settings = wrapCosmicBin prev.cosmic-settings "cosmic-settings";
          cosmic-term = wrapCosmicBin prev.cosmic-term "cosmic-term";
        })
    ];

    # COSMIC environment configuration
    environment = {
      # cosmic-edit/files/settings/term are installed by
      # services.desktopManager.cosmic.enable; the overlay above wraps them
      # in-place so we don't need (and must not) list them here too.
      systemPackages = with pkgs;
        let
          waylandLibs = lib.makeLibraryPath [ pkgs.wayland pkgs.libxkbcommon pkgs.vulkan-loader pkgs.libglvnd ];

          wrapCosmicApp = name: pkg: pkgs.symlinkJoin {
            name = "${name}-wrapped";
            paths = [ pkg ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/${name} \
                --prefix LD_LIBRARY_PATH : "${waylandLibs}"
            '';
          };
        in
        [
          # libEGL.so.1 + Wayland runtime libs needed by COSMIC apps
          libglvnd
          mesa
          wayland
          libxkbcommon

          tasks

          wl-clipboard
          wl-clipboard-x11

          grim
          slurp

          libnotify

          nwg-look
        ]
        ++ optionals cfg.installAllApps [
          # Productivity applications
          tasks # Task/TODO manager
          cosmic-reader # PDF/document reader
          cosmic-store # Application store
          cosmic-player # Media player

          # System utilities
          cosmic-screenshot # Screenshot tool
          cosmic-randr # Display configuration

          # Web applications
          cosmic-ext-web-apps # Web app manager for COSMIC Desktop

          # Extensions and tweaks
          cosmic-ext-calculator # Calculator application
          cosmic-ext-tweaks # Advanced tweaking tool
          cosmic-ext-ctl # Extension control tool

          # Applets
          cosmic-ext-applet-minimon # System monitor applet
          cosmic-ext-applet-caffeine # Prevent screen sleep applet
          cosmic-ext-applet-privacy-indicator # Privacy indicator applet

          # Visual assets
          cosmic-icons # COSMIC icon theme
          cosmic-wallpapers # Wallpaper collection

          # Development/Design tools
          cosmic-design-demo # Design system demo
        ]
        ++ optional cfg.enableTailscaleApplet
          # Tailscale VPN management applet (wrapped for proper Wayland library loading)
          (wrapCosmicApp "gui-scale-applet" pkgs.customPkgs.cosmic-ext-applet-tailscale)
        ++ optional cfg.enableNextMeetingApplet
          # Next meeting calendar applet (wrapped for proper Wayland library loading)
          (wrapCosmicApp "cosmic-next-meeting" pkgs.customPkgs.cosmic-ext-applet-next-meeting)
        # Evolution Data Server / GOA for calendar — gnome already provides
        # these via evolution-with-plugins; only install when gnome is off.
        ++ optionals
          (cfg.enableNextMeetingApplet
          && !config.services.desktopManager.gnome.enable) [
          pkgs.evolution-data-server
          pkgs.gnome-online-accounts
        ]
        ++ optional cfg.enableMusicPlayerApplet
          # Music player applet with MPRIS control (wrapped for proper Wayland library loading)
          (wrapCosmicApp "cosmic-ext-applet-music-player" pkgs.cosmic-ext-applet-music-player)
        ++ optional cfg.enableSpotifyApplet
          # Spotify applet for displaying currently playing track information (wrapped for proper Wayland library loading)
          (wrapCosmicApp "cosmic-applet-spotify" pkgs.cosmic-applet-spotify)
        ++ optional cfg.enableForecastApp
          # Forecast weather application for COSMIC desktop
          pkgs.forecast;

      # COSMIC-specific environment variables
      sessionVariables = {
        # Enable Wayland for compatible applications
        NIXOS_OZONE_WL = "1";
        MOZ_ENABLE_WAYLAND = "1";
        QT_QPA_PLATFORM = "wayland";
      };

      # Set environment variable to suppress KDE hint warnings in cosmic-notifications
      variables = {
        COSMIC_IGNORE_KDE_HINTS = "1";
        # Fix for missing libEGL.so.1 in cosmic-greeter
        # Use mkForce to resolve conflict with shells-environment.nix
        LD_LIBRARY_PATH = lib.mkForce "/run/opengl-driver/lib:/run/opengl-driver-32/lib:/etc/sane-libs";
      };
    };

    # XDG portal configuration for COSMIC
    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-cosmic
        pkgs.xdg-desktop-portal-gtk
      ];
      config.cosmic.default = [ "cosmic" "gtk" "*" ];
    };

    # Required system services
    security.polkit.enable = true;

    # Hardware acceleration
    hardware.graphics.enable = true;

    # Font configuration for better COSMIC experience
    fonts.packages = with pkgs; [
      fira
      fira-code
      fira-code-symbols
      font-awesome
    ];

    # Systemd-logind configuration for proper session management
    # Fix for COSMIC logout button issue (https://github.com/pop-os/cosmic-epoch/issues/795)
    services.logind.settings.Login = {
      # Enable killing user processes on logout to prevent black screen
      KillUserProcesses = true;

      # Additional session cleanup settings
      RemoveIPC = "yes";
      InhibitDelayMaxSec = 5;
      HandlePowerKey = "poweroff";
      IdleAction = "ignore";
    };

    # Systemd configuration for COSMIC
    systemd = {
      # Configure Tailscale operator privileges for GUI applet
      services.tailscale-operator-setup = mkIf cfg.enableTailscaleApplet {
        description = "Configure Tailscale operator for COSMIC GUI applet";
        after = [ "tailscaled.service" ];
        wants = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        path = with pkgs; [ getent coreutils gawk ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          # Configure operator privileges for all human users (UID 1000-29999)
          # In NixOS, users typically have primary GID 100 (users group) but aren't listed in group members
          # Excludes nixbld users (30000+) and system users (<1000)
          for user in $(${pkgs.getent}/bin/getent passwd | ${pkgs.gawk}/bin/awk -F: '$3 >= 1000 && $3 < 30000 {print $1}'); do
            echo "Setting Tailscale operator privileges for $user"
            ${pkgs.tailscale}/bin/tailscale set --operator="$user" 2>/dev/null || true
          done
        '';
      };

      services = {
        # Filter out harmless KDE notification hint warnings from logs
        systemd-journald.environment = {
          # Suppress KDE notification hint warnings (x-kde-* hints are not errors)
          SYSTEMD_LOG_LEVEL = "info";
        };


        # Ensure cosmic-greeter-daemon has access to EGL libraries as well
        cosmic-greeter-daemon = mkIf cfg.useCosmicGreeter {
          path = [ pkgs.libglvnd pkgs.mesa pkgs.wayland ];
          serviceConfig = {
            Environment = [
              "LD_LIBRARY_PATH=${pkgs.libglvnd}/lib:/run/opengl-driver/lib:/run/opengl-driver-32/lib"
            ];
          };
        };
      };
    };

    # COSMIC Connect - KDE Connect alternative for device connectivity
    services.cosmic-ext-connect = mkIf cfg.enableConnect {
      enable = true;
      openFirewall = cfg.connectOpenFirewall;
    };
  };
}
