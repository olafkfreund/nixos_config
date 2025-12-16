# DankMaterialShell (DMS) Skill

A specialized skill for configuring and customizing DankMaterialShell with Wayland compositors (MangoWC, Niri, Hyprland, Sway, labwc), providing expert guidance on this complete desktop shell replacement built with Quickshell & Go.

## Skill Overview

**Purpose**: Provide comprehensive support for DankMaterialShell configuration, theming, and integration with Wayland compositors in NixOS.

**Invoke When**:

- Setting up DankMaterialShell desktop environment
- Configuring DMS with Niri, Hyprland, MangoWC, Sway, or labwc
- Customizing DMS theming and appearance
- Managing DMS components (launcher, control center, notifications)
- Using DMS CLI and IPC system
- Troubleshooting DankMaterialShell issues
- Replacing traditional Wayland desktop components
- Creating custom themes for DMS
- Integrating DMS with NixOS/home-manager

## Core Capabilities

### 1. What is DankMaterialShell?

**DankMaterialShell (DMS)** is a complete desktop shell for Wayland compositors that **replaces waybar, swaylock, swayidle, mako, fuzzel, polkit, and everything else** you'd normally stitch together to make a desktop.

**Built With:**

- **Quickshell**: QML-based UI framework for panels and widgets
- **Go**: Backend for CLI tools and system integration

**Key Philosophy**: Instead of combining multiple separate tools (waybar + mako + fuzzel + swaylock + etc.), DMS provides a unified, cohesive desktop experience.

**Project**: [AvengeMedia/DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
**Website**: [danklinux.com](https://danklinux.com)
**Documentation**: [danklinux.com/docs](https://danklinux.com/docs)

### 2. Architecture & Components

**DMS Replaces:**

| Traditional Tool | DMS Component      | Purpose               |
| ---------------- | ------------------ | --------------------- |
| waybar           | DMS Panels         | Status bar and panels |
| swaylock         | DMS Session        | Screen lock           |
| swayidle         | DMS Session        | Idle detection        |
| mako/dunst       | DMS Notifications  | Notification system   |
| fuzzel/rofi      | DMS Spotlight      | Application launcher  |
| polkit-agent     | DMS Polkit         | Authentication        |
| nm-applet        | DMS Control Center | Network management    |
| blueman          | DMS Control Center | Bluetooth management  |
| pavucontrol      | DMS Control Center | Audio control         |

**Three-Part Architecture:**

1. **Quickshell** (QML Interface)
   - UI components for panels, widgets, overlays
   - System integration modules
   - Shared theming resources

2. **Core** (Go Backend)
   - `dms` CLI for shell control
   - IPC system for external communication
   - System integration

3. **Distro** (Packaging)
   - NixOS/home-manager modules
   - Distribution-specific packaging

### 3. Installation

**Method 1: Quick Install (One-Command)**

```bash
# Automatic installation for most distros
curl -fsSL https://install.danklinux.com | sh

# Supports: Arch, Fedora, Debian, Ubuntu, openSUSE, Gentoo
```

**Method 2: NixOS Flake (Recommended for NixOS)**

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Add DankMaterialShell
    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, dms, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        home-manager.nixosModules.home-manager
        {
          home-manager.users.username = {
            # Import DMS home-manager module
            imports = [ dms.homeModules.dankMaterialShell.default ];

            # Enable DankMaterialShell
            programs.dankMaterialShell = {
              enable = true;

              # Compositor integration
              compositor = "niri";  # or "hyprland", "mangowc", "sway", "labwc"

              # Theming
              theming = {
                matugen.enable = true;  # Wallpaper-based theming
                dank16.enable = true;   # Color scheme generation
              };

              # Components
              components = {
                panels.enable = true;
                spotlight.enable = true;
                notifications.enable = true;
                controlCenter.enable = true;
                session.enable = true;
                polkit.enable = true;
              };
            };
          };
        }
      ];
    };
  };
}
```

**Method 3: Arch Linux (AUR)**

```bash
# Binary package
yay -S dms-shell-bin

# Git version
yay -S dms-shell-git
```

**Method 4: Manual Build from Source**

```bash
# Clone repository
git clone https://github.com/AvengeMedia/DankMaterialShell.git
cd DankMaterialShell

# Build Go backend
cd core
make
make dankinstall

# Run Quickshell
cd ..
quickshell -p quickshell/
```

### 4. Compositor Integration

**Fully Supported Compositors:**

DMS works best with these compositors (full workspace switching, overview integration, monitor management):

1. **Niri** - Scrollable-tiling compositor
2. **Hyprland** - Dynamic tiling with effects
3. **MangoWC** - DWM-like Wayland compositor
4. **Sway** - i3-compatible Wayland compositor
5. **labwc** - Openbox-like stacking compositor
6. **Scroll** - Experimental compositor

**Other Wayland compositors** work with reduced features.

**Niri Integration Example:**

```nix
# home.nix
{ config, pkgs, ... }:
{
  # Configure Niri
  programs.niri.settings = {
    # Disable built-in components (DMS replaces them)
    # No need for waybar, etc.

    # Spawn DMS at startup
    spawn-at-startup = [
      { command = [ "dms" "run" ]; }
    ];

    # DMS handles panels, so adjust struts
    layout.struts = {
      top = 40;     # DMS panel height
      bottom = 0;
      left = 0;
      right = 0;
    };

    # Remove keybindings that conflict with DMS
    binds = {
      # Let DMS handle launcher
      # "Mod+Space" removed

      # DMS Spotlight toggle
      "Mod+Space".action = spawn "dms" "ipc" "call" "spotlight" "toggle";

      # DMS Control Center
      "Mod+Shift+C".action = spawn "dms" "ipc" "call" "controlcenter" "toggle";

      # DMS lock screen
      "Mod+L".action = spawn "dms" "ipc" "call" "session" "lock";
    };
  };

  # Enable DankMaterialShell
  programs.dankMaterialShell = {
    enable = true;
    compositor = "niri";
  };
}
```

**Hyprland Integration Example:**

```nix
# home.nix
{ config, pkgs, ... }:
{
  # Configure Hyprland
  wayland.windowManager.hyprland.settings = {
    # Spawn DMS at startup
    exec-once = [
      "dms run"
    ];

    # DMS keybindings
    bind = [
      # Launcher
      "SUPER, Space, exec, dms ipc call spotlight toggle"

      # Control Center
      "SUPER_SHIFT, C, exec, dms ipc call controlcenter toggle"

      # Lock screen
      "SUPER, L, exec, dms ipc call session lock"

      # Volume (DMS handles OSD)
      ", XF86AudioRaiseVolume, exec, dms ipc call audio setvolume +5"
      ", XF86AudioLowerVolume, exec, dms ipc call audio setvolume -5"
      ", XF86AudioMute, exec, dms ipc call audio togglemute"

      # Brightness (DMS handles OSD)
      ", XF86MonBrightnessUp, exec, dms brightness set +10"
      ", XF86MonBrightnessDown, exec, dms brightness set -10"
    ];

    # Layer rules for DMS panels
    layerrule = [
      "blur, dms-panel"
      "ignorezero, dms-panel"
    ];

    # Window rules for DMS components
    windowrulev2 = [
      "float, class:^(dms-spotlight)$"
      "center, class:^(dms-spotlight)$"
      "stayfocused, class:^(dms-spotlight)$"

      "float, class:^(dms-controlcenter)$"
      "move 100%-420 60, class:^(dms-controlcenter)$"
      "size 400 800, class:^(dms-controlcenter)$"
    ];
  };

  # Enable DankMaterialShell
  programs.dankMaterialShell = {
    enable = true;
    compositor = "hyprland";
  };
}
```

**MangoWC Integration Example:**

```bash
# ~/.config/mango/config.conf

# Spawn DMS at startup
spawn-at-startup "dms run"

# DMS keybindings
bind=SUPER,Space,spawn,dms ipc call spotlight toggle
bind=SUPER_SHIFT,c,spawn,dms ipc call controlcenter toggle
bind=SUPER,l,spawn,dms ipc call session lock

# Volume with DMS OSD
bind=,XF86AudioRaiseVolume,spawn,dms ipc call audio setvolume +5
bind=,XF86AudioLowerVolume,spawn,dms ipc call audio setvolume -5
bind=,XF86AudioMute,spawn,dms ipc call audio togglemute

# Brightness with DMS OSD
bind=,XF86MonBrightnessUp,spawn,dms brightness set +10
bind=,XF86MonBrightnessDown,spawn,dms brightness set -10
```

### 5. CLI Usage & IPC System

**DMS CLI Commands:**

```bash
# ============ Shell Management ============
dms run                           # Start DankMaterialShell
dms stop                          # Stop DankMaterialShell
dms restart                       # Restart DankMaterialShell
dms version                       # Show version info

# ============ IPC Commands ============
# Spotlight (Launcher)
dms ipc call spotlight toggle     # Toggle launcher
dms ipc call spotlight show       # Show launcher
dms ipc call spotlight hide       # Hide launcher

# Control Center
dms ipc call controlcenter toggle # Toggle control center
dms ipc call controlcenter show   # Show control center
dms ipc call controlcenter hide   # Hide control center

# Notifications
dms ipc call notifications show   # Show notification center
dms ipc call notifications clear  # Clear all notifications
dms ipc call notifications dismiss # Dismiss latest

# Audio
dms ipc call audio setvolume 50   # Set volume to 50%
dms ipc call audio setvolume +5   # Increase volume
dms ipc call audio setvolume -5   # Decrease volume
dms ipc call audio togglemute     # Toggle mute
dms ipc call audio getsources     # List audio sources
dms ipc call audio getsinks       # List audio sinks

# Session
dms ipc call session lock         # Lock screen
dms ipc call session unlock       # Unlock screen
dms ipc call session logout       # Logout
dms ipc call session suspend      # Suspend system
dms ipc call session reboot       # Reboot system
dms ipc call session shutdown     # Shutdown system

# Wallpaper
dms ipc call wallpaper set /path/to/image.jpg
dms ipc call wallpaper next       # Next wallpaper
dms ipc call wallpaper previous   # Previous wallpaper
dms ipc call wallpaper random     # Random wallpaper

# Theme
dms ipc call theme set dark       # Set dark theme
dms ipc call theme set light      # Set light theme
dms ipc call theme set auto       # Auto theme (time-based)
dms ipc call theme list           # List available themes

# Night Mode
dms ipc call nightmode toggle     # Toggle night mode
dms ipc call nightmode set 3500   # Set color temperature

# ============ Display Management ============
dms brightness list               # List displays
dms brightness get                # Get current brightness
dms brightness set 50             # Set brightness to 50%
dms brightness set +10            # Increase brightness
dms brightness set -10            # Decrease brightness

# ============ Plugin System ============
dms plugins search <query>        # Search plugin registry
dms plugins list                  # List installed plugins
dms plugins install <plugin>      # Install plugin
dms plugins remove <plugin>       # Remove plugin
dms plugins update                # Update all plugins

# ============ Configuration ============
dms config get <key>              # Get config value
dms config set <key> <value>      # Set config value
dms config reset                  # Reset to defaults

# ============ Debugging ============
dms debug logs                    # Show logs
dms debug status                  # Show system status
dms debug reload                  # Reload configuration
```

**IPC in Scripts:**

```bash
#!/bin/bash
# Example: Volume control with notification

case "$1" in
  up)
    dms ipc call audio setvolume +5
    ;;
  down)
    dms ipc call audio setvolume -5
    ;;
  mute)
    dms ipc call audio togglemute
    ;;
esac
```

### 6. Dynamic Theming System

**Matugen Integration:**

DMS automatically generates color schemes from your wallpaper using **matugen** and **dank16**.

**How It Works:**

1. Set wallpaper via DMS
2. DMS spawns matugen to extract colors
3. Color palette generated using Material Design 3
4. Theme files created for:
   - GTK applications
   - Qt applications
   - Terminals (alacritty, kitty, foot, etc.)
   - Text editors (VSCode, VSCodium, Neovim, etc.)
   - Shell (bash, zsh, fish)
   - DMS itself

**Configuration:**

```nix
# home.nix
programs.dankMaterialShell = {
  theming = {
    # Enable automatic wallpaper-based theming
    matugen = {
      enable = true;
      mode = "auto";  # or "dark", "light"
      scheme = "content";  # or "expressive", "neutral", "vibrant"
      contrast = 0.0;  # -1.0 to 1.0
    };

    # Enable dank16 color scheme
    dank16.enable = true;

    # Custom matugen templates
    customTemplates = [
      "/home/user/.config/matugen/templates/myapp.toml"
    ];
  };

  # Initial wallpaper
  wallpaper = "/home/user/Pictures/wallpaper.jpg";
};
```

**Disable Matugen (if needed):**

```bash
# Environment variable
export DMS_DISABLE_MATUGEN=1

# Then start DMS
dms run
```

**Custom Themes:**

```bash
# List available themes
dms ipc call theme list

# Pre-made themes:
# - Cyberpunk Electric
# - Hotline Miami
# - Miami Vice
# - Material Design 3 (default)

# Set custom theme
dms ipc call theme set "Cyberpunk Electric"
```

**Manual Theme Creation:**

```nix
# Create custom Material Design 3 theme
programs.dankMaterialShell.theming = {
  customTheme = {
    name = "My Custom Theme";
    colors = {
      primary = "#89b4fa";
      secondary = "#cba6f7";
      tertiary = "#f5c2e7";
      error = "#f38ba8";
      background = "#1e1e2e";
      surface = "#313244";
      onPrimary = "#11111b";
      onSecondary = "#11111b";
      onTertiary = "#11111b";
      onError = "#11111b";
      onBackground = "#cdd6f4";
      onSurface = "#cdd6f4";
    };
  };
};
```

### 7. DMS Components

**7.1 Spotlight (Launcher)**

Powerful search supporting:

- Applications
- Files
- Emojis
- Running windows
- Calculator functions
- Extensible plugins

**Configuration:**

```nix
programs.dankMaterialShell.spotlight = {
  enable = true;
  keybind = "Super+Space";

  # Search providers
  providers = {
    applications = true;
    files = true;
    emojis = true;
    windows = true;
    calculator = true;
    web = true;
  };

  # File search paths
  fileSearchPaths = [
    "~/Documents"
    "~/Downloads"
    "~/Pictures"
  ];

  # Appearance
  width = 600;
  maxResults = 8;
  fuzzyMatching = true;
};
```

**Usage:**

```bash
# Toggle spotlight
dms ipc call spotlight toggle

# Or use keybind (default: Super+Space)
```

**7.2 Control Center**

Unified interface for system settings:

- Network management
- Bluetooth
- Audio control
- Display settings
- Night mode
- Power management

**Configuration:**

```nix
programs.dankMaterialShell.controlCenter = {
  enable = true;
  keybind = "Super+Shift+C";

  # Modules
  modules = {
    network = true;
    bluetooth = true;
    audio = true;
    brightness = true;
    nightMode = true;
    power = true;
  };

  # Appearance
  width = 400;
  height = 800;
  position = "top-right";
};
```

**7.3 Notifications**

Rich notification system with:

- Grouping support
- Rich text rendering
- Keyboard navigation
- Image previews
- Action buttons

**Configuration:**

```nix
programs.dankMaterialShell.notifications = {
  enable = true;

  # Position
  position = "top-right";
  offset = {
    x = 10;
    y = 60;
  };

  # Behavior
  timeout = 5000;  # 5 seconds
  maxNotifications = 5;
  grouping = true;

  # Do Not Disturb
  dnd = {
    enable = true;
    schedule = {
      start = "22:00";
      end = "07:00";
    };
  };
};
```

**7.4 Session Management**

Handles:

- Screen locking
- Idle detection
- Auto-lock/suspend
- AC/battery profiles
- Greeter support

**Configuration:**

```nix
programs.dankMaterialShell.session = {
  enable = true;

  # Lock screen
  lock = {
    wallpaper = "current";  # or path to image
    showClock = true;
    showDate = true;
    blurBackground = true;
  };

  # Idle detection
  idle = {
    timeout = 300;  # 5 minutes
    actions = {
      lock = true;
      dpms = true;
    };
  };

  # Auto-suspend
  suspend = {
    enable = true;
    timeout = 1800;  # 30 minutes

    # Different timeouts for AC/battery
    acTimeout = 3600;      # 1 hour on AC
    batteryTimeout = 900;  # 15 minutes on battery
  };
};
```

**7.5 Panels**

Status panels with widgets:

- Workspaces/tags
- Window title
- System tray
- Clock/calendar
- System stats (CPU, RAM, etc.)
- Weather
- Media player
- Quick settings

**Configuration:**

```nix
programs.dankMaterialShell.panels = {
  enable = true;

  # Top panel
  top = {
    height = 40;
    modules = {
      left = [
        "workspaces"
        "window-title"
      ];
      center = [
        "clock"
      ];
      right = [
        "system-tray"
        "audio"
        "network"
        "battery"
        "power-menu"
      ];
    };
  };

  # Optional bottom panel
  bottom = {
    enable = false;
    height = 30;
  };

  # Appearance
  backgroundColor = "rgba(30, 30, 46, 0.9)";
  foregroundColor = "#cdd6f4";
  accentColor = "#89b4fa";
};
```

**7.6 Media Integration**

MPRIS player controls:

- Play/pause
- Next/previous track
- Album art
- Track progress

**Configuration:**

```nix
programs.dankMaterialShell.media = {
  enable = true;

  # Player controls in panel
  showInPanel = true;

  # Media popup
  popup = {
    enable = true;
    timeout = 3000;  # 3 seconds
    position = "top-center";
  };
};
```

**7.7 Calendar & Weather**

Calendar synchronization and weather widgets.

**Configuration:**

```nix
programs.dankMaterialShell = {
  calendar = {
    enable = true;
    provider = "google";  # or "outlook", "caldav"
    # Authentication configured separately
  };

  weather = {
    enable = true;
    location = "New York, NY";
    provider = "openweathermap";
    apiKey = "/run/secrets/openweather-api";
    units = "metric";  # or "imperial"
  };
};
```

**7.8 Clipboard Manager**

Clipboard history with:

- Text history
- Image previews
- Search
- Pin items

**Configuration:**

```nix
programs.dankMaterialShell.clipboard = {
  enable = true;
  keybind = "Super+V";

  # History
  maxItems = 100;
  persistHistory = true;
  historyPath = "~/.local/share/dms/clipboard";

  # Features
  imageSupport = true;
  searchEnabled = true;
};
```

### 8. Plugin System

**Browse Plugin Registry:**

```bash
# Search plugins
dms plugins search music

# List categories
dms plugins categories

# Show plugin details
dms plugins info spotify-control
```

**Install Plugins:**

```bash
# Install plugin
dms plugins install spotify-control

# Update plugins
dms plugins update

# Remove plugin
dms plugins remove spotify-control
```

**Declarative Plugin Management (NixOS):**

```nix
programs.dankMaterialShell.plugins = {
  enable = true;

  # List of plugins from registry
  installed = [
    "spotify-control"
    "github-notifications"
    "pomodoro-timer"
    "weather-extended"
  ];

  # Custom plugins
  custom = [
    {
      name = "my-custom-plugin";
      src = ./plugins/my-plugin;
    }
  ];
};
```

**Plugin Development:**

```qml
// ~/.local/share/dms/plugins/my-plugin/main.qml
import Quickshell
import DMS.Core

DmsPlugin {
    id: plugin

    pluginId: "my-plugin"
    name: "My Custom Plugin"
    version: "1.0.0"
    author: "Your Name"

    // Plugin implementation
    Component.onCompleted: {
        console.log("My plugin loaded!")
    }
}
```

### 9. NixOS-Specific Configuration

**Complete NixOS Example:**

```nix
# home.nix
{ config, pkgs, inputs, ... }:
{
  imports = [
    inputs.dms.homeModules.dankMaterialShell.default
  ];

  # DankMaterialShell configuration
  programs.dankMaterialShell = {
    enable = true;

    # Compositor integration
    compositor = "niri";  # or "hyprland", "mangowc", "sway"

    # Theming
    theming = {
      matugen = {
        enable = true;
        mode = "auto";
        scheme = "content";
      };
      dank16.enable = true;
    };

    wallpaper = "/home/user/Pictures/wallpaper.jpg";

    # Components
    spotlight = {
      enable = true;
      keybind = "Super+Space";
      providers = {
        applications = true;
        files = true;
        emojis = true;
        calculator = true;
      };
    };

    controlCenter = {
      enable = true;
      keybind = "Super+Shift+C";
      modules = {
        network = true;
        bluetooth = true;
        audio = true;
        brightness = true;
        nightMode = true;
      };
    };

    notifications = {
      enable = true;
      position = "top-right";
      timeout = 5000;
    };

    session = {
      enable = true;
      lock.blurBackground = true;
      idle.timeout = 300;
      suspend.enable = true;
    };

    panels = {
      enable = true;
      top = {
        height = 40;
        modules = {
          left = [ "workspaces" "window-title" ];
          center = [ "clock" ];
          right = [ "system-tray" "audio" "network" "battery" ];
        };
      };
    };

    media.enable = true;
    clipboard.enable = true;
    weather = {
      enable = true;
      location = "New York, NY";
    };

    # Plugins
    plugins = {
      enable = true;
      installed = [
        "spotify-control"
        "github-notifications"
      ];
    };
  };

  # Additional packages for DMS
  home.packages = with pkgs; [
    # Theming dependencies
    matugen
    imagemagick

    # Optional enhancements
    playerctl  # Media control
    brightnessctl  # Brightness control
    pamixer    # Audio control
  ];

  # Environment variables
  home.sessionVariables = {
    # Disable matugen if needed
    # DMS_DISABLE_MATUGEN = "1";
  };
}
```

**System-Level Configuration:**

```nix
# configuration.nix
{ config, pkgs, inputs, ... }:
{
  # Enable required services
  services = {
    dbus.enable = true;
    udisks2.enable = true;
    upower.enable = true;
  };

  # Security for polkit
  security.polkit.enable = true;

  # Audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Network
  networking.networkmanager.enable = true;

  # Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = false;  # DMS handles Bluetooth

  # Fonts (for DMS UI)
  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" ]; })
    noto-fonts
    noto-fonts-emoji
  ];
}
```

### 10. Common Patterns and Solutions

**Pattern 1: Multi-Compositor Setup**

```nix
# Switch between compositors easily
let
  currentCompositor = "niri";  # Change this variable
in
{
  programs.dankMaterialShell = {
    enable = true;
    compositor = currentCompositor;
  };

  # Compositor-specific configuration
  programs.niri.enable = currentCompositor == "niri";
  wayland.windowManager.hyprland.enable = currentCompositor == "hyprland";
}
```

**Pattern 2: Custom Keybindings per Compositor**

```nix
# Compositor-specific keybinds for DMS
wayland.windowManager.hyprland.settings.bind =
  lib.optionals config.programs.dankMaterialShell.enable [
    "SUPER, Space, exec, dms ipc call spotlight toggle"
    "SUPER_SHIFT, C, exec, dms ipc call controlcenter toggle"
    "SUPER, L, exec, dms ipc call session lock"
  ];
```

**Pattern 3: Theming Integration**

```nix
# Sync DMS theme with system theme
programs.dankMaterialShell.theming = {
  matugen.mode = if config.stylix.polarity == "dark" then "dark" else "light";
};

# Or use Stylix with DMS
stylix = {
  enable = true;
  image = config.programs.dankMaterialShell.wallpaper;
};
```

**Pattern 4: Systemd Integration**

```nix
# Ensure DMS starts with compositor
systemd.user.services.dankMaterialShell = {
  Unit = {
    Description = "DankMaterialShell Desktop Environment";
    After = [ "graphical-session.target" ];
    PartOf = [ "graphical-session.target" ];
  };

  Service = {
    ExecStart = "${pkgs.dankMaterialShell}/bin/dms run";
    Restart = "on-failure";
  };

  Install.WantedBy = [ "graphical-session.target" ];
};
```

**Pattern 5: Plugin Development Workflow**

```bash
# Create plugin directory
mkdir -p ~/.local/share/dms/plugins/my-plugin

# Create plugin manifest
cat > ~/.local/share/dms/plugins/my-plugin/plugin.json <<EOF
{
  "id": "my-plugin",
  "name": "My Plugin",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "Plugin description",
  "main": "main.qml"
}
EOF

# Create plugin QML
# Edit ~/.local/share/dms/plugins/my-plugin/main.qml

# Reload DMS
dms restart
```

## Troubleshooting Guide

### Issue 1: DMS Won't Start

**Problem**: DankMaterialShell fails to launch

**Solution**:

```bash
# Check logs
journalctl --user -u dankMaterialShell -f

# Run directly for debugging
dms run --debug

# Check dependencies
dms debug status

# Verify Quickshell installation
which quickshell
quickshell --version
```

### Issue 2: Compositor Not Detected

**Problem**: DMS doesn't integrate with compositor

**Solution**:

```nix
# Explicitly set compositor
programs.dankMaterialShell.compositor = "niri";

# Verify compositor is running
echo $WAYLAND_DISPLAY
pgrep -a niri

# Check compositor-specific integration
dms debug compositor
```

### Issue 3: Theming Not Working

**Problem**: Wallpaper colors not applied

**Solution**:

```bash
# Verify matugen is installed
which matugen
matugen --version

# Check if matugen is enabled
echo $DMS_DISABLE_MATUGEN  # Should be empty or unset

# Manually trigger theme generation
dms ipc call wallpaper set /path/to/image.jpg

# Check theme files
ls -la ~/.config/gtk-3.0/
ls -la ~/.config/qt5ct/
ls -la ~/.config/alacritty/
```

### Issue 4: Spotlight Not Responding

**Problem**: Launcher won't open

**Solution**:

```bash
# Test IPC
dms ipc call spotlight toggle

# Check if process is running
ps aux | grep dms

# Verify keybind
# Check compositor keybinding configuration

# Restart DMS
dms restart
```

### Issue 5: Notifications Not Showing

**Problem**: No notifications appear

**Solution**:

```bash
# Check notification daemon
systemctl --user status dms-notifications

# Test notification
notify-send "Test" "This is a test notification"

# Check DMS notification settings
dms config get notifications.enable

# Verify Do Not Disturb is off
dms ipc call notifications dnd off
```

### Issue 6: Control Center Empty

**Problem**: Control center modules not loading

**Solution**:

```nix
# Verify system services are enabled
services.networkmanager.enable = true;
hardware.bluetooth.enable = true;
services.pipewire.enable = true;

# Check module configuration
programs.dankMaterialShell.controlCenter.modules = {
  network = true;
  bluetooth = true;
  audio = true;
};

# Rebuild and test
home-manager switch
```

### Issue 7: High CPU/Memory Usage

**Problem**: DMS using excessive resources

**Solution**:

```bash
# Check resource usage
dms debug status

# Disable matugen if needed
export DMS_DISABLE_MATUGEN=1
dms restart

# Reduce panel update frequency
# Edit panel configuration

# Disable unused components
programs.dankMaterialShell = {
  media.enable = false;  # If not needed
  weather.enable = false;
};
```

## Best Practices

### DO ✅

1. **Use DMS as complete replacement**

   ```nix
   # Remove individual tools
   # programs.waybar.enable = false;
   # services.mako.enable = false;
   # programs.rofi.enable = false;

   # Enable DMS
   programs.dankMaterialShell.enable = true;
   ```

2. **Enable matugen for cohesive theming**

   ```nix
   theming.matugen.enable = true;
   ```

3. **Configure compositor integration**

   ```nix
   compositor = "niri";  # Match your compositor
   ```

4. **Use IPC for custom scripts**

   ```bash
   dms ipc call spotlight toggle
   ```

5. **Leverage plugin system**

   ```nix
   plugins.installed = [ "useful-plugin" ];
   ```

6. **Enable relevant components**

   ```nix
   # Only enable what you need
   media.enable = true;
   weather.enable = false;
   ```

7. **Use declarative configuration**

   ```nix
   # NixOS declarative config
   programs.dankMaterialShell = { };
   ```

8. **Set up systemd integration**

   ```nix
   # Ensure proper startup
   ```

9. **Configure keybindings in compositor**

   ```nix
   # Bind DMS IPC calls to keys
   ```

10. **Keep DMS updated**

    ```bash
    dms plugins update
    # Or rebuild NixOS configuration
    ```

### DON'T ❌

1. **Don't mix DMS with individual tools**

   ```nix
   # ❌ Bad - conflicts
   programs.dankMaterialShell.enable = true;
   programs.waybar.enable = true;  # DMS replaces this

   # ✅ Good - DMS only
   programs.dankMaterialShell.enable = true;
   ```

2. **Don't disable matugen without reason**

   ```nix
   # ❌ Loses automatic theming
   # ✅ Keep enabled for best experience
   theming.matugen.enable = true;
   ```

3. **Don't forget compositor integration**

   ```nix
   # ❌ No compositor set
   # ✅ Specify compositor
   compositor = "hyprland";
   ```

4. **Don't skip required system services**

   ```nix
   # ❌ Missing services
   # ✅ Enable required services
   services.networkmanager.enable = true;
   hardware.bluetooth.enable = true;
   ```

5. **Don't ignore IPC capabilities**

   ```bash
   # ❌ Manual tool launching
   fuzzel

   # ✅ Use DMS IPC
   dms ipc call spotlight toggle
   ```

6. **Don't hardcode paths**

   ```nix
   # ❌ Hardcoded
   wallpaper = "/home/user/Pictures/wall.jpg";

   # ✅ Use variable
   wallpaper = "${config.home.homeDirectory}/Pictures/wallpaper.jpg";
   ```

7. **Don't disable all components**

   ```nix
   # ❌ Why use DMS then?
   # ✅ Use at least core components
   ```

## Command Reference

### DMS CLI

```bash
# Shell management
dms run                           # Start DMS
dms stop                          # Stop DMS
dms restart                       # Restart DMS
dms version                       # Version info

# IPC
dms ipc call <component> <action> [args]

# Brightness
dms brightness list               # List displays
dms brightness get                # Current brightness
dms brightness set <value>        # Set brightness

# Plugins
dms plugins search <query>        # Search registry
dms plugins install <plugin>      # Install plugin
dms plugins remove <plugin>       # Remove plugin
dms plugins update                # Update plugins

# Config
dms config get <key>              # Get value
dms config set <key> <value>      # Set value

# Debug
dms debug logs                    # Show logs
dms debug status                  # System status
```

### IPC Components

```bash
# Spotlight
spotlight toggle|show|hide

# Control Center
controlcenter toggle|show|hide

# Notifications
notifications show|clear|dismiss

# Audio
audio setvolume|togglemute|getsources|getsinks

# Session
session lock|unlock|logout|suspend|reboot|shutdown

# Wallpaper
wallpaper set|next|previous|random

# Theme
theme set|list

# Night Mode
nightmode toggle|set
```

## Resources and Documentation

### Official Resources

- **[GitHub - DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)** - Official repository
- **[Dank Linux Website](https://danklinux.com)** - Project website
- **[Dank Linux Docs](https://danklinux.com/docs)** - Complete documentation
- **[NixOS Installation Guide](https://danklinux.com/docs/dankmaterialshell/nixos)** - NixOS-specific setup
- **[Application Theming Guide](https://danklinux.com/docs/dankmaterialshell/application-themes)** - Theming docs

### Community Resources

- **[syslog.space - DMS Article](https://syslog.space/dankmaterialshell/)** - Overview and features
- **[Plugin Registry](https://plugins.danklinux.com)** - Browse available plugins
- **[DankInstall Docs](https://danklinux.com/docs/dankinstall)** - Installer documentation

### Related Projects

- **[Quickshell](https://github.com/outfoxxed/quickshell)** - QML framework for DMS
- **[Matugen](https://github.com/InioX/matugen)** - Material Design color generation
- **Community Forks**: Various community-maintained versions

Ready to configure DankMaterialShell! Let me know what you need help with. 🎨
