{...}: {
  wayland.windowManager.hyprland.extraConfig = ''
    # =============================================================================
    # GLOBAL SETTINGS
    # =============================================================================
    # Disable hyprbars titlebar for all windows
    windowrulev2 = plugin:hyprbars:nobar, class:(album-art)

    # =============================================================================
    # TERMINAL EMULATOR RULES
    # =============================================================================
    # Set all terminal emulators to float with consistent sizing
    windowrulev2 = float, class:(alacritty)
    windowrulev2 = size 1000 1000, class:(alacritty)
    windowrulev2 = float, class:(kitty)
    windowrulev2 = size 1000 1000, class:(kitty)
    windowrulev2 = float, class:(wezterm)
    windowrulev2 = size 1000 1000, class:(wezterm)
    windowrulev2 = float, class:(foot)
    windowrulev2 = size 1000 1000, class:(foot)
    windowrulev2 = animation slide left, class:^(foot)$

    windowrulev2 = float, class:(web-search)
    windowrulev2 = size 1000 1000, class:(web-search)
    windowrulev2 = animation slide down, class:^(web-search)$

    # =============================================================================
    # SYSTEM UTILITY RULES
    # =============================================================================
    # Keep system utilities in current workspace
    windowrulev2 = workspace current, title:MainPicker
    windowrulev2 = workspace current, class:.blueman-manager-wrapped
    windowrulev2 = workspace current, class:xdg-desktop-portal-gtk

    # Bluetooth manager
    windowrulev2 = float, class:(blueman-manager)
    windowrulev2 = center, class:(blueman-manager)

    # Network utilities
    windowrulev2 = float,class:^(nm-applet)$
    windowrulev2 = float,class:^(nm-connection-editor)$

    # Sound control
    windowrulev2 = float, class:(org.pulseaudio.pavucontrol)
    windowrulev2 = size 1000 1000, class:(org.pulseaudio.pavucontrol)
    windowrulev2 = center, class:(org.pulseaudio.pavucontrol)

    # XDG portal
    windowrulev2 = float, class:^(xdg-desktop-portal-gtk)$
    windowrulev2 = size 900 500, class:^(xdg-desktop-portal-gtk)$
    windowrulev2 = dimaround, class:^(xdg-desktop-portal-gtk)$
    windowrulev2 = center, class:^(xdg-desktop-portal-gtk)$

    # =============================================================================
    # APPLICATION LAUNCHERS
    # =============================================================================
    # Rofi - application launcher
    windowrulev2 = animation bounce, class:^(rofi)$

    # =============================================================================
    # PRODUCTIVITY APPLICATIONS
    # =============================================================================
    # Obsidian note-taking app
    windowrulev2 = float, class:(obsidian)

    # =============================================================================
    # THUNDERBIRD EMAIL CLIENT
    # =============================================================================
    # Main window - assign to mail workspace
    windowrulev2 = workspace special:mail, class:^(thunderbird)$
    windowrulev2 = animation slide bottom, class:^(thunderbird)$
    # Make main Thunderbird window fullscreen
    windowrulev2 = fullscreen, class:^(thunderbird)$, title:^(Mozilla Thunderbird)$

    # Make all thunderbird windows float by default
    # windowrulev2 = float, class:^(thunderbird)$  # Disabled to allow fullscreen for main window

    # Size the main window appropriately (70%) - will only apply when not fullscreen
    windowrulev2 = size 70% 70%, class:^(thunderbird)$, title:^(Mozilla Thunderbird)$

    # Handle all common dialog types
    windowrulev2 = float, class:^(thunderbird)$, title:^(.*)(Reminder)(.*)$
    windowrulev2 = float, class:^(thunderbird)$, title:^(.*)(Write)(.*)$
    windowrulev2 = float, class:^(thunderbird)$, title:^(.*)(Compose)(.*)$
    windowrulev2 = float, class:^(thunderbird)$, title:^(.*)(Calendar)(.*)$
    windowrulev2 = float, class:^(thunderbird)$, title:^(.*)(Event)(.*)$
    windowrulev2 = float, class:^(thunderbird)$, title:^(.*)(Properties)(.*)$
    windowrulev2 = float, class:^(thunderbird)$, title:^(.*)(Preferences)(.*)$
    windowrulev2 = float, class:^(thunderbird)$, title:^(.*)(Settings)(.*)$
    windowrulev2 = float, class:^(thunderbird)$, title:^(.*)(Add-ons)(.*)$
    windowrulev2 = float, class:^(thunderbird)$, title:^(.*)(About)(.*)$
    windowrulev2 = float, class:^(thunderbird)$, title:^(.*)(Quick Filter)(.*)$

    # Size for common popups (centered, 60% size)
    windowrulev2 = size 60% 60%, class:^(thunderbird)$, title:^(.*)(Write)(.*)$
    windowrulev2 = size 60% 60%, class:^(thunderbird)$, title:^(.*)(Compose)(.*)$
    windowrulev2 = center, class:^(thunderbird)$, title:^(.*)(Write)(.*)$
    windowrulev2 = center, class:^(thunderbird)$, title:^(.*)(Compose)(.*)$

    # Handle smaller dialogs (centered, 50% size)
    windowrulev2 = size 50% 50%, class:^(thunderbird)$, title:^(.*)(Reminder)(.*)$
    windowrulev2 = size 50% 50%, class:^(thunderbird)$, title:^(.*)(Properties)(.*)$
    windowrulev2 = size 50% 50%, class:^(thunderbird)$, title:^(.*)(Event)(.*)$
    windowrulev2 = center, class:^(thunderbird)$, title:^(.*)(Reminder)(.*)$
    windowrulev2 = center, class:^(thunderbird)$, title:^(.*)(Properties)(.*)$
    windowrulev2 = center, class:^(thunderbird)$, title:^(.*)(Event)(.*)$

    # Very small dialogs (40% size)
    windowrulev2 = size 40% 40%, class:^(thunderbird)$, title:^(.*)(About)(.*)$
    windowrulev2 = center, class:^(thunderbird)$, title:^(.*)(About)(.*)$

    # =============================================================================
    # WEB BROWSERS AND COMMUNICATION
    # =============================================================================
    # Google Chrome
    windowrulev2 = workspace special:chrome, float, class:(google-chrome)

    # Common dialog boxes
    windowrulev2 = float,size 900 500,title:^(Choose Files)
    windowrulev2 = float,size 900 500,title:^(Sign in)

    # Microsoft Edge
    windowrulev2 = workspace 4, class:^(Edge)$

    # Slack communication platform
    windowrulev2 = workspace special:slack, float, class:^(Slack)
    windowrulev2 = workspace special:slack,size 50% 50%,float,class:^(Slack),title:^(Huddle)

    # Discord communication platform
    windowrulev2 = workspace special:discord, float, class:^(vesktop)
    windowrulev2 = workspace special:discord, size 50% 50%, float, class:^(vesktop)

    # Telegram messaging
    windowrulev2 = workspace 8, class:(org.telegram.desktop)
    windowrulev2 = size 970 480, class:(org.telegram.desktop), title:(Choose Files)
    windowrulev2 = center, class:(org.telegram.desktop), title:(Choose Files)

    # =============================================================================
    # DEVELOPMENT TOOLS
    # =============================================================================
    # Tmux terminal multiplexer
    windowrulev2 = workspace special:tmux, float, title:^(tmux-sratch)

    # =============================================================================
    # ENTERTAINMENT APPLICATIONS
    # =============================================================================
    # Spotify music player
    windowrulev2 = workspace special:spotify, float, class:^(spotify)
    windowrulev2 = workspace special:spotify, class:^(Spotify)$

    # =============================================================================
    # PASSWORD MANAGEMENT
    # =============================================================================
    # 1Password password manager
    windowrulev2 = workspace special:magic, float, class:^(1Password)$
    windowrulev2 = workspace special:magic, float, class:^(org.1password.1password)$
    # Handle 1Password dialogs
    windowrulev2 = float, class:^(1Password)$, title:^(.*)(Preferences)(.*)$
    windowrulev2 = center, class:^(1Password)$, title:^(.*)(Preferences)(.*)$
    windowrulev2 = size 50% 50%, class:^(1Password)$, title:^(.*)(Preferences)(.*)$

    # =============================================================================
    # VIRTUALIZATION
    # =============================================================================
    # Virtual Machine Manager
    windowrulev2 = float, class:(.virt-manager-wrapped)
    windowrulev2 = size 1000 1000, class:(.virt-manager-wrapped)

    # =============================================================================
    # SYSTEM APPLICATIONS
    # =============================================================================
    # GNOME applications
    windowrulev2 = float, class:(org.gnome.*)
    windowrulev2 = size 1000 1000, class:(org.gnome.*)
    windowrulev2 = center, class:(org.gnome.*)

    # GNOME Calendar - specific positioning
    windowrulev2 = animation slide up, class:^(org.gnome.Calendar)$
    windowrulev2 = size 400 500, class:^(org.gnome.Calendar)$
    windowrulev2 = move 480 45, class:^(org.gnome.Calendar)$

    # Camera controls
    windowrulev2 = size 500 500, float, class:(hu.irl.cameractrls)  # Fixed typo: fload -> float

    # Zen applications
    windowrulev2 = size 70% 70%, float, class:(zen.aplha)$,title:^(.*)(Save)(.*)$  # Note: possible typo in 'aplha'

    # =============================================================================
    # GAMING OPTIMIZATIONS
    # =============================================================================
    # Allow screen tearing for reduced input latency on games
    windowrulev2 = immediate, class:^(cs2)$
    windowrulev2 = immediate, class:^(steam_app_0)$
    windowrulev2 = immediate, class:^(steam_app_1)$
    windowrulev2 = immediate, class:^(steam_app_2)$
    windowrulev2 = immediate, class:^(.*)(.exe)$

    # =============================================================================
    # SCREEN SHARING / RECORDING
    # =============================================================================
    # XWayland video bridge for screen sharing compatibility
    windowrulev2 = opacity 0.0 override,class:^(xwaylandvideobridge)$
    windowrulev2 = noanim,class:^(xwaylandvideobridge)$
    windowrulev2 = noinitialfocus,class:^(xwaylandvideobridge)$
    windowrulev2 = maxsize 1 1,class:^(xwaylandvideobridge)$
    windowrulev2 = noblur,class:^(xwaylandvideobridge)$

    # =============================================================================
    # SCREEN CAPTURE AND EDITING
    # =============================================================================
    # Flameshot screenshot tool
    windowrulev2 = float, class:^(flameshot)$
    windowrulev2 = pin, class:^(flameshot)$
    windowrulev2 = move 0 0, title:^(flameshot)$
    windowrulev2 = suppressevent fullscreen, class:^(flameshot)$

    # OBS Studio for screen recording and streaming
    windowrulev2 = float, class:^(com.obsproject.Studio)$
    windowrulev2 = workspace 4, class:^(com.obsproject.Studio)$

    # =============================================================================
    # MISCELLANEOUS
    # =============================================================================
    # Fullscreen windows
    windowrule = bordercolor rgba(FF0050FF),fullscreen:1
  '';
}
