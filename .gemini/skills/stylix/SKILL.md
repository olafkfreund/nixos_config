---
name: stylix
version: 1.0
description: Stylix Skill
---

# Stylix Skill

## Overview

**Stylix** is a comprehensive theming framework for NixOS-based systems that applies color schemes, wallpapers, and fonts across a wide range of applications. Unlike similar tools like base16.nix or nix-colors that only provide color definitions, Stylix follows an "it just works" philosophy by automatically implementing themes across supported programs.

### Key Features

- **System-wide theming**: Applies consistent themes to applications, desktop environments, and system components
- **Multi-platform support**: Works with NixOS, Home Manager, nix-darwin, and Nix-on-Droid
- **Automatic color generation**: Extracts color schemes from wallpapers using genetic algorithms
- **Base16 integration**: Full support for Tinted Theming (base16) color schemes
- **Font management**: Centralized font configuration for serif, sans-serif, monospace, and emoji fonts
- **Wallpaper handling**: Local and remote wallpaper sources with automatic palette generation
- **Target control**: Granular control over which applications and components receive theming

### Supported Platforms

- **NixOS**: System-wide theming with full integration
- **Home Manager**: Per-user theming with NixOS integration
- **nix-darwin**: macOS system theming
- **Nix-on-Droid**: Android device theming

### Project Information

- **Repository**: <https://github.com/danth/stylix>
- **Documentation**: <https://nix-community.github.io/stylix/>
- **License**: MIT
- **Contributors**: 180+
- **Community**: GitHub Discussions, Matrix chat

## Installation

### NixOS Installation (Flakes)

Add Stylix to your flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    stylix.url = "github:danth/stylix";
    # Optional: Pin to a specific version
    # stylix.url = "github:danth/stylix/release-24.11";
  };

  outputs = { nixpkgs, stylix, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      modules = [
        stylix.nixosModules.stylix
        ./configuration.nix
      ];
    };
  };
}
```

### Home Manager Installation (Flakes)

#### Standalone Home Manager

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    stylix.url = "github:danth/stylix";
  };

  outputs = { nixpkgs, home-manager, stylix, ... }: {
    homeConfigurations.username = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      modules = [
        stylix.homeManagerModules.stylix
        ./home.nix
      ];
    };
  };
}
```

#### Home Manager as NixOS Module

When using Home Manager as a NixOS module, Stylix settings are automatically inherited:

```nix
{
  nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
    modules = [
      stylix.nixosModules.stylix
      home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        # Stylix automatically integrates
      }
      ./configuration.nix
    ];
  };
}
```

### nix-darwin Installation

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    darwin.url = "github:LnL7/nix-darwin";
    stylix.url = "github:danth/stylix";
  };

  outputs = { nixpkgs, darwin, stylix, ... }: {
    darwinConfigurations.hostname = darwin.lib.darwinSystem {
      modules = [
        stylix.darwinModules.stylix
        ./darwin-configuration.nix
      ];
    };
  };
}
```

### Nix-on-Droid Installation

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-on-droid.url = "github:t184256/nix-on-droid";
    stylix.url = "github:danth/stylix";
  };

  outputs = { nixpkgs, nix-on-droid, stylix, ... }: {
    nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
      modules = [
        stylix.nixOnDroidModules.stylix
        ./nix-on-droid.nix
      ];
    };
  };
}
```

## Basic Configuration

### Enable Stylix

Stylix requires explicit activation:

```nix
{
  stylix.enable = true;
}
```

### Minimal Configuration

The minimum viable configuration requires a wallpaper or color scheme:

```nix
{ pkgs, ... }:
{
  stylix.enable = true;
  stylix.image = ./wallpaper.png;
  # Stylix will auto-generate color scheme from wallpaper
}
```

Or with an explicit color scheme:

```nix
{ pkgs, ... }:
{
  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
}
```

## Color Scheme Configuration

### Using Pre-made Base16 Schemes

Stylix includes the Tinted Theming (base16) scheme collection via `pkgs.base16-schemes`:

```nix
{ pkgs, ... }:
{
  # Popular schemes
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
  # stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";
  # stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
  # stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
  # stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/solarized-dark.yaml";
  # stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-dark.yaml";
  # stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/onedark.yaml";
}
```

### Custom Color Schemes (Attribute Set)

Define your own base16 color scheme:

```nix
{
  stylix.base16Scheme = {
    base00 = "282828";  # Background
    base01 = "3c3836";  # Lighter background
    base02 = "504945";  # Selection background
    base03 = "665c54";  # Comments
    base04 = "bdae93";  # Dark foreground
    base05 = "d5c4a1";  # Default foreground
    base06 = "ebdbb2";  # Light foreground
    base07 = "fbf1c7";  # Light background
    base08 = "fb4934";  # Red
    base09 = "fe8019";  # Orange
    base0A = "fabd2f";  # Yellow
    base0B = "b8bb26";  # Green
    base0C = "8ec07c";  # Cyan
    base0D = "83a598";  # Blue
    base0E = "d3869b";  # Magenta
    base0F = "d65d0e";  # Brown
  };
}
```

### Custom Color Schemes (YAML String)

```nix
{
  stylix.base16Scheme = builtins.fromYAML ''
    scheme: "My Custom Theme"
    author: "Your Name"
    base00: "282828"
    base01: "3c3836"
    base02: "504945"
    base03: "665c54"
    base04: "bdae93"
    base05: "d5c4a1"
    base06: "ebdbb2"
    base07: "fbf1c7"
    base08: "fb4934"
    base09: "fe8019"
    base0A: "fabd2f"
    base0B: "b8bb26"
    base0C: "8ec07c"
    base0D: "83a598"
    base0E: "d3869b"
    base0F: "d65d0e"
  '';
}
```

### Custom Color Schemes (External File)

```nix
{
  stylix.base16Scheme = ./my-theme.yaml;
}
```

Where `my-theme.yaml` contains:

```yaml
scheme: "My Theme Name"
author: "Your Name"
base00: "282828"
base01: "3c3836"
# ... other colors
```

### Automatic Color Generation from Wallpaper

If you don't specify `stylix.base16Scheme`, Stylix automatically generates one from your wallpaper:

```nix
{
  stylix.enable = true;
  stylix.image = ./wallpaper.png;
  # No base16Scheme specified - auto-generated from image

  # Control whether palette is light or dark
  stylix.polarity = "dark";  # or "light" or "either"
}
```

View generated palette:

- **NixOS**: `/etc/stylix/palette.html`
- **Home Manager**: `~/.config/stylix/palette.html`

### Overriding Specific Colors

Modify portions of a color scheme without redefining everything:

```nix
{ pkgs, ... }:
{
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";

  stylix.override = {
    base00 = "1d2021";  # Override background to darker
    base08 = "cc241d";  # Override red
  };
}
```

### Accessing Color Values in Configuration

Reference configured colors in your own modules:

```nix
{ config, lib, ... }:
{
  # Access individual colors
  programs.kitty.extraConfig = ''
    background ${config.lib.stylix.colors.base00}
    foreground ${config.lib.stylix.colors.base05}
    cursor ${config.lib.stylix.colors.base0D}
  '';

  # Available formats:
  # config.lib.stylix.colors.base00       # Hex: "282828"
  # config.lib.stylix.colors.base00-hex   # With #: "#282828"
  # config.lib.stylix.colors.base00-rgb-r # Red channel (0-255)
  # config.lib.stylix.colors.base00-rgb-g # Green channel
  # config.lib.stylix.colors.base00-rgb-b # Blue channel
  # config.lib.stylix.colors.base00-dec-r # Red (0.0-1.0)
  # config.lib.stylix.colors.base00-dec-g # Green (0.0-1.0)
  # config.lib.stylix.colors.base00-dec-b # Blue (0.0-1.0)
}
```

Example using colors in custom scripts:

```nix
{ config, pkgs, ... }:
let
  colors = config.lib.stylix.colors;
in {
  home.packages = [
    (pkgs.writeShellScriptBin "show-theme" ''
      echo "Background: ${colors.base00}"
      echo "Foreground: ${colors.base05}"
      echo "Red: ${colors.base08}"
      echo "Green: ${colors.base0B}"
      echo "Blue: ${colors.base0D}"
    '')
  ];
}
```

## Wallpaper Configuration

### Local Wallpaper

```nix
{
  stylix.image = ./wallpapers/gruvbox-dark.png;
  # Or absolute path
  # stylix.image = /home/user/Pictures/wallpaper.jpg;
}
```

### Remote Wallpaper

```nix
{ pkgs, ... }:
{
  stylix.image = pkgs.fetchurl {
    url = "https://example.com/wallpaper.png";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
}
```

### Generated Wallpaper from Theme

Create solid color wallpaper from theme:

```nix
{ config, ... }:
{
  stylix.image = config.lib.stylix.pixel "base00";
  # Creates a 1x1 pixel wallpaper in base00 color
  # Useful for solid color backgrounds
}
```

### Dynamic Wallpaper with ImageMagick

Adjust brightness/contrast programmatically:

```nix
{ pkgs, ... }:
let
  dimmedWallpaper = pkgs.runCommand "dimmed-wallpaper" {
    buildInputs = [ pkgs.imagemagick ];
  } ''
    convert ${./original-wallpaper.png} \
      -brightness-contrast -20x0 \
      $out
  '';
in {
  stylix.image = dimmedWallpaper;
}
```

Generate wallpaper from theme color:

```nix
{ config, pkgs, lib, ... }:
let
  themeColor = config.lib.stylix.colors.base0A;
  generatedWallpaper = pkgs.runCommand "theme-wallpaper" {
    buildInputs = [ pkgs.imagemagick ];
  } ''
    convert -size 1920x1080 xc:#${themeColor} $out
  '';
in {
  stylix.image = generatedWallpaper;
}
```

## Font Configuration

### Default Fonts

Stylix uses these defaults:

- **Serif**: DejaVu Serif
- **Sans-Serif**: DejaVu Sans
- **Monospace**: DejaVu Sans Mono
- **Emoji**: Noto Color Emoji

### Custom Font Configuration

Override individual font families:

```nix
{ pkgs, ... }:
{
  stylix.fonts = {
    serif = {
      package = pkgs.dejavu_fonts;
      name = "DejaVu Serif";
    };

    sansSerif = {
      package = pkgs.dejavu_fonts;
      name = "DejaVu Sans";
    };

    monospace = {
      package = pkgs.jetbrains-mono;
      name = "JetBrains Mono";
    };

    emoji = {
      package = pkgs.noto-fonts-emoji;
      name = "Noto Color Emoji";
    };
  };
}
```

### Popular Font Combinations

**Modern Developer Setup**:

```nix
{ pkgs, ... }:
{
  stylix.fonts = {
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
}
```

**Classic Setup**:

```nix
{ pkgs, ... }:
{
  stylix.fonts = {
    monospace = {
      package = pkgs.fira-code;
      name = "Fira Code";
    };
    sansSerif = {
      package = pkgs.roboto;
      name = "Roboto";
    };
    serif = {
      package = pkgs.roboto-slab;
      name = "Roboto Slab";
    };
  };
}
```

**Minimalist Setup**:

```nix
{ pkgs, ... }:
{
  stylix.fonts = {
    monospace = {
      package = pkgs.source-code-pro;
      name = "Source Code Pro";
    };
    sansSerif = {
      package = pkgs.source-sans;
      name = "Source Sans 3";
    };
    serif = {
      package = pkgs.source-serif;
      name = "Source Serif 4";
    };
  };
}
```

### Font Sizes

Configure base font sizes:

```nix
{
  stylix.fonts.sizes = {
    applications = 12;
    terminal = 11;
    desktop = 10;
    popups = 12;
  };
}
```

## Target Management

### What are Targets?

Targets are individual applications or system components that Stylix can theme. Each target can be enabled or disabled independently.

### Auto-Enable Behavior

By default, Stylix enables all available targets. Control this globally:

```nix
{
  stylix.enable = true;
  stylix.autoEnable = false;  # Disable all targets by default

  # Then enable specific targets
  stylix.targets.kitty.enable = true;
  stylix.targets.gtk.enable = true;
  stylix.targets.gnome.enable = true;
}
```

### Disabling Specific Targets

Disable individual targets while keeping others enabled:

```nix
{
  stylix.enable = true;
  # autoEnable is true by default

  # Disable specific targets
  stylix.targets.firefox.enable = false;
  stylix.targets.plymouth.enable = false;
}
```

### Common Targets (NixOS)

```nix
{
  stylix.targets = {
    # Desktop Environments
    gnome.enable = true;
    kde.enable = true;

    # Display Managers
    grub.enable = true;
    plymouth.enable = true;

    # GTK Applications
    gtk.enable = true;

    # Specific Applications
    console.enable = true;
    nixvim.enable = true;
  };
}
```

### Common Targets (Home Manager)

```nix
{
  stylix.targets = {
    # Terminal Emulators
    alacritty.enable = true;
    kitty.enable = true;
    foot.enable = true;
    wezterm.enable = true;

    # Shells
    fish.enable = true;
    zsh.enable = true;

    # Editors
    vim.enable = true;
    neovim.enable = true;
    emacs.enable = true;
    vscode.enable = true;

    # Window Managers
    hyprland.enable = true;
    i3.enable = true;
    sway.enable = true;

    # Notification Daemons
    dunst.enable = true;
    mako.enable = true;

    # Bars
    waybar.enable = true;
    polybar.enable = true;

    # Browsers
    firefox.enable = true;
    qutebrowser.enable = true;

    # Applications
    rofi.enable = true;
    fzf.enable = true;
    bat.enable = true;
    btop.enable = true;
  };
}
```

### Disabling Conflicting Modules

If a Stylix module conflicts with your configuration:

```nix
{ inputs, ... }:
{
  disabledModules = [
    "${inputs.stylix}/modules/kitty/nixos.nix"
  ];

  # Now configure kitty manually
  programs.kitty = {
    # Your custom configuration
  };
}
```

## Home Manager Integration

### Automatic Inheritance (NixOS + Home Manager)

When using Home Manager as a NixOS module, settings are automatically inherited:

```nix
# In your NixOS configuration
{ pkgs, ... }:
{
  # System-wide Stylix settings
  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
  stylix.image = ./wallpaper.png;

  home-manager.users.alice = { ... };
  # Alice automatically inherits stylix settings
}
```

### Per-User Override

Override Stylix settings per user:

```nix
# NixOS configuration
{ pkgs, ... }:
{
  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";

  home-manager.users.alice = { pkgs, ... }: {
    # Alice uses a different theme
    stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";
  };

  home-manager.users.bob = { ... };
  # Bob uses the system default (gruvbox)
}
```

### Disable Automatic Import

Prevent Home Manager from automatically importing Stylix:

```nix
{
  stylix.homeManagerIntegration.autoImport = false;
}
```

### Control System Following

```nix
# In Home Manager configuration
{
  stylix.homeManagerIntegration.followSystem = false;
  # This user's Stylix settings are independent of system
}
```

## Advanced Configuration

### Opacity Settings

Configure transparency for various UI elements:

```nix
{
  stylix.opacity = {
    terminal = 0.9;
    desktop = 0.95;
    popups = 0.85;
    applications = 1.0;
  };
}
```

### Cursor Theme

```nix
{ pkgs, ... }:
{
  stylix.cursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };
}
```

### Theme Polarity

Control whether generated themes should be light or dark:

```nix
{
  stylix.polarity = "dark";   # Force dark themes
  # stylix.polarity = "light"; # Force light themes
  # stylix.polarity = "either"; # Auto-detect from wallpaper
}
```

## Desktop Environment Examples

### GNOME Configuration

```nix
{ pkgs, ... }:
{
  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
  stylix.image = ./wallpaper.png;

  # GNOME-specific
  stylix.targets.gnome.enable = true;
  stylix.targets.gtk.enable = true;

  # Font configuration for GNOME
  stylix.fonts = {
    sansSerif = {
      package = pkgs.cantarell-fonts;
      name = "Cantarell";
    };
    monospace = {
      package = pkgs.jetbrains-mono;
      name = "JetBrains Mono";
    };
  };
}
```

Test GNOME theme:

```bash
nix run github:nix-community/stylix#testbed:gnome:dark
```

### KDE Plasma Configuration

```nix
{ pkgs, ... }:
{
  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/breeze-dark.yaml";
  stylix.image = ./wallpaper.png;

  stylix.targets.kde.enable = true;

  # Note: KDE support is still in development
  # Some manual theme application may be required
}
```

### Hyprland Configuration

```nix
{ pkgs, config, ... }:
{
  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
  stylix.image = ./wallpaper.png;

  # Home Manager
  home-manager.users.user = {
    stylix.targets.hyprland.enable = true;
    stylix.targets.waybar.enable = true;
    stylix.targets.kitty.enable = true;
    stylix.targets.rofi.enable = true;

    # Stylix colors available in Hyprland config
    wayland.windowManager.hyprland.settings = {
      general = {
        "col.active_border" = "rgb(${config.lib.stylix.colors.base0D})";
        "col.inactive_border" = "rgb(${config.lib.stylix.colors.base03})";
      };
    };
  };
}
```

### i3 Configuration

```nix
{ pkgs, config, ... }:
{
  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";

  home-manager.users.user = {
    stylix.targets.i3.enable = true;
    stylix.targets.polybar.enable = true;

    xsession.windowManager.i3.config = {
      # Colors automatically applied by Stylix
      # Can reference theme colors if needed
      bars = [{
        statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs";
      }];
    };
  };
}
```

## Application-Specific Examples

### Terminal Emulators

**Alacritty**:

```nix
{
  stylix.targets.alacritty.enable = true;

  # Stylix automatically configures:
  # - Color scheme
  # - Font family and size
  # - Opacity
}
```

**Kitty**:

```nix
{
  stylix.targets.kitty.enable = true;

  # Additional customization
  programs.kitty.extraConfig = ''
    # Stylix handles colors and fonts
    # Add custom settings here
    cursor_blink_interval 0
  '';
}
```

**WezTerm**:

```nix
{
  stylix.targets.wezterm.enable = true;
}
```

### Text Editors

**Neovim**:

```nix
{
  stylix.targets.neovim.enable = true;

  # Stylix sets colorscheme automatically
  programs.neovim = {
    enable = true;
    # Your plugins and config
  };
}
```

**VSCode**:

```nix
{
  stylix.targets.vscode.enable = true;

  programs.vscode = {
    enable = true;
    # Stylix provides theme extension
  };
}
```

**Emacs**:

```nix
{
  stylix.targets.emacs.enable = true;
}
```

### Browsers

**Firefox**:

```nix
{
  stylix.targets.firefox.enable = true;

  # Stylix creates custom theme
  programs.firefox = {
    enable = true;
    # Additional configuration
  };
}
```

**Qutebrowser**:

```nix
{
  stylix.targets.qutebrowser.enable = true;
}
```

### Shell and CLI Tools

**Fish**:

```nix
{
  stylix.targets.fish.enable = true;
}
```

**Zsh**:

```nix
{
  stylix.targets.zsh.enable = true;
}
```

**Fzf**:

```nix
{
  stylix.targets.fzf.enable = true;

  # Colors automatically configured
  programs.fzf.enable = true;
}
```

**Bat**:

```nix
{
  stylix.targets.bat.enable = true;
}
```

**Btop**:

```nix
{
  stylix.targets.btop.enable = true;
}
```

### Application Launchers

**Rofi**:

```nix
{
  stylix.targets.rofi.enable = true;

  programs.rofi = {
    enable = true;
    # Stylix provides theme
  };
}
```

### Notification Daemons

**Dunst**:

```nix
{
  stylix.targets.dunst.enable = true;
}
```

**Mako**:

```nix
{
  stylix.targets.mako.enable = true;
}
```

## Complete Configuration Examples

### Minimal GNOME Desktop

```nix
{ pkgs, ... }:
{
  # NixOS Configuration
  stylix.enable = true;
  stylix.image = ./wallpaper.png;
  # Auto-generates color scheme from wallpaper

  # Desktop environment
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Stylix applies to GNOME automatically
}
```

### Advanced Hyprland Setup

```nix
{ pkgs, inputs, ... }:
{
  # Flake inputs
  inputs = {
    stylix.url = "github:danth/stylix";
  };

  # NixOS Configuration
  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-dark.yaml";
  stylix.image = pkgs.fetchurl {
    url = "https://example.com/wallpaper.png";
    sha256 = "...";
  };

  stylix.fonts = {
    monospace = {
      package = pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; };
      name = "JetBrainsMono Nerd Font Mono";
    };
    sansSerif = {
      package = pkgs.inter;
      name = "Inter";
    };
  };

  stylix.cursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  stylix.opacity = {
    terminal = 0.9;
    popups = 0.85;
  };

  # Home Manager
  home-manager.users.user = { pkgs, config, ... }: {
    # Wayland compositor
    wayland.windowManager.hyprland.enable = true;

    # Styled applications
    stylix.targets = {
      hyprland.enable = true;
      waybar.enable = true;
      kitty.enable = true;
      rofi.enable = true;
      dunst.enable = true;
      neovim.enable = true;
      firefox.enable = true;
      fzf.enable = true;
      bat.enable = true;
    };

    programs.kitty.enable = true;
    programs.rofi.enable = true;
    programs.waybar.enable = true;
    services.dunst.enable = true;
  };
}
```

### Multi-User System

```nix
{ pkgs, ... }:
{
  # System default theme
  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
  stylix.image = ./default-wallpaper.png;

  # Alice: Uses system default
  home-manager.users.alice = {
    # Inherits system theme
  };

  # Bob: Custom theme
  home-manager.users.bob = { pkgs, ... }: {
    stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";
    stylix.image = ./bob-wallpaper.png;
  };

  # Charlie: Fully custom
  home-manager.users.charlie = { pkgs, ... }: {
    stylix.base16Scheme = {
      base00 = "1e1e2e";
      base01 = "181825";
      # ... custom colors
    };
    stylix.image = ./charlie-wallpaper.jpg;

    stylix.fonts.monospace = {
      package = pkgs.victor-mono;
      name = "Victor Mono";
    };
  };
}
```

### Development Environment

```nix
{ pkgs, config, ... }:
{
  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/one-dark.yaml";

  home-manager.users.dev = { pkgs, ... }: {
    # Developer tools with consistent theming
    stylix.targets = {
      neovim.enable = true;
      vscode.enable = true;
      alacritty.enable = true;
      tmux.enable = true;
      git.enable = true;
      fzf.enable = true;
      bat.enable = true;
      btop.enable = true;
    };

    programs = {
      neovim.enable = true;
      vscode.enable = true;
      alacritty.enable = true;
      tmux.enable = true;
      git.enable = true;
      fzf.enable = true;
      bat.enable = true;
      btop.enable = true;
    };

    # Custom development shell with themed prompt
    programs.fish = {
      enable = true;
      # Stylix handles theming
    };
  };
}
```

## Tips and Tricks

### Override CSS in GTK Applications

Use `lib.mkAfter` to ensure your CSS takes priority:

```nix
{ lib, ... }:
{
  programs.waybar.style = lib.mkAfter ''
    #workspaces button {
      background: @base01;
      border-radius: 8px;
    }

    #workspaces button.active {
      background: @base0D;
    }
  '';
}
```

### Create Dynamic Wallpapers

Generate wallpapers based on theme colors:

```nix
{ config, pkgs, ... }:
let
  colors = config.lib.stylix.colors;

  gradientWallpaper = pkgs.runCommand "gradient-wallpaper" {
    buildInputs = [ pkgs.imagemagick ];
  } ''
    convert -size 1920x1080 \
      gradient:#${colors.base00}-#${colors.base01} \
      $out
  '';
in {
  stylix.image = gradientWallpaper;
}
```

### Extract Colors from Existing Wallpaper

Let Stylix analyze your favorite wallpaper:

```nix
{
  stylix.enable = true;
  stylix.image = ./favorite-wallpaper.jpg;
  stylix.polarity = "dark";

  # View generated palette at /etc/stylix/palette.html
}
```

Then if you like the result, you can export it as a permanent scheme.

### Use Different Themes for Different Contexts

```nix
{ pkgs, ... }:
let
  workTheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
  playTheme = "${pkgs.base16-schemes}/share/themes/synthwave-84.yaml";
in {
  # Default to work theme
  stylix.base16Scheme = workTheme;

  # Script to switch themes
  home.packages = [
    (pkgs.writeShellScriptBin "theme-work" ''
      # Implementation to switch to work theme
    '')
    (pkgs.writeShellScriptBin "theme-play" ''
      # Implementation to switch to play theme
    '')
  ];
}
```

### Per-Application Opacity Override

```nix
{
  stylix.opacity.terminal = 0.9;

  # Override for specific terminal
  programs.kitty.settings.background_opacity = "0.95";
}
```

### Disable Stylix for Specific Files

```nix
{
  stylix.targets.vim.enable = true;

  programs.vim.extraConfig = ''
    " Disable Stylix colorscheme temporarily
    syntax off

    " Use your own colorscheme
    colorscheme custom
  '';
}
```

### Debug Theme Issues

View current theme configuration:

```bash
# NixOS
cat /etc/stylix/palette.html

# Home Manager
cat ~/.config/stylix/palette.html
```

Check which colors are being used:

```nix
{ config, lib, pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "show-stylix-colors" ''
      echo "Stylix Color Scheme:"
      echo "==================="
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList
        (name: value: "echo '${name}: ${value}'")
        config.lib.stylix.colors
      )}
    '')
  ];
}
```

### Combine Multiple Wallpapers

Create a wallpaper collage:

```nix
{ pkgs, ... }:
let
  collageWallpaper = pkgs.runCommand "collage" {
    buildInputs = [ pkgs.imagemagick ];
  } ''
    montage ${./wall1.png} ${./wall2.png} ${./wall3.png} ${./wall4.png} \
      -tile 2x2 -geometry 960x540+0+0 \
      $out
  '';
in {
  stylix.image = collageWallpaper;
}
```

## Troubleshooting

### Theme Not Applying

**Check if Stylix is enabled:**

```nix
{
  stylix.enable = true;  # Must be explicitly set
}
```

**Verify targets are enabled:**

```nix
{
  # Check autoEnable
  stylix.autoEnable = true;  # Default

  # Or enable specific targets
  stylix.targets.kitty.enable = true;
}
```

**Rebuild and switch:**

```bash
# NixOS
sudo nixos-rebuild switch

# Home Manager
home-manager switch
```

### Colors Look Wrong

**Check polarity:**

```nix
{
  stylix.polarity = "dark";  # or "light"
}
```

**View generated palette:**

```bash
# Check what colors were generated
firefox /etc/stylix/palette.html
```

**Use explicit color scheme:**

```nix
{ pkgs, ... }:
{
  # Instead of auto-generation
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
}
```

### Font Not Displaying

**Verify font package is correct:**

```nix
{ pkgs, ... }:
{
  stylix.fonts.monospace = {
    package = pkgs.jetbrains-mono;
    name = "JetBrains Mono";  # Exact name from `fc-list`
  };
}
```

**Check font name:**

```bash
fc-list | grep -i "jetbrains"
```

**Ensure font sizes are set:**

```nix
{
  stylix.fonts.sizes = {
    applications = 12;
    terminal = 11;
  };
}
```

### Target Conflicts

**Disable conflicting module:**

```nix
{ inputs, ... }:
{
  disabledModules = [
    "${inputs.stylix}/modules/alacritty/hm.nix"
  ];

  # Configure manually
  programs.alacritty = {
    # Manual configuration
  };
}
```

### Home Manager Integration Issues

**Verify integration is enabled:**

```nix
{
  stylix.homeManagerIntegration.autoImport = true;  # Default
}
```

**Check system following:**

```nix
# In Home Manager config
{
  stylix.homeManagerIntegration.followSystem = true;
}
```

**Explicit override if needed:**

```nix
# In Home Manager config
{ pkgs, ... }:
{
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";
  # Overrides system theme
}
```

### Wallpaper Not Showing

**Check file exists:**

```bash
ls -lh ./wallpaper.png
```

**Try absolute path:**

```nix
{
  stylix.image = /home/user/wallpapers/background.png;
}
```

**Verify image format:**

```bash
file wallpaper.png
# Should show: PNG image data
```

### KDE Plasma Issues

KDE support is still in development. Some manual steps may be required:

1. Apply theme through System Settings
2. Manually set wallpaper
3. Adjust color scheme in KDE settings

**Workaround:**

```nix
{
  stylix.targets.kde.enable = true;

  # May need to manually apply some settings
  # Check Stylix GitHub issues for latest KDE status
}
```

### Performance Issues

**Disable unused targets:**

```nix
{
  stylix.autoEnable = false;

  # Enable only what you need
  stylix.targets.kitty.enable = true;
  stylix.targets.neovim.enable = true;
}
```

**Optimize wallpaper:**

```nix
{ pkgs, ... }:
let
  optimizedWallpaper = pkgs.runCommand "wallpaper" {
    buildInputs = [ pkgs.imagemagick ];
  } ''
    convert ${./large-wallpaper.png} \
      -resize 1920x1080 \
      -quality 85 \
      $out
  '';
in {
  stylix.image = optimizedWallpaper;
}
```

## Best Practices

### 1. Use Explicit Color Schemes for Consistency

```nix
# ✅ Good: Explicit, reproducible
{ pkgs, ... }:
{
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
}

# ❌ Avoid: Auto-generated can change
{
  stylix.image = ./random-wallpaper.png;
  # Color scheme regenerates if wallpaper changes
}
```

### 2. Set Polarity Explicitly

```nix
# ✅ Good: Clear intent
{
  stylix.polarity = "dark";
}

# ❌ Avoid: Ambiguous
{
  # Defaults to "either" - may not match expectations
}
```

### 3. Use Version Pinning for Stability

```nix
{
  inputs = {
    stylix.url = "github:danth/stylix/release-24.11";
    # Pin to stable release
  };
}
```

### 4. Document Custom Color Schemes

```nix
{
  # Document the theme choice
  stylix.base16Scheme = {
    # Based on Gruvbox Dark with custom adjustments
    # - Darkened background for reduced eye strain
    # - Increased blue saturation for better link visibility
    base00 = "1d2021";  # Background (darker than default)
    base01 = "3c3836";
    # ...
  };
}
```

### 5. Test Theme Changes Incrementally

```bash
# Test locally before committing
home-manager switch

# Verify changes
firefox ~/.config/stylix/palette.html

# Commit only after verification
git add .
git commit -m "theme: switch to nord"
```

### 6. Use Targets Selectively

```nix
# ✅ Good: Explicit about what's themed
{
  stylix.autoEnable = false;
  stylix.targets = {
    alacritty.enable = true;
    neovim.enable = true;
    firefox.enable = true;
  };
}

# ❌ Avoid: Everything enabled may cause conflicts
{
  stylix.autoEnable = true;
  # All targets enabled, may conflict with manual configs
}
```

### 7. Share Themes Across Machines

```nix
# shared/theme.nix
{ pkgs, ... }:
{
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
  stylix.fonts = {
    monospace = {
      package = pkgs.jetbrains-mono;
      name = "JetBrains Mono";
    };
  };
}

# hosts/desktop/configuration.nix
{
  imports = [ ../../shared/theme.nix ];
  stylix.image = ./desktop-wallpaper.png;
}

# hosts/laptop/configuration.nix
{
  imports = [ ../../shared/theme.nix ];
  stylix.image = ./laptop-wallpaper.png;
}
```

### 8. Keep Wallpapers in Repository

```nix
# ✅ Good: Reproducible
{
  stylix.image = ./wallpapers/gruvbox.png;
}

# ❌ Avoid: External dependencies
{
  stylix.image = /home/user/Downloads/wallpaper.png;
  # Breaks on other machines
}
```

### 9. Use Override Sparingly

```nix
# ✅ Good: Minor tweaks
{ pkgs, ... }:
{
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
  stylix.override = {
    base00 = "1d2021";  # Slightly darker background
  };
}

# ❌ Avoid: Extensive overrides
{
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
  stylix.override = {
    # Changing 10+ colors defeats purpose of base scheme
    base00 = "...";
    base01 = "...";
    # ... many more
  };
  # Just define a custom scheme instead
}
```

### 10. Provide Fallbacks for Remote Resources

```nix
{ pkgs, ... }:
let
  remoteWallpaper = pkgs.fetchurl {
    url = "https://example.com/wallpaper.png";
    sha256 = "sha256-AAAA...";
  };

  localFallback = ./fallback-wallpaper.png;
in {
  stylix.image = remoteWallpaper;
  # Keep local fallback in repo for offline builds
}
```

## Resources

### Official Documentation

- **Website**: <https://nix-community.github.io/stylix/>
- **GitHub**: <https://github.com/danth/stylix>
- **Issues**: <https://github.com/danth/stylix/issues>

### Community

- **Discussions**: <https://github.com/danth/stylix/discussions>
- **Matrix**: #stylix:matrix.org

### Related Projects

- **Base16**: <https://github.com/tinted-theming/home>
- **Tinted Theming**: <https://github.com/tinted-theming>
- **base16-schemes**: Included in nixpkgs

### Useful Tools

- **Base16 Builder**: Create custom schemes
- **ImageMagick**: Wallpaper manipulation
- **wpgtk**: GUI for generating themes from wallpapers (non-Nix)

### Example Configurations

- <https://github.com/donovanglover/nix-config>
- <https://github.com/TheMaxMur/NixOS-Configuration>
- Search GitHub for "stylix nixos" for more examples

## Quick Reference

### Basic Setup

```nix
{ pkgs, ... }:
{
  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
  stylix.image = ./wallpaper.png;
}
```

### Essential Options

| Option                        | Type                    | Description             |
| ----------------------------- | ----------------------- | ----------------------- |
| `stylix.enable`               | boolean                 | Enable Stylix           |
| `stylix.base16Scheme`         | path/attrset/string     | Color scheme            |
| `stylix.image`                | path                    | Wallpaper image         |
| `stylix.polarity`             | "dark"/"light"/"either" | Theme polarity          |
| `stylix.autoEnable`           | boolean                 | Auto-enable all targets |
| `stylix.fonts.*`              | attrset                 | Font configuration      |
| `stylix.opacity.*`            | float                   | Opacity settings        |
| `stylix.cursor.*`             | attrset                 | Cursor theme            |
| `stylix.targets.<app>.enable` | boolean                 | Enable per-app          |

### Common Color Schemes

- `gruvbox-dark-medium.yaml`
- `nord.yaml`
- `dracula.yaml`
- `catppuccin-mocha.yaml`
- `tokyo-night-dark.yaml`
- `solarized-dark.yaml`
- `one-dark.yaml`

### Accessing Colors

```nix
config.lib.stylix.colors.base00       # "282828"
config.lib.stylix.colors.base00-hex   # "#282828"
config.lib.stylix.colors.base00-rgb-r # Red channel
config.lib.stylix.pixel "base00"      # 1x1 wallpaper
```

### Viewing Generated Theme

```bash
# NixOS
firefox /etc/stylix/palette.html

# Home Manager
firefox ~/.config/stylix/palette.html
```

### Testing Desktop Environments

```bash
# GNOME Dark
nix run github:nix-community/stylix#testbed:gnome:dark

# GNOME Light
nix run github:nix-community/stylix#testbed:gnome:light
```

## When to Use Stylix

### ✅ Use Stylix When

- You want consistent theming across all applications
- You use multiple NixOS machines and want the same theme everywhere
- You frequently switch between themes
- You want automatic wallpaper-based color generation
- You use many different applications that need coordinated colors
- You value declarative, reproducible theming

### ❌ Don't Use Stylix When

- You need per-application themes that differ significantly
- You have very specific, manual customizations for every app
- You're using applications that aren't supported by Stylix
- You prefer imperative theme management
- You need features that conflict with Stylix's approach

### Alternatives

- **base16.nix**: Color scheme definitions without automatic application
- **nix-colors**: Similar to base16.nix
- **Manual theming**: Configure each application individually
- **System theme managers**: GNOME Tweaks, lxappearance, qt5ct

Stylix excels at providing a unified, declarative theming experience across your entire NixOS system while maintaining the flexibility to customize per-application when needed.

## Summary

Stylix is a powerful theming framework that brings consistency and ease to NixOS system appearance management. By leveraging base16 color schemes, automatic wallpaper analysis, and comprehensive application support, it enables declarative, reproducible theming across your entire system.

Key advantages:

- **Declarative**: Theme configuration in Nix
- **Reproducible**: Same config = same theme everywhere
- **Comprehensive**: Supports 50+ applications and targets
- **Flexible**: Works at system and user levels
- **Automatic**: Smart defaults with manual override capability
- **Community-driven**: Active development and support

Start with a simple configuration and expand as needed. Stylix makes it easy to maintain a beautiful, consistent system appearance across all your NixOS machines.
