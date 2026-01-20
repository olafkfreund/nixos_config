---
name: cosmic-de
version: 1.0
description: COSMIC Desktop Environment Skill
---

# COSMIC Desktop Environment Skill

> **Expert guidance for System76's COSMIC Desktop on NixOS**
> Rust-based desktop environment with modern Wayland compositor

## Overview

COSMIC (Computer Operating System Main Interface Components) is System76's next-generation desktop environment written
entirely in Rust. Built using the iced cross-platform GUI library and Smithay compositor framework, COSMIC provides a
modern, performant, and customizable desktop experience on NixOS.

**Key Features**:

- **Rust-based**: Memory-safe, high-performance implementation
- **Wayland-native**: Modern compositor (cosmic-comp) built on Smithay
- **Tiling & Floating**: Flexible workspace management
- **RON Configuration**: Rusty Object Notation for settings
- **Modular Architecture**: Component-based design
- **Active Development**: Regular updates from System76

**NixOS Status**:

- Native support since NixOS 25.05 (Alpha 7)
- Beta support in NixOS 25.11+
- Flake available for cutting-edge versions
- Binary cache available for faster builds

## Installation

### Method 1: Native NixOS (25.05+)

**Basic Setup** (NixOS 25.05 and later):

```nix
# configuration.nix
{
  # Enable COSMIC Desktop
  services.desktopManager.cosmic.enable = true;

  # Enable COSMIC Greeter (login manager)
  services.displayManager.cosmic-greeter.enable = true;
}
```

**Minimal Installation** (exclude unwanted apps in NixOS 25.11+):

```nix
{
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  # Exclude specific COSMIC applications
  environment.cosmic.excludePackages = with pkgs; [
    cosmic-edit      # Text editor
    cosmic-term      # Terminal emulator
    cosmic-files     # File manager
    # Add other packages to exclude
  ];
}
```

### Method 2: Flake-Based (Cutting-Edge)

**For Latest Development Versions**:

Create `/etc/nixos/flake.nix`:

```nix
{
  description = "NixOS configuration with COSMIC Desktop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # COSMIC flake (follows specific nixpkgs)
    nixos-cosmic = {
      url = "github:lilyinstarlight/nixos-cosmic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-cosmic, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        # Enable binary cache FIRST
        {
          nix.settings = {
            substituters = [ "https://cosmic.cachix.org/" ];
            trusted-public-keys = [
              "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
            ];
          };
        }

        # Import COSMIC module
        nixos-cosmic.nixosModules.default

        # Your configuration
        ./configuration.nix
      ];
    };
  };
}
```

**Important**: Run `nixos-rebuild test` FIRST to set up binary substituters before adding COSMIC packages.

**Build Requirements**:

- RAM: ~16 GiB (reduce with `--cores 1`)
- Disk: ~40 GiB for local builds
- Binary cache available for nixos-unstable and nixos-24.11

### Method 3: Home Manager Integration

COSMIC can be managed via Home Manager for user-specific configurations:

```nix
# home.nix
{ config, pkgs, ... }:
{
  # Install COSMIC applications
  home.packages = with pkgs; [
    cosmic-edit
    cosmic-term
    cosmic-files
    cosmic-store
  ];

  # Manage COSMIC config files declaratively
  xdg.configFile = {
    # Panel configuration
    "cosmic/com.system76.CosmicPanel.Panel/v1/name".text = "Panel";

    # Applets configuration (example)
    "cosmic/com.system76.CosmicPanel.Panel/v1/plugins_center".text = ''
      (
        entries: [
          CosmicAppletTime,
          CosmicAppletNotifications,
        ],
      )
    '';

    # Compositor settings
    "cosmic/com.system76.CosmicComp/v1/xkb_config".text = ''
      (
        rules: "",
        model: "",
        layout: "us",
        variant: "",
        options: Some("caps:escape"),
      )
    '';
  };
}
```

## Configuration Structure

### Configuration File Hierarchy

COSMIC uses RON (Rusty Object Notation) files for configuration:

```text
~/.config/cosmic/
├── com.system76.CosmicPanel.Panel/
│   ├── v1/
│   │   ├── name              # Panel name
│   │   ├── plugins_wings     # Left/right applets
│   │   ├── plugins_center    # Center applets
│   │   └── output            # Display output
│   └── v2/                   # Future version
├── com.system76.CosmicComp/
│   └── v1/
│       ├── xkb_config        # Keyboard layout
│       ├── workspaces        # Workspace config
│       └── autotile          # Tiling settings
├── com.system76.CosmicSettings/
│   └── v1/
│       └── ...               # Desktop settings
└── com.system76.CosmicAppletTime/
    └── v1/
        └── ...               # Applet-specific settings
```

**Key Characteristics**:

- **System-wide**: `/run/current-system/sw/share/cosmic/` (NixOS defaults)
- **User-specific**: `~/.config/cosmic/` (overrides system defaults)
- **RON Format**: Rust Object Notation (similar to JSON)
- **Versioned**: Each component uses versioned directories (v1, v2, etc.)

### RON Configuration Examples

**Panel Applet Configuration**:

```ron
// ~/.config/cosmic/com.system76.CosmicPanel.Panel/v1/plugins_wings
(
  entries: [
    (
      applet: CosmicAppletWorkspaces,
      config: (
        workspace_mode: Fixed(4),
      ),
    ),
    CosmicAppletLauncher,
    CosmicAppletAudio,
    CosmicAppletNetwork,
    CosmicAppletBattery,
    CosmicAppletTime,
    CosmicAppletNotifications,
  ],
)
```

**Compositor Configuration**:

```ron
// ~/.config/cosmic/com.system76.CosmicComp/v1/autotile
(
  enabled: true,
  behavior: Global,
  gap: 8,
)
```

**Keyboard Layout**:

```ron
// ~/.config/cosmic/com.system76.CosmicComp/v1/xkb_config
(
  rules: "",
  model: "pc105",
  layout: "us",
  variant: "",
  options: Some("caps:escape,compose:ralt"),
)
```

## Essential Configuration

### Auto-Login

```nix
{
  services.displayManager.autoLogin = {
    enable = true;
    user = "username";
  };
}
```

### Performance Optimization

**Enable System76 Scheduler** (recommended):

```nix
{
  # Improves system responsiveness and performance
  services.system76-scheduler.enable = true;

  # Optional: Configure scheduler settings
  services.system76-scheduler.settings = {
    cfsProfiles.enable = true;
    processScheduler.foregroundBoost.enable = true;
  };
}
```

### Clipboard Management

**Enable Clipboard Protocol** (required for some apps):

```nix
{
  # Override Wayland security restrictions for clipboard
  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = "1";
}
```

### Flatpak Support

**For COSMIC Store and Flatpak Applications**:

```nix
{
  services.flatpak.enable = true;
}
```

Then add Flathub as a user:

```bash
flatpak remote-add --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

### Firefox Integration

**Fix Firefox Theming** (disable libadwaita interference):

```nix
{
  programs.firefox = {
    enable = true;
    preferences = {
      # Prevent GTK4/libadwaita from overriding COSMIC theme
      "widget.gtk.libadwaita-colors.enabled" = false;
    };
  };
}
```

## Declarative Configuration with Home Manager

### Complete Panel Configuration

```nix
{ config, pkgs, lib, ... }:
{
  xdg.configFile = {
    # Panel name and basic config
    "cosmic/com.system76.CosmicPanel.Panel/v1/name".text = "Panel";
    "cosmic/com.system76.CosmicPanel.Panel/v1/output".text = ''"All"'';
    "cosmic/com.system76.CosmicPanel.Panel/v1/anchor".text = "Bottom";
    "cosmic/com.system76.CosmicPanel.Panel/v1/size".text = "S";

    # Left/right applets
    "cosmic/com.system76.CosmicPanel.Panel/v1/plugins_wings".text = ''
      (
        entries: [
          CosmicAppletWorkspaces,
          CosmicAppletApplications,
          CosmicAppletAudio,
          CosmicAppletNetwork,
          CosmicAppletBattery,
          CosmicAppletTime,
          CosmicAppletNotifications,
          CosmicAppletPower,
        ],
      )
    '';

    # Center applets (optional)
    "cosmic/com.system76.CosmicPanel.Panel/v1/plugins_center".text = ''
      (
        entries: [],
      )
    '';
  };
}
```

### Compositor Settings

```nix
{
  xdg.configFile = {
    # Auto-tiling configuration
    "cosmic/com.system76.CosmicComp/v1/autotile".text = ''
      (
        enabled: true,
        behavior: Global,
        gap: 8,
      )
    '';

    # Workspace configuration
    "cosmic/com.system76.CosmicComp/v1/workspaces".text = ''
      (
        workspace_mode: OutputBound,
        workspace_layout: Horizontal,
      )
    '';

    # Keyboard layout
    "cosmic/com.system76.CosmicComp/v1/xkb_config".text = ''
      (
        rules: "",
        model: "pc105",
        layout: "us,ru",
        variant: "",
        options: Some("grp:alt_shift_toggle,caps:escape"),
      )
    '';
  };
}
```

### Application Theming

```nix
{
  xdg.configFile = {
    # Dark mode preference
    "cosmic/com.system76.CosmicTheme.Dark/v1/".text = ''
      (
        base: (
          palette: Dark,
          neutral_tint: None,
        ),
      )
    '';

    # Light mode preference
    "cosmic/com.system76.CosmicTheme.Light/v1/".text = ''
      (
        base: (
          palette: Light,
          neutral_tint: None,
        ),
      )
    '';
  };
}
```

## Theming and Customization

### Current Theming Status

**Stylix Integration**: Not yet available (tracked in [issue #265](https://github.com/nix-community/stylix/issues/265))

**Current Approach**: Manual theme configuration via RON files

### Manual Theme Configuration

**Dark Theme Example**:

```nix
{
  xdg.configFile."cosmic/com.system76.CosmicTheme.Dark/v1/".text = ''
    (
      base: (
        palette: Dark,
        neutral_tint: Some(Rgb(0.2, 0.3, 0.4)),
        accent: Rgb(0.5, 0.7, 1.0),
      ),
      spacing: Comfortable,
      corner_radii: Round,
      interface_density: Default,
    )
  '';
}
```

**Wallpaper Configuration**:

```nix
{
  # Set wallpaper via COSMIC settings
  xdg.configFile."cosmic/com.system76.CosmicSettings.Wallpaper/v1/".text = ''
    (
      wallpapers: [
        (
          path: "/path/to/wallpaper.png",
          method: Zoom,
        ),
      ],
    )
  '';
}
```

### Font Configuration

```nix
{
  # System-wide fonts (affects COSMIC)
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" ]; })
    ];

    fontconfig = {
      defaultFonts = {
        serif = [ "Noto Serif" ];
        sansSerif = [ "Noto Sans" ];
        monospace = [ "JetBrainsMono Nerd Font" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
```

## Keyboard Shortcuts

### Default Shortcuts

**Window Management**:

- `Super + Tab` / `Alt + Tab` - Switch windows
- `Super + Q` - Close window
- `Super + M` - Maximize/restore window
- `Super + R` - Resize mode (use arrows to resize)
- `Super + Shift + R` - Resize opposite direction
- `Super + G` - Toggle tiling/floating mode

**Workspace Management**:

- `Super + 1-9` - Switch to workspace
- `Super + Shift + 1-9` - Move window to workspace
- `Super + Ctrl + Left/Right` - Switch workspace
- `Super + Shift + Ctrl + Left/Right` - Move window to adjacent workspace

**Launcher and Tools**:

- `Super + /` - Open launcher
- `Super + T` - Open terminal
- `Super + E` - Open file manager
- `Super + L` - Lock screen
- `Super + Esc` - Power menu

**Tiling Shortcuts**:

- `Super + Left/Right/Up/Down` - Tile window in direction
- `Super + Enter` - Swap with master

### Custom Keyboard Shortcuts

**Via Home Manager** (RON configuration):

```nix
{
  xdg.configFile."cosmic/com.system76.CosmicComp/v1/keybindings".text = ''
    (
      bindings: {
        // Custom terminal launcher
        (Modifiers(Super), "Return"): System(Terminal),

        // Custom browser launcher
        (Modifiers(Super), "b"): Spawn("firefox"),

        // Screenshot
        (Modifiers(Super Shift), "s"): System(Screenshot),

        // Custom workspace switching
        (Modifiers(Super), "bracketleft"): Workspace(Previous),
        (Modifiers(Super), "bracketright"): Workspace(Next),
      },
    )
  '';
}
```

## Troubleshooting

### 1. NVIDIA Phantom Display Issue

**Problem**: Extra phantom display appears with NVIDIA GPUs

**Solution**:

```nix
{
  boot.kernelParams = [ "nvidia_drm.fbdev=1" ];
}
```

### 2. Clipboard Not Working

**Problem**: Copy/paste between applications fails

**Solution**:

```nix
{
  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = "1";
}
```

### 3. Observatory Service Not Starting

**Problem**: System monitoring tool (Observatory) doesn't start

**Solution**:

```nix
{
  systemd.packages = [ pkgs.observatory ];
  systemd.services.monitord.wantedBy = [ "multi-user.target" ];
}
```

### 4. Settings Not Persisting

**Problem**: Changes in COSMIC Settings don't persist after reboot

**Causes**:

- Home Manager overwriting config files
- Conflicting declarative and imperative configurations
- Incorrect file permissions

**Solution**:

```nix
{
  # Option 1: Remove Home Manager config file management
  # Comment out xdg.configFile for COSMIC settings

  # Option 2: Use Home Manager force option
  xdg.configFile."cosmic/...".force = true;

  # Option 3: Exclude specific paths from Home Manager
  home.file = {
    ".config/cosmic".source = lib.mkForce null;
  };
}
```

### 5. Applets Not Loading

**Problem**: Panel applets don't appear or crash

**Debugging**:

```bash
# Check applet logs
journalctl --user -u cosmic-panel -f

# Verify applet configuration
cat ~/.config/cosmic/com.system76.CosmicPanel.Panel/v1/plugins_wings

# Reset applet configuration
rm -rf ~/.config/cosmic/com.system76.CosmicPanel.Panel/
```

**Solution**: Ensure RON syntax is valid and applet names are correct

### 6. Theme Not Applying

**Problem**: Custom theme doesn't take effect

**Solution**:

```bash
# Restart COSMIC session
cosmic-session --reload

# Or log out and log back in

# Verify theme file syntax
cat ~/.config/cosmic/com.system76.CosmicTheme.Dark/v1/
```

### 7. Slow Performance

**Problem**: Laggy desktop, slow animations

**Solutions**:

```nix
{
  # Enable System76 scheduler
  services.system76-scheduler.enable = true;

  # Reduce compositor effects
  xdg.configFile."cosmic/com.system76.CosmicComp/v1/animations".text = ''
    (
      enabled: false,
    )
  '';

  # Disable transparency
  xdg.configFile."cosmic/com.system76.CosmicComp/v1/opacity".text = ''
    (
      window: 1.0,
      panel: 1.0,
    )
  '';
}
```

### 8. Flatpak Apps Not Theming Correctly

**Problem**: Flatpak applications don't match COSMIC theme

**Solution**:

```bash
# Install COSMIC theme for Flatpak
flatpak install org.gtk.Gtk3theme.cosmic
flatpak install org.kde.KStyle.cosmic

# Force Flatpak to use system theme
flatpak override --user --env=GTK_THEME=cosmic
```

### 9. Multi-Monitor Issues

**Problem**: Incorrect display layout or resolution

**Solution**:

```nix
{
  # Use COSMIC Settings UI for initial setup
  # Then capture configuration:
  xdg.configFile."cosmic/com.system76.CosmicComp/v1/outputs".text = ''
    (
      outputs: {
        "DP-1": (
          mode: (1920, 1080, 60.0),
          position: (0, 0),
          scale: 1.0,
          transform: Normal,
        ),
        "HDMI-1": (
          mode: (1920, 1080, 60.0),
          position: (1920, 0),
          scale: 1.0,
          transform: Normal,
        ),
      },
    )
  '';
}
```

### 10. Flake Build Failures

**Problem**: Building from nixos-cosmic flake fails

**Solutions**:

```bash
# Ensure substituters are set FIRST
nixos-rebuild test  # Sets up binary cache

# Then rebuild with COSMIC
nixos-rebuild switch --flake .#hostname

# For low-memory systems
nixos-rebuild switch --flake .#hostname --cores 1 -j 1

# Update flake inputs
nix flake update
```

## Discovery and Debugging Tools

### Configuration Discovery

**Find Configuration Files**:

```bash
# List all COSMIC config directories
ls -la ~/.config/cosmic/

# View component configuration
cat ~/.config/cosmic/com.system76.CosmicPanel.Panel/v1/plugins_wings

# Watch configuration changes in real-time
watch -n 1 'ls -lt ~/.config/cosmic/*/v1/*'
```

**Monitor COSMIC Processes**:

```bash
# View running COSMIC components
ps aux | grep cosmic

# Monitor resource usage
htop -p $(pgrep -d',' cosmic)
```

### Log Analysis

**Component Logs**:

```bash
# Panel logs
journalctl --user -u cosmic-panel -f

# Compositor logs
journalctl --user -u cosmic-comp -f

# Greeter logs
journalctl -u cosmic-greeter -f

# All COSMIC logs
journalctl --user -t cosmic -f
```

**Session Debugging**:

```bash
# Start COSMIC session with debug output
RUST_LOG=debug cosmic-session

# Or set in configuration:
environment.sessionVariables.RUST_LOG = "debug";
```

### Testing Configuration Changes

**Safe Testing Workflow**:

```bash
# 1. Backup current config
cp -r ~/.config/cosmic ~/.config/cosmic.backup

# 2. Make changes via Home Manager or direct edit

# 3. Test without rebuilding (if manual edit)
cosmic-session --reload

# 4. If using Home Manager, test first
home-manager switch --flake .#user

# 5. Verify changes took effect
diff ~/.config/cosmic ~/.config/cosmic.backup
```

### Binary Cache Verification

**Check Substituter Status**:

```bash
# Verify binary cache is configured
nix show-config | grep substituters

# Test cache availability
nix store ping --store https://cosmic.cachix.org/

# Check cache statistics
nix path-info --all --store https://cosmic.cachix.org/ | wc -l
```

## Golden Path: Best Practices

### 1. ✅ Use Native NixOS Module (25.05+)

**Do**: Start with the native NixOS module for stability

```nix
services.desktopManager.cosmic.enable = true;
services.displayManager.cosmic-greeter.enable = true;
```

**Why**: Official support, binary cache, less maintenance

### 2. ✅ Enable Binary Cache First

**Do**: Configure substituters BEFORE adding COSMIC packages

```nix
nix.settings = {
  substituters = [ "https://cosmic.cachix.org/" ];
  trusted-public-keys = [ "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE=" ];
};
```

**Why**: Avoids lengthy local builds (~40GB, 16GB RAM requirement)

### 3. ✅ Use Home Manager for User Config

**Do**: Manage user-specific COSMIC settings via Home Manager

```nix
xdg.configFile."cosmic/com.system76.CosmicPanel.Panel/v1/plugins_wings".text = ''...'';
```

**Why**: Declarative, version-controlled, reproducible across machines

### 4. ✅ Enable System76 Scheduler

**Do**: Enable the scheduler for better performance

```nix
services.system76-scheduler.enable = true;
```

**Why**: Optimizes process scheduling for desktop responsiveness

### 5. ✅ Test Configuration Incrementally

**Do**: Build and test before committing

```bash
# Test first
nixos-rebuild test

# If successful, switch
nixos-rebuild switch
```

**Why**: Allows rollback without reboot if something breaks

### 6. ✅ Validate RON Syntax

**Do**: Validate RON files before deploying

```bash
# Check for syntax errors
cat ~/.config/cosmic/file.ron | cosmic-settings --validate-ron
```

**Why**: Invalid RON causes silent failures or crashes

### 7. ✅ Version Your Configuration

**Do**: Use versioned directories in COSMIC config paths

```nix
xdg.configFile."cosmic/com.system76.CosmicComp/v1/...".text = ''...'';
```

**Why**: Future COSMIC versions may use v2, v3, etc.

### 8. ✅ Exclude Unwanted Packages

**Do**: Minimize installation footprint

```nix
environment.cosmic.excludePackages = with pkgs; [
  cosmic-edit
  cosmic-term
];
```

**Why**: Reduces disk usage and potential conflicts

### 9. ✅ Document Custom Settings

**Do**: Add comments to your configuration

```nix
# Custom keyboard layout: US with Caps as Escape
xdg.configFile."cosmic/com.system76.CosmicComp/v1/xkb_config".text = ''
  (
    layout: "us",
    options: Some("caps:escape"),
  )
'';
```

**Why**: Future you (or team members) will understand the choices

### 10. ✅ Monitor Development Progress

**Do**: Track COSMIC development and NixOS integration

- Follow: [NixOS/nixpkgs #259641](https://github.com/NixOS/nixpkgs/issues/259641)
- Follow: [nixos-cosmic flake](https://github.com/lilyinstarlight/nixos-cosmic)
- Join: `#cosmic:nixos.org` on Matrix

**Why**: Stay informed about breaking changes and new features

## Anti-Patterns: What to Avoid

### 1. ❌ Mixing Imperative and Declarative Config

**Don't**: Use COSMIC Settings GUI AND Home Manager for same settings

```nix
# Bad: This will be overwritten by Home Manager
# Then manually changing in COSMIC Settings
xdg.configFile."cosmic/...".text = ''...'';
```

**Why**: Creates conflicts, settings don't persist

**Do Instead**: Choose one approach - preferably Home Manager for reproducibility

### 2. ❌ Skipping Binary Cache Setup

**Don't**: Add COSMIC without configuring substituters

```nix
# Bad: Will trigger massive local build
services.desktopManager.cosmic.enable = true;
# (without substituters configured)
```

**Why**: Requires 16GB RAM, 40GB disk, hours of compilation

**Do Instead**: Configure binary cache FIRST, then enable COSMIC

### 3. ❌ Hardcoding Paths

**Don't**: Use absolute paths in configuration

```nix
# Bad: Not portable
xdg.configFile."cosmic/wallpaper".source = /home/user/pictures/wall.png;
```

**Why**: Breaks on other machines, not reproducible

**Do Instead**: Use relative paths or package references

```nix
xdg.configFile."cosmic/wallpaper".source = ./wallpapers/default.png;
```

### 4. ❌ Ignoring RON Syntax Errors

**Don't**: Deploy invalid RON configuration

```ron
# Bad: Invalid RON syntax
(
  entries: [
    CosmicAppletTime,  # Missing comma or wrong format
    CosmicAppletAudio
  ]
)
```

**Why**: Silent failures, applets won't load

**Do Instead**: Validate RON syntax, test incrementally

### 5. ❌ Using Bleeding Edge Without Understanding

**Don't**: Use nixos-cosmic flake without understanding implications

```nix
# Bad: Blindly using development version
inputs.nixpkgs.follows = "nixos-cosmic/nixpkgs";
```

**Why**: Unstable, frequent breaking changes, no guarantees

**Do Instead**: Use native NixOS module unless you need cutting-edge features

### 6. ❌ Not Restarting COSMIC Session

**Don't**: Expect configuration changes to apply without restart

```bash
# Bad: Edit config and expect immediate effect
nano ~/.config/cosmic/...
# No restart
```

**Why**: Most settings require session restart

**Do Instead**: Restart session after changes

```bash
cosmic-session --reload
# Or log out and back in
```

### 7. ❌ Overusing environment.systemPackages

**Don't**: Install user applications system-wide

```nix
# Bad: Installing user apps system-wide
environment.systemPackages = with pkgs; [
  cosmic-edit
  cosmic-term
  firefox
  vscode
];
```

**Why**: Clutters system, applies to all users

**Do Instead**: Use Home Manager for user applications

```nix
home.packages = with pkgs; [ cosmic-edit cosmic-term ];
```

### 8. ❌ Ignoring COSMIC Version Compatibility

**Don't**: Mix COSMIC versions or ignore version warnings

```nix
# Bad: Using incompatible package versions
environment.systemPackages = [ pkgs.cosmic-edit ];
services.desktopManager.cosmic.enable = true;
# (from different nixpkgs commits)
```

**Why**: API incompatibilities, crashes

**Do Instead**: Ensure consistent COSMIC package versions

### 9. ❌ Disabling Security Features Without Reason

**Don't**: Globally disable Wayland security

```nix
# Bad: Unnecessary security compromise
environment.sessionVariables = {
  COSMIC_DATA_CONTROL_ENABLED = "1";
  MOZ_ENABLE_WAYLAND = "0";  # Disabling Wayland entirely
};
```

**Why**: Reduces security for no benefit

**Do Instead**: Enable only what's needed, understand implications

### 10. ❌ Not Backing Up Configuration

**Don't**: Make major changes without backup

```bash
# Bad: Deleting config without backup
rm -rf ~/.config/cosmic/
```

**Why**: May lose working configuration, hard to recover

**Do Instead**: Always backup before major changes

```bash
cp -r ~/.config/cosmic ~/.config/cosmic.backup.$(date +%Y%m%d)
```

## Complete Configuration Examples

### Example 1: Developer Workstation

**Full NixOS + Home Manager Setup**:

```nix
# configuration.nix
{ config, pkgs, ... }:
{
  # COSMIC Desktop
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  # Performance
  services.system76-scheduler.enable = true;

  # Flatpak for COSMIC Store
  services.flatpak.enable = true;

  # Clipboard support
  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = "1";

  # Development tools
  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  # Minimal COSMIC apps
  environment.cosmic.excludePackages = with pkgs; [
    cosmic-edit  # Using VSCode instead
  ];
}
```

```nix
# home.nix
{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    cosmic-term
    cosmic-files
    firefox
    vscode
  ];

  # Panel configuration
  xdg.configFile = {
    "cosmic/com.system76.CosmicPanel.Panel/v1/plugins_wings".text = ''
      (
        entries: [
          CosmicAppletWorkspaces,
          CosmicAppletApplications,
          CosmicAppletAudio,
          CosmicAppletNetwork,
          CosmicAppletBattery,
          CosmicAppletTime,
          CosmicAppletNotifications,
        ],
      )
    '';

    # Dark theme
    "cosmic/com.system76.CosmicTheme.Dark/v1/".text = ''
      (
        base: (
          palette: Dark,
          neutral_tint: Some(Rgb(0.15, 0.2, 0.25)),
          accent: Rgb(0.4, 0.6, 1.0),
        ),
      )
    '';

    # Tiling enabled by default
    "cosmic/com.system76.CosmicComp/v1/autotile".text = ''
      (
        enabled: true,
        behavior: Global,
        gap: 8,
      )
    '';

    # Keyboard shortcuts
    "cosmic/com.system76.CosmicComp/v1/xkb_config".text = ''
      (
        rules: "",
        model: "",
        layout: "us",
        variant: "",
        options: Some("caps:escape"),
      )
    '';
  };
}
```

### Example 2: Minimal COSMIC (Flake-Based)

**For Cutting-Edge Testing**:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
  };

  outputs = { nixpkgs, nixos-cosmic, ... }: {
    nixosConfigurations.cosmic-test = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          nix.settings = {
            substituters = [ "https://cosmic.cachix.org/" ];
            trusted-public-keys = [
              "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
            ];
            experimental-features = [ "nix-command" "flakes" ];
          };
        }

        nixos-cosmic.nixosModules.default

        {
          services.desktopManager.cosmic.enable = true;
          services.displayManager.cosmic-greeter.enable = true;
          services.system76-scheduler.enable = true;

          users.users.user = {
            isNormalUser = true;
            extraGroups = [ "wheel" "networkmanager" ];
          };
        }
      ];
    };
  };
}
```

### Example 3: Multi-Monitor Setup

```nix
# home.nix
{
  xdg.configFile = {
    # Display configuration
    "cosmic/com.system76.CosmicComp/v1/outputs".text = ''
      (
        outputs: {
          "DP-1": (
            mode: (2560, 1440, 144.0),
            position: (0, 0),
            scale: 1.0,
            transform: Normal,
          ),
          "HDMI-1": (
            mode: (1920, 1080, 60.0),
            position: (2560, 0),
            scale: 1.0,
            transform: Normal,
          ),
        },
      )
    '';

    # Workspace per monitor
    "cosmic/com.system76.CosmicComp/v1/workspaces".text = ''
      (
        workspace_mode: OutputBound,
        workspace_layout: Horizontal,
      )
    '';
  };
}
```

## Resources and References

### Official Documentation

- [NixOS Wiki - COSMIC](https://wiki.nixos.org/wiki/COSMIC)
- [nixos-cosmic GitHub](https://github.com/lilyinstarlight/nixos-cosmic)
- [COSMIC Epoch GitHub](https://github.com/pop-os/cosmic-epoch)
- [System76 COSMIC Updates](https://blog.system76.com/tag/cosmic/)

### Community

- Matrix: `#cosmic:nixos.org`
- NixOS Discourse: [COSMIC category](https://discourse.nixos.org/)
- Tracking Issue: [NixOS/nixpkgs #259641](https://github.com/NixOS/nixpkgs/issues/259641)

### Related Issues

- [Stylix COSMIC Support](https://github.com/nix-community/stylix/issues/265)
- [COSMIC Keyboard Navigation](https://github.com/pop-os/cosmic-epoch/issues/46)

### Learning Resources

- [COSMIC Desktop First Look](https://www.debugpoint.com/cosmic-desktop-first-look/)
- [Pop!\_OS Keyboard Shortcuts](https://support.system76.com/articles/pop-cosmic-keyboard-shortcuts/)
- [COSMIC Desktop Basics](https://www.techsolutions.support.com/how-to/cosmic-desktop-basics)

---

**Remember**: COSMIC is actively developed. Configuration patterns may change. Always check the official NixOS wiki and
nixos-cosmic repository for the latest information.
