# GNOME Desktop Environment Configuration

A comprehensive, optional GNOME desktop environment configuration for NixOS with Gruvbox theming,
extensions support, and extensive customization options.

## Features

- **🎨 Gruvbox Theming**: Complete Gruvbox dark/light theme with GTK, icons, and cursor themes
- **🧩 Extensions Framework**: Easy-to-configure GNOME Shell extensions
- **📱 Rich Applications**: Full suite of GNOME applications with proper configuration
- **⌨️ Custom Keybindings**: Productivity-focused keyboard shortcuts
- **🔧 Modular Design**: Optional components that can be enabled/disabled per host
- **🎯 Host-Optimized**: Different configurations for workstations vs laptops

## Usage

### Enabling GNOME

GNOME is **disabled by default** on all hosts. To enable it, set `desktop.gnome.enable = true`
in your host-specific home configuration:

#### P620 (Workstation)

```nix
# In Users/olafkfreund/p620_home.nix
desktop.gnome = {
  enable = true;  # Set to true to enable GNOME
  theme = {
    enable = true;
    variant = "dark";  # or "light"
  };
  extensions.enable = true;
  apps.enable = true;
  keybindings.enable = true;
};
```

#### Razer/Samsung (Laptops)

```nix
# In Users/olafkfreund/razer_home.nix or samsung_home.nix
desktop.gnome = {
  enable = true;  # Set to true to enable GNOME
  theme = {
    enable = true;
    variant = "dark";
  };
  extensions.enable = true;
  apps.enable = true;
  keybindings.enable = true;
};
```

### Configuration Options

#### Theme Configuration

```nix
desktop.gnome.theme = {
  enable = true;           # Enable Gruvbox theming
  variant = "dark";        # "dark" or "light"
};
```

#### Extensions Configuration

```nix
desktop.gnome.extensions = {
  enable = true;           # Enable extensions support
  packages = with pkgs.gnomeExtensions; [
    # Add your preferred extensions
    dash-to-dock           # Dock/taskbar
    appindicator          # System tray
    vitals                # System monitoring
    blur-my-shell         # Visual effects
    caffeine              # Prevent sleep
    clipboard-indicator   # Clipboard manager
    # ... add more as needed
  ];
};
```

#### Applications Configuration

```nix
desktop.gnome.apps = {
  enable = true;           # Enable additional GNOME apps
  packages = with pkgs; [
    # Add extra applications
    gnome-tweaks
    dconf-editor
    gnome-power-manager    # For laptops
    # ... add more as needed
  ];
};
```

#### Keybindings

```nix
desktop.gnome.keybindings.enable = true;  # Enable custom keybindings
```

## Pre-configured Extensions

### Always Available (when extensions.enable = true)

- **User Themes**: Enables custom shell themes
- **GSConnect**: Android device integration

### Host-Specific Examples

#### Workstation (P620)

- Dash to Dock
- AppIndicator support
- Vitals (system monitoring)
- Blur My Shell (visual effects)

#### Laptops (Razer/Samsung)

- Dash to Dock
- AppIndicator support
- Battery Threshold (battery management)
- Caffeine (prevent sleep)
- Clipboard Indicator

## Included Applications

### Core GNOME Apps

- **System**: Tweaks, Extensions App, Settings, System Monitor
- **Productivity**: Calculator, Calendar, Clocks, Weather, Contacts
- **Media**: Eye of GNOME (images), Videos, Music, Photos
- **Files**: Nautilus, File Roller (archives)
- **Text**: Text Editor, Gedit, Evince (PDF)

### Development Tools

- GNOME Builder (IDE) - optional, large package

## Theming Details

### Gruvbox Theme Components

- **GTK Theme**: Gruvbox-Dark-BL / Gruvbox-Light-BL
- **Icon Theme**: Gruvbox-Plus-Dark
- **Cursor Theme**: Bibata-Modern-Classic
- **Fonts**: Inter (UI), JetBrainsMono Nerd Font (terminal)

### Terminal Colors

Custom Gruvbox color palette for GNOME Terminal with proper contrast and readability.

### Custom CSS

Additional styling for consistent Gruvbox appearance across all GNOME applications.

## Keyboard Shortcuts

### Window Management

- `Super + Q`: Close window
- `Super + M`: Toggle maximize
- `Super + H`: Minimize
- `Super + L`: Lock screen
- `F11`: Toggle fullscreen

### Workspaces

- `Super + 1-9`: Switch to workspace
- `Super + Shift + 1-9`: Move window to workspace
- `Super + Ctrl + Arrow`: Navigate workspaces

### Applications

- `Super + E`: File manager
- `Super + C`: Calculator
- `Ctrl + Alt + T`: Terminal
- `Ctrl + Shift + Esc`: System monitor

### Media Keys

- Volume, brightness, media playback controls
- `Print`: Screenshot UI
- `Alt + Print`: Window screenshot

## File Associations

Proper MIME type associations for GNOME applications:

- Images → Eye of GNOME
- Videos → GNOME Videos
- Music → GNOME Music
- PDFs → Evince
- Archives → File Roller
- Text → Text Editor

## Requirements

### System Requirements

- GNOME desktop environment enabled in NixOS configuration
- Wayland or X11 support
- Sufficient resources for GNOME Shell

### Dependencies

All required packages are automatically installed when GNOME components are enabled.

## Switching Between Desktop Environments

You can have both GNOME and other desktop environments (like Hyprland) installed simultaneously:

1. **Enable GNOME** in home-manager configuration
2. **Enable GNOME** in NixOS system configuration
3. **Choose at login** which desktop session to use

## Troubleshooting

### GNOME Shell Extensions Not Working

1. Ensure `desktop.gnome.extensions.enable = true`
2. Check extension compatibility with your GNOME version
3. Restart GNOME Shell: `Alt + F2`, type `r`, press Enter

### Theme Not Applied

1. Verify `desktop.gnome.theme.enable = true`
2. Check GNOME Tweaks → Appearance
3. Restart user session

### Custom Keybindings Not Working

1. Ensure `desktop.gnome.keybindings.enable = true`
2. Check Settings → Keyboard → Keyboard Shortcuts
3. Resolve conflicts with existing shortcuts

## Customization

### Adding Extensions

Add extensions to your host configuration:

```nix
desktop.gnome.extensions.packages = with pkgs.gnomeExtensions; [
  your-extension-here
  another-extension
];
```

### Adding Applications

Add applications to your host configuration:

```nix
desktop.gnome.apps.packages = with pkgs; [
  your-app-here
  another-app
];
```

### Modifying Theme

Edit `theme.nix` to customize colors, fonts, or styling.

### Custom Keybindings

Edit `keybindings.nix` to add or modify keyboard shortcuts.

## Architecture

```text
home/desktop/gnome/
├── default.nix      # Main configuration and options
├── theme.nix        # Gruvbox theming and Stylix integration
├── extensions.nix   # GNOME Shell extensions
├── apps.nix         # GNOME applications and settings
├── keybindings.nix  # Custom keyboard shortcuts
└── README.md        # This documentation
```

This modular architecture allows you to:

- Enable/disable components independently
- Customize each component separately
- Maintain clean, organized configuration
- Share configurations between hosts with variations
