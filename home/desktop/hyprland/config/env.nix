# Hyprland Environment Variables Configuration
# Converted to native Nix configuration for better type safety and maintainability
{
  config,
  lib,
  ...
}:
with lib; {
  wayland.windowManager.hyprland.settings = {
    env = [
      # General system settings
      "EDITOR,nvim" # Default text editor
      "BROWSER,google-chrome-stable" # Default web browser
      "TERMINAL,foot" # Default terminal emulator

      # Wayland-specific settings
      "XDG_CURRENT_DESKTOP,Hyprland" # Current desktop environment
      "XDG_SESSION_TYPE,wayland" # Session type
      "XDG_SESSION_DESKTOP,Hyprland" # Session desktop

      # Suppress Wayland warnings
      "WAYLAND_DEBUG,suppress" # Suppress non-critical warnings
      "NO_XDG_ICON_WARNING,1" # Suppress icon warnings

      # Wayland backend configuration
      "CLUTTER_BACKEND,wayland" # Clutter backend
      "EGL_PLATFORM,wayland" # EGL platform
      "SDL_VIDEODRIVER,wayland" # SDL video driver

      # Cursor settings
      "XCURSOR_THEME,Bibata-Modern-Ice" # Cursor theme
      "XCURSOR_SIZE,24" # X cursor size
      "HYPRCURSOR_SIZE,24" # Hyprland cursor size

      # Application-specific Wayland support
      "KITTY_ENABLE_WAYLAND,1" # Kitty terminal
      "MOZ_ENABLE_WAYLAND,1" # Mozilla applications
      "MOZ_WEBRENDER,1" # Firefox WebRender
      "MOZ_USE_XINPUT2,1" # Firefox touchpad support

      # GUI toolkit configuration
      "GDK_BACKEND,wayland,x11" # GTK backend (Wayland with X11 fallback)
      "GTK_THEME,Gruvbox-Dark-B-LB" # GTK theme
      "QT_QPA_PLATFORM,wayland;xcb" # Qt platform (Wayland with X11 fallback)
      "QT_QPA_PLATFORMTHEME,gnome" # Qt theming
      "QT_WAYLAND_DISABLE_WINDOWDECORATION,1" # Disable Qt window decorations
      "QT_AUTO_SCREEN_SCALE_FACTOR,1" # Qt automatic scaling

      # Electron and Chromium-based applications
      "ELECTRON_OZONE_PLATFORM_HINT,wayland" # Force Electron to use Wayland
      "OZONE_PLATFORM,wayland" # Ozone platform
    ];
  };
}
