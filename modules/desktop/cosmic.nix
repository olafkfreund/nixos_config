{ config
, lib
, pkgs
, ...
}:
with lib; let
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

    disableOsd = mkOption {
      type = types.bool;
      default = false;
      description = "Disable cosmic-osd (on-screen display) to work around polkit agent crashes";
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
  };

  config = mkIf cfg.enable {
    # Enable COSMIC Desktop Environment and display manager configuration
    services = {
      desktopManager.cosmic.enable = true;
      displayManager = {
        cosmic-greeter.enable = cfg.useCosmicGreeter;
        defaultSession = mkIf cfg.defaultSession "cosmic";
      };
    };

    # Wrap cosmic-comp with proper library paths to fix libEGL.so.1 loading
    nixpkgs.overlays = mkIf cfg.useCosmicGreeter [
      (_final: prev: {
        cosmic-comp = prev.cosmic-comp.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
          postInstall = (old.postInstall or "") + ''
            wrapProgram $out/bin/cosmic-comp \
              --prefix LD_LIBRARY_PATH : "${prev.libglvnd}/lib:${prev.mesa}/lib:/run/opengl-driver/lib"
          '';
        });
      })
    ];

    # COSMIC environment configuration
    environment = {
      # COSMIC applications and utilities
      systemPackages = with pkgs;
        let
          # Wayland library path for COSMIC applications
          waylandLibs = lib.makeLibraryPath [ pkgs.wayland pkgs.libxkbcommon pkgs.vulkan-loader pkgs.libglvnd ];

          # Helper function to wrap COSMIC apps with Wayland libraries
          wrapCosmicApp = name: pkg: pkgs.symlinkJoin {
            name = "${name}-wrapped";
            paths = [ pkg ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/${name} \
                --prefix LD_LIBRARY_PATH : "${waylandLibs}"
            '';
          };

          # Wrap essential COSMIC applications with proper Wayland library paths
          cosmic-settings-wrapped = wrapCosmicApp "cosmic-settings" pkgs.cosmic-settings;
          cosmic-term-wrapped = wrapCosmicApp "cosmic-term" pkgs.cosmic-term;
          cosmic-edit-wrapped = wrapCosmicApp "cosmic-edit" pkgs.cosmic-edit;
          cosmic-files-wrapped = wrapCosmicApp "cosmic-files" pkgs.cosmic-files;
        in
        [
          # Essential applications (always installed) - all wrapped with Wayland libs
          cosmic-edit-wrapped # Text editor
          cosmic-files-wrapped # File manager
          cosmic-term-wrapped # Terminal emulator
          cosmic-settings-wrapped # System settings

          # Fix for missing libEGL.so.1
          libglvnd
          mesa
          wayland
          libxkbcommon

          #Applications for COSMIC core functionality
          quick-webapps # Web application integration
          tasks

          # Wayland utilities
          wl-clipboard
          wl-clipboard-x11

          # Screenshot and screen recording support
          grim
          slurp

          # Notifications
          libnotify
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
        ++ optionals cfg.enableNextMeetingApplet [
          # Evolution Data Server for calendar access
          pkgs.evolution-data-server
          pkgs.gnome-online-accounts # For Google Calendar integration
        ]
        ++ optional cfg.enableMusicPlayerApplet
          # Music player applet with MPRIS control (wrapped for proper Wayland library loading)
          (wrapCosmicApp "cosmic-ext-applet-music-player" pkgs.cosmic-ext-applet-music-player);

      # COSMIC-specific environment variables
      sessionVariables = {
        # Enable Wayland for compatible applications
        NIXOS_OZONE_WL = "1";
        MOZ_ENABLE_WAYLAND = "1";
        QT_QPA_PLATFORM = "wayland";
        # Disable cosmic-osd if requested (workaround for polkit crashes)
        COSMIC_DISABLE_OSD = mkIf cfg.disableOsd "1";
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

      # Workaround for cosmic-osd polkit agent crashes
      user.services.cosmic-osd-blocker = mkIf cfg.disableOsd {
        description = "Block cosmic-osd from starting (workaround for polkit crashes)";
        wantedBy = [ "cosmic-session.target" ];
        before = [ "cosmic-session.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        # Create a dummy cosmic-osd that does nothing
        script = ''
          mkdir -p $HOME/.local/bin
          cat > $HOME/.local/bin/cosmic-osd << 'EOF'
          #!/bin/sh
          # Dummy cosmic-osd to prevent crashes - does nothing
          exit 0
          EOF
          chmod +x $HOME/.local/bin/cosmic-osd
        '';
      };

      # Fix for COSMIC logout button black screen issue
      # Ensures proper session cleanup via systemd-logind
      user.services.cosmic-session-cleanup = {
        description = "COSMIC session cleanup on logout";
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStop = "${pkgs.systemd}/bin/loginctl terminate-session $XDG_SESSION_ID";
        };
      };

      services = {
        # Filter out harmless KDE notification hint warnings from logs
        systemd-journald.environment = {
          # Suppress KDE notification hint warnings (x-kde-* hints are not errors)
          SYSTEMD_LOG_LEVEL = "info";
        };

        # Fix for greetd service not inheriting LD_LIBRARY_PATH
        # This ensures cosmic-comp can find libEGL.so.1 from libglvnd
        greetd = mkIf cfg.useCosmicGreeter {
          path = [ pkgs.libglvnd pkgs.mesa ];
          serviceConfig = {
            Environment = [
              "LD_LIBRARY_PATH=${pkgs.libglvnd}/lib:/run/opengl-driver/lib:/run/opengl-driver-32/lib"
            ];
          };
          # Also ensure hardware graphics drivers are loaded before greeter starts
          after = [ "systemd-udev-settle.service" ];
          wants = [ "systemd-udev-settle.service" ];
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
  };
}
