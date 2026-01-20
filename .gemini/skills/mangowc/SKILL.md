---
name: mangowc
version: 1.0
description: MangoWC Skill
---

# MangoWC Skill

A specialized skill for configuring and customizing MangoWC Wayland compositor in NixOS using Home Manager, providing expert guidance on tag-based window management, animations, effects, and declarative configuration.

## Skill Overview

**Purpose**: Provide comprehensive support for MangoWC configuration, customization, and ecosystem integration in NixOS.

**Invoke When**:

- Setting up MangoWC Wayland compositor
- Configuring MangoWC via Home Manager or NixOS module
- Customizing keybindings and window behavior
- Setting up animations and visual effects (scenefx)
- Configuring tags, layouts, and scratchpads
- Integrating waybar, launchers, and other tools
- Troubleshooting MangoWC issues
- Migrating from DWM or other window managers
- Optimizing MangoWC performance

## Core Capabilities

### 1. What is MangoWC?

**MangoWC** is a fast, lightweight, modern Wayland compositor based on wlroots and scenefx. It's described as "dwm but Wayland" and provides:

- **Tag-based window management** (not workspaces)
- **Rich animations** for windows, tags, and layers
- **Scenefx effects**: blur, shadows, rounded corners, opacity
- **Excellent XWayland support**
- **Scratchpad functionality** (Sway-like)
- **IPC support** for external program communication
- **Hot-reload configuration**
- **Nine layout options**
- **Minimal resource footprint**

**Project**: [DreamMaoMao/mangowc](https://github.com/DreamMaoMao/mangowc) (1.5k+ stars)
**Website**: [mangowc.vercel.app](https://mangowc.vercel.app/)

### 2. Installation and Configuration

**NixOS Flake Setup (Recommended)**

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Add MangoWC flake
    mangowc = {
      url = "github:DreamMaoMao/mangowc";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, mangowc, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import MangoWC NixOS module
        mangowc.nixosModules.default

        # Your NixOS configuration
        {
          # Enable MangoWC system-wide
          programs.mango.enable = true;

          # Essential packages
          environment.systemPackages = with pkgs; [
            foot          # Terminal
            wmenu         # Launcher
            wl-clipboard  # Clipboard
            grim          # Screenshots
            slurp         # Region select
            swaybg        # Wallpaper
            firefox       # Browser
          ];
        }

        # Home Manager with MangoWC
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.users.username = {
            imports = [ mangowc.homeManagerModules.default ];

            # MangoWC configuration
            wayland.windowManager.mango = {
              enable = true;

              # Configuration file content
              settings = ''
                # Your config.conf content here
              '';

              # Autostart script content
              autostart_sh = ''
                # Your autostart.sh content here
              '';
            };
          };
        }
      ];
    };
  };
}
```

**NixOS Module Only (System-wide)**

```nix
# configuration.nix
{ config, pkgs, ... }:
{
  # Import MangoWC module from flake
  programs.mango.enable = true;

  # Essential packages
  environment.systemPackages = with pkgs; [
    # Core tools
    foot
    wmenu
    wl-clipboard
    grim
    slurp
    swaybg

    # Optional but recommended
    waybar
    dunst
    rofi-wayland
    swaylock
    swayidle
    playerctl
    brightnessctl
    pamixer
  ];
}
```

**Home Manager Module (Per-User)**

```nix
# home.nix
{ config, pkgs, ... }:
{
  wayland.windowManager.mango = {
    enable = true;

    # Configuration file (~/.config/mango/config.conf)
    settings = ''
      # See section 3 for complete configuration
    '';

    # Autostart script (~/.config/mango/autostart.sh)
    autostart_sh = ''
      # Launch waybar
      waybar -c ~/.config/mango/config.jsonc -s ~/.config/mango/style.css >/dev/null 2>&1 &

      # Set wallpaper
      swaybg -i ~/Pictures/Wallpapers/default.png >/dev/null 2>&1 &

      # Notification daemon
      dunst >/dev/null 2>&1 &

      # Network manager applet
      nm-applet --indicator >/dev/null 2>&1 &

      # Bluetooth manager
      blueman-applet >/dev/null 2>&1 &
    '';
  };
}
```

### 3. Complete Configuration (config.conf)

**Full config.conf Example**:

```bash
# MangoWC Configuration
# Format: bind=MODIFIER,KEY,ACTION,PARAMETERS

# ============ Modifiers ============
# SUPER  - Windows/Super key
# ALT    - Alt key
# CTRL   - Control key
# SHIFT  - Shift key

# ============ Applications ============
# Terminal
bind=SUPER,Return,spawn,foot

# Application launcher
bind=SUPER,d,spawn,wmenu-run -l 10
bind=SUPER,Space,spawn,rofi -show drun

# Browser
bind=SUPER,b,spawn,firefox

# File manager
bind=SUPER,e,spawn,thunar

# Screenshot
bind=,Print,spawn,grim -g "$(slurp)" - | wl-copy
bind=SUPER,Print,spawn,grim -g "$(slurp)" ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png
bind=SUPER_SHIFT,Print,spawn,grim - | wl-copy

# Clipboard history
bind=SUPER,v,spawn,cliphist list | rofi -dmenu | cliphist decode | wl-copy

# Lock screen
bind=SUPER,l,spawn,swaylock -f -c 000000

# ============ Window Management ============
# Close window
bind=SUPER,q,killclient

# Toggle fullscreen
bind=SUPER,f,togglefullscreen

# Toggle floating
bind=SUPER_SHIFT,f,togglefloating

# Toggle fakefullscreen
bind=SUPER_CTRL,f,togglefakefullscreen

# Cycle window focus
bind=SUPER,Tab,focusstack,1
bind=SUPER_SHIFT,Tab,focusstack,-1

# Focus window by direction
bind=SUPER,h,focusdir,left
bind=SUPER,j,focusdir,down
bind=SUPER,k,focusdir,up
bind=SUPER,l,focusdir,right
bind=SUPER,Left,focusdir,left
bind=SUPER,Down,focusdir,down
bind=SUPER,Up,focusdir,up
bind=SUPER,Right,focusdir,right

# Move window by direction
bind=SUPER_SHIFT,h,movewindow,left
bind=SUPER_SHIFT,j,movewindow,down
bind=SUPER_SHIFT,k,movewindow,up
bind=SUPER_SHIFT,l,movewindow,right
bind=SUPER_SHIFT,Left,movewindow,left
bind=SUPER_SHIFT,Down,movewindow,down
bind=SUPER_SHIFT,Up,movewindow,up
bind=SUPER_SHIFT,Right,movewindow,right

# Resize window
bind=SUPER_CTRL,h,resizeactive,-50,0
bind=SUPER_CTRL,j,resizeactive,0,50
bind=SUPER_CTRL,k,resizeactive,0,-50
bind=SUPER_CTRL,l,resizeactive,50,0
bind=SUPER_CTRL,Left,resizeactive,-50,0
bind=SUPER_CTRL,Down,resizeactive,0,50
bind=SUPER_CTRL,Up,resizeactive,0,-50
bind=SUPER_CTRL,Right,resizeactive,50,0

# Master/stack ratio
bind=SUPER,equal,setmfact,0.05
bind=SUPER,minus,setmfact,-0.05

# Promote window to master
bind=SUPER,Return,zoom

# ============ Tags (Workspaces) ============
# Switch to tag
bind=SUPER,1,view,1
bind=SUPER,2,view,2
bind=SUPER,3,view,3
bind=SUPER,4,view,4
bind=SUPER,5,view,5
bind=SUPER,6,view,6
bind=SUPER,7,view,7
bind=SUPER,8,view,8
bind=SUPER,9,view,9

# Move window to tag
bind=SUPER_SHIFT,1,tag,1
bind=SUPER_SHIFT,2,tag,2
bind=SUPER_SHIFT,3,tag,3
bind=SUPER_SHIFT,4,tag,4
bind=SUPER_SHIFT,5,tag,5
bind=SUPER_SHIFT,6,tag,6
bind=SUPER_SHIFT,7,tag,7
bind=SUPER_SHIFT,8,tag,8
bind=SUPER_SHIFT,9,tag,9

# Toggle tag view
bind=SUPER_CTRL,1,toggleview,1
bind=SUPER_CTRL,2,toggleview,2
bind=SUPER_CTRL,3,toggleview,3
bind=SUPER_CTRL,4,toggleview,4
bind=SUPER_CTRL,5,toggleview,5
bind=SUPER_CTRL,6,toggleview,6
bind=SUPER_CTRL,7,toggleview,7
bind=SUPER_CTRL,8,toggleview,8
bind=SUPER_CTRL,9,toggleview,9

# Toggle window on tag
bind=SUPER_ALT,1,toggletag,1
bind=SUPER_ALT,2,toggletag,2
bind=SUPER_ALT,3,toggletag,3
bind=SUPER_ALT,4,toggletag,4
bind=SUPER_ALT,5,toggletag,5
bind=SUPER_ALT,6,toggletag,6
bind=SUPER_ALT,7,toggletag,7
bind=SUPER_ALT,8,toggletag,8
bind=SUPER_ALT,9,toggletag,9

# View all tags
bind=SUPER,0,view,~0
bind=SUPER_SHIFT,0,tag,~0

# ============ Layouts ============
# Cycle through layouts
bind=SUPER,t,setlayout,tile
bind=SUPER,m,setlayout,monocle
bind=SUPER,g,setlayout,grid
bind=SUPER,s,setlayout,scroller
bind=SUPER,c,setlayout,center_tile
bind=SUPER,n,cyclelayout,1
bind=SUPER_SHIFT,n,cyclelayout,-1

# Available layouts:
# - tile: Master-stack tiling
# - scroller: Scrolling layout
# - monocle: One window fullscreen
# - grid: Grid layout
# - deck: Deck layout
# - center_tile: Centered master
# - vertical_tile: Vertical tiling
# - vertical_grid: Vertical grid
# - vertical_scroller: Vertical scrolling

# ============ Scratchpad ============
# Toggle scratchpad
bind=SUPER,grave,togglescratch,0

# Named scratchpads
bind=SUPER,F1,togglescratch,terminal
bind=SUPER,F2,togglescratch,music
bind=SUPER,F3,togglescratch,notes

# ============ Overview ============
# Show overview (all windows)
bind=SUPER,o,toggleoverview

# ============ Monitors ============
# Focus monitor
bind=SUPER,comma,focusmon,left
bind=SUPER,period,focusmon,right

# Move window to monitor
bind=SUPER_SHIFT,comma,tagmon,left
bind=SUPER_SHIFT,period,tagmon,right

# ============ Window States ============
# Minimize
bind=SUPER,x,minimize

# Maximize
bind=SUPER,z,maximize

# Overlay mode
bind=SUPER,a,overlay

# Global (show on all tags)
bind=SUPER_SHIFT,g,global

# Swallow windows
bind=SUPER_SHIFT,s,swallow

# ============ Media Keys ============
# Volume
bind=,XF86AudioRaiseVolume,spawn,pamixer -i 5
bind=,XF86AudioLowerVolume,spawn,pamixer -d 5
bind=,XF86AudioMute,spawn,pamixer -t

# Media playback
bind=,XF86AudioPlay,spawn,playerctl play-pause
bind=,XF86AudioPause,spawn,playerctl pause
bind=,XF86AudioNext,spawn,playerctl next
bind=,XF86AudioPrev,spawn,playerctl previous

# Brightness
bind=,XF86MonBrightnessUp,spawn,brightnessctl set 10%+
bind=,XF86MonBrightnessDown,spawn,brightnessctl set 10%-

# ============ System ============
# Reload configuration
bind=SUPER_SHIFT,r,reloadconfig

# Quit MangoWC
bind=SUPER_SHIFT,q,quit

# ============ Mouse Bindings ============
# SUPER + left click: move window
# SUPER + right click: resize window
# These are built-in and don't need configuration

# ============ Window Rules ============
# Format: rule=CLASS,TITLE,COMMAND
# Commands: float, tile, fullscreen, tag:N, monitor:N

# Float specific windows
rule=pavucontrol,,float
rule=nm-connection-editor,,float
rule=blueman-manager,,float

# Picture-in-Picture
rule=.*,Picture-in-Picture,float,pin

# Assign to tags
rule=firefox,,tag:2
rule=code,,tag:3
rule=discord,,tag:4
rule=spotify,,tag:5

# ============ Animations ============
# Enable animations
animations=true

# Animation duration (ms)
animation_duration=300

# Animation curve (bezier)
# Format: x1,y1,x2,y2
animation_curve=0.25,0.1,0.25,1.0

# ============ Visual Effects (scenefx) ============
# Corner radius
corner_radius=10

# Blur
blur=true
blur_radius=8
blur_passes=2

# Shadows
shadow=true
shadow_radius=15
shadow_offset_x=0
shadow_offset_y=0
shadow_color=#000000
shadow_opacity=0.6

# Opacity
inactive_opacity=0.95
active_opacity=1.0

# ============ Gaps ============
# Outer gaps
gaps_outer=10

# Inner gaps
gaps_inner=5

# ============ Borders ============
# Border width
border_width=2

# Border colors
border_active=#89b4fa
border_inactive=#313244
border_urgent=#f38ba8

# ============ General Settings ============
# Focus follows mouse
focus_follows_mouse=true

# Click to focus
click_to_focus=true

# Smart gaps (disable when only one window)
smart_gaps=true

# Smart borders (disable when only one window)
smart_borders=true

# Repeat rate (keyboard)
repeat_rate=25
repeat_delay=300

# Cursor theme
cursor_theme=Adwaita
cursor_size=24

# ============ Monitor Configuration ============
# Format: monitor=NAME,RESOLUTION@REFRESH,POSITION,SCALE
monitor=DP-1,3840x2160@144,0x0,1
monitor=HDMI-A-1,1920x1080@60,3840x0,1
monitor=,preferred,auto,1  # Fallback

# ============ XWayland ============
# Enable XWayland
xwayland=true

# ============ IPC ============
# Enable IPC socket
ipc=true
ipc_socket=/tmp/mango-ipc.sock
```

### 4. Autostart Configuration

**Complete autostart.sh Example**:

```bash
#!/bin/sh
# MangoWC Autostart Script
# ~/.config/mango/autostart.sh

# NOTE: No shebang needed when using home-manager module
# The module handles execution automatically

# ============ Status Bar ============
waybar -c ~/.config/mango/config.jsonc -s ~/.config/mango/style.css >/dev/null 2>&1 &

# ============ Wallpaper ============
# Static wallpaper
swaybg -i ~/Pictures/Wallpapers/default.png >/dev/null 2>&1 &

# Or animated wallpaper with swww
# swww-daemon >/dev/null 2>&1 &
# sleep 0.5
# swww img ~/Pictures/Wallpapers/animated.gif >/dev/null 2>&1 &

# ============ Notifications ============
dunst >/dev/null 2>&1 &

# Or mako
# mako >/dev/null 2>&1 &

# ============ System Tray ============
nm-applet --indicator >/dev/null 2>&1 &
blueman-applet >/dev/null 2>&1 &

# ============ Authentication ============
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 >/dev/null 2>&1 &

# Or on NixOS:
# ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1 >/dev/null 2>&1 &

# ============ Clipboard Manager ============
wl-paste --watch cliphist store >/dev/null 2>&1 &

# ============ Idle Management ============
swayidle -w \
  timeout 300 'swaylock -f -c 000000' \
  timeout 600 'swaymsg "output * dpms off"' \
    resume 'swaymsg "output * dpms on"' \
  before-sleep 'swaylock -f -c 000000' >/dev/null 2>&1 &

# ============ Night Light ============
gammastep -l 40.7:-74.0 >/dev/null 2>&1 &

# Or wlsunset
# wlsunset -l 40.7 -L -74.0 >/dev/null 2>&1 &

# ============ Auto-mount ============
udiskie -t >/dev/null 2>&1 &

# ============ Cloud Sync ============
# syncthing >/dev/null 2>&1 &

# ============ Scratchpad Applications ============
# Start applications in scratchpad
foot --app-id=scratchpad_terminal >/dev/null 2>&1 &
```

**NixOS/Home Manager Version**:

```nix
wayland.windowManager.mango.autostart_sh = ''
  # Status bar
  ${pkgs.waybar}/bin/waybar -c ~/.config/mango/config.jsonc -s ~/.config/mango/style.css >/dev/null 2>&1 &

  # Wallpaper
  ${pkgs.swaybg}/bin/swaybg -i ~/Pictures/Wallpapers/default.png >/dev/null 2>&1 &

  # Notifications
  ${pkgs.dunst}/bin/dunst >/dev/null 2>&1 &

  # System tray
  ${pkgs.networkmanagerapplet}/bin/nm-applet --indicator >/dev/null 2>&1 &
  ${pkgs.blueman}/bin/blueman-applet >/dev/null 2>&1 &

  # Polkit
  ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1 >/dev/null 2>&1 &

  # Clipboard
  ${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store >/dev/null 2>&1 &

  # Idle management
  ${pkgs.swayidle}/bin/swayidle -w \
    timeout 300 '${pkgs.swaylock}/bin/swaylock -f -c 000000' \
    timeout 600 'wlr-randr --output "*" --off' \
      resume 'wlr-randr --output "*" --on' \
    before-sleep '${pkgs.swaylock}/bin/swaylock -f -c 000000' >/dev/null 2>&1 &
'';
```

### 5. Essential Packages

**Complete Package Set**:

```nix
{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    # ============ Core Dependencies ============
    # (These are usually handled by the MangoWC package)
    wayland
    wayland-protocols
    wlroots
    libinput
    libxkbcommon
    pixman
    xwayland

    # ============ Terminal Emulators ============
    foot          # Lightweight, fast (recommended)
    alacritty     # GPU-accelerated
    kitty         # Feature-rich
    wezterm       # GPU-accelerated with tmux-like features

    # ============ Launchers ============
    wmenu         # Dmenu for Wayland (lightweight)
    rofi-wayland  # Feature-rich launcher
    bemenu        # Alternative dmenu
    fuzzel        # Fuzzy launcher
    tofi          # Minimal launcher

    # ============ Status Bars ============
    waybar        # Highly customizable (recommended)
    yambar        # Minimal status bar
    i3status-rust # Rust-based status bar

    # ============ Wallpaper ============
    swaybg        # Static wallpapers
    swww          # Animated wallpapers
    hyprpaper     # Alternative wallpaper daemon
    mpvpaper      # Video wallpapers

    # ============ Notifications ============
    dunst         # Lightweight (recommended)
    mako          # Minimal notification daemon
    swaync        # Notification center

    # ============ Screen Locking ============
    swaylock      # Screen lock
    swaylock-effects  # Swaylock with effects
    hyprlock      # Alternative lock screen

    # ============ Idle Management ============
    swayidle      # Idle daemon
    hypridle      # Alternative idle daemon

    # ============ Screenshots ============
    grim          # Screenshot tool
    slurp         # Region selector
    grimblast     # Grim wrapper
    swappy        # Screenshot editor
    satty         # Screenshot annotation

    # ============ Clipboard ============
    wl-clipboard  # CLI clipboard tools
    cliphist      # Clipboard history
    copyq         # Clipboard manager (GUI)

    # ============ Screen Recording ============
    wf-recorder   # Screen recorder
    obs-studio    # Full-featured recording

    # ============ File Managers ============
    thunar        # GTK file manager
    pcmanfm       # Lightweight
    dolphin       # KDE file manager
    nautilus      # GNOME file manager
    nnn           # Terminal file manager
    ranger        # Terminal file manager
    yazi          # Modern terminal file manager

    # ============ Color Temperature ============
    wlsunset      # Redshift for Wayland
    gammastep     # Alternative to wlsunset

    # ============ System Utilities ============
    brightnessctl # Screen brightness
    playerctl     # Media control
    pamixer       # Audio control (CLI)
    pavucontrol   # Audio control (GUI)
    pulsemixer    # Audio mixer (TUI)

    # ============ Network Management ============
    networkmanagerapplet  # Network manager applet

    # ============ Bluetooth ============
    blueman       # Bluetooth manager
    bluez-tools   # Bluetooth CLI tools

    # ============ Authentication ============
    polkit_gnome  # Polkit authentication agent

    # ============ Display Management ============
    wlr-randr     # Display configuration
    kanshi        # Display hotplug daemon
    nwg-displays  # Display configuration GUI

    # ============ Session Management ============
    wlogout       # Logout menu
    nwg-bar       # Session bar

    # ============ Wayland Utilities ============
    wtype         # xdotool for Wayland
    wev           # Wayland event viewer
    wayvnc        # VNC server
    ydotool       # Generic automation tool

    # ============ System Monitoring ============
    btop          # Resource monitor
    htop          # Process viewer
    glances       # System monitor

    # ============ Auto-mount ============
    udiskie       # Auto-mount USB drives

    # ============ Fonts ============
    (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" "Hack" ]; })

    # ============ Browsers ============
    firefox       # Web browser
    chromium      # Alternative browser

    # ============ Development ============
    # Add your development tools
  ];
}
```

### 6. Waybar Configuration for MangoWC

**Waybar config.jsonc**:

```jsonc
{
  "layer": "top",
  "position": "top",
  "height": 34,
  "spacing": 4,

  "modules-left": ["custom/mango-tags", "custom/mango-layout"],

  "modules-center": ["clock"],

  "modules-right": [
    "pulseaudio",
    "network",
    "cpu",
    "memory",
    "temperature",
    "backlight",
    "battery",
    "tray",
  ],

  // MangoWC-specific modules using IPC
  "custom/mango-tags": {
    "exec": "mango-ipc tags",
    "interval": 1,
    "format": "{}",
    "on-click": "mango-ipc tag-click",
  },

  "custom/mango-layout": {
    "exec": "mango-ipc layout",
    "interval": 1,
    "format": " {}",
    "on-click": "mango-ipc cycle-layout",
  },

  "clock": {
    "timezone": "America/New_York",
    "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
    "format": "{:%H:%M}",
    "format-alt": "{:%Y-%m-%d}",
  },

  "cpu": {
    "format": " {usage}%",
    "tooltip": true,
  },

  "memory": {
    "format": " {}%",
  },

  "temperature": {
    "critical-threshold": 80,
    "format": "{icon} {temperatureC}°C",
    "format-icons": ["", "", ""],
  },

  "backlight": {
    "format": "{icon} {percent}%",
    "format-icons": ["", "", "", "", "", "", "", "", ""],
  },

  "battery": {
    "states": {
      "warning": 30,
      "critical": 15,
    },
    "format": "{icon} {capacity}%",
    "format-charging": " {capacity}%",
    "format-plugged": " {capacity}%",
    "format-alt": "{icon} {time}",
    "format-icons": ["", "", "", "", ""],
  },

  "network": {
    "format-wifi": " {essid}",
    "format-ethernet": " {ipaddr}",
    "format-linked": " {ifname} (No IP)",
    "format-disconnected": "⚠ Disconnected",
    "tooltip-format": "{ifname} via {gwaddr} ",
  },

  "pulseaudio": {
    "format": "{icon} {volume}%",
    "format-bluetooth": "{icon} {volume}%",
    "format-muted": "",
    "format-icons": {
      "headphone": "",
      "hands-free": "",
      "headset": "",
      "phone": "",
      "portable": "",
      "car": "",
      "default": ["", "", ""],
    },
    "on-click": "pavucontrol",
  },

  "tray": {
    "spacing": 10,
  },
}
```

**Waybar style.css** (Catppuccin Theme):

```css
* {
  border: none;
  border-radius: 0;
  font-family: "JetBrainsMono Nerd Font";
  font-size: 13px;
  min-height: 0;
}

window#waybar {
  background: rgba(30, 30, 46, 0.9);
  color: #cdd6f4;
}

#custom-mango-tags,
#custom-mango-layout,
#clock,
#battery,
#cpu,
#memory,
#temperature,
#backlight,
#network,
#pulseaudio,
#tray {
  padding: 0 10px;
  margin: 0 5px;
}

#custom-mango-tags {
  padding: 0 5px;
}

#battery.charging {
  color: #a6e3a1;
}

#battery.warning:not(.charging) {
  color: #f9e2af;
}

#battery.critical:not(.charging) {
  color: #f38ba8;
}

#pulseaudio.muted {
  color: #6c7086;
}
```

**Home Manager Integration**:

```nix
programs.waybar = {
  enable = true;
  systemd.enable = true;

  settings = {
    mainBar = {
      # Copy the JSON config above
    };
  };

  style = ''
    /* Copy the CSS above */
  '';
};

# Link waybar config for MangoWC autostart
xdg.configFile."mango/config.jsonc".source = config.xdg.configHome + "/waybar/config";
xdg.configFile."mango/style.css".source = config.xdg.configHome + "/waybar/style.css";
```

### 7. IPC Support

**MangoWC IPC Commands**:

```bash
# Query current state
mango-ipc tags              # Get active tags
mango-ipc layout            # Get current layout
mango-ipc clients           # List all clients
mango-ipc focused           # Get focused client

# Control compositor
mango-ipc tag 3             # Switch to tag 3
mango-ipc layout tile       # Set layout
mango-ipc reload            # Reload configuration
mango-ipc quit              # Quit compositor

# Window operations
mango-ipc close             # Close focused window
mango-ipc fullscreen        # Toggle fullscreen
mango-ipc floating          # Toggle floating
```

**IPC Scripts Example**:

```bash
#!/bin/sh
# ~/.local/bin/mango-tag-status

# Get current tag state and format for waybar
current_tag=$(mango-ipc tags | jq -r '.current')
tags=$(mango-ipc tags | jq -r '.all[]')

output=""
for tag in $tags; do
  if [ "$tag" = "$current_tag" ]; then
    output="$output <span color='#89b4fa'>[$tag]</span>"
  else
    output="$output $tag"
  fi
done

echo "$output"
```

### 8. Layout System

**Available Layouts**:

1. **tile**: Master-stack tiling (DWM-like)
2. **scroller**: Scrolling layout for many windows
3. **monocle**: One window fullscreen (tabbed-like)
4. **grid**: Grid layout for equal-sized windows
5. **deck**: Deck layout (one visible, others stacked)
6. **center_tile**: Centered master window
7. **vertical_tile**: Vertical tiling variant
8. **vertical_grid**: Vertical grid variant
9. **vertical_scroller**: Vertical scrolling variant

**Layout Configuration**:

```bash
# In config.conf
bind=SUPER,t,setlayout,tile
bind=SUPER,m,setlayout,monocle
bind=SUPER,g,setlayout,grid
bind=SUPER,s,setlayout,scroller
bind=SUPER,d,setlayout,deck
bind=SUPER,c,setlayout,center_tile

# Cycle layouts
bind=SUPER,n,cyclelayout,1
bind=SUPER_SHIFT,n,cyclelayout,-1

# Per-tag layout persistence
# Layouts are automatically saved per tag
```

### 9. Window States and Features

**Window States**:

- **Normal**: Standard window
- **Floating**: Window floats above tiling
- **Fullscreen**: Window fills entire screen
- **Fakefullscreen**: Fullscreen within tile
- **Minimized**: Hidden but accessible
- **Maximized**: Fills tile area
- **Overlay**: Window shown on all tags
- **Global**: Window visible on all tags
- **Swallow**: Terminal swallows GUI applications

**Scratchpad**:

```bash
# Default scratchpad
bind=SUPER,grave,togglescratch,0

# Named scratchpads
bind=SUPER,F1,togglescratch,terminal
bind=SUPER,F2,togglescratch,music
bind=SUPER,F3,togglescratch,notes

# Launch applications in scratchpad
foot --app-id=scratchpad_terminal &
spotify --class=scratchpad_music &
```

**Overview Mode**:

```bash
# Show all windows (Exposé-like)
bind=SUPER,o,toggleoverview

# Navigate in overview
# Use vim keys or arrow keys to select
# Enter to focus selected window
# Escape to cancel
```

### 10. Visual Effects (scenefx)

**Effect Configuration in config.conf**:

```bash
# Corner radius (0 to disable)
corner_radius=10

# Blur settings
blur=true
blur_radius=8      # Blur strength
blur_passes=2      # Quality (higher = better)

# Shadow settings
shadow=true
shadow_radius=15
shadow_offset_x=0
shadow_offset_y=0
shadow_color=#000000
shadow_opacity=0.6

# Opacity
inactive_opacity=0.95
active_opacity=1.0

# Per-window opacity rules
# Format: opacity=CLASS,TITLE,OPACITY
opacity=Alacritty,,0.9
opacity=foot,,0.9
opacity=Code,,0.95
```

**Animation Settings**:

```bash
# Enable animations
animations=true

# Animation duration (milliseconds)
animation_duration=300

# Animation curve (cubic-bezier)
# Format: x1,y1,x2,y2
# Examples:
# 0.25,0.1,0.25,1.0  - Ease (default)
# 0.42,0.0,0.58,1.0  - Ease-in-out
# 0.0,0.0,1.0,1.0    - Linear
animation_curve=0.25,0.1,0.25,1.0

# Disable specific animations
animate_windows=true
animate_tags=true
animate_layers=true
```

### 11. Multi-Monitor Setup

**Monitor Configuration**:

```bash
# Format: monitor=NAME,RESOLUTION@REFRESH,POSITION,SCALE
monitor=DP-1,3840x2160@144,0x0,1
monitor=HDMI-A-1,1920x1080@60,3840x0,1
monitor=eDP-1,1920x1080@60,0x0,1

# Fallback for unknown monitors
monitor=,preferred,auto,1

# Disable monitor
monitor=HDMI-A-2,disable
```

**Per-Monitor Tag Assignment**:

```bash
# Assign specific tags to monitors
# Format: workspace=TAG,monitor:NAME
workspace=1,monitor:DP-1
workspace=2,monitor:DP-1
workspace=3,monitor:DP-1
workspace=4,monitor:HDMI-A-1
workspace=5,monitor:HDMI-A-1
```

**Monitor Hotplug with Kanshi**:

```nix
services.kanshi = {
  enable = true;

  settings = [
    {
      profile.name = "laptop-only";
      profile.outputs = [
        {
          criteria = "eDP-1";
          status = "enable";
        }
      ];
    }
    {
      profile.name = "docked";
      profile.outputs = [
        {
          criteria = "eDP-1";
          status = "disable";
        }
        {
          criteria = "DP-1";
          mode = "3840x2160@144";
          position = "0,0";
        }
      ];
    }
  ];
};
```

## Common Patterns and Solutions

### Pattern 1: Per-Application Configuration

```bash
# Window rules format: rule=CLASS,TITLE,COMMAND

# Float windows by class
rule=pavucontrol,,float
rule=nm-connection-editor,,float
rule=blueman-manager,,float
rule=.*,Picture-in-Picture,float,pin

# Assign to specific tags
rule=firefox,,tag:2
rule=code,,tag:3
rule=discord,,tag:4
rule=spotify,,tag:5

# Opacity per application
opacity=Alacritty,,0.9
opacity=foot,,0.9
opacity=firefox,Picture-in-Picture,1.0

# Disable effects for games
rule=steam_app_.*,,fullscreen,no_blur,no_shadow
```

### Pattern 2: Dynamic Configuration Reload

```bash
# Watch and reload configuration on change
inotifywait -m -e modify ~/.config/mango/config.conf | while read; do
  mango-ipc reload
done
```

**Systemd Service**:

```nix
systemd.user.services.mango-config-reload = {
  Unit = {
    Description = "Auto-reload MangoWC configuration";
  };

  Service = {
    ExecStart = toString (pkgs.writeShellScript "mango-reload" ''
      ${pkgs.inotify-tools}/bin/inotifywait -m -e modify ~/.config/mango/config.conf | while read; do
        mango-ipc reload
      done
    '');
    Restart = "always";
  };

  Install.WantedBy = [ "mango-session.target" ];
};
```

### Pattern 3: Tag Persistence

```bash
# Tags persist their layout and windows across restarts
# This is handled automatically by MangoWC

# Restore session on startup (optional)
# Add to autostart.sh:
mango-session-restore &
```

### Pattern 4: Scratchpad Terminal

```nix
# Launch scratchpad terminal in autostart
wayland.windowManager.mango.autostart_sh = ''
  ${pkgs.foot}/bin/foot \
    --app-id=scratchpad_terminal \
    --title="Scratchpad Terminal" \
    >/dev/null 2>&1 &
'';

# Bind in config.conf
# bind=SUPER,grave,togglescratch,scratchpad_terminal
```

## Troubleshooting Guide

### Issue 1: MangoWC Won't Start

**Problem**: Compositor fails to launch

**Solution**:

```bash
# Check logs
journalctl --user -u mango.service
cat ~/.local/share/mango/mango.log

# Check Wayland socket
echo $WAYLAND_DISPLAY

# Verify dependencies
ldd $(which mango)

# Run directly for debugging
mango --debug
```

### Issue 2: Configuration Not Loading

**Problem**: Changes to config.conf not applied

**Solution**:

```bash
# Verify config path
ls -la ~/.config/mango/config.conf

# Check for syntax errors
# MangoWC logs syntax errors on startup

# Reload configuration
mango-ipc reload

# Restart compositor
mango-ipc quit
# Then restart from display manager
```

### Issue 3: Keybindings Not Working

**Problem**: Keybinds don't respond

**Solution**:

```bash
# Check keyboard layout
mango-ipc devices

# Test key events
wev  # Press keys and verify they're detected

# Verify keybind syntax in config.conf
# Format: bind=MODIFIER,KEY,ACTION,PARAMETERS

# Check for conflicting binds
grep "bind=SUPER,Return" ~/.config/mango/config.conf
```

### Issue 4: Visual Effects Not Showing

**Problem**: Blur, shadows, or rounded corners not visible

**Solution**:

```bash
# Verify scenefx support
mango --version | grep scenefx

# Check effect settings in config.conf
blur=true
corner_radius=10
shadow=true

# Disable for testing
blur=false
animations=false

# Check GPU drivers
glxinfo | grep OpenGL
```

### Issue 5: High CPU/GPU Usage

**Problem**: MangoWC using excessive resources

**Solution**:

```bash
# Disable animations
animations=false

# Reduce blur
blur_passes=1
blur_radius=4

# Disable shadows
shadow=false

# Reduce animation duration
animation_duration=150

# Check for runaway processes
ps aux | grep mango
```

### Issue 6: Monitor Not Detected

**Problem**: External monitor not recognized

**Solution**:

```bash
# List connected monitors
wlr-randr

# Manually configure in config.conf
monitor=HDMI-A-1,1920x1080@60,0x0,1

# Check cable connection
# Try different port/cable

# Use kanshi for hotplug
services.kanshi.enable = true;
```

### Issue 7: IPC Socket Not Working

**Problem**: Cannot communicate with compositor

**Solution**:

```bash
# Verify IPC enabled in config.conf
ipc=true
ipc_socket=/tmp/mango-ipc.sock

# Check socket exists
ls -la /tmp/mango-ipc.sock

# Test IPC
echo "tags" | socat - UNIX-CONNECT:/tmp/mango-ipc.sock

# Check permissions
chmod 700 /tmp/mango-ipc.sock
```

## Best Practices

### DO ✅

1. **Use the flake-based installation**

   ```nix
   inputs.mangowc.url = "github:DreamMaoMao/mangowc";
   ```

2. **Enable hot-reload for configuration**

   ```bash
   # Watch and reload on config change
   inotifywait -m ~/.config/mango/config.conf
   ```

3. **Use declarative settings in home-manager**

   ```nix
   wayland.windowManager.mango.settings = ''
     # Your config here
   '';
   ```

4. **Organize keybindings by category**

   ```bash
   # Applications
   # Window Management
   # Tags
   # Layouts
   ```

5. **Use IPC for dynamic control**

   ```bash
   mango-ipc tag 3
   mango-ipc layout tile
   ```

6. **Enable systemd integration**

   ```nix
   wayland.windowManager.mango.enable = true;
   ```

7. **Test configuration before reload**

   ```bash
   # Syntax check
   mango --test-config ~/.config/mango/config.conf
   ```

8. **Use scratchpads for quick access**

   ```bash
   bind=SUPER,grave,togglescratch,terminal
   ```

9. **Set up per-tag layouts**

   ```bash
   # Layouts persist automatically per tag
   ```

10. **Use window rules for consistency**

    ```bash
    rule=firefox,,tag:2
    rule=pavucontrol,,float
    ```

### DON'T ❌

1. **Don't modify MangoWC source**

   ```nix
   # ❌ Bad
   # Patching source directly

   # ✅ Good
   # Use configuration options
   ```

2. **Don't ignore NixOS module**

   ```nix
   # ❌ Bad - manual installation
   # ✅ Good - use flake module
   programs.mango.enable = true;
   ```

3. **Don't use absolute paths in config**

   ```bash
   # ❌ Bad
   bind=SUPER,Return,spawn,/usr/bin/foot

   # ✅ Good
   bind=SUPER,Return,spawn,foot
   ```

4. **Don't disable XWayland without reason**

   ```bash
   # ❌ Bad (breaks many apps)
   xwayland=false

   # ✅ Good
   xwayland=true
   ```

5. **Don't set animation duration too low**

   ```bash
   # ❌ Jarring
   animation_duration=50

   # ✅ Smooth
   animation_duration=300
   ```

6. **Don't overuse blur**

   ```bash
   # ❌ Performance impact
   blur_passes=5
   blur_radius=20

   # ✅ Balanced
   blur_passes=2
   blur_radius=8
   ```

7. **Don't hardcode monitor names everywhere**

   ```bash
   # ❌ Not portable
   workspace=1,monitor:DP-1

   # ✅ Better
   workspace=1,monitor:primary
   ```

## Command Reference

### MangoWC IPC Commands

```bash
# Query state
mango-ipc tags              # Get tag information
mango-ipc layout            # Get current layout
mango-ipc clients           # List all clients
mango-ipc focused           # Get focused client
mango-ipc monitors          # List monitors

# Control
mango-ipc tag <N>           # Switch to tag
mango-ipc layout <NAME>     # Set layout
mango-ipc reload            # Reload configuration
mango-ipc quit              # Quit compositor

# Window operations
mango-ipc close             # Close focused window
mango-ipc fullscreen        # Toggle fullscreen
mango-ipc floating          # Toggle floating
mango-ipc minimize          # Minimize window
mango-ipc maximize          # Maximize window
```

### Display Management

```bash
# wlr-randr commands
wlr-randr                   # List outputs
wlr-randr --output DP-1 --mode 1920x1080@60
wlr-randr --output HDMI-A-1 --off
wlr-randr --output eDP-1 --scale 1.5
```

### Debugging

```bash
# View logs
journalctl --user -u mango.service -f
cat ~/.local/share/mango/mango.log

# Test events
wev                         # Wayland event viewer

# Check processes
ps aux | grep mango

# Test IPC
echo "tags" | socat - UNIX-CONNECT:/tmp/mango-ipc.sock
```

## Resources and Documentation

### Official Resources

- **[GitHub - DreamMaoMao/mangowc](https://github.com/DreamMaoMao/mangowc)** - Official repository
- **[MangoWC Website](https://mangowc.vercel.app/)** - Official website
- **[MangoWC Wiki](https://github.com/DreamMaoMao/mangowc/wiki)** - Documentation wiki
- **[MangoWC Installation Guide](https://www.tonybtw.com/tutorial/mangowc/)** - Tutorial

### Community Resources

- **[LinuxLinks - MangoWC](https://www.linuxlinks.com/mangowc-wayland-compositor/)** - Overview
- **[Example Configurations](https://github.com/radiaku/mangowc)** - Community configs
- **[tonybanters/mangowc-btw](https://github.com/tonybanters/mangowc-btw)** - Configuration example

### Related Tools

- **[wlroots](https://gitlab.freedesktop.org/wlroots/wlroots)** - Wayland compositor library
- **[scenefx](https://github.com/wlrfx/scenefx)** - Visual effects library
- **[waybar](https://github.com/Alexays/Waybar)** - Status bar

Ready to configure MangoWC! Let me know what you need help with. 🥭
