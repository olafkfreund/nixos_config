# Niri Skill

A specialized skill for configuring and customizing niri Wayland compositor in NixOS using Home Manager, providing expert guidance on scrollable-tiling window management, dynamic workspaces, declarative configuration, and the unique infinite horizontal desktop paradigm.

## Skill Overview

**Purpose**: Provide comprehensive support for niri configuration, customization, and ecosystem integration in NixOS.

**Invoke When**:

- Setting up niri Wayland compositor
- Configuring niri via Home Manager or niri-flake
- Understanding scrollable-tiling paradigm
- Setting up dynamic workspaces (GNOME-like)
- Configuring keybindings (no defaults!)
- Managing multi-monitor infinite strips
- Integrating screenshot/screencast features
- Troubleshooting niri issues
- Migrating from traditional tiling WMs
- Optimizing niri performance

## Core Capabilities

### 1. What is Niri?

**Niri** is a scrollable-tiling Wayland compositor written in Rust that uses a unique window management paradigm:

**Unique Features:**

- **Infinite horizontal desktop**: Windows arranged in columns on an endless strip
- **Per-monitor strips**: Each monitor has its own independent window layout
- **No resize on new windows**: Opening windows never resizes existing ones
- **Dynamic workspaces**: GNOME-style workspaces arranged vertically
- **Built-in screenshot UI**: Native screenshot and screencast support
- **Smooth animations**: Custom shader support for eye-candy
- **Pixel-perfect scaling**: Fractional scaling without blur

**Project**: [YaLTeR/niri](https://github.com/YaLTeR/niri) (16.3k+ stars)
**Community**: [Matrix #niri:matrix.org](https://matrix.to/#/#niri:matrix.org), [Discord](https://discord.gg/vT8Sfjy7sx)

### 2. Installation and Configuration

**Method 1: NixOS Packages (Simple)**

```nix
# configuration.nix
{ config, pkgs, ... }:
{
  # Enable niri from nixpkgs
  programs.niri.enable = true;

  # Essential packages
  environment.systemPackages = with pkgs; [
    alacritty  # Terminal (required for default config)
    fuzzel     # Launcher (required for default config)
    mako       # Notifications
    waybar     # Status bar
  ];
}
```

```nix
# home.nix
{ config, pkgs, ... }:
{
  # Configure niri via config file
  xdg.configFile."niri/config.kdl".text = ''
    // Your KDL configuration here
  '';
}
```

**Method 2: niri-flake (Declarative with Validation)**

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Add niri-unstable (main repository)
    niri-unstable.url = "github:YaLTeR/niri";

    # Add niri-flake (NixOS/home-manager modules)
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.niri-unstable.follows = "niri-unstable";
    };
  };

  outputs = { nixpkgs, home-manager, niri, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        # Import niri NixOS module
        niri.nixosModules.niri

        {
          # Add niri overlay
          nixpkgs.overlays = [ niri.overlays.niri ];

          # Enable niri (but don't start yet - see best practices)
          programs.niri = {
            enable = true;
            package = pkgs.niri-unstable;  # or pkgs.niri-stable
          };

          # Essential packages
          environment.systemPackages = with pkgs; [
            alacritty
            fuzzel
            mako
            waybar
          ];
        }

        # Home Manager with niri
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.users.username = {
            # niri.homeModules.config automatically imported

            # Declarative configuration (validated at build-time)
            programs.niri.settings = {
              # See section 3 for complete configuration
            };
          };
        }
      ];
    };
  };
}
```

**Binary Cache Setup** (Recommended):

```nix
# configuration.nix
{
  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://niri.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
    ];
  };
}
```

### 3. Declarative Configuration (programs.niri.settings)

**Complete Nix Configuration Example**:

```nix
# home.nix
{ config, pkgs, lib, ... }:
{
  programs.niri.settings = {
    # ============ Input ============
    input = {
      keyboard = {
        xkb = {
          layout = "us";
          # variant = "";
          # options = "caps:escape";
        };

        repeat-delay = 600;
        repeat-rate = 25;
      };

      touchpad = {
        tap = true;
        dwt = true;  # Disable while typing
        natural-scroll = true;
        accel-speed = 0.0;
        accel-profile = "adaptive";  # or "flat"
        tap-button-map = "left-right-middle";
        scroll-method = "two-finger";
        click-method = "button-areas";  # or "clickfinger"
      };

      mouse = {
        accel-speed = 0.0;
        accel-profile = "adaptive";
        natural-scroll = false;
      };

      tablet = {
        # Tablet configuration
        map-to-output = "eDP-1";
      };

      touch = {
        # Touchscreen configuration
      };

      trackpoint = {
        accel-speed = 0.0;
        accel-profile = "adaptive";
      };

      # Focus follows mouse
      focus-follows-mouse = {
        enable = true;
        max-scroll-amount = "10%";
      };

      # Workspace switch on edge scroll
      workspace-auto-back-and-forth = false;
    };

    # ============ Outputs (Monitors) ============
    outputs = {
      "eDP-1" = {
        enable = true;
        mode = {
          width = 1920;
          height = 1080;
          refresh = 60.0;
        };
        scale = 1.0;
        position = {
          x = 0;
          y = 0;
        };
        transform = "normal";  # or "90", "180", "270", "flipped", etc.
      };

      "DP-1" = {
        enable = true;
        mode = {
          width = 3840;
          height = 2160;
          refresh = 144.0;
        };
        scale = 1.5;
        position = {
          x = 1920;
          y = 0;
        };
        variable-refresh-rate = true;
      };

      "HDMI-A-1" = {
        enable = false;  # Disable specific output
      };
    };

    # ============ Layout ============
    layout = {
      # Focus ring
      focus-ring = {
        enable = true;
        width = 2;
        active-color = "#89b4fa";     # Active window
        inactive-color = "#313244";   # Inactive window
        active-gradient = {
          from = "#89b4fa";
          to = "#cba6f7";
          angle = 45;
          # relative-to = "workspace-view";  # or "window"
        };
      };

      # Border
      border = {
        enable = true;
        width = 2;
        active-color = "#89b4fa";
        inactive-color = "#313244";
        active-gradient = {
          from = "#89b4fa";
          to = "#cba6f7";
          angle = 45;
        };
      };

      # Preset column widths
      preset-column-widths = [
        { proportion = 0.33333; }
        { proportion = 0.5; }
        { proportion = 0.66667; }
        { proportion = 1.0; }
      ];

      # Default column width
      default-column-width = { proportion = 0.5; };

      # Center focused column
      center-focused-column = "never";  # or "always", "on-overflow"

      # Gaps
      gaps = 10;

      # Struts (space for panels)
      struts = {
        left = 0;
        right = 0;
        top = 34;  # Space for waybar
        bottom = 0;
      };
    };

    # ============ Cursor ============
    cursor = {
      xcursor-theme = "Adwaita";
      xcursor-size = 24;
    };

    # ============ Screenshot ============
    screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

    # ============ Hotkey Overlay ============
    hotkey-overlay = {
      skip-at-startup = false;
    };

    # ============ Prefer No CSD ============
    # Prefer server-side decorations
    prefer-no-csd = true;

    # ============ Spawn at Startup ============
    spawn-at-startup = [
      { command = [ "waybar" ]; }
      { command = [ "mako" ]; }
      { command = [ "nm-applet" "--indicator" ]; }
      { command = [ "blueman-applet" ]; }
    ];

    # ============ Environment ============
    environment = {
      # Set environment variables
      # QT_QPA_PLATFORM = "wayland";
      # MOZ_ENABLE_WAYLAND = "1";
    };

    # ============ Animations ============
    animations = {
      # Slow down animations
      slowdown = 1.0;

      # Window open animation
      window-open = {
        duration-ms = 150;
        curve = "ease-out-cubic";
      };

      # Window close animation
      window-close = {
        duration-ms = 150;
        curve = "ease-out-cubic";
      };

      # Window resize animation
      window-resize = {
        duration-ms = 150;
        curve = "ease-out-cubic";
      };

      # Window movement
      window-movement = {
        duration-ms = 150;
        curve = "ease-out-cubic";
      };

      # Workspace switch animation
      workspace-switch = {
        duration-ms = 200;
        curve = "ease-out-cubic";
      };

      # Horizontal view movement
      horizontal-view-movement = {
        duration-ms = 200;
        curve = "ease-out-cubic";
      };

      # Config notification
      config-notification-open-close = {
        duration-ms = 150;
        curve = "ease-out-cubic";
      };

      # Animation curves: linear, ease-in-quad, ease-out-quad, ease-in-out-quad,
      #                  ease-in-cubic, ease-out-cubic, ease-in-out-cubic,
      #                  ease-in-expo, ease-out-expo, ease-in-out-expo
    };

    # ============ Window Rules ============
    window-rules = [
      {
        # Match by app-id
        matches = [{ app-id = "^org.mozilla.firefox$"; }];
        # Open on specific workspace
        open-on-workspace = "browser";
      }
      {
        matches = [{ app-id = "^Alacritty$"; }];
        default-column-width = { proportion = 0.5; };
      }
      {
        # Floating windows
        matches = [
          { app-id = "^pavucontrol$"; }
          { app-id = "^nm-connection-editor$"; }
        ];
        # Rules for floating (when implemented)
      }
      {
        # Block out sensitive content
        matches = [{ title = ".*Private Browsing.*"; }];
        block-out-from = "screencast";
      }
      {
        # Picture-in-Picture
        matches = [
          { title = "Picture-in-Picture"; }
          { title = "^Picture in picture$"; }
        ];
        # geometry-corner-radius = { top-left = 0; top-right = 0; bottom-left = 0; bottom-right = 0; };
        # clip-to-geometry = true;
      }
    ];

    # ============ Keybindings ============
    binds = with config.lib.niri.actions; {
      # IMPORTANT: Niri has NO default keybindings!
      # You must define all bindings explicitly.

      # -------- System --------
      "Mod+Shift+Slash".action = show-hotkey-overlay;
      "Mod+Shift+E".action = quit;
      "Mod+Shift+P".action = power-off-monitors;

      # Configuration
      "Mod+Shift+R".action = reload-config;

      # -------- Applications --------
      # Terminal
      "Mod+Return".action = spawn "alacritty";
      "Mod+T".action = spawn "foot";

      # Launcher
      "Mod+Space".action = spawn "fuzzel";
      "Mod+D".action = spawn "rofi" "-show" "drun";

      # Browser
      "Mod+B".action = spawn "firefox";

      # File manager
      "Mod+E".action = spawn "thunar";

      # -------- Windows --------
      # Close window
      "Mod+Q".action = close-window;

      # Fullscreen
      "Mod+F".action = fullscreen-window;
      "Mod+Shift+F".action = maximize-column;

      # Focus
      "Mod+Left".action = focus-column-left;
      "Mod+Right".action = focus-column-right;
      "Mod+Down".action = focus-window-down;
      "Mod+Up".action = focus-window-up;

      # Vim-style focus
      "Mod+H".action = focus-column-left;
      "Mod+L".action = focus-column-right;
      "Mod+J".action = focus-window-down;
      "Mod+K".action = focus-window-up;

      # Focus first/last
      "Mod+Home".action = focus-column-first;
      "Mod+End".action = focus-column-last;

      # Move windows
      "Mod+Shift+Left".action = move-column-left;
      "Mod+Shift+Right".action = move-column-right;
      "Mod+Shift+Down".action = move-window-down;
      "Mod+Shift+Up".action = move-window-up;

      # Vim-style move
      "Mod+Shift+H".action = move-column-left;
      "Mod+Shift+L".action = move-column-right;
      "Mod+Shift+J".action = move-window-down;
      "Mod+Shift+K".action = move-window-up;

      # Move to workspace edge
      "Mod+Ctrl+Left".action = move-column-to-first;
      "Mod+Ctrl+Right".action = move-column-to-last;

      # Consume/expel windows in columns
      "Mod+BracketLeft".action = consume-window-into-column;
      "Mod+BracketRight".action = expel-window-from-column;

      # -------- Column Sizing --------
      # Set column width
      "Mod+R".action = switch-preset-column-width;
      "Mod+Shift+R".action = reset-window-height;

      # Resize
      "Mod+Minus".action = set-column-width "-10%";
      "Mod+Equal".action = set-column-width "+10%";
      "Mod+Shift+Minus".action = set-window-height "-10%";
      "Mod+Shift+Equal".action = set-window-height "+10%";

      # -------- Workspaces --------
      # Switch workspace down/up
      "Mod+Page_Down".action = focus-workspace-down;
      "Mod+Page_Up".action = focus-workspace-up;

      # Vim-style workspace navigation
      "Mod+U".action = focus-workspace-down;
      "Mod+I".action = focus-workspace-up;

      # Move to workspace
      "Mod+Shift+Page_Down".action = move-column-to-workspace-down;
      "Mod+Shift+Page_Up".action = move-column-to-workspace-up;

      # Vim-style workspace movement
      "Mod+Shift+U".action = move-column-to-workspace-down;
      "Mod+Shift+I".action = move-column-to-workspace-up;

      # Switch to specific workspace
      "Mod+1".action = focus-workspace 1;
      "Mod+2".action = focus-workspace 2;
      "Mod+3".action = focus-workspace 3;
      "Mod+4".action = focus-workspace 4;
      "Mod+5".action = focus-workspace 5;
      "Mod+6".action = focus-workspace 6;
      "Mod+7".action = focus-workspace 7;
      "Mod+8".action = focus-workspace 8;
      "Mod+9".action = focus-workspace 9;

      # Move to specific workspace
      "Mod+Shift+1".action = move-column-to-workspace 1;
      "Mod+Shift+2".action = move-column-to-workspace 2;
      "Mod+Shift+3".action = move-column-to-workspace 3;
      "Mod+Shift+4".action = move-column-to-workspace 4;
      "Mod+Shift+5".action = move-column-to-workspace 5;
      "Mod+Shift+6".action = move-column-to-workspace 6;
      "Mod+Shift+7".action = move-column-to-workspace 7;
      "Mod+Shift+8".action = move-column-to-workspace 8;
      "Mod+Shift+9".action = move-column-to-workspace 9;

      # -------- Monitors --------
      # Focus monitor
      "Mod+Comma".action = focus-monitor-left;
      "Mod+Period".action = focus-monitor-right;

      # Move to monitor
      "Mod+Shift+Comma".action = move-column-to-monitor-left;
      "Mod+Shift+Period".action = move-column-to-monitor-right;

      # -------- Screenshots --------
      "Print".action = screenshot;
      "Mod+Print".action = screenshot-screen;
      "Mod+Shift+Print".action = screenshot-window;

      # Screencast
      "Mod+Ctrl+Print".action = screencast;

      # -------- Media Keys --------
      "XF86AudioRaiseVolume" = {
        allow-when-locked = true;
        action = spawn "pamixer" "-i" "5";
      };
      "XF86AudioLowerVolume" = {
        allow-when-locked = true;
        action = spawn "pamixer" "-d" "5";
      };
      "XF86AudioMute" = {
        allow-when-locked = true;
        action = spawn "pamixer" "-t";
      };

      # Media playback
      "XF86AudioPlay" = {
        allow-when-locked = true;
        action = spawn "playerctl" "play-pause";
      };
      "XF86AudioPause" = {
        allow-when-locked = true;
        action = spawn "playerctl" "pause";
      };
      "XF86AudioNext" = {
        allow-when-locked = true;
        action = spawn "playerctl" "next";
      };
      "XF86AudioPrev" = {
        allow-when-locked = true;
        action = spawn "playerctl" "previous";
      };

      # Brightness
      "XF86MonBrightnessUp".action = spawn "brightnessctl" "set" "10%+";
      "XF86MonBrightnessDown".action = spawn "brightnessctl" "set" "10%-";

      # -------- Mouse Bindings --------
      # Window movement and resizing are automatic with Mod+LeftClick and Mod+RightClick
    };

    # ============ Debug ============
    debug = {
      # Enable debug features
      # render-drm-device = "/dev/dri/renderD128";
      # disable-cursor-plane = false;
      # wait-for-frame-completion-before-queueing = false;
      # enable-overlay-planes = false;
      # disable-direct-scanout = false;
    };
  };
}
```

### 4. KDL Configuration Format (Alternative)

If not using niri-flake, configure using KDL in `~/.config/niri/config.kdl`:

```kdl
// ~/.config/niri/config.kdl

// Input
input {
    keyboard {
        xkb {
            layout "us"
            // options "caps:escape"
        }
        repeat-delay 600
        repeat-rate 25
    }

    touchpad {
        tap
        dwt
        natural-scroll
        accel-speed 0.0
    }

    focus-follows-mouse max-scroll-amount="10%"
}

// Outputs
output "eDP-1" {
    mode "1920x1080@60"
    scale 1.0
    position x=0 y=0
}

output "DP-1" {
    mode "3840x2160@144"
    scale 1.5
    position x=1920 y=0
    variable-refresh-rate
}

// Layout
layout {
    focus-ring {
        width 2
        active-color "#89b4fa"
        inactive-color "#313244"
    }

    border {
        width 2
        active-color "#89b4fa"
        inactive-color "#313244"
    }

    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
    }

    default-column-width { proportion 0.5 }

    gaps 10

    struts {
        left 0
        right 0
        top 34
        bottom 0
    }
}

// Cursor
cursor {
    xcursor-theme "Adwaita"
    xcursor-size 24
}

// Spawn at startup
spawn-at-startup "waybar"
spawn-at-startup "mako"

// Keybindings
binds {
    // IMPORTANT: NO default bindings!

    // System
    Mod+Shift+Slash { show-hotkey-overlay; }
    Mod+Shift+E { quit; }

    // Applications
    Mod+Return { spawn "alacritty"; }
    Mod+Space { spawn "fuzzel"; }

    // Windows
    Mod+Q { close-window; }
    Mod+F { fullscreen-window; }

    // Focus
    Mod+H { focus-column-left; }
    Mod+L { focus-column-right; }
    Mod+J { focus-window-down; }
    Mod+K { focus-window-up; }

    // Move
    Mod+Shift+H { move-column-left; }
    Mod+Shift+L { move-column-right; }

    // Workspaces
    Mod+U { focus-workspace-down; }
    Mod+I { focus-workspace-up; }
    Mod+Shift+U { move-column-to-workspace-down; }
    Mod+Shift+I { move-column-to-workspace-up; }

    // Numbered workspaces
    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    // ... etc

    // Screenshots
    Print { screenshot; }
    Mod+Print { screenshot-screen; }
}

// Animations
animations {
    window-open {
        duration-ms 150
        curve "ease-out-cubic"
    }
    workspace-switch {
        duration-ms 200
        curve "ease-out-cubic"
    }
}
```

### 5. Essential Packages

**Complete Package Set**:

```nix
{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    # ============ Required (for default config) ============
    alacritty       # Terminal
    fuzzel          # Launcher

    # ============ Terminals ============
    foot            # Lightweight
    kitty           # GPU-accelerated
    wezterm         # Feature-rich

    # ============ Launchers ============
    rofi-wayland    # Feature-rich
    bemenu          # Dmenu alternative
    tofi            # Minimal launcher
    wofi            # Wayland native

    # ============ Status Bars ============
    waybar          # Highly customizable (recommended)
    yambar          # Minimal
    i3status-rust   # Rust-based

    # ============ Notifications ============
    mako            # Minimal (recommended)
    dunst           # Feature-rich
    swaync          # Notification center

    # ============ Wallpaper ============
    swaybg          # Static wallpapers
    swww            # Animated wallpapers
    hyprpaper       # Alternative

    # ============ Screen Locking ============
    swaylock        # Screen lock
    swaylock-effects  # Swaylock with effects
    hyprlock        # Alternative

    # ============ Idle Management ============
    swayidle        # Idle daemon
    hypridle        # Alternative

    # ============ File Managers ============
    thunar          # GTK file manager
    pcmanfm         # Lightweight
    dolphin         # KDE
    nautilus        # GNOME
    yazi            # Terminal file manager

    # ============ System Utilities ============
    brightnessctl   # Screen brightness
    playerctl       # Media control
    pamixer         # Audio control (CLI)
    pavucontrol     # Audio control (GUI)

    # ============ Network Management ============
    networkmanagerapplet  # Network manager

    # ============ Bluetooth ============
    blueman         # Bluetooth manager

    # ============ Authentication ============
    polkit-kde-agent  # Polkit (automatically installed)

    # ============ GNOME Keyring ============
    # Automatically enabled by niri-flake

    # ============ Wayland Utilities ============
    wl-clipboard    # CLI clipboard
    cliphist        # Clipboard history
    wtype           # xdotool for Wayland
    wev             # Event viewer
    wlr-randr       # Display config

    # ============ Screenshot/Screencast ============
    # Built into niri! No external tools needed.
    # Optional: swappy for annotation
    swappy          # Screenshot editor
    satty           # Screenshot annotation

    # ============ Color Temperature ============
    wlsunset        # Redshift for Wayland
    gammastep       # Alternative

    # ============ System Monitoring ============
    btop            # Resource monitor
    htop            # Process viewer

    # ============ Fonts ============
    (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" ]; })

    # ============ Xwayland Support ============
    # From v25.08+: use xwayland-satellite
    xwayland-satellite  # X11 support (future)
  ];
}
```

### 6. Waybar Configuration for Niri

**waybar config.json**:

```json
{
  "layer": "top",
  "position": "top",
  "height": 34,
  "spacing": 4,

  "modules-left": ["custom/niri-workspaces"],

  "modules-center": ["clock"],

  "modules-right": [
    "pulseaudio",
    "network",
    "cpu",
    "memory",
    "temperature",
    "backlight",
    "battery",
    "tray"
  ],

  "custom/niri-workspaces": {
    "exec": "niri msg --json workspaces | jq -r '.[] | \"\\(.name) \\(.is-active)\"'",
    "interval": 1,
    "format": "{}",
    "on-click": "niri msg workspace {}"
  },

  "clock": {
    "format": "{:%H:%M}",
    "format-alt": "{:%Y-%m-%d}",
    "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
  },

  "pulseaudio": {
    "format": "{icon} {volume}%",
    "format-muted": "",
    "format-icons": {
      "default": ["", "", ""]
    },
    "on-click": "pavucontrol"
  },

  "network": {
    "format-wifi": " {essid}",
    "format-ethernet": " {ipaddr}",
    "format-disconnected": "⚠ Disconnected"
  },

  "cpu": {
    "format": " {usage}%"
  },

  "memory": {
    "format": " {}%"
  },

  "temperature": {
    "format": "{icon} {temperatureC}°C",
    "format-icons": ["", "", ""]
  },

  "backlight": {
    "format": "{icon} {percent}%",
    "format-icons": ["", "", "", "", "", "", "", "", ""]
  },

  "battery": {
    "states": {
      "warning": 30,
      "critical": 15
    },
    "format": "{icon} {capacity}%",
    "format-charging": " {capacity}%",
    "format-plugged": " {capacity}%",
    "format-icons": ["", "", "", "", ""]
  },

  "tray": {
    "spacing": 10
  }
}
```

**Home Manager Integration**:

```nix
programs.waybar = {
  enable = true;
  systemd.enable = true;

  settings = {
    mainBar = {
      # Copy JSON config above
    };
  };

  style = ''
    * {
      border: none;
      font-family: "JetBrainsMono Nerd Font";
      font-size: 13px;
    }

    window#waybar {
      background: rgba(30, 30, 46, 0.9);
      color: #cdd6f4;
    }

    #custom-niri-workspaces,
    #clock,
    #pulseaudio,
    #network,
    #cpu,
    #memory,
    #temperature,
    #backlight,
    #battery,
    #tray {
      padding: 0 10px;
      margin: 0 5px;
    }

    #battery.warning {
      color: #f9e2af;
    }

    #battery.critical {
      color: #f38ba8;
    }
  '';
};
```

### 7. Understanding Scrollable Tiling

**Key Concepts:**

1. **Infinite Horizontal Strip**: Windows arranged in columns from left to right
2. **Per-Monitor Independence**: Each monitor has its own separate strip
3. **Dynamic Workspaces**: Workspaces stack vertically (GNOME-style)
4. **No Window Resizing**: Opening windows never resizes existing ones

**Scrollable Tiling Workflow**:

```
Monitor 1:                    Monitor 2:
┌─────────────────────┐      ┌─────────────────────┐
│ Workspace 1         │      │ Workspace 1         │
│ [App1] [App2] [App3]│      │ [Browser] [Terminal]│
│ ← → → → → → → →     │      │ ← → → → →           │
└─────────────────────┘      └─────────────────────┘
┌─────────────────────┐      ┌─────────────────────┐
│ Workspace 2         │      │ Workspace 2         │
│ [Code] [Docs] [Test]│      │ [Email] [Chat]      │
│ ← → → → → → →       │      │ ← → → →             │
└─────────────────────┘      └─────────────────────┘
```

**Navigation**:

- **Horizontal** (Mod+H/L): Scroll left/right through columns
- **Vertical** (Mod+J/K): Move between windows in a column
- **Workspace** (Mod+U/I): Switch between workspaces vertically

**Column Management**:

```bash
# Consume window into column (stack vertically)
Mod+BracketLeft

# Expel window from column (unstahuman ck)
Mod+BracketRight

# Adjust column width
Mod+Minus / Mod+Equal
```

### 8. Dynamic Workspaces

**How It Works:**

- Workspaces created automatically as needed
- Always one empty workspace available
- Removing last window destroys workspace
- Workspaces preserved per-monitor across reconnects

**Workspace Management**:

```nix
binds = {
  # Vertical navigation (like GNOME)
  "Mod+Page_Down".action = focus-workspace-down;
  "Mod+Page_Up".action = focus-workspace-up;

  # Or vim-style
  "Mod+U".action = focus-workspace-down;
  "Mod+I".action = focus-workspace-up;

  # Move window to workspace
  "Mod+Shift+U".action = move-column-to-workspace-down;
  "Mod+Shift+I".action = move-column-to-workspace-up;

  # Direct workspace access
  "Mod+1".action = focus-workspace 1;
  "Mod+2".action = focus-workspace 2;
  # ... etc
};
```

**Named Workspaces**:

```nix
window-rules = [
  {
    matches = [{ app-id = "^firefox$"; }];
    open-on-workspace = "browser";  # Named workspace
  }
  {
    matches = [{ app-id = "^code$"; }];
    open-on-workspace = "dev";
  }
];
```

### 9. Built-in Screenshot & Screencast

**Niri has native screenshot/screencast support!**

**Screenshot Bindings**:

```nix
binds = {
  # Interactive screenshot (select area)
  "Print".action = screenshot;

  # Screenshot entire screen
  "Mod+Print".action = screenshot-screen;

  # Screenshot current window
  "Mod+Shift+Print".action = screenshot-window;

  # Start/stop screencast
  "Mod+Ctrl+Print".action = screencast;
};

# Screenshot save path
screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";
```

**Features:**

- Interactive region selection
- Full screen capture
- Window capture
- Screen recording (screencast)
- Privacy: Block sensitive content with window rules

**Privacy Controls**:

```nix
window-rules = [
  {
    matches = [
      { title = ".*Private Browsing.*"; }
      { app-id = "^org.keepassxc.KeePassXC$"; }
    ];
    block-out-from = "screencast";  # Black out in recordings
  }
];
```

### 10. Multi-Monitor Management

**Configuration**:

```nix
outputs = {
  # Laptop screen
  "eDP-1" = {
    mode = {
      width = 1920;
      height = 1080;
      refresh = 60.0;
    };
    scale = 1.0;
    position = { x = 0; y = 0; };
  };

  # External monitor
  "DP-1" = {
    mode = {
      width = 3840;
      height = 2160;
      refresh = 144.0;
    };
    scale = 1.5;
    position = { x = 1920; y = 0; };
    variable-refresh-rate = true;
  };

  # Disable specific output
  "HDMI-A-1" = {
    enable = false;
  };
};
```

**Monitor Navigation**:

```nix
binds = {
  # Focus adjacent monitor
  "Mod+Comma".action = focus-monitor-left;
  "Mod+Period".action = focus-monitor-right;

  # Move column to monitor
  "Mod+Shift+Comma".action = move-column-to-monitor-left;
  "Mod+Shift+Period".action = move-column-to-monitor-right;
};
```

**Per-Monitor Workspace Persistence**:

- Each monitor maintains independent workspace list
- Workspaces remember their monitor assignment
- Reconnecting monitors restores workspace positions

## Common Patterns and Solutions

### Pattern 1: Startup Applications

```nix
# Programs to launch at startup
spawn-at-startup = [
  # Essential services
  { command = [ "waybar" ]; }
  { command = [ "mako" ]; }
  { command = [ "nm-applet" "--indicator" ]; }
  { command = [ "blueman-applet" ]; }

  # Background services
  { command = [ "swaybg" "-i" "/home/user/Pictures/wallpaper.png" ]; }
  { command = [ "wl-paste" "--watch" "cliphist" "store" ]; }

  # Applications
  { command = [ "firefox" ]; }
];
```

### Pattern 2: Dynamic Hotkeys Reference

```nix
# Show hotkey overlay on startup
hotkey-overlay = {
  skip-at-startup = false;  # Show on first launch
};

# Toggle hotkey overlay
binds = {
  "Mod+Shift+Slash".action = show-hotkey-overlay;
};
```

### Pattern 3: Column Width Presets

```nix
layout = {
  # Preset widths for quick switching
  preset-column-widths = [
    { proportion = 0.25; }   # Quarter
    { proportion = 0.33333; }  # Third
    { proportion = 0.5; }    # Half
    { proportion = 0.66667; }  # Two-thirds
    { proportion = 0.75; }   # Three-quarters
    { proportion = 1.0; }    # Full
  ];

  # Cycle through presets
  # Bound to Mod+R in keybindings
};

binds = {
  "Mod+R".action = switch-preset-column-width;
};
```

### Pattern 4: Stylix Integration

```nix
# Automatic theming with Stylix
stylix = {
  enable = true;
  image = ./wallpaper.png;

  base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
};

# Niri automatically uses Stylix colors for borders and cursor
```

### Pattern 5: IPC Communication

```bash
# Query niri state
niri msg --json workspaces
niri msg --json outputs
niri msg --json windows

# Control niri
niri msg action focus-workspace-down
niri msg action close-window
niri msg action screenshot

# Example: Focus specific workspace from script
workspace_name="dev"
niri msg action focus-workspace "$workspace_name"
```

## Troubleshooting Guide

### Issue 1: Niri Won't Start

**Problem**: Compositor fails to launch

**Solution**:

```bash
# Check logs
journalctl --user -u niri.service -f

# Run niri directly for debugging
niri

# Check Wayland socket
echo $WAYLAND_DISPLAY

# Verify package
which niri
niri --version
```

### Issue 2: No Keybindings Work

**Problem**: Niri doesn't respond to any keys

**Cause**: **Niri has NO default keybindings!**

**Solution**:

```nix
# You MUST define all bindings in configuration
programs.niri.settings.binds = with config.lib.niri.actions; {
  "Mod+Return".action = spawn "alacritty";
  "Mod+Q".action = close-window;
  # ... etc
};

# Press Mod+Shift+E to quit if you forgot bindings
```

### Issue 3: Configuration Not Loading

**Problem**: Changes not applied

**Solution**:

```bash
# Check config path
ls -la ~/.config/niri/config.kdl

# Validate configuration (niri-flake only)
nix build .#nixosConfigurations.hostname.config.programs.niri.finalConfig

# Reload configuration
niri msg action reload-config

# Check for errors in logs
journalctl --user -u niri.service | grep -i error
```

### Issue 4: Applications Not Launching

**Problem**: Can't launch alacritty or fuzzel

**Solution**:

```bash
# Install required packages
nix-shell -p alacritty fuzzel

# Or add to configuration
environment.systemPackages = with pkgs; [ alacritty fuzzel ];

# Rebuild
sudo nixos-rebuild switch
```

### Issue 5: Screenshots Not Working

**Problem**: Screenshot keybind doesn't work

**Solution**:

```bash
# Check screenshot path exists
mkdir -p ~/Pictures/Screenshots

# Check keybinding is defined
# In config:
binds = {
  "Print".action = screenshot;
};

# Test manually
niri msg action screenshot
```

### Issue 6: High CPU Usage on Blur

**Problem**: CPU usage high with blur enabled

**Solution**:

```nix
# Blur is not yet implemented in niri
# This is expected to be added in future versions

# For now, niri uses simple borders
layout = {
  border = {
    enable = true;
    width = 2;
    active-color = "#89b4fa";
  };
};
```

### Issue 7: Binary Cache Not Working

**Problem**: Building niri from source

**Solution**:

```nix
# Ensure binary cache is configured
nix.settings = {
  substituters = [ "https://niri.cachix.org" ];
  trusted-public-keys = [
    "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
  ];
};

# Clear and retry
nix-store --gc
nixos-rebuild switch
```

## Best Practices

### DO ✅

1. **Use niri-flake for declarative config**

   ```nix
   inputs.niri.url = "github:sodiboo/niri-flake";
   programs.niri.settings = { /* ... */ };
   ```

2. **Enable binary cache FIRST**

   ```nix
   # Add before enabling niri
   nix.settings.substituters = [ "https://niri.cachix.org" ];
   ```

3. **Define ALL keybindings explicitly**

   ```nix
   # Niri has NO defaults!
   binds = { /* all your bindings */ };
   ```

4. **Use validation with programs.niri.settings**

   ```nix
   # Build-time schema validation
   programs.niri.settings = { };  # Type-checked!
   ```

5. **Show hotkey overlay for new users**

   ```nix
   hotkey-overlay.skip-at-startup = false;
   ```

6. **Use named workspaces**

   ```nix
   window-rules = [{
     matches = [{ app-id = "firefox"; }];
     open-on-workspace = "browser";
   }];
   ```

7. **Leverage built-in screenshot**

   ```nix
   # No need for grim/slurp!
   binds."Print".action = screenshot;
   ```

8. **Set reasonable animation durations**

   ```nix
   animations = {
     window-open.duration-ms = 150;
     workspace-switch.duration-ms = 200;
   };
   ```

9. **Use column presets for productivity**

   ```nix
   layout.preset-column-widths = [
     { proportion = 0.5; }
     { proportion = 0.66667; }
   ];
   ```

10. **Configure struts for panels**

    ```nix
    layout.struts.top = 34;  # For waybar
    ```

### DON'T ❌

1. **Don't expect default keybindings**

   ```nix
   # ❌ Niri has NONE
   # ✅ Define everything explicitly
   ```

2. **Don't skip binary cache setup**

   ```nix
   # ❌ Will build from source (slow)
   # ✅ Configure cache first
   ```

3. **Don't use grim/slurp**

   ```nix
   # ❌ External screenshot tools
   # ✅ Use built-in screenshot
   ```

4. **Don't forget to install alacritty & fuzzel**

   ```nix
   # ❌ Will be unable to launch apps
   # ✅ Install required packages
   ```

5. **Don't use traditional workspace concepts**

   ```nix
   # ❌ Think in tags/static workspaces
   # ✅ Embrace dynamic workspaces
   ```

6. **Don't try to tile like i3/sway**

   ```nix
   # ❌ Expecting traditional tiling
   # ✅ Learn scrollable-tiling paradigm
   ```

7. **Don't ignore the hotkey overlay**

   ```nix
   # ❌ Hiding Mod+Shift+Slash
   # ✅ Use it to learn bindings
   ```

## Command Reference

### Niri IPC (niri msg)

```bash
# Query state
niri msg --json workspaces      # List workspaces
niri msg --json outputs         # List monitors
niri msg --json windows         # List windows
niri msg --json version         # Niri version

# Execute actions
niri msg action focus-workspace-down
niri msg action close-window
niri msg action screenshot
niri msg action quit

# Request confirmation
niri msg --json request-error  # Get last error
```

### Display Management

```bash
# List outputs
wlr-randr

# Configure output
wlr-randr --output eDP-1 --mode 1920x1080@60

# Disable output
wlr-randr --output HDMI-A-1 --off
```

### Debugging

```bash
# View logs
journalctl --user -u niri.service -f

# Test configuration
niri validate

# Check events
wev  # Wayland event viewer
```

## Resources and Documentation

### Official Resources

- **[YaLTeR/niri GitHub](https://github.com/YaLTeR/niri)** - Official repository
- **[NixOS Wiki - Niri](https://wiki.nixos.org/wiki/Niri)** - NixOS setup guide
- **[sodiboo/niri-flake](https://github.com/sodiboo/niri-flake)** - NixOS/Home Manager modules
- **[Niri Documentation](https://variety4me.github.io/niri_docs/)** - Community docs

### Community Resources

- **[Matrix Chat](https://matrix.to/#/#niri:matrix.org)** - Community support
- **[Discord](https://discord.gg/vT8Sfjy7sx)** - Community chat
- **[LWN Article](https://lwn.net/Articles/1025866/)** - Tour of niri
- **[Archcraft Wiki](https://wiki.archcraft.io/docs/wayland-compositors/niri/)** - Configuration examples

### Blog Posts

- **[TypeVar.dev - Adopting niri](https://typevar.dev/articles/YaLTeR/niri)** - Customization guide

Ready to configure niri! Let me know what you need help with. 🌊
