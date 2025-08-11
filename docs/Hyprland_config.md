# Hyprland Configuration Documentation

## Overview

This document provides comprehensive information about the Hyprland window manager configuration in this NixOS system. Hyprland is a modern, high-performance Wayland compositor that provides advanced window management capabilities with extensive customization options.

## Configuration Structure

### File Organization

```
home/desktop/hyprland/
├── default.nix              # Main Hyprland configuration
├── config/
│   ├── binds.nix            # Comprehensive keybindings
│   ├── settings.nix         # Visual settings and behavior
│   └── startup.nix          # Startup applications
└── scripts/
    └── hyprkeys.nix         # Keybinding help script
```

### System Integration

```
hosts/common/hyprland.nix    # System-level Hyprland enablement
modules/desktop/hyprland-uwsm.nix  # UWSM session management
```

## Complete Keybinding Reference

### Core Navigation

| Keybinding          | Action                    | Description                            |
| ------------------- | ------------------------- | -------------------------------------- |
| `ALT + TAB`         | Window cycling (forward)  | Cycle through open windows             |
| `ALT + SHIFT + TAB` | Window cycling (backward) | Cycle through windows in reverse       |
| `SUPER + h/j/k/l`   | Focus movement            | Move focus between windows (vim-style) |
| `SUPER + TAB`       | Previous workspace        | Switch to previously active workspace  |

### Workspace Management

| Keybinding              | Action               | Description                          |
| ----------------------- | -------------------- | ------------------------------------ |
| `SUPER + 1-9,0`         | Switch workspace     | Switch to workspace 1-10             |
| `SUPER + SHIFT + 1-9,0` | Move to workspace    | Move active window to workspace 1-10 |
| `SUPER + CTRL + h/l`    | Navigate workspaces  | Move to adjacent workspaces          |
| `SUPER + mouse scroll`  | Workspace navigation | Scroll through workspaces with mouse |

### Window Management

| Keybinding        | Action          | Description                  |
| ----------------- | --------------- | ---------------------------- |
| `SUPER + Q`       | Kill window     | Close active window          |
| `SUPER + F`       | Fullscreen      | Toggle fullscreen mode       |
| `SUPER + F`       | Toggle floating | Toggle floating mode         |
| `SUPER + ALT + P` | Pin window      | Pin window to all workspaces |
| `SUPER + Y`       | Dwindle layout  | Switch to dwindle layout     |
| `SUPER + U`       | Master layout   | Switch to master layout      |

### Window Movement and Resizing

| Keybinding                | Action        | Description                  |
| ------------------------- | ------------- | ---------------------------- |
| `SUPER + SHIFT + h/j/k/l` | Move window   | Move window within workspace |
| `SUPER + SHIFT + c`       | Center window | Center floating window       |
| `SUPER + R`               | Resize mode   | Enter resize mode            |
| `SUPER + mouse:272`       | Move window   | Drag window with mouse       |
| `SUPER + mouse:273`       | Resize window | Resize window with mouse     |

### Advanced Window Features

| Keybinding              | Action         | Description                |
| ----------------------- | -------------- | -------------------------- |
| `SUPER + ALT + =`       | Reduce opacity | Set window opacity to 90%  |
| `SUPER + ALT + -`       | Reduce opacity | Set window opacity to 80%  |
| `SUPER + ALT + 0`       | Reset opacity  | Set window opacity to 100% |
| `SUPER + ALT + h/j/k/l` | Manual tiling  | Preselect split direction  |

### Modern Window Management (2024)

| Keybinding                   | Action             | Description                        |
| ---------------------------- | ------------------ | ---------------------------------- |
| `SUPER + W`                  | Toggle group       | Create window tabs/groups          |
| `SUPER + SHIFT + W`          | Lock groups        | Prevent accidental ungrouping      |
| `SUPER + CTRL + TAB`         | Next group tab     | Switch to next window in group     |
| `SUPER + CTRL + SHIFT + TAB` | Previous group tab | Switch to previous window in group |
| `SUPER + ALT + 1/2`          | Group indicators   | Set visual group colors            |

### Smart Window Sizing

| Keybinding          | Action       | Description                       |
| ------------------- | ------------ | --------------------------------- |
| `SUPER + SHIFT + =` | Full HD size | Resize to 1920x1080               |
| `SUPER + SHIFT + -` | HD size      | Resize to 1280x720                |
| `SUPER + SHIFT + 0` | Half screen  | Resize to 50% screen size         |
| `SUPER + ALT + G`   | Golden ratio | Resize to 61.8% width (aesthetic) |

### Application Launchers

| Keybinding               | Action            | Description                               |
| ------------------------ | ----------------- | ----------------------------------------- |
| `SUPER + RETURN`         | Floating terminal | Launch foot terminal (floating, centered) |
| `SUPER + CTRL + RETURN`  | Tiled terminal    | Launch foot terminal (tiled mode)         |
| `SUPER + space`          | App launcher      | Launch rofi application launcher          |
| `SUPER + backspace`      | Show keybindings  | Display this help via rofi                |
| `SUPER + E`              | File manager      | Launch thunar file manager                |
| `SUPER + V`              | Clipboard manager | Access clipboard history via rofi         |
| `SUPER + CTRL + V`       | Clear clipboard   | Clear clipboard history with notification |
| `SUPER + =`              | Calculator        | Launch qalc calculator (floating)         |
| `SUPER + SHIFT + Escape` | System monitor    | Launch htop system monitor                |

### Special Workspaces

| Keybinding          | Action            | Description                      |
| ------------------- | ----------------- | -------------------------------- |
| `SUPER + S`         | Slack workspace   | Toggle Slack special workspace   |
| `SUPER + SHIFT + S` | Magic workspace   | Toggle magic special workspace   |
| `SUPER + B`         | Firefox workspace | Toggle Firefox special workspace |
| `SUPER + M`         | Mail workspace    | Toggle mail special workspace    |
| `SUPER + SHIFT + M` | Spotify workspace | Toggle Spotify special workspace |
| `SUPER + T`         | Scratchpad        | Toggle scratchpad workspace      |
| `SUPER + D`         | Discord workspace | Toggle Discord special workspace |

### Development Workflow

| Keybinding               | Action         | Description                                 |
| ------------------------ | -------------- | ------------------------------------------- |
| `SUPER + SHIFT + Return` | Code editor    | Launch VS Code                              |
| `SUPER + SHIFT + T`      | Large terminal | Launch large floating terminal (80% screen) |
| `SUPER + CTRL + T`       | Tmux session   | Launch tmux in floating terminal            |
| `SUPER + CTRL + Y`       | AI assistant   | Launch yai AI assistant                     |

### Dynamic Workspace Management

| Keybinding         | Action             | Description                |
| ------------------ | ------------------ | -------------------------- |
| `SUPER + CTRL + N` | Create workspace   | Create new empty workspace |
| `SUPER + CTRL + X` | Previous workspace | Go to previous workspace   |

### Workspace-Specific Layouts

| Keybinding        | Action         | Description                       |
| ----------------- | -------------- | --------------------------------- |
| `SUPER + ALT + 1` | Dwindle layout | Set workspace 1 to dwindle layout |
| `SUPER + ALT + 2` | Master layout  | Set workspace 2 to master layout  |
| `SUPER + ALT + 3` | Dwindle layout | Set workspace 3 to dwindle layout |

### Layout Management

| Keybinding          | Action            | Description                    |
| ------------------- | ----------------- | ------------------------------ |
| `SUPER + I`         | Cycle next        | Cycle to next window in layout |
| `SUPER + O`         | Swap with master  | Swap window with master        |
| `SUPER + SHIFT + U` | Orientation cycle | Cycle layout orientation       |
| `SUPER + SHIFT + I` | Cycle previous    | Cycle to previous window       |
| `SUPER + SHIFT + O` | Focus master      | Focus master window            |
| `SUPER + [`         | Roll next         | Roll layout next               |
| `SUPER + ]`         | Roll previous     | Roll layout previous           |

### Group Management

| Keybinding          | Action            | Description                     |
| ------------------- | ----------------- | ------------------------------- |
| `SUPER + G`         | Toggle group      | Toggle group mode               |
| `SUPER + SHIFT + G` | Move out of group | Move window out of group        |
| `ALT + left`        | Previous group    | Change to previous group window |
| `ALT + right`       | Next group        | Change to next group window     |

### System Controls

| Keybinding          | Action              | Description                      |
| ------------------- | ------------------- | -------------------------------- |
| `SUPER + L`         | Lock screen         | Lock screen immediately          |
| `SUPER + ALT + L`   | Lock screen         | Alternative lock screen shortcut |
| `SUPER + N`         | Notifications       | Toggle notification panel        |
| `SUPER + SHIFT + N` | Clear notifications | Clear all notifications          |
| `SUPER + SHIFT + P` | Screenshot          | Take screenshot                  |

### Gaming and Performance

| Keybinding               | Action          | Description                                |
| ------------------------ | --------------- | ------------------------------------------ |
| `SUPER + CTRL + G`       | Gaming mode ON  | Disable compositor effects for performance |
| `SUPER + CTRL + ALT + G` | Gaming mode OFF | Re-enable compositor effects               |

### Power Management

| Keybinding               | Action    | Description      |
| ------------------------ | --------- | ---------------- |
| `SUPER + SHIFT + End`    | Suspend   | Suspend system   |
| `SUPER + SHIFT + Delete` | Power off | Power off system |
| `SUPER + SHIFT + Insert` | Reboot    | Reboot system    |

### Network Management

| Keybinding          | Action      | Description                |
| ------------------- | ----------- | -------------------------- |
| `SUPER + CTRL + W`  | Network TUI | Launch network manager TUI |
| `SUPER + SHIFT + W` | Weather     | Launch weather popup       |

### Media Controls

| Keybinding          | Action         | Description            |
| ------------------- | -------------- | ---------------------- |
| `XF86AudioPlay`     | Play/pause     | Media play/pause       |
| `XF86AudioNext`     | Next track     | Next media track       |
| `XF86AudioPrev`     | Previous track | Previous media track   |
| `SUPER + P`         | Play/pause     | Alternative play/pause |
| `SUPER + SHIFT + .` | Next track     | Next track             |
| `SUPER + SHIFT + ,` | Previous track | Previous track         |

### Volume Controls

| Keybinding             | Action      | Description                   |
| ---------------------- | ----------- | ----------------------------- |
| `SUPER + /`            | Mute toggle | Toggle audio mute             |
| `SUPER + SHIFT + V`    | Volume down | Decrease volume by 2%         |
| `SUPER + SHIFT + B`    | Volume up   | Increase volume by 2%         |
| `XF86AudioRaiseVolume` | Volume up   | Hardware volume up with OSD   |
| `XF86AudioLowerVolume` | Volume down | Hardware volume down with OSD |
| `XF86AudioMute`        | Mute toggle | Hardware mute toggle with OSD |
| `XF86AudioMicMute`     | Mic mute    | Microphone mute toggle        |

### Brightness Controls

| Keybinding              | Action                  | Description                 |
| ----------------------- | ----------------------- | --------------------------- |
| `XF86MonBrightnessUp`   | Brightness up           | Increase screen brightness  |
| `XF86MonBrightnessDown` | Brightness down         | Decrease screen brightness  |
| `SUPER + F3`            | Keyboard backlight up   | Increase keyboard backlight |
| `SUPER + F2`            | Keyboard backlight down | Decrease keyboard backlight |

### Screenshot Controls

| Keybinding      | Action                  | Description                            |
| --------------- | ----------------------- | -------------------------------------- |
| `Print`         | Screenshot to clipboard | Capture area to clipboard              |
| `SHIFT + Print` | Screenshot to file      | Capture area to ~/Pictures/screenshots |
| `CTRL + Print`  | Full screenshot to file | Capture entire screen to file          |

### Modern Mouse Integration (2024)

| Keybinding      | Action             | Description               |
| --------------- | ------------------ | ------------------------- |
| `Mouse Forward` | Next workspace     | Use mouse forward button  |
| `Mouse Back`    | Previous workspace | Use mouse back button     |
| `SUPER + Click` | Focus window       | Focus window under cursor |

### Modern Touchpad Gestures

| Gesture            | Action             | Description              |
| ------------------ | ------------------ | ------------------------ |
| `3-finger swipe →` | Previous workspace | Swipe right to go back   |
| `3-finger swipe ←` | Next workspace     | Swipe left to go forward |
| `3-finger swipe ↑` | Empty workspace    | Go to empty workspace    |
| `3-finger swipe ↓` | Close window       | Kill active window       |

### Performance Controls (2024)

| Keybinding          | Action                  | Description                      |
| ------------------- | ----------------------- | -------------------------------- |
| `SUPER + SHIFT + G` | Toggle blur             | Instantly toggle blur effects    |
| `SUPER + SHIFT + A` | Toggle animations       | Instantly toggle all animations  |
| `SUPER + CTRL + M`  | GPU monitor             | Launch nvtop (GPU usage monitor) |
| `SUPER + SHIFT + M` | Enhanced system monitor | Launch htop (70% screen size)    |

### Emergency & Debug Tools

| Keybinding                 | Action            | Description                       |
| -------------------------- | ----------------- | --------------------------------- |
| `SUPER + CTRL + SHIFT + R` | Reload config     | Reload Hyprland configuration     |
| `SUPER + CTRL + SHIFT + K` | Kill Hyprland     | Emergency kill (force exit)       |
| `SUPER + CTRL + SHIFT + E` | Exit Hyprland     | Clean exit to login manager       |
| `SUPER + SHIFT + D`        | Copy window info  | Copy active window debug info     |
| `SUPER + SHIFT + I`        | Copy version info | Copy Hyprland version for support |

### Resize Mode

When in resize mode (`SUPER + R`):

| Keybinding  | Action           | Description                 |
| ----------- | ---------------- | --------------------------- |
| `SUPER + h` | Resize left      | Resize window left by 30px  |
| `SUPER + l` | Resize right     | Resize window right by 30px |
| `SUPER + k` | Resize up        | Resize window up by 30px    |
| `SUPER + j` | Resize down      | Resize window down by 30px  |
| `Escape`    | Exit resize mode | Return to normal mode       |

### Laptop-Specific Features

| Keybinding   | Action              | Description                                |
| ------------ | ------------------- | ------------------------------------------ |
| `Lid Switch` | Monitor toggle      | Enable/disable laptop display on lid close |
| `Caps Lock`  | Caps lock indicator | Show caps lock status via OSD              |

## Configuration Features

### Visual Settings

**Theming:**

- Gruvbox Dark color scheme
- Consistent with system-wide theme
- **2024 Modern Animations**: Bouncy, elastic, and smooth bezier curves
- **Fancy Visual Effects**: Popin animations, directional slides, looping borders
- **Enhanced Blur & Vibrancy**: Popup blur, vibrancy effects, smooth transitions
- Hardware-accelerated rendering with 60+ FPS support

**Window Behavior:**

- Smart gaps and borders
- **Modern Focus Management:** Focus follows mouse with intelligent floating focus
- **Comprehensive Auto-Placement:** Applications automatically position and size themselves
- **Smart Window Rules:** Over 25 application-specific rules for optimal UX
- **Workspace Auto-Assignment:** Development, communication, and media apps auto-organize
- Multi-monitor support

**Smart Application Rules (2024):**

- **Audio/Video Controls:** pavucontrol auto-floats and centers (800x600)
- **System Monitors:** htop/btop auto-size to 900x650 and center
- **Development IDEs:** VS Code automatically assigned to workspace 3
- **Communication Apps:** Discord/Slack auto-assign to special workspaces
- **Gaming Optimization:** Steam games get performance optimizations automatically
- **Media Windows:** Picture-in-picture auto-pins and positions correctly
- **File Managers:** thunar opens at optimal 1000x700 size

### Performance Optimizations

**Hardware Acceleration:**

- GPU-accelerated rendering
- Efficient memory management
- Optimized for different GPU types (AMD, NVIDIA, Intel)

**Gaming Mode:**

- Disables compositor effects for maximum performance
- One-click toggle for gaming sessions
- Automatic restoration of effects

**Modern Animation System (2024):**

- **13 Custom Bezier Curves**: Smooth, bounce, elastic, overshot effects
- **Comprehensive Animation Coverage**: Windows, borders, fades, workspaces, layers
- **Fancy Visual Effects**: Popin (70-80%), directional slides, looping borders
- **Performance Optimized**: 5-8 speed range for smooth 60+ FPS
- **Smart Animation Hierarchy**: Specialized curves for different element types

### Integration Features

**Wayland Native:**

- Full Wayland protocol support
- Native clipboard integration
- Screen sharing capabilities

**System Integration:**

- SwayOSD for volume/brightness feedback
- SwayNC for notification management
- Proper XDG portal configuration

## Advanced Configuration

### Customization Options

**Adding New Keybindings:**

```nix
# In home/desktop/hyprland/config/binds.nix
bind = $mainMod, KEY, ACTION, PARAMETERS
```

**Modifying Window Rules:**

```nix
# In home/desktop/hyprland/config/settings.nix
windowrule = float, ^(APPLICATION_CLASS)$
```

**Custom Startup Applications:**

```nix
# In home/desktop/hyprland/config/startup.nix
exec-once = APPLICATION_COMMAND
```

### Host-Specific Overrides

Some hosts may have specific overrides:

- `/home/olafkfreund/.config/nixos/hosts/*/nixos/hypr_override.nix`

### Scripts and Utilities

**Keybinding Help:**

- `rofi-hyprkeys` - Interactive keybinding reference
- Located in: `home/desktop/hyprland/scripts/hyprkeys.nix`

## Troubleshooting

### Common Issues

1. **Window not responding to keybindings:**
   - Check if the window is floating or has special rules
   - Verify the window class with `hyprctl activewindow`

2. **Gaming mode not improving performance:**
   - Ensure your GPU supports hardware acceleration
   - Check if other applications are using GPU resources

3. **Special workspaces not working:**
   - Verify applications are installed and configured
   - Check workspace rules for specific applications

### Debug Commands

```bash
# Check Hyprland status
hyprctl version

# View active window information
hyprctl activewindow

# List all windows
hyprctl clients

# Monitor configuration
hyprctl monitors

# Reload configuration
hyprctl reload
```

## Dependencies

### Required Packages

**Core:**

- `hyprland` - Window manager
- `hyprlock` - Screen locker
- `foot` - Terminal emulator
- `rofi` - Application launcher

**Media and System:**

- `pamixer` - Volume control
- `playerctl` - Media control
- `brightnessctl` - Brightness control
- `flameshot` - Screenshot utility

**Integration:**

- `swayosd` - On-screen display
- `swaync` - Notification daemon
- `cliphist` - Clipboard manager
- `thunar` - File manager

### Optional Enhancements

**Development:**

- `code` - VS Code editor
- `tmux` - Terminal multiplexer
- `htop` - System monitor
- `qalc` - Calculator

**Network:**

- `nmtui` - Network manager TUI

## Best Practices

### Workflow Recommendations

1. **Use special workspaces** for persistent applications
2. **Leverage gaming mode** for performance-critical applications
3. **Utilize resize mode** for precise window adjustments
4. **Take advantage of vim-style navigation** for efficient window management

### Customization Guidelines

1. **Test keybindings** before committing to configuration
2. **Document custom modifications** in this file
3. **Consider ergonomics** when adding new shortcuts
4. **Maintain consistency** with existing patterns

## Recent Enhancements (2024)

### Recently Added Modern Features ✅

1. **Smart Window Rules** - Automatic application positioning and sizing
2. **Modern Focus Management** - Focus follows mouse with intelligent behavior
3. **Window Grouping/Tabbing** - Browser-like tabs for window organization
4. **Smart Window Sizing** - Golden ratio and standard size shortcuts
5. **Dynamic Workspace Management** - Create/destroy workspaces on demand
6. **Performance Quick Toggles** - Instant blur/animation control
7. **Mouse Integration** - Forward/back buttons for workspace navigation
8. **Touchpad Gestures** - 3-finger swipes for all major actions
9. **Emergency Tools** - Debug shortcuts and system recovery
10. **Enhanced System Monitoring** - GPU monitoring and better system tools

## Future Enhancements

### Planned Features

1. **Action Menu System** - Context-sensitive quick actions
2. **Enhanced multi-monitor support** with workspace assignment
3. **Application-specific keybindings** for specialized workflows
4. **Advanced Alt-Tab with previews** - Modern window switcher

### Contributing

When adding new features:

1. Follow existing naming conventions
2. Document new keybindings in this file
3. Test on multiple hosts
4. Consider backwards compatibility

---

_This documentation reflects the current state of the Hyprland configuration. For the most up-to-date keybindings, refer to the source files in the configuration directory._
