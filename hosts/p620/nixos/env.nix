{...}: {
  wayland.windowManager.hyprland.extraConfig = ''
    # Environment variables for Hyprland configuration

    # General system settings
    env = EDITOR,nvim                    # Set default text editor to Neovim
    env = BROWSER,google-chrome-stable   # Set default web browser to Google Chrome
    env = TERMINAL,foot                  # Set default terminal emulator to Foot

    # Wayland-specific settings
    env = KITTY_DISABLE_WAYLAND,1          # Enable Wayland support for Kitty terminal
    env = XDG_CURRENT_DESKTOP,Hyprland     # Set current desktop environment to Hyprland
    env = XDG_SESSION_TYPE,wayland         # Set session type to Wayland
    env = CLUTTER_BACKEND,wayland          # Use Wayland backend for Clutter
    env = EGL_PLATFORM,wayland             # Set EGL platform to Wayland

    # Cursor settings
    env = XCURSOR_THEME,Bibata-Modern-Ice  # Set cursor theme
    env = XCURSOR_SIZE,24                  # Set X cursor size
    env = HYPRCURSOR_SIZE,24               # Set Hyprland cursor size

    # Graphics and display settings
    env = SDL_VIDEODRIVER,wayland          # Use wyaland video driver for SDL

    # GTK settings
    env = GDK_BACKEND,wayland          # Set GTK backend to Wayland, fallback to X11
    env = GTK_THEME,Gruvbox-Dark-B-LB      # Set GTK theme

    # Qt settings
    env = QT_QPA_PLATFORM,wayland          # Set Qt platform to Wayland
    env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1  # Disable window decorations in Qt Wayland
    env = QT_AUTO_SCREEN_SCALE_FACTOR,1    # Enable automatic screen scaling for Qt
    env = QT_ENABLE_HIGHDPI_SCALING,1      # Enable high DPI scaling for Qt

    # Firefox and Thunderbird settings
    env = MOZ_ENABLE_WAYLAND,1             # Enable Wayland support for Mozilla applications

    # NixOS-specific settings
    env = NIXOS_WAYLAND,1                  # Enable Wayland support in NixOS
    env = NIXOS_OZONE_WL,1                 # Enable Ozone Wayland support in NixOS
    env = ELECTRON_OZONE_PLATFORM_HINT,auto  # Set Electron to automatically choose between Wayland and X11
  '';
}
