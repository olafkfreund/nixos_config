---
name: mangowc
version: 1.0
description: MangoWC Skill
---

# MangoWC Skill

A specialized skill for configuring and customizing MangoWC Wayland compositor in NixOS using Home Manager, providing
expert guidance on tag-based window management, animations, effects, and declarative configuration.

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

**MangoWC** is a fast, lightweight, modern Wayland compositor based on wlroots and scenefx. It's described as "dwm but
Wayland" and provides:

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

#### NixOS Flake Setup (Recommended)

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

  outputs = { nixpkgs, home-manager, mangowc, ... }:
    {
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
          environment.systemPackages = with pkgs;
            [
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

#### NixOS Module Only (System-wide)

```nix
# configuration.nix
{ config, pkgs, ... }:
{
  # Import MangoWC module from flake
  programs.mango.enable = true;

  # Essential packages
  environment.systemPackages = with pkgs;
    [
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

#### Home Manager Module (Per-User)

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

#### Full config.conf Example

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
