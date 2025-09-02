# P510 Server Conversion Example

> **Demonstration**: How to convert P510 from workstation to headless media server
> **Status**: Example configuration (not applied yet)
> **Benefits**: Removes ~60 GUI packages, improves performance, reduces resource usage

## Current vs New Configuration

### Current P510 Configuration (Workstation)

```nix
# hosts/p510/configuration.nix (current)
imports = hostTypes.workstation.imports ++ [
  # ... hardware imports
];

# Result:
# - Full desktop environment (Hyprland, GUI apps)
# - All GUI packages installed (~60 GUI packages)
# - Development tools with GUI editors
# - Resource usage: Higher memory/CPU for desktop
```

### Proposed P510 Configuration (Server)

```nix
# hosts/p510/configuration.nix (proposed)
imports = hostTypes.server.imports ++ [
  # ... same hardware imports (no changes needed)
];

# Result:
# - Headless operation (no desktop environment)
# - Only server-essential packages (~95 packages)
# - Media server optimized tools
# - Resource usage: Lower memory/CPU, optimized for media serving
```

## Package Comparison

### Removed Packages (GUI-only, ~60 packages)

- **Desktop Environment**: Hyprland, waybar, rofi, desktop portals
- **GUI Applications**: Firefox, Discord, Slack, Spotify, VS Code, Obsidian
- **GUI Development**: GUI editors, desktop IDEs
- **GUI Media**: VLC player, GIMP, Inkscape, OBS Studio
- **GUI System**: Desktop file managers, GUI settings, themes

### Retained Packages (Server-essential, ~95 packages)

- **Core System**: curl, wget, git, vim, systemctl, journalctl
- **Development**: Python, Node.js (for server scripts), headless editors
- **Media Server**: ffmpeg, mediainfo, youtube-dl, media processing tools
- **Network**: SSH, monitoring tools, network analysis
- **Containers**: Docker, container management (for services)
- **Security**: GPG, SSH keys, server hardening tools
- **Monitoring**: htop, iotop, server performance tools

## Implementation Steps

### Step 1: Simple Template Change

```diff
# hosts/p510/configuration.nix
- imports = hostTypes.workstation.imports ++ [
+ imports = hostTypes.server.imports ++ [
```

### Step 2: Remove Desktop-Specific Imports

```diff
# hosts/p510/configuration.nix
imports = hostTypes.server.imports ++ [
  # Hardware imports (keep all)
  ./nixos/hardware-configuration.nix
  ./nixos/power.nix
  ./nixos/boot.nix
  ./nixos/nvidia.nix
  ./nixos/cpu.nix
  ./nixos/memory.nix
  ./nixos/plex.nix

  # Remove desktop-specific imports
-  ./nixos/greetd.nix          # Desktop login manager
-  ./nixos/screens.nix         # Display configuration
-  ./themes/stylix.nix         # Desktop theming
-  ../common/hyprland.nix      # Desktop environment
```

### Step 3: Update Package Configuration (Automatic)

The new server template automatically configures packages:

```nix
# Automatic server package configuration
packages = {
  desktop.enable = false;              # No GUI packages
  media = {
    enable = true;
    server = true;                     # Media server tools
    processing = true;                 # Media processing
    gui = false;                       # No GUI media apps
  };
  development = {
    enable = true;
    languages.python = true;           # Server admin
    editors.neovim = true;             # Headless editor
    editors.vscode = false;            # No GUI
  };
};
```

## Benefits of Conversion

### Performance Improvements

- **Memory Usage**: Reduce by ~2-4GB (no desktop environment)
- **CPU Usage**: Lower background CPU from GUI processes
- **Boot Time**: Faster startup (no desktop initialization)
- **Network**: More bandwidth available for media serving

### Security Improvements

- **Attack Surface**: Removed GUI applications reduce vulnerability exposure
- **SSH Focus**: Optimized for secure remote administration
- **Service Isolation**: Better resource isolation for media services

### Maintenance Benefits

- **Updates**: Fewer packages to update and maintain
- **Complexity**: Simpler configuration, easier troubleshooting
- **Resources**: More resources dedicated to media serving

## Testing the Conversion

### Safe Testing Process

```bash
# 1. Test the server template configuration
nix build .#nixosConfigurations.p510.config.system.build.toplevel --no-link

# 2. Check package differences
nix eval .#nixosConfigurations.p510.config.environment.systemPackages --apply "builtins.length"
# Expected: ~650 packages (vs current ~800+)

# 3. Preview removed packages
# (Implementation: Compare current vs server package lists)

# 4. Deploy with caution
sudo nixos-rebuild switch --flake .#p510
```

### Rollback Plan

```bash
# If issues occur, rollback is instant
sudo nixos-rebuild switch --rollback

# Or revert the configuration change and redeploy
git checkout HEAD~1 hosts/p510/configuration.nix
sudo nixos-rebuild switch --flake .#p510
```

## Media Server Functionality

### Retained Media Features

✅ **Plex Media Server**: Full functionality maintained
✅ **Media Processing**: ffmpeg, transcoding tools available
✅ **Remote Access**: SSH, Tailscale VPN access maintained
✅ **Monitoring**: System monitoring and performance tracking
✅ **Storage**: All storage and file management capabilities
✅ **Network**: Media streaming and network optimization

### Removed (GUI-only) Features

❌ **Desktop GUI**: No desktop environment or GUI apps
❌ **Local Display**: No monitor/keyboard/mouse interface
❌ **GUI Media Players**: VLC, desktop media applications
❌ **GUI Development**: Visual Studio Code, GUI editors

## Recommendation

The P510 server conversion is **low-risk, high-benefit**:

- ✅ **Easy Rollback**: Instant rollback available if issues
- ✅ **Preserved Media**: All media server functionality retained
- ✅ **Performance Gain**: Significant resource optimization
- ✅ **Simplified Management**: Easier headless administration
- ✅ **Better Security**: Reduced attack surface

**Ideal for**: P510 as dedicated media server with remote management
**Perfect fit**: Current usage pattern (headless operation, media serving)

---

**Ready for Implementation**: This conversion can be implemented safely with the new package management system, providing immediate benefits with minimal risk.
