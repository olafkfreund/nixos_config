# Hyprland Window Rules Configuration
# Converted to native Nix configuration for better type safety and maintainability
{
  config,
  lib,
  ...
}:
with lib; {
  wayland.windowManager.hyprland.settings = {
    # Window rules using the modern windowrulev2 format
    windowrulev2 = [
      # =============================================================================
      # GLOBAL SETTINGS
      # =============================================================================
      # Disable hyprbars titlebar for specific windows
      "plugin:hyprbars:nobar, class:(album-art)"

      # =============================================================================
      # TERMINAL EMULATOR RULES
      # =============================================================================
      # Terminal emulators - consistent floating with 1000x1000 size
      "float, class:(alacritty)"
      "size 1000 1000, class:(alacritty)"
      "float, class:(kitty)"
      "size 1000 1000, class:(kitty)"
      "float, class:(wezterm)"
      "size 1000 1000, class:(wezterm)"
      "float, class:(foot)"
      "size 1000 1000, class:(foot)"
      "animation slide left, class:^(foot)$"
      
      # Web search utility
      "float, class:(web-search)"
      "size 1000 1000, class:(web-search)"
      "animation slide down, class:^(web-search)$"

      # =============================================================================
      # SYSTEM UTILITY RULES
      # =============================================================================
      # System utilities stay in current workspace
      "workspace current, title:MainPicker"
      "workspace current, class:.blueman-manager-wrapped"
      "workspace current, class:xdg-desktop-portal-gtk"

      # Bluetooth manager
      "float, class:(blueman-manager)"
      "center, class:(blueman-manager)"

      # Network utilities
      "float, class:^(nm-applet)$"
      "float, class:^(nm-connection-editor)$"

      # Sound control (PulseAudio Volume Control)
      "float, class:(org.pulseaudio.pavucontrol)"
      "size 1000 1000, class:(org.pulseaudio.pavucontrol)"
      "center, class:(org.pulseaudio.pavucontrol)"

      # XDG desktop portal
      "float, class:^(xdg-desktop-portal-gtk)$"
      "size 900 500, class:^(xdg-desktop-portal-gtk)$"
      "dimaround, class:^(xdg-desktop-portal-gtk)$"
      "center, class:^(xdg-desktop-portal-gtk)$"

      # =============================================================================
      # APPLICATION LAUNCHERS
      # =============================================================================
      # Rofi application launcher
      "animation bounce, class:^(rofi)$"

      # =============================================================================
      # PRODUCTIVITY APPLICATIONS
      # =============================================================================
      # Obsidian note-taking application
      "float, class:(obsidian)"

      # =============================================================================
      # THUNDERBIRD EMAIL CLIENT
      # =============================================================================
      # Main Thunderbird window
      "workspace special:mail, class:^(thunderbird)$"
      "animation slide bottom, class:^(thunderbird)$"
      "float, class:^(thunderbird)$, title:^(Mozilla Thunderbird)$"
      "size 70% 70%, class:^(thunderbird)$, title:^(Mozilla Thunderbird)$"

      # Thunderbird dialog windows
      "float, class:^(thunderbird)$, title:^(.*)(Reminder)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Write)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Compose)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Calendar)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Event)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Properties)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Preferences)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Settings)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Add-ons)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(About)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Quick Filter)(.*)$"

      # Common Thunderbird popup sizing (60%)
      "size 60% 60%, class:^(thunderbird)$, title:^(.*)(Write)(.*)$"
      "size 60% 60%, class:^(thunderbird)$, title:^(.*)(Compose)(.*)$"
      "center, class:^(thunderbird)$, title:^(.*)(Write)(.*)$"
      "center, class:^(thunderbird)$, title:^(.*)(Compose)(.*)$"

      # Smaller Thunderbird dialogs (50%)
      "size 50% 50%, class:^(thunderbird)$, title:^(.*)(Reminder)(.*)$"
      "size 50% 50%, class:^(thunderbird)$, title:^(.*)(Properties)(.*)$"
      "size 50% 50%, class:^(thunderbird)$, title:^(.*)(Event)(.*)$"
      "center, class:^(thunderbird)$, title:^(.*)(Reminder)(.*)$"
      "center, class:^(thunderbird)$, title:^(.*)(Properties)(.*)$"
      "center, class:^(thunderbird)$, title:^(.*)(Event)(.*)$"

      # Very small Thunderbird dialogs (40%)
      "size 40% 40%, class:^(thunderbird)$, title:^(.*)(About)(.*)$"
      "center, class:^(thunderbird)$, title:^(.*)(About)(.*)$"

      # =============================================================================
      # WEB BROWSERS AND COMMUNICATION
      # =============================================================================
      # Google Chrome
      "workspace special:chrome, float, class:(google-chrome)"

      # Common file dialogs
      "float, size 900 500, title:^(Choose Files)"
      "float, size 900 500, title:^(Sign in)"

      # Microsoft Edge
      "workspace 4, class:^(Edge)$"

      # Slack communication
      "workspace special:slack, float, class:^(Slack)"
      "workspace special:slack, size 50% 50%, float, class:^(Slack), title:^(Huddle)"

      # Discord communication (using Vesktop)
      "workspace special:discord, float, class:^(vesktop)"
      "workspace special:discord, size 50% 50%, float, class:^(vesktop)"

      # Telegram messaging
      "workspace 8, class:(org.telegram.desktop)"
      "size 970 480, class:(org.telegram.desktop), title:(Choose Files)"
      "center, class:(org.telegram.desktop), title:(Choose Files)"

      # =============================================================================
      # DEVELOPMENT TOOLS
      # =============================================================================
      # Tmux scratchpad terminal
      "workspace special:tmux, float, title:^(tmux-sratch)"

      # =============================================================================
      # ENTERTAINMENT APPLICATIONS
      # =============================================================================
      # Spotify music player
      "workspace special:spotify, float, class:^(spotify)"
      "workspace special:spotify, class:^(Spotify)$"

      # =============================================================================
      # PASSWORD MANAGEMENT
      # =============================================================================
      # 1Password password manager
      "workspace special:magic, float, class:^(1Password)$"
      "workspace special:magic, float, class:^(org.1password.1password)$"
      "float, class:^(1Password)$, title:^(.*)(Preferences)(.*)$"
      "center, class:^(1Password)$, title:^(.*)(Preferences)(.*)$"
      "size 50% 50%, class:^(1Password)$, title:^(.*)(Preferences)(.*)$"

      # =============================================================================
      # VIRTUALIZATION
      # =============================================================================
      # Virtual Machine Manager
      "float, class:(.virt-manager-wrapped)"
      "size 1000 1000, class:(.virt-manager-wrapped)"

      # =============================================================================
      # SYSTEM APPLICATIONS
      # =============================================================================
      # GNOME applications
      "float, class:(org.gnome.*)"
      "size 1000 1000, class:(org.gnome.*)"
      "center, class:(org.gnome.*)"

      # GNOME Calendar specific positioning
      "animation slide up, class:^(org.gnome.Calendar)$"
      "size 400 500, class:^(org.gnome.Calendar)$"
      "move 480 45, class:^(org.gnome.Calendar)$"

      # Camera controls
      "size 500 500, float, class:(hu.irl.cameractrls)"

      # Zen browser applications
      "size 70% 70%, float, class:(zen.alpha)$, title:^(.*)(Save)(.*)$"

      # =============================================================================
      # GAMING OPTIMIZATIONS
      # =============================================================================
      # Enable immediate mode for games (reduced input latency)
      "immediate, class:^(cs2)$"
      "immediate, class:^(steam_app_0)$"
      "immediate, class:^(steam_app_1)$"
      "immediate, class:^(steam_app_2)$"
      "immediate, class:^(.*)(.exe)$"

      # =============================================================================
      # SCREEN SHARING / RECORDING
      # =============================================================================
      # XWayland video bridge (invisible for screen sharing)
      "opacity 0.0 override, class:^(xwaylandvideobridge)$"
      "noanim, class:^(xwaylandvideobridge)$"
      "noinitialfocus, class:^(xwaylandvideobridge)$"
      "maxsize 1 1, class:^(xwaylandvideobridge)$"
      "noblur, class:^(xwaylandvideobridge)$"

      # =============================================================================
      # SCREEN CAPTURE AND EDITING
      # =============================================================================
      # Flameshot screenshot tool
      "float, class:^(flameshot)$"
      "pin, class:^(flameshot)$"
      "move 0 0, title:^(flameshot)$"
      "suppressevent fullscreen, class:^(flameshot)$"

      # OBS Studio
      "float, class:^(com.obsproject.Studio)$"
      "workspace 4, class:^(com.obsproject.Studio)$"

      # =============================================================================
      # WEATHER POPUP RULES
      # =============================================================================
      # Weather popup window behavior
      "float, title:^(Weather - London)$"
      "center, title:^(Weather - London)$"
      "size 900 700, title:^(Weather - London)$"
      "opacity 0.95, title:^(Weather - London)$"
      "rounding 10, title:^(Weather - London)$"
      "pin, title:^(Weather - London)$"
      "stayfocused, title:^(Weather - London)$"
      "dimaround, title:^(Weather - London)$"
      "animation slide, title:^(Weather - London)$"

      # Weather popup class-based rules for reliability
      "float, class:^(weather-popup)$"
      "center, class:^(weather-popup)$"
      "size 900 700, class:^(weather-popup)$"
      "opacity 0.95, class:^(weather-popup)$"
      "rounding 10, class:^(weather-popup)$"
      "pin, class:^(weather-popup)$"
    ];

    # Legacy window rules (older format)
    windowrule = [
      "bordercolor rgba(FF0050FF), fullscreen:1"
    ];
  };
}
