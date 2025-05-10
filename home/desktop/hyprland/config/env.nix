{...}: {
  wayland.windowManager.hyprland.extraConfig = ''
    # Environment variables for Hyprland configuration

    # General system settings
    env = EDITOR,nvim                      # Set default text editor to Neovim
    env = BROWSER,google-chrome-stable     # Set default web browser to Google Chrome
    env = TERMINAL,foot                    # Set default terminal emulator to Foot

    # Wayland-specific settings
    env = XDG_CURRENT_DESKTOP,Hyprland     # Set current desktop environment to Hyprland
    env = XDG_SESSION_TYPE,wayland         # Set session type to Wayland
    env = XDG_SESSION_DESKTOP,Hyprland     # Set session desktop to Hyprland

    # Disable XDG toplevel icon protocol warning
    env = WAYLAND_DEBUG,suppress           # Suppress non-critical Wayland warnings
    env = NO_XDG_ICON_WARNING,1            # Custom variable to suppress icon warnings

    # Ensure proper Wayland integration
    env = CLUTTER_BACKEND,wayland          # Use Wayland backend for Clutter
    env = EGL_PLATFORM,wayland             # Set EGL platform to Wayland
    env = SDL_VIDEODRIVER,wayland          # Use Wayland video driver for SDL

    # Cursor settings
    env = XCURSOR_THEME,Bibata-Modern-Ice  # Set cursor theme
    env = XCURSOR_SIZE,24                  # Set X cursor size
    env = HYPRCURSOR_SIZE,24               # Set Hyprland cursor size

    # Graphics and display settings
    # Uncomment these settings for NVIDIA GPUs
    # env = GBM_BACKEND,nvidia-drm           # Use NVIDIA GBM backend
    # env = __GLX_VENDOR_LIBRARY_NAME,nvidia # Set GLX vendor library to NVIDIA
    # env = WLR_NO_HARDWARE_CURSORS,1        # Disable hardware cursors
    # env = WLR_DRM_NO_ATOMIC,1              # Disable atomic mode setting for wlroots

    # Application-specific settings
    env = KITTY_ENABLE_WAYLAND,1           # Enable Wayland support for Kitty terminal
    env = MOZ_ENABLE_WAYLAND,1             # Enable Wayland support for Mozilla applications
    env = MOZ_WEBRENDER,1                  # Enable WebRender in Firefox for better performance
    env = MOZ_USE_XINPUT2,1                # Enable XInput2 for better touchpad support in Firefox

    # GUI toolkit settings
    env = GDK_BACKEND,wayland,x11          # Set GTK backend to Wayland, fallback to X11
    env = GTK_THEME,Gruvbox-Dark-B-LB      # Set GTK theme
    env = QT_QPA_PLATFORM,wayland;xcb      # Set Qt platform to Wayland, fallback to X11
    env = QT_QPA_PLATFORMTHEME,adwaita     # Use adwaita for Qt theming
    env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1  # Disable window decorations in Qt Wayland
    env = QT_AUTO_SCREEN_SCALE_FACTOR,1    # Enable automatic screen scaling for Qt

    # Electron application settings
    env = ELECTRON_OZONE_PLATFORM_HINT,wayland  # Force Electron apps to use Wayland
    env = OZONE_PLATFORM,wayland           # Set Ozone platform to Wayland
  '';
}
