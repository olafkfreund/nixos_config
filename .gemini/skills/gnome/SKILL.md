---
name: gnome
version: 1.0
description: GNOME Skill
---

# GNOME Skill

## Overview

**GNOME** is a modern, full-featured desktop environment for NixOS. This skill provides comprehensive guidance for
configuring GNOME declaratively using NixOS and Home Manager, with deep integration of Stylix theming, extension
management, and best practices for a reproducible desktop experience.

### Key Capabilities

- **Declarative configuration**: Everything defined in Nix configuration files
- **Stylix integration**: Automatic theming across all GNOME applications
- **Extension management**: Reproducible extension installation and configuration
- **dconf settings**: Complete control over GNOME preferences
- **GDM customization**: Display manager and login screen theming
- **GTK theming**: Consistent look across GTK3/GTK4 applications
- **Troubleshooting**: Debug and fix common GNOME configuration issues

### Why This Matters

Traditional GNOME configuration is **imperative** (click settings, install extensions manually). NixOS enables
**declarative** GNOME configuration, making your desktop environment:

- ✅ Reproducible across machines
- ✅ Version controlled
- ✅ Easy to backup and restore
- ✅ Documented in code
- ✅ Consistent with system configuration philosophy

## Installation

### Basic GNOME Setup (NixOS 25.11+)

```nix
# configuration.nix
{ pkgs, ... }:
{
  # Enable GDM and GNOME
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Note: GNOME uses Wayland by default
  # Xwayland is included for compatibility
}
```

### Legacy Setup (Pre-25.11)

```nix
# For older NixOS versions
{
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };
}
```

### Minimal GNOME (No Bloat)

```nix
{
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Disable default applications
  services.gnome = {
    core-apps.enable = false;          # gnome-calculator, gnome-calendar, etc.
    core-developer-tools.enable = false; # gnome-builder, etc.
    games.enable = false;               # gnome-chess, etc.
  };

  # Exclude specific packages
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-connections
    epiphany  # GNOME Web
    geary     # Email client
  ];

  # Install only what you need
  environment.systemPackages = with pkgs; [
    gnome-tweaks
    dconf-editor
    gnome-extension-manager
  ];
}
```

## Home Manager Integration

### Basic Setup

```nix
# home.nix
{ config, pkgs, ... }:
{
  # Enable dconf for GNOME settings
  dconf.enable = true;

  # GTK configuration
  gtk = {
    enable = true;

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };
}
```

### Complete Home Manager Configuration

```nix
{ config, pkgs, lib, ... }:
{
  dconf = {
    enable = true;
    settings = {
      # Desktop interface
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        enable-hot-corners = false;
        clock-show-weekday = true;
        clock-show-seconds = true;
        show-battery-percentage = true;
      };

      # Window manager
      "org/gnome/desktop/wm/preferences" = {
        button-layout = "appmenu:minimize,maximize,close";
        num-workspaces = 4;
        workspace-names = [ "Main" "Work" "Media" "Misc" ];
      };

      # Keybindings
      "org/gnome/desktop/wm/keybindings" = {
        close = [ "<Super>q" ];
        toggle-fullscreen = [ "<Super>f" ];
        switch-to-workspace-left = [ "<Control><Alt>Left" ];
        switch-to-workspace-right = [ "<Control><Alt>Right" ];
      };

      # Mouse and touchpad
      "org/gnome/desktop/peripherals/mouse" = {
        accel-profile = "flat";
        speed = 0.0;
      };

      "org/gnome/desktop/peripherals/touchpad" = {
        tap-to-click = true;
        two-finger-scrolling-enabled = true;
        natural-scroll = false;
      };

      # Favorite apps
      "org/gnome/shell" = {
        favorite-apps = [
          "org.gnome.Nautilus.desktop"
          "firefox.desktop"
          "kitty.desktop"
          "code.desktop"
        ];
      };
    };
  };
}
```

## Stylix Integration

### Basic Stylix Configuration

```nix
# configuration.nix
{ pkgs, inputs, ... }:
{
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  stylix = {
    enable = true;

    # Base16 color scheme
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";

    # Wallpaper
    image = ./wallpapers/gruvbox.png;

    # Font configuration
    fonts = {
      monospace = {
        package = pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; };
        name = "JetBrainsMono Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.merriweather;
        name = "Merriweather";
      };
    };

    # Cursor theme
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };

    # Opacity
    opacity = {
      terminal = 0.9;
      applications = 1.0;
    };

    # Enable GNOME targets
    targets = {
      gnome.enable = true;
      gtk.enable = true;
    };
  };

  # Additional GNOME setup
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
}
```

### Advanced Stylix + GNOME

```nix
{ config, pkgs, lib, inputs, ... }:
{
  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-dark.yaml";
    image = ./wallpaper.png;

    # Polarity control
    polarity = "dark";

    # Font configuration
    fonts = {
      monospace = {
        package = pkgs.jetbrains-mono;
        name = "JetBrains Mono";
      };
      sansSerif = {
        package = pkgs.cantarell-fonts;
        name = "Cantarell";
      };
      sizes = {
        applications = 11;
        desktop = 10;
        popups = 10;
      };
    };

    # Targets
    targets = {
      gnome.enable = true;
      gtk.enable = true;
      console.enable = true;
    };
  };

  # Home Manager integration
  home-manager.users.myuser = { pkgs, config, ... }: {
    # Stylix automatically configures GTK
    # Additional GNOME-specific tweaks
    dconf.settings = {
      # Use Stylix colors in GNOME
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = lib.mkForce "Adwaita-dark";
        icon-theme = "Papirus-Dark";
      };

      # GNOME Shell theme (requires user-theme extension)
      "org/gnome/shell/extensions/user-theme" = {
        name = "Adwaita-dark";
      };
    };

    # Additional packages for theming
    home.packages = with pkgs; [
      papirus-icon-theme
      gnomeExtensions.user-themes
    ];
  };
}
```

### Stylix Color Access in GNOME

```nix
{ config, lib, ... }:
{
  # Access Stylix colors for custom GNOME configuration
  dconf.settings = {
    "org/gnome/desktop/background" = {
      # Use solid color from theme
      picture-uri = "";
      primary-color = config.lib.stylix.colors.base00;
    };

    "org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9" = {
      background-color = "rgb(${config.lib.stylix.colors.base00-rgb-r},${config.lib.stylix.colors.base00-rgb-g},${config.lib.stylix.colors.base00-rgb-b})";
      foreground-color = "rgb(${config.lib.stylix.colors.base05-rgb-r},${config.lib.stylix.colors.base05-rgb-g},${config.lib.stylix.colors.base05-rgb-b})";
    };
  };
}
```

## Extension Management

### Installing Extensions

```nix
# configuration.nix or home.nix
{ pkgs, ... }:
{
  home.packages = with pkgs.gnomeExtensions; [
    # Productivity
    dash-to-dock
    appindicator
    clipboard-indicator
    gsconnect

    # Visual
    blur-my-shell
    just-perfection
    user-themes

    # Window management
    tiling-assistant
    window-list

    # System
    vitals
    caffeine
  ];
}
```

### Enabling Extensions via dconf

```nix
{ pkgs, ... }:
{
  dconf.settings = {
    "org/gnome/shell" = {
      disable-user-extensions = false;

      enabled-extensions = with pkgs.gnomeExtensions; [
        blur-my-shell.extensionUuid
        dash-to-dock.extensionUuid
        appindicator.extensionUuid
        clipboard-indicator.extensionUuid
        just-perfection.extensionUuid
        user-themes.extensionUuid
        tiling-assistant.extensionUuid
        vitals.extensionUuid
      ];
    };
  };
}
```

### Configuring Extension Settings

```nix
{
  dconf.settings = {
    # Dash to Dock
    "org/gnome/shell/extensions/dash-to-dock" = {
      dock-position = "BOTTOM";
      dash-max-icon-size = 48;
      show-trash = false;
      show-mounts = false;
      intellihide-mode = "FOCUS_APPLICATION_WINDOWS";
      hot-keys = false;
    };

    # Blur My Shell
    "org/gnome/shell/extensions/blur-my-shell" = {
      brightness = 0.75;
      sigma = 30;
    };

    # Just Perfection
    "org/gnome/shell/extensions/just-perfection" = {
      panel = true;
      activities-button = false;
      app-menu = false;
      clock-menu-position = 1;  # Center
      workspace-switcher-should-show = true;
    };

    # Tiling Assistant
    "org/gnome/shell/extensions/tiling-assistant" = {
      enable-tiling-popup = false;
      window-gap = 8;
    };

    # Vitals
    "org/gnome/shell/extensions/vitals" = {
      hot-sensors = [
        "_processor_usage_"
        "_memory_usage_"
        "_temperature_processor_"
      ];
    };
  };
}
```

## Complete GNOME Configuration Examples

### Example 1: Developer Workstation

```nix
{ config, pkgs, lib, ... }:
{
  # System configuration
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Minimal GNOME
  services.gnome.core-apps.enable = false;
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    epiphany
    geary
  ];

  # System packages
  environment.systemPackages = with pkgs; [
    gnome-tweaks
    dconf-editor
    gnome-extension-manager
  ];

  # Home Manager
  home-manager.users.dev = { pkgs, ... }: {
    dconf = {
      enable = true;
      settings = {
        # Interface
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          enable-hot-corners = false;
          show-battery-percentage = true;
        };

        # Window management
        "org/gnome/desktop/wm/preferences" = {
          num-workspaces = 6;
          workspace-names = [ "Code" "Browser" "Terminal" "Docs" "Chat" "Music" ];
        };

        # Keybindings
        "org/gnome/settings-daemon/plugins/media-keys" = {
          custom-keybindings = [
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
          ];
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          binding = "<Super>Return";
          command = "kitty";
          name = "Launch Terminal";
        };

        # Extensions
        "org/gnome/shell" = {
          disable-user-extensions = false;
          enabled-extensions = with pkgs.gnomeExtensions; [
            dash-to-dock.extensionUuid
            vitals.extensionUuid
            clipboard-indicator.extensionUuid
          ];
          favorite-apps = [
            "code.desktop"
            "firefox.desktop"
            "kitty.desktop"
            "org.gnome.Nautilus.desktop"
          ];
        };
      };
    };

    home.packages = with pkgs.gnomeExtensions; [
      dash-to-dock
      vitals
      clipboard-indicator
    ];
  };
}
```

### Example 2: Media/Creative Workstation

```nix
{ config, pkgs, inputs, ... }:
{
  # Stylix theming
  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    image = ./creative-wallpaper.jpg;

    fonts = {
      monospace = {
        package = pkgs.fira-code;
        name = "Fira Code";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
    };

    targets = {
      gnome.enable = true;
      gtk.enable = true;
    };
  };

  # GNOME with full apps
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Home Manager
  home-manager.users.creative = { pkgs, ... }: {
    dconf.settings = {
      # Visual tweaks
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "Adwaita-dark";
        icon-theme = "Papirus-Dark";
      };

      # Workspaces for different tasks
      "org/gnome/desktop/wm/preferences" = {
        num-workspaces = 4;
        workspace-names = [ "Edit" "Preview" "Assets" "Reference" ];
      };

      # Extensions
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = with pkgs.gnomeExtensions; [
          blur-my-shell.extensionUuid
          just-perfection.extensionUuid
          user-themes.extensionUuid
        ];
      };

      # Blur My Shell for aesthetics
      "org/gnome/shell/extensions/blur-my-shell" = {
        brightness = 0.8;
        sigma = 40;
        blur-panel = true;
        blur-overview = true;
      };
    };

    home.packages = with pkgs; [
      papirus-icon-theme
      gnomeExtensions.blur-my-shell
      gnomeExtensions.just-perfection
      gnomeExtensions.user-themes
    ];
  };
}
```

### Example 3: Minimal Tiling Setup

```nix
{ config, pkgs, ... }:
{
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Minimal install
  services.gnome.core-apps.enable = false;

  home-manager.users.user = { pkgs, ... }: {
    dconf.settings = {
      # Minimal interface
      "org/gnome/desktop/interface" = {
        enable-hot-corners = false;
        show-battery-percentage = true;
      };

      # Remove top bar elements
      "org/gnome/shell/extensions/just-perfection" = {
        activities-button = false;
        app-menu = false;
        panel-in-overview = false;
      };

      # Tiling configuration
      "org/gnome/shell/extensions/tiling-assistant" = {
        enable-tiling-popup = false;
        window-gap = 4;
        single-screen-gap = 4;
        tiling-popup-all-workspace = true;
        enable-advanced-experimental-features = true;
      };

      # Extensions
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = with pkgs.gnomeExtensions; [
          tiling-assistant.extensionUuid
          just-perfection.extensionUuid
          appindicator.extensionUuid
        ];
      };
    };

    home.packages = with pkgs.gnomeExtensions; [
      tiling-assistant
      just-perfection
      appindicator
    ];
  };
}
```

## Golden Path: Best Practices

### 1. Use Home Manager for User Settings

```nix
# ✅ CORRECT: Home Manager manages user settings
home-manager.users.alice = {
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
};

# ❌ WRONG: System-level user settings
programs.dconf.profiles.user.databases = [
  {
    settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  }
];
```

**Why**: User settings belong in Home Manager, system settings in NixOS configuration.

### 2. Enable Extensions via dconf

```nix
# ✅ CORRECT: Declarative extension enablement
{
  dconf.settings."org/gnome/shell" = {
    disable-user-extensions = false;
    enabled-extensions = with pkgs.gnomeExtensions; [
      dash-to-dock.extensionUuid
    ];
  };

  home.packages = [ pkgs.gnomeExtensions.dash-to-dock ];
}

# ❌ WRONG: Just installing without enabling
{
  home.packages = [ pkgs.gnomeExtensions.dash-to-dock ];
  # Extension won't be active!
}
```

**Why**: Extensions must be explicitly enabled via dconf to function.

### 3. Use Stylix for Consistent Theming

```nix
# ✅ CORRECT: Let Stylix handle themes
{
  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
    targets.gnome.enable = true;
    targets.gtk.enable = true;
  };
}

# ❌ WRONG: Manual theme configuration everywhere
{
  gtk.theme.name = "Adwaita-dark";
  dconf.settings."org/gnome/desktop/interface".gtk-theme = "Adwaita-dark";
  # Inconsistent, hard to maintain
}
```

**Why**: Stylix provides centralized, consistent theming across all applications.

### 4. Discover Settings with dconf watch

```bash
# ✅ CORRECT: Discover the right dconf paths
$ dconf watch /
# Change setting in GNOME Settings
# Output shows: /org/gnome/desktop/interface/show-battery-percentage

# Then add to config:
dconf.settings."org/gnome/desktop/interface".show-battery-percentage = true;

# ❌ WRONG: Guessing paths
dconf.settings."org/gnome/battery".show-percentage = true;  # Doesn't exist!
```

**Why**: dconf paths are not always intuitive; discovery prevents errors.

### 5. Organize Settings Logically

```nix
# ✅ CORRECT: Grouped by function
{
  dconf.settings = {
    # Interface
    "org/gnome/desktop/interface" = { /* ... */ };

    # Window management
    "org/gnome/desktop/wm/preferences" = { /* ... */ };
    "org/gnome/desktop/wm/keybindings" = { /* ... */ };

    # Peripherals
    "org/gnome/desktop/peripherals/mouse" = { /* ... */ };
    "org/gnome/desktop/peripherals/touchpad" = { /* ... */ };

    # Extensions
    "org/gnome/shell" = { /* ... */ };
    "org/gnome/shell/extensions/dash-to-dock" = { /* ... */ };
  };
}
```

**Why**: Maintainability and readability improve with logical organization.

### 6. Pin Extension Versions

```nix
# ✅ CORRECT: Explicit version pinning
{
  home.packages = [
    (pkgs.gnomeExtensions.dash-to-dock.overrideAttrs (old: {
      version = "87";
    }))
  ];
}

# ⚠️ CAUTION: Latest version may break
{
  home.packages = [ pkgs.gnomeExtensions.dash-to-dock ];
  # May update unexpectedly
}
```

**Why**: GNOME Shell API changes can break extensions; pinning ensures stability.

### 7. Use lib.mkForce Sparingly

```nix
# ✅ CORRECT: Let Stylix manage, override only when necessary
{
  stylix.targets.gtk.enable = true;

  # Only override if you have a specific reason
  gtk.theme.name = lib.mkForce "Adwaita-dark";
}

# ❌ WRONG: Overriding everything defeats declarative benefits
{
  gtk.theme.name = lib.mkForce "CustomTheme";
  gtk.iconTheme.name = lib.mkForce "CustomIcons";
  # Harder to maintain, Stylix integration broken
}
```

**Why**: `mkForce` breaks Stylix integration and reduces reproducibility.

### 8. Test Configuration Incrementally

```bash
# ✅ CORRECT: Test before committing
$ home-manager switch
# Verify changes work
$ git commit

# ❌ WRONG: Large config changes without testing
# Add 50 settings, rebuild, everything breaks
```

**Why**: Incremental testing isolates issues and saves debugging time.

### 9. Document Custom Keybindings

```nix
# ✅ CORRECT: Documented keybindings
{
  dconf.settings = {
    # Custom keybindings
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Super>Return";
      command = "kitty";
      name = "Launch Terminal";
    };
    # Super+Return: Launch terminal
  };
}

# ❌ WRONG: Cryptic bindings
{
  dconf.settings."org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0".binding = "<Super>Return";
  # What does this do? No one knows!
}
```

**Why**: Documentation helps future you and collaborators.

### 10. Handle Multi-User Setups Properly

```nix
# ✅ CORRECT: Per-user configuration
{
  home-manager.users.alice = {
    dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };

  home-manager.users.bob = {
    dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-light";
  };
}

# ❌ WRONG: System-wide user settings
{
  programs.dconf.profiles.user.databases = [{
    settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  }];
  # Applies to all users!
}
```

**Why**: Different users have different preferences.

## Anti-Patterns: What to Avoid

### 1. ❌ Manual Extension Installation

```nix
# WRONG: Installing extensions manually
$ gnome-extensions install extension.zip

# CORRECT: Declarative installation
{
  home.packages = [ pkgs.gnomeExtensions.dash-to-dock ];
  dconf.settings."org/gnome/shell".enabled-extensions = [
    pkgs.gnomeExtensions.dash-to-dock.extensionUuid
  ];
}
```

**Why**: Manual installations are not reproducible and lost on rebuild.

### 2. ❌ Using gnome-tweaks for Settings

```nix
# WRONG: Configuring via gnome-tweaks
# Click, click, click...

# CORRECT: Declarative dconf settings
{
  dconf.settings."org/gnome/desktop/interface" = {
    clock-show-weekday = true;
    show-battery-percentage = true;
  };
}
```

**Why**: GUI changes are ephemeral; dconf settings are reproducible.

### 3. ❌ Ignoring Extension Dependencies

```nix
# WRONG: Missing dependencies
{
  dconf.settings."org/gnome/shell/extensions/user-theme".name = "MyTheme";
  # Extension not installed!
}

# CORRECT: Install extension first
{
  home.packages = [ pkgs.gnomeExtensions.user-themes ];
  dconf.settings."org/gnome/shell" = {
    enabled-extensions = [ pkgs.gnomeExtensions.user-themes.extensionUuid ];
  };
  dconf.settings."org/gnome/shell/extensions/user-theme".name = "Adwaita-dark";
}
```

**Why**: Extension settings are useless without the extension.

### 4. ❌ Hardcoding Paths

```nix
# WRONG: Hardcoded paths
{
  dconf.settings."org/gnome/desktop/background".picture-uri = "file:///home/user/wallpaper.png";
}

# CORRECT: Relative to config
{
  dconf.settings."org/gnome/desktop/background".picture-uri = "file://${./wallpaper.png}";
}

# BEST: Use Stylix
{
  stylix.image = ./wallpaper.png;
  stylix.targets.gnome.enable = true;
}
```

**Why**: Hardcoded paths break portability and reproducibility.

### 5. ❌ Mixed Imperative and Declarative

```nix
# WRONG: Some settings declarative, some manual
{
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  # Then manually changing theme via gnome-tweaks
}

# CORRECT: Everything declarative
{
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
      icon-theme = "Papirus-Dark";
    };
  };
}
```

**Why**: Mixed approaches lead to configuration drift.

### 6. ❌ Not Restarting GNOME Session

```bash
# WRONG: Expecting immediate changes
$ home-manager switch
# Settings don't apply!

# CORRECT: Log out and back in
$ home-manager switch
$ gnome-session-quit --logout
```

**Why**: Many GNOME settings require session restart to take effect.

### 7. ❌ Overusing environment.systemPackages

```nix
# WRONG: User applications in system packages
{
  environment.systemPackages = with pkgs; [
    firefox
    vscode
    spotify
  ];
}

# CORRECT: User packages in Home Manager
{
  home-manager.users.alice = {
    home.packages = with pkgs; [
      firefox
      vscode
      spotify
    ];
  };
}
```

**Why**: User applications belong in user profiles, not system-wide.

### 8. ❌ Ignoring GNOME Shell Version

```nix
# WRONG: Using extensions without checking compatibility
{
  home.packages = [ pkgs.gnomeExtensions.some-old-extension ];
  # May not work with current GNOME version!
}

# CORRECT: Check compatibility or pin GNOME version
{
  # Pin to GNOME 45
  services.xserver.desktopManager.gnome.enable = true;
  environment.systemPackages = with pkgs.gnome; [
    # Packages compatible with GNOME 45
  ];
}
```

**Why**: Extensions break between GNOME versions; version awareness prevents issues.

### 9. ❌ Forgetting to Disable User Extensions

```nix
# WRONG: Enabling extensions but leaving disable flag
{
  dconf.settings."org/gnome/shell".enabled-extensions = [ "..." ];
  # But disable-user-extensions defaults to true!
}

# CORRECT: Explicitly enable user extensions
{
  dconf.settings."org/gnome/shell" = {
    disable-user-extensions = false;
    enabled-extensions = [ "..." ];
  };
}
```

**Why**: Extensions won't load if user extensions are disabled.

### 10. ❌ Not Using dconf-editor for Discovery

```bash
# WRONG: Guessing setting paths
{
  dconf.settings."org/gnome/display/resolution" = "1920x1080";  # Doesn't exist
}

# CORRECT: Use dconf-editor or dconf watch
$ dconf watch /
# Make change in GUI
# See actual path: /org/gnome/desktop/interface/scaling-factor
```

**Why**: Wrong paths silently fail; discovery ensures correctness.

## Troubleshooting and Debugging

### Issue 1: Extensions Not Loading

**Symptoms**: Extensions installed but not visible in GNOME

**Diagnosis**:

```bash
# Check if extensions are installed
ls ~/.local/share/gnome-shell/extensions/

# Check enabled extensions
dconf read /org/gnome/shell/enabled-extensions

# Check if user extensions are disabled
dconf read /org/gnome/shell/disable-user-extensions
```

**Fix**:

```nix
{
  dconf.settings."org/gnome/shell" = {
    disable-user-extensions = false;  # Must be false!
    enabled-extensions = with pkgs.gnomeExtensions; [
      dash-to-dock.extensionUuid
    ];
  };
}
```

### Issue 2: Settings Not Persisting

**Symptoms**: dconf settings revert after session restart

**Diagnosis**:

```bash
# Check Home Manager service status
systemctl status home-manager-$USER

# Check for conflicts
dconf dump / | grep -A 5 "setting-key"
```

**Fix**:

```bash
# Restart Home Manager service
systemctl restart home-manager-$USER

# Or rebuild
home-manager switch
```

### Issue 3: Theme Not Applying

**Symptoms**: Stylix theme not visible in GNOME

**Diagnosis**:

```bash
# Check GTK theme
gsettings get org.gnome.desktop.interface gtk-theme

# Check if Stylix targets are enabled
nix eval .#nixosConfigurations.hostname.config.stylix.targets.gnome.enable
```

**Fix**:

```nix
{
  stylix = {
    enable = true;
    targets = {
      gnome.enable = true;  # Must be enabled
      gtk.enable = true;    # Must be enabled
    };
  };
}
```

### Issue 4: Cursor Theme Issues

**Symptoms**: Cursor doesn't match theme or appears as default X cursor

**Diagnosis**:

```bash
# Check cursor theme
gsettings get org.gnome.desktop.interface cursor-theme

# Check if cursor package is installed
nix-store -q --references /run/current-system | grep cursor
```

**Fix**:

```nix
{
  stylix.cursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  # Or manually via dconf
  dconf.settings."org/gnome/desktop/interface" = {
    cursor-theme = "Bibata-Modern-Classic";
    cursor-size = 24;
  };
}
```

**Alternative**: Reset dconf completely

```bash
dconf reset -f /
```

### Issue 5: GDM Not Showing Users

**Symptoms**: Login screen shows "Not listed?" instead of usernames

**Diagnosis**:

```bash
# Check if shell is registered
echo $SHELL

# Check NixOS shell configuration
cat /etc/shells
```

**Fix**:

```nix
{
  # Register user shell
  environment.shells = with pkgs; [ zsh bash ];

  users.users.alice = {
    shell = pkgs.zsh;
  };
}
```

### Issue 6: Extension Configuration Not Working

**Symptoms**: Extension settings don't change behavior

**Diagnosis**:

```bash
# Find extension's schema
dconf dump /org/gnome/shell/extensions/

# Check if extension is actually enabled
gnome-extensions list --enabled
```

**Fix**:

```nix
{
  # Ensure extension is enabled BEFORE configuring
  dconf.settings = {
    "org/gnome/shell".enabled-extensions = [
      pkgs.gnomeExtensions.dash-to-dock.extensionUuid
    ];

    # Then configure
    "org/gnome/shell/extensions/dash-to-dock" = {
      dock-position = "BOTTOM";
    };
  };
}
```

### Issue 7: Keybindings Not Working

**Symptoms**: Custom keybindings don't trigger

**Diagnosis**:

```bash
# Check keybinding configuration
dconf dump /org/gnome/settings-daemon/plugins/media-keys/

# Test if command works
kitty  # Or whatever command
```

**Fix**:

```nix
{
  dconf.settings = {
    # Must register custom keybinding path
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };

    # Then define the keybinding
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Super>Return";
      command = "kitty";
      name = "Launch Terminal";
    };
  };
}
```

### Issue 8: Fractional Scaling Blurry

**Symptoms**: UI elements blurry with fractional scaling

**Diagnosis**:

```bash
# Check current scaling
gsettings get org.gnome.desktop.interface scaling-factor
```

**Fix**:

```nix
{
  # Enable experimental features for better fractional scaling
  programs.dconf.profiles.user.databases = [{
    settings."org/gnome/mutter".experimental-features = [
      "scale-monitor-framebuffer"
    ];
  }];

  # Or use integer scaling
  dconf.settings."org/gnome/desktop/interface".text-scaling-factor = 1.25;
}
```

### Issue 9: GNOME Console Theme Not Matching

**Symptoms**: GNOME Console (kgx) doesn't use Stylix theme

**Diagnosis**:

```bash
# Check if Stylix GNOME Console target exists
nix search nixpkgs gnome-console
```

**Fix**:

```nix
{
  # Use different terminal
  home.packages = [ pkgs.kitty ];  # Stylix supports kitty better

  # Or configure GNOME Console manually
  dconf.settings."org/gnome/Console" = {
    theme = "auto";  # Follows system theme
  };
}
```

### Issue 10: Performance Issues

**Symptoms**: GNOME feels sluggish or laggy

**Diagnosis**:

```bash
# Check enabled extensions
gnome-extensions list --enabled

# Monitor resource usage
gnome-system-monitor

# Check for errors
journalctl -b | grep -i gnome
```

**Fix**:

```nix
{
  # Disable unnecessary extensions
  dconf.settings."org/gnome/shell".enabled-extensions = [
    # Only essential extensions
    pkgs.gnomeExtensions.appindicator.extensionUuid
  ];

  # Disable animations
  dconf.settings."org/gnome/desktop/interface".enable-animations = false;

  # Use lighter theme
  services.gnome.core-apps.enable = false;
}
```

## Discovery Tools

### dconf watch

Monitor dconf changes in real-time:

```bash
# Watch all changes
dconf watch /

# Make change in GNOME Settings
# Output shows the dconf path and value
```

### dconf-editor

Visual dconf browser:

```nix
{
  environment.systemPackages = [ pkgs.dconf-editor ];
}
```

Launch and explore `/org/gnome/` tree to find settings.

### gsettings

Query schemas and values:

```bash
# List all schemas
gsettings list-schemas

# List keys in a schema
gsettings list-keys org.gnome.desktop.interface

# Get current value
gsettings get org.gnome.desktop.interface color-scheme

# Get possible values
gsettings range org.gnome.desktop.interface color-scheme
```

### Extension UUID Discovery

```bash
# List installed extensions with UUIDs
gnome-extensions list

# Get UUID from package
nix eval --raw nixpkgs#gnomeExtensions.dash-to-dock.extensionUuid
```

## Complete Configuration Template

```nix
# configuration.nix
{ config, pkgs, inputs, ... }:
{
  # Import Stylix
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  # GNOME Desktop
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Minimal GNOME
  services.gnome.core-apps.enable = false;
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
  ];

  # System packages
  environment.systemPackages = with pkgs; [
    gnome-tweaks
    dconf-editor
    gnome-extension-manager
  ];

  # Stylix theming
  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
    image = ./wallpaper.png;

    fonts = {
      monospace = {
        package = pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; };
        name = "JetBrainsMono Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
    };

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };

    targets = {
      gnome.enable = true;
      gtk.enable = true;
    };
  };

  # Home Manager
  home-manager.users.myuser = { pkgs, config, lib, ... }: {
    # dconf settings
    dconf = {
      enable = true;
      settings = {
        # Interface
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          enable-hot-corners = false;
          clock-show-weekday = true;
          show-battery-percentage = true;
        };

        # Window manager
        "org/gnome/desktop/wm/preferences" = {
          button-layout = "appmenu:minimize,maximize,close";
          num-workspaces = 4;
        };

        # Peripherals
        "org/gnome/desktop/peripherals/touchpad" = {
          tap-to-click = true;
          two-finger-scrolling-enabled = true;
        };

        # Extensions
        "org/gnome/shell" = {
          disable-user-extensions = false;
          enabled-extensions = with pkgs.gnomeExtensions; [
            dash-to-dock.extensionUuid
            appindicator.extensionUuid
          ];
          favorite-apps = [
            "org.gnome.Nautilus.desktop"
            "firefox.desktop"
          ];
        };

        # Extension settings
        "org/gnome/shell/extensions/dash-to-dock" = {
          dock-position = "BOTTOM";
          dash-max-icon-size = 48;
        };
      };
    };

    # Packages
    home.packages = with pkgs; [
      # Extensions
      gnomeExtensions.dash-to-dock
      gnomeExtensions.appindicator

      # Icons
      papirus-icon-theme
    ];
  };
}
```

## Resources

### Official Documentation

- **NixOS GNOME Wiki**: <https://wiki.nixos.org/wiki/GNOME>
- **Stylix Documentation**: <https://nix-community.github.io/stylix/>
- **Home Manager Manual**: <https://nix-community.github.io/home-manager/>

### Community Resources

- **Declarative GNOME**: <https://hoverbear.org/blog/declarative-gnome-configuration-in-nixos/>
- **GNOME Extensions**: <https://extensions.gnome.org/>
- **NixOS Discourse**: <https://discourse.nixos.org/>

### Tools

- **dconf-editor**: Browse and edit dconf settings
- **gnome-tweaks**: Additional GNOME customization
- **gnome-extension-manager**: Manage extensions (use declaratively!)

## Summary

This GNOME skill provides:

- ✅ Complete installation and configuration guide
- ✅ Deep Stylix integration for consistent theming
- ✅ Extension management best practices
- ✅ Golden path for correct configuration
- ✅ Anti-patterns to avoid common mistakes
- ✅ Comprehensive troubleshooting guide
- ✅ Discovery tools and debugging techniques
- ✅ Real-world configuration examples

**Key Takeaways**:

1. Use Home Manager for user settings, NixOS for system settings
2. Stylix provides centralized, consistent theming
3. Extensions must be enabled via dconf
4. Use `dconf watch /` to discover settings
5. Organize configuration logically
6. Test incrementally
7. Avoid imperative configuration
8. Session restart often required for changes

Configure GNOME declaratively with NixOS for a reproducible, version-controlled desktop experience! 🚀
