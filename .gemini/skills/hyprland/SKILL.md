---
name: hyprland
version: 1.0
description: Hyprland Skill
---

# Hyprland Skill

A specialized skill for configuring and customizing Hyprland window manager in NixOS using Home Manager, providing expert
guidance on Wayland compositor setup, essential packages, plugins, and declarative configuration.

## Skill Overview

**Purpose**: Provide comprehensive support for Hyprland configuration, customization, and ecosystem integration in NixOS.

**Invoke When**:

- Setting up Hyprland window manager
- Configuring Hyprland via Home Manager
- Installing Hyprland plugins and extensions
- Setting up Waybar, rofi-wayland, or other companions
- Troubleshooting Hyprland issues
- Migrating from X11 window managers to Hyprland
- Customizing Hyprland keybindings and behavior
- Optimizing Hyprland performance

## Core Capabilities

### 1. Installation and Configuration

#### Two-Module Approach (Recommended)

The best practice is using both NixOS and Home Manager modules for optimal integration.

**NixOS Module** (configuration.nix):

```nix
{ config, pkgs, ... }:
{
  # Enable Hyprland system-wide
  programs.hyprland = {
    enable = true;

    # Optional: Use nightly builds
    # package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;

    # Enable XWayland support (for X11 apps)
    xwayland.enable = true;

    # UWSM support (New in 2025 - Recommended)
    withUWSM = true;  # Universal Wayland Session Manager
  };

  # Portal configuration for screen sharing
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  # Required for some applications
  environment.sessionVariables = {
    # Hint electron apps to use Wayland
    NIXOS_OZONE_WL = "1";
  };
}
```

**Home Manager Module** (home.nix):

```nix
{ config, pkgs, lib, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;

    # Use system package (recommended)
    package = null;  # Uses NixOS module package
    portalPackage = null;  # Uses NixOS module portal package

    # Enable systemd integration
    systemd = {
      enable = true;
      variables = ["--all"];
    };

    # XWayland support
    xwayland.enable = true;

    # Declarative settings (recommended)
    settings = {
      # See section 2 for detailed settings
    };

    # Or use extraConfig for raw config
    # extraConfig = ''
    #   # Your hyprland.conf here
    # '';
  };
}
```

**Flake-based Setup**:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Optional: Use Hyprland flake for latest features
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
  };

  outputs = { nixpkgs, home-manager, hyprland, ... }:
  {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      modules = [
        # Import Hyprland NixOS module
        hyprland.nixosModules.default

        # Your configuration
        {
          programs.hyprland.enable = true;
        }

        # Home Manager with Hyprland
        home-manager.nixosModules.home-manager
        {
          home-manager.users.username = {
            imports = [ hyprland.homeManagerModules.default ];

            wayland.windowManager.hyprland = {
              enable = true;
              # Configuration
            };
          };
        }
      ];
    };
  };
}
```

### 2. Declarative Configuration (Settings)

#### Complete Settings Example

```nix
wayland.windowManager.hyprland.settings = {
  # Monitors
  monitor = [
    "DP-1,3840x2160@144,0x0,1"
    "HDMI-A-1,1920x1080@60,3840x0,1"
    ",preferred,auto,1"  # Fallback for unknown monitors
  ];

  # Workspace assignment
  workspace = [
    "1, monitor:DP-1, default:true"
    "2, monitor:DP-1"
    "9, monitor:HDMI-A-1"
  ];

  # Environment variables
  env = [
    "XCURSOR_SIZE,24"
    "HYPRCURSOR_SIZE,24"
    "QT_QPA_PLATFORM,wayland"
    "SDL_VIDEODRIVER,wayland"
    "GDK_BACKEND,wayland,x11"
  ];

  # Autostart
  exec-once = [
    "waybar"
    "hyprpaper"
    "dunst"
    "nm-applet"
    "blueman-applet"
    "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
  ];

  # General settings
  general = {
    gaps_in = 5;
    gaps_out = 10;
    border_size = 2;

    # Colors
    "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
    "col.inactive_border" = "rgba(595959aa)";

    layout = "dwindle";
    resize_on_border = true;
  };

  # Decorations
  decoration = {
    rounding = 10;

    blur = {
      enabled = true;
      size = 3;
      passes = 1;
      new_optimizations = true;
    };

    drop_shadow = true;
    shadow_range = 4;
    shadow_render_power = 3;
    "col.shadow" = "rgba(1a1a1aee)";
  };

  # Animations
  animations = {
    enabled = true;

    bezier = [
      "myBezier, 0.05, 0.9, 0.1, 1.05"
      "linear, 0, 0, 1, 1"
      "easeInOutCubic, 0.65, 0, 0.35, 1"
    ];

    animation = [
      "windows, 1, 7, myBezier"
      "windowsOut, 1, 7, default, popin 80%"
      "border, 1, 10, default"
      "fade, 1, 7, default"
      "workspaces, 1, 6, default"
      "specialWorkspace, 1, 6, default, slidevert"
    ];
  };

  # Input settings
  input = {
    kb_layout = "us";
    kb_variant = "";
    kb_options = "caps:escape";  # Caps as Escape

    follow_mouse = 1;

    touchpad = {
      natural_scroll = true;
      disable_while_typing = true;
      tap-to-click = true;
    };

    sensitivity = 0;  # -1.0 to 1.0, 0 = no modification
  };

  # Gestures
  gestures = {
    workspace_swipe = true;
    workspace_swipe_fingers = 3;
    workspace_swipe_distance = 300;
    workspace_swipe_cancel_ratio = 0.5;
  };

  # Layout settings
  dwindle = {
    pseudotile = true;
    preserve_split = true;
    special_scale_factor = 0.8;
  };

  master = {
    new_status = "master";
    new_on_top = false;
    mfact = 0.5;
  };

  # Miscellaneous
  misc = {
    disable_hyprland_logo = true;
    disable_splash_rendering = true;
    mouse_move_enables_dpms = true;
    key_press_enables_dpms = true;
    vrr = 1;  # Variable refresh rate
    enable_swallow = true;
    swallow_regex = "^(Alacritty|kitty|foot)$";
  };

  # Window rules
  windowrule = [
    "float, ^(pavucontrol)$"
    "float, ^(nm-connection-editor)$"
    "float, title:^(Picture-in-Picture)$"
    "pin, title:^(Picture-in-Picture)$"
    "opacity 0.9, ^(Alacritty)$"
  ];

  windowrulev2 = [
    "opacity 0.8 0.8, class:^(Code)$"
    "float, class:^(firefox)$, title:^(Picture-in-Picture)$"
    "pin, class:^(firefox)$, title:^(Picture-in-Picture)$"
    "workspace 2, class:^(firefox)$"
    "workspace 3, class:^(Code)$"
  ];

  # Layer rules
  layerrule = [
    "blur, waybar"
    "ignorezero, waybar"
    "blur, notifications"
    "ignorezero, notifications"
  ];
};
```

### 3. Keybindings Configuration

#### Essential Keybindings

```nix
wayland.windowManager.hyprland.settings = {
  # Modifier key
  "$mod" = "SUPER";

  # Keybindings
  bind = [
    # Application launchers
    "$mod, Return, exec, alacritty"
    "$mod, Q, killactive"
    "$mod, M, exit"
    "$mod, E, exec, thunar"
    "$mod, V, togglefloating"
    "$mod, R, exec, rofi -show drun"
    "$mod, P, pseudo"  # dwindle
    "$mod, J, togglesplit"  # dwindle

    # Move focus
    "$mod, left, movefocus, l"
    "$mod, right, movefocus, r"
    "$mod, up, movefocus, u"
    "$mod, down, movefocus, d"

    # Vim-style focus
    "$mod, h, movefocus, l"
    "$mod, l, movefocus, r"
    "$mod, k, movefocus, u"
    "$mod, j, movefocus, d"

    # Switch workspaces
    "$mod, 1, workspace, 1"
    "$mod, 2, workspace, 2"
    "$mod, 3, workspace, 3"
    "$mod, 4, workspace, 4"
    "$mod, 5, workspace, 5"
    "$mod, 6, workspace, 6"
    "$mod, 7, workspace, 7"
    "$mod, 8, workspace, 8"
    "$mod, 9, workspace, 9"
    "$mod, 0, workspace, 10"

    # Move window to workspace
    "$mod SHIFT, 1, movetoworkspace, 1"
    "$mod SHIFT, 2, movetoworkspace, 2"
    "$mod SHIFT, 3, movetoworkspace, 3"
    "$mod SHIFT, 4, movetoworkspace, 4"
    "$mod SHIFT, 5, movetoworkspace, 5"
    "$mod SHIFT, 6, movetoworkspace, 6"
    "$mod SHIFT, 7, movetoworkspace, 7"
    "$mod SHIFT, 8, movetoworkspace, 8"
    "$mod SHIFT, 9, movetoworkspace, 9"
    "$mod SHIFT, 0, movetoworkspace, 10"

    # Special workspaces (scratchpad)
    "$mod, S, togglespecialworkspace, magic"
    "$mod SHIFT, S, movetoworkspace, special:magic"

    # Scroll through workspaces
    "$mod, mouse_down, workspace, e+1"
    "$mod, mouse_up, workspace, e-1"

    # Fullscreen
    "$mod, F, fullscreen, 0"
    "$mod SHIFT, F, fullscreen, 1"  # Maximize

    # Screenshot
    ", Print, exec, grimblast copy area"
    "$mod, Print, exec, grimblast copy screen"

    # Media keys
    ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
    ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
    ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
    ", XF86AudioPlay, exec, playerctl play-pause"
    ", XF86AudioPause, exec, playerctl pause"
    ", XF86AudioNext, exec, playerctl next"
    ", XF86AudioPrev, exec, playerctl previous"

    # Brightness
    ", XF86MonBrightnessUp, exec, brightnessctl set 10%+"
    ", XF86MonBrightnessDown, exec, brightnessctl set 10%-"

    # Lock screen
    "$mod, L, exec, hyprlock"
  ];

  # Mouse bindings
  bindm = [
    "$mod, mouse:272, movewindow"
    "$mod, mouse:273, resizewindow"
  ];

  # Repeating binds
  binde = [
    # Resize windows
    "$mod CTRL, left, resizeactive, -10 0"
    "$mod CTRL, right, resizeactive, 10 0"
    "$mod CTRL, up, resizeactive, 0 -10"
    "$mod CTRL, down, resizeactive, 0 10"

    # Vim-style resize
    "$mod CTRL, h, resizeactive, -10 0"
    "$mod CTRL, l, resizeactive, 10 0"
    "$mod CTRL, k, resizeactive, 0 -10"
    "$mod CTRL, j, resizeactive, 0 10"
  ];

  # Move window binds
  bind = [
    "$mod SHIFT, left, movewindow, l"
    "$mod SHIFT, right, movewindow, r"
    "$mod SHIFT, up, movewindow, u"
    "$mod SHIFT, down, movewindow, d"

    # Vim-style move
    "$mod SHIFT, h, movewindow, l"
    "$mod SHIFT, l, movewindow, r"
    "$mod SHIFT, k, movewindow, u"
    "$mod SHIFT, j, movewindow, d"
  ];
};
```

### 4. Essential Packages

#### Complete Package Set

```nix
{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    # Hyprland ecosystem
    hyprpaper         # Wallpaper daemon
    hypridle          # Idle daemon
    hyprlock          # Screen lock
    hyprpicker        # Color picker
    hyprcursor        # Cursor manager

    # Status bar and panels
    waybar            # Status bar

    # Application launcher
    rofi-wayland      # App launcher

    # Notifications
    dunst             # Notification daemon
    mako              # Alternative notification daemon

    # Screenshot tools
    grim              # Screenshot
    slurp             # Select screen region
    grimblast         # Grim wrapper with clipboard
    swappy            # Screenshot editor

    # Clipboard management
    wl-clipboard      # CLI clipboard tools
    cliphist          # Clipboard history

    # Screen recording
    wf-recorder       # Screen recorder

    # Color temperature
    wlsunset          # Redshift for Wayland
    gammastep         # Alternative to wlsunset

    # File manager
    thunar            # GTK file manager
    # Or alternatives:
    # pcmanfm
    # dolphin
    # nautilus

    # Terminal emulators
    alacritty         # GPU-accelerated terminal
    kitty             # Alternative terminal
    foot              # Lightweight terminal

    # System utilities
    brightnessctl     # Screen brightness
    playerctl         # Media control
    pavucontrol       # Audio control (GUI)
    pamixer           # Audio control (CLI)

    # Network management
    networkmanagerapplet  # Network manager applet

    # Bluetooth
    blueman           # Bluetooth manager

    # Authentication agent
    polkit_gnome      # Polkit authentication

    # Display management
    wlr-randr         # Display configuration
    kanshi            # Display hotplug daemon

    # Logout menu
    wlogout           # Logout/shutdown menu

    # Wayland utilities
    wtype             # xdotool for Wayland
    wev               # Wayland event viewer
    wayvnc            # VNC server for wlroots

    # Eye candy
    swww              # Animated wallpapers

    # Performance
    wlroots           # Wayland compositor library
  ];
}
```

### 5. Waybar Configuration

#### Complete Waybar Setup

```nix
programs.waybar = {
  enable = true;
  systemd.enable = true;

  settings = {
    mainBar = {
      layer = "top";
      position = "top";
      height = 34;
      spacing = 4;

      modules-left = [
        "hyprland/workspaces"
        "hyprland/submap"
        "hyprland/window"
      ];

      modules-center = [
        "clock"
      ];

      modules-right = [
        "idle_inhibitor"
        "pulseaudio"
        "network"
        "cpu"
        "memory"
        "temperature"
        "backlight"
        "battery"
        "tray"
      ];

      # Module configurations
      "hyprland/workspaces" = {
        disable-scroll = true;
        all-outputs = true;
        format = "{icon}";
        format-icons = {
          "1" = "";
          "2" = "";
          "3" = "";
          "4" = "";
          "5" = "";
          urgent = "";
          focused = "";
          default = "";
        };
      };

      "hyprland/window" = {
        max-length = 50;
        separate-outputs = true;
      };

      "hyprland/submap" = {
        format = "✌️ {}";
        max-length = 8;
        tooltip = false;
      };

      clock = {
        timezone = "America/New_York";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        format = "{:%H:%M}";
        format-alt = "{:%Y-%m-%d}";
      };

      cpu = {
        format = " {usage}%";
        tooltip = false;
      };

      memory = {
        format = " {}%";
      };

      temperature = {
        critical-threshold = 80;
        format = "{icon} {temperatureC}°C";
        format-icons = ["" "" ""];
      };

      backlight = {
        format = "{icon} {percent}%";
        format-icons = ["" "" "" "" "" "" "" ""];
      };

      battery = {
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{icon} {capacity}%";
        format-charging = " {capacity}%";
        format-plugged = " {capacity}%";
        format-alt = "{icon} {time}";
        format-icons = ["" "" "" "" ""];
      };

      network = {
        format-wifi = " {essid}";
        format-ethernet = " {ipaddr}";
        format-linked = " {ifname} (No IP)";
        format-disconnected = "⚠ Disconnected";
        tooltip-format = "{ifname} via {gwaddr} ";
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-bluetooth = "{icon} {volume}%";
        format-muted = "";
        format-icons = {
          headphone = "";
          hands-free = "";
          headset = "";
          phone = "";
          portable = "";
          car = "";
          default = ["" "" ""];
        };
        on-click = "pavucontrol";
      };

      idle_inhibitor = {
        format = "{icon}";
        format-icons = {
          activated = "";
          deactivated = "";
        };
      };

      tray = {
        spacing = 10;
      };
    };
  };

  style = ''
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

    #workspaces button {
      padding: 0 5px;
      color: #cdd6f4;
      background: transparent;
    }

    #workspaces button.active {
      color: #89b4fa;
    }

    #workspaces button.urgent {
      color: #f38ba8;
    }

    #workspaces button:hover {
      background: rgba(205, 214, 244, 0.1);
    }

    #clock,
    #battery,
    #cpu,
    #memory,
    #temperature,
    #backlight,
    #network,
    #pulseaudio,
    #tray,
    #idle_inhibitor {
      padding: 0 10px;
      margin: 0 5px;
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
  '';
};
```

### 6. Rofi Configuration

#### Rofi-Wayland Setup

```nix
programs.rofi = {
  enable = true;
  package = pkgs.rofi-wayland;

  terminal = "${pkgs.alacritty}/bin/alacritty";

  theme = "Arc-Dark";

  extraConfig = {
    modi = "drun,run,window";
    show-icons = true;
    icon-theme = "Papirus";
    display-drun = " Apps";
    display-run = " Run";
    display-window = " Windows";
    drun-display-format = "{name}";
    window-format = "{w} · {c} · {t}";
    font = "JetBrainsMono Nerd Font 10";
  };
};

# Custom rofi theme
xdg.configFile."rofi/themes/custom.rasi".text = ''
  * {
    bg: #1e1e2e;
    bg-alt: #313244;
    fg: #cdd6f4;
    fg-alt: #6c7086;

    background-color: @bg;
    border: 0;
    margin: 0;
    padding: 0;
    spacing: 0;
  }

  window {
    width: 30%;
    border: 2px;
    border-color: #89b4fa;
    border-radius: 10px;
  }

  element {
    padding: 8 12;
    text-color: @fg-alt;
  }

  element selected {
    text-color: @fg;
    background-color: @bg-alt;
  }

  element-text {
    background-color: inherit;
    text-color: inherit;
  }

  element-icon {
    size: 1.2em;
  }

  entry {
    padding: 12;
    text-color: @fg;
  }

  inputbar {
    children: [prompt, entry];
    background-color: @bg-alt;
  }

  listview {
    columns: 1;
    lines: 8;
  }

  mainbox {
    children: [inputbar, listview];
  }

  prompt {
    enabled: true;
    padding: 12 0 0 12;
    text-color: @fg;
  }
'';
```

### 7. Additional Components

#### Hyprpaper (Wallpaper)

```nix
services.hyprpaper = {
  enable = true;

  settings = {
    ipc = "on";
    splash = false;

    preload = [
      "~/Pictures/Wallpapers/mountain.jpg"
      "~/Pictures/Wallpapers/city.png"
    ];

    wallpaper = [
      "DP-1,~/Pictures/Wallpapers/mountain.jpg"
      "HDMI-A-1,~/Pictures/Wallpapers/city.png"
      ",~/Pictures/Wallpapers/mountain.jpg"  # Fallback
    ];
  };
};
```

#### Hypridle (Idle Management)

```nix
services.hypridle = {
  enable = true;

  settings = {
    general = {
      lock_cmd = "pidof hyprlock || hyprlock";
      before_sleep_cmd = "loginctl lock-session";
      after_sleep_cmd = "hyprctl dispatch dpms on";
    };

    listener = [
      {
        timeout = 150;  # 2.5 minutes
        on-timeout = "brightnessctl -s set 10";
        on-resume = "brightnessctl -r";
      }
      {
        timeout = 300;  # 5 minutes
        on-timeout = "loginctl lock-session";
      }
      {
        timeout = 330;  # 5.5 minutes
        on-timeout = "hyprctl dispatch dpms off";
        on-resume = "hyprctl dispatch dpms on";
      }
      {
        timeout = 1800;  # 30 minutes
        on-timeout = "systemctl suspend";
      }
    ];
  };
};
```

#### Hyprlock (Screen Lock)

```nix
programs.hyprlock = {
  enable = true;

  settings = {
    general = {
      disable_loading_bar = true;
      grace = 0;
      hide_cursor = true;
      no_fade_in = false;
    };

    background = [
      {
        path = "screenshot";
        blur_passes = 3;
        blur_size = 8;
      }
    ];

    input-field = [
      {
        size = "200, 50";
        position = "0, -80";
        monitor = "";
        dots_center = true;
        fade_on_empty = false;
        font_color = "rgb(202, 211, 245)";
        inner_color = "rgb(91, 96, 120)";
        outer_color = "rgb(24, 25, 38)";
        outline_thickness = 5;
        placeholder_text = ''<span foreground="##cad3f5">Password...</span>'';
        shadow_passes = 2;
      }
    ];
  };
};
```

#### Dunst (Notifications)

```nix
services.dunst = {
  enable = true;

  settings = {
    global = {
      width = 300;
      height = 300;
      offset = "30x50";
      origin = "top-right";
      transparency = 10;
      frame_color = "#89b4fa";
      font = "JetBrainsMono Nerd Font 10";
      format = "<b>%s</b>\n%b";
      alignment = "left";
      word_wrap = true;
      show_age_threshold = 60;
      idle_threshold = 120;
      icon_position = "left";
      max_icon_size = 48;
      corner_radius = 10;
    };

    urgency_low = {
      background = "#1e1e2e";
      foreground = "#cdd6f4";
      timeout = 5;
    };

    urgency_normal = {
      background = "#1e1e2e";
      foreground = "#cdd6f4";
      timeout = 10;
    };

    urgency_critical = {
      background = "#1e1e2e";
      foreground = "#f38ba8";
      frame_color = "#f38ba8";
      timeout = 0;
    };
  };
};
```

### 8. Plugins (Hyprland-Plugins)

#### Plugin Installation (NixOS)

```nix
{ inputs, pkgs, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;

    # Plugins (requires Hyprland flake)
    plugins = [
      inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.borders-plus-plus
      inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprbars
      inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprexpo
      inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprtrails
      inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprwinwrap
    ];
  };
}
```

**Note**: hyprpm is **not supported** on NixOS. Use the home-manager module for plugins.

#### Available Plugins

- **borders-plus-plus**: Enhanced border customization
- **hyprbars**: Window title bars for floating windows
- **hyprexpo**: Workspace overview (Exposé-like)
- **hyprtrails**: Mouse trail effects
- **hyprwinwrap**: Xwinwrap equivalent for Hyprland

#### Plugin Configuration Example (hyprbars)

```nix
wayland.windowManager.hyprland.settings = {
  "plugin:hyprbars" = {
    bar_height = 20;
    bar_color = "rgb(1e1e2e)";
    "col.text" = "rgb(cdd6f4)";
    bar_text_font = "JetBrainsMono Nerd Font";
    bar_text_size = 10;
    bar_button_padding = 5;
    bar_padding = 10;
    bar_precedence_over_border = true;
  };
};
```

### 9. Per-Device Configuration

#### Multi-Monitor Setup

```nix
{ lib, ... }:
let
  # Detect hostname
  hostname = lib.fileContents /etc/hostname;

  # Monitor configurations per host
  monitorConfigs = {
    desktop = [
      "DP-1,3840x2160@144,0x0,1"
      "HDMI-A-1,1920x1080@60,3840x0,1"
    ];

    laptop = [
      "eDP-1,1920x1080@60,0x0,1"
    ];
  };

  # Get current config
  currentMonitors = monitorConfigs.${hostname} or monitorConfigs.laptop;
in
{
  wayland.windowManager.hyprland.settings = {
    monitor = currentMonitors;

    # Laptop-specific: disable built-in when lid closed
    bindl = lib.optionals (hostname == "laptop") [
      ",switch:on:Lid Switch,exec,hyprctl keyword monitor 'eDP-1,disable'"
      ",switch:off:Lid Switch,exec,hyprctl keyword monitor 'eDP-1,1920x1080@60,0x0,1'"
    ];
  };
}
```

#### Performance Tuning (Per-Device)

```nix
wayland.windowManager.hyprland.settings = {
  # High-end system
  decoration.blur = lib.mkIf (hostname == "desktop") {
    enabled = true;
    size = 8;
    passes = 3;
  };

  # Low-end system
  decoration.blur = lib.mkIf (hostname == "laptop") {
    enabled = false;
  };

  animations.enabled = hostname != "low-end";
};
```

## Common Patterns and Solutions

### Pattern 1: Systemd User Services

#### Custom Service for Hyprland

```nix
systemd.user.services.hyprland-startup = {
  Unit = {
    Description = "Hyprland startup script";
    After = [ "graphical-session.target" ];
  };

  Service = {
    Type = "oneshot";
    ExecStart = toString (pkgs.writeShellScript "hyprland-startup" ''
      # Wait for Hyprland
      until hyprctl monitors > /dev/null 2>&1;
        sleep 1
      done

      # Your startup commands
      ${pkgs.networkmanagerapplet}/bin/nm-applet &
      ${pkgs.blueman}/bin/blueman-applet &
    '');
  };

  Install.WantedBy = [ "hyprland-session.target" ];
};
```

### Pattern 2: Display Hotplug (Kanshi)

```nix
services.kanshi = {
  enable = true;

  settings = [
    {
      profile.name = "undocked";
      profile.outputs = [
        {
          criteria = "eDP-1";
          scale = 1.0;
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
          scale = 1.0;
          position = "0,0";
        }
      ];
    }
  ];
};
```

### Pattern 3: Environment Variables (UWSM)

**With UWSM enabled**:

```bash
# In home.nix with programs.hyprland.withUWSM = true
xdg.configFile."uwsm/env".text = ''
  export QT_QPA_PLATFORM=wayland
  export SDL_VIDEODRIVER=wayland
  export MOZ_ENABLE_WAYLAND=1
'';
```

### Pattern 4: Clipboard Management

```nix
# Clipboard history with cliphist
systemd.user.services.cliphist = {
  Unit = {
    Description = "Clipboard history";
    After = [ "graphical-session.target" ];
  };

  Service = {
    ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
    Restart = "always";
  };

  Install.WantedBy = [ "hyprland-session.target" ];
};

# Rofi clipboard menu keybind
wayland.windowManager.hyprland.settings.bind = [
  "$mod, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy"
];
```

## Troubleshooting Guide

### Issue 1: Screen Sharing Not Working

**Problem**: Cannot share screen in applications

**Solution**:

```nix
# Ensure portals are configured
xdg.portal = {
  enable = true;
  config.common.default = "*";
  extraPortals = with pkgs; [
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
  ];
};

# Environment variables
home.sessionVariables = {
  XDG_CURRENT_DESKTOP = "Hyprland";
  XDG_SESSION_TYPE = "wayland";
};
```

### Issue 2: NVIDIA Graphics Issues

**Problem**: Flickering or crashes with NVIDIA

**Solution**:

```nix
# NixOS configuration
programs.hyprland = {
  enable = true;

  # NVIDIA-specific settings
  nvidiaPatches = true;
};

# Hyprland settings
wayland.windowManager.hyprland.settings = {
  env = [
    "LIBVA_DRIVER_NAME,nvidia"
    "XDG_SESSION_TYPE,wayland"
    "GBM_BACKEND,nvidia-drm"
    "__GLX_VENDOR_LIBRARY_NAME,nvidia"
    "WLR_NO_HARDWARE_CURSORS,1"
  ];

  cursor.no_hardware_cursors = true;
};

# Enable modesetting in NixOS
hardware.nvidia.modesetting.enable = true;
```

### Issue 3: Applications Not Using Wayland

**Problem**: Apps default to X11

**Solution**:

```nix
home.sessionVariables = {
  # Force Wayland for compatible apps
  MOZ_ENABLE_WAYLAND = "1";  # Firefox
  QT_QPA_PLATFORM = "wayland";
  SDL_VIDEODRIVER = "wayland";
  CLUTTER_BACKEND = "wayland";

  # Electron apps
  NIXOS_OZONE_WL = "1";
};
```

### Issue 4: High CPU Usage

**Problem**: Hyprland using too much CPU

**Solution**:

```nix
wayland.windowManager.hyprland.settings = {
  # Disable animations
  animations.enabled = false;

  # Reduce blur
  decoration.blur = {
    enabled = true;
    size = 3;
    passes = 1;
  };

  # Disable shadows
  decoration.drop_shadow = false;

  # Reduce VRR
  misc.vrr = 0;
};
```

### Issue 5: Monitor Not Detected

**Problem**: External monitor not recognized

**Solution**:

```bash
# Check connected monitors
hyprctl monitors

# Manually set monitor
hyprctl keyword monitor "HDMI-A-1,1920x1080@60,0x0,1"

# Reload configuration
hyprctl reload
```

**Permanent fix**:

```nix
wayland.windowManager.hyprland.settings = {
  monitor = [
    # Explicit configurations
    "DP-1,3840x2160@144,0x0,1"
    "HDMI-A-1,1920x1080@60,3840x0,1"
    # Fallback for any unknown monitor
    ",preferred,auto,1"
  ];
};
```

## Best Practices

### DO ✅

1. **Use both NixOS and Home Manager modules**

   ```nix
   # NixOS for system integration
   programs.hyprland.enable = true;

   # Home Manager for user config
   wayland.windowManager.hyprland.enable = true;
   ```

2. **Use declarative settings over extraConfig**

   ```nix
   # ✅ Preferred
   settings = {
     general.gaps_in = 5;
   };

   # ❌ Avoid when possible
   extraConfig = ''
     general {
       gaps_in = 5
     }
   '';
   ```

3. **Enable systemd integration**

   ```nix
   wayland.windowManager.hyprland.systemd.enable = true;
   ```

4. **Use UWSM for session management (2025+)**

   ```nix
   programs.hyprland.withUWSM = true;
   ```

5. **Set package to null for version sync**

   ```nix
   wayland.windowManager.hyprland = {
     package = null;  # Use NixOS module package
     portalPackage = null;
   };
   ```

6. **Organize configuration in modules**

   ```nix
   imports = [
     ./hyprland/settings.nix
     ./hyprland/binds.nix
     ./hyprland/rules.nix
   ];
   ```

7. **Use monitor fallback for portability**

   ```nix
   monitor = [
     "DP-1,preferred,auto,1"
     ",preferred,auto,1"  # Catch-all
   ];
   ```

8. **Enable XWayland for compatibility**

   ```nix
   xwayland.enable = true;
   ```

### DON'T ❌

1. **Don't mix package versions**

   ```nix
   # ❌ Bad - version mismatch
   programs.hyprland.package = pkgs.hyprland;
   wayland.windowManager.hyprland.package = inputs.hyprland.packages.x86_64-linux.hyprland;
   ```

2. **Don't use hyprpm on NixOS**

   ```bash
   # ❌ Not supported
   hyprpm add https://github.com/plugin/repo
   ```

3. **Don't hardcode monitor names everywhere**

   ```nix
   # ❌ Not portable
   workspace = [ "1, monitor:DP-1" ];

   # ✅ Better
   workspace = [ "1, default:true" ];
   ```

4. **Don't skip portal configuration**

   ```nix
   # ❌ Screen sharing won't work

   # ✅ Required
   xdg.portal.enable = true;
   ```

5. **Don't ignore NVIDIA requirements**

   ```nix
   # ❌ Will have issues on NVIDIA

   # ✅ Configure properly
   cursor.no_hardware_cursors = true;
   env = [ "WLR_NO_HARDWARE_CURSORS,1" ];
   ```

## Command Reference

### Hyprctl Commands

```bash
# Monitor management
hyprctl monitors                    # List monitors
hyprctl keyword monitor "name,res"  # Set monitor
hyprctl dispatch dpms off          # Turn off displays
hyprctl dispatch dpms on           # Turn on displays

# Workspace management
hyprctl workspaces                 # List workspaces
hyprctl dispatch workspace 1       # Switch workspace
hyprctl dispatch movetoworkspace 2 # Move window

# Window management
hyprctl clients                    # List windows
hyprctl activewindow              # Get active window
hyprctl dispatch killactive       # Close window
hyprctl dispatch togglefloating   # Toggle floating

# Configuration
hyprctl reload                    # Reload config
hyprctl keyword general:gaps_in 5 # Set option

# Information
hyprctl version                   # Hyprland version
hyprctl devices                   # Input devices
hyprctl binds                     # List keybinds
hyprctl animations               # List animations

# Plugin management (not for NixOS)
# hyprpm commands don't work on NixOS
```

### Debugging Commands

```bash
# View Hyprland logs
journalctl --user -u hyprland.service

# Debug mode
Hyprland --debug

# Check Wayland socket
echo $WAYLAND_DISPLAY

# Test input
wev  # Wayland event viewer

# Check portals
systemctl --user status xdg-desktop-portal-hyprland
```

## Resources and Documentation

### Official Documentation

- **[Hyprland Wiki](https://wiki.hypr.land/)** - Complete Hyprland documentation
- **[Hyprland on NixOS](https://wiki.hypr.land/Nix/Hyprland-on-NixOS/)** - NixOS integration guide
- **[Hyprland on Home Manager](https://wiki.hypr.land/Nix/Hyprland-on-Home-Manager/)** - Home Manager module docs
- **[Home Manager Options](https://github.com/nix-community/home-manager/blob/master/modules/services/window-managers/hyprland.nix)**
  - All available options

### Community Resources

- **[NixOS Discourse - Hyprland](https://discourse.nixos.org/tag/hyprland)** - Community discussions
- **[Minimal Hyprland + Waybar Setup](https://discourse.nixos.org/t/minimal-hyprland-waybar-setup/63304)** - Tutorial
- **[Example Configurations](https://github.com/Frost-Phoenix/nixos-config)** - Community configs

### Useful Utilities

- **[Hyprland Useful Utilities](https://wiki.hypr.land/Useful-Utilities/)** - Recommended tools
- **[Status Bars](https://wiki.hypr.land/Useful-Utilities/Status-Bars/)** - Waybar and alternatives

Ready to configure Hyprland! Let me know what you need help with. 🚀
