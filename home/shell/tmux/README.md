# 🖥️ Enhanced Tmux Configuration

## Overview

This configuration provides a modern, high-performance tmux environment with vim-style navigation, intelligent session management, and comprehensive developer productivity features.

## 🚀 Key Features

### Modern Performance
- **Zero escape time** for responsive key handling
- **50,000 line history** with enhanced scrollback
- **True color support** for modern terminals (alacritty, kitty, foot, wezterm)
- **Aggressive resizing** and focus events for better window management

### Vim-Style Navigation
- **hjkl pane navigation** with Alt+hjkl prefix-free alternatives
- **HJKL pane resizing** with repeat capability
- **Smart pane splitting** with intuitive keybindings
- **Quick window access** with Alt+1-5 shortcuts

### Developer Productivity
- **Tilish**: i3/sway-like tiling window management
- **tmux-thumbs**: Quick text copying with hint mode
- **extrakto**: Enhanced text extraction from terminal output
- **Enhanced Session Manager**: Smart project detection with fuzzy selection

## 🎹 Keybindings

### Prefix Key
- **Prefix**: `Ctrl+b` (default, but many operations work without prefix)

### Pane Management
```bash
# Pane splitting (prefix required)
|          # Split vertically (current directory)
-          # Split horizontally (current directory)
\          # Alternative vertical split
_          # Alternative horizontal split

# Pane navigation (prefix required)
h/j/k/l    # Vim-style pane navigation
H/J/K/L    # Pane resizing (repeatable)

# Prefix-free pane navigation
Alt+h/j/k/l     # Direct pane navigation
Alt+Arrow keys  # Arrow key navigation
```

### Window Management
```bash
# Window navigation (prefix-free)
Shift+Left/Right  # Previous/next window
Alt+H/L          # Alternative window navigation
Alt+1-5          # Quick window access

# Window creation (prefix required)
c          # New window at current path
C          # New window at home directory
```

### Session Management
```bash
# Session operations (prefix required)
s          # Choose session (tree view)
S          # New session
T          # Smart session manager (tmux-sessionizer)

# Prefix-free session access
Alt+s      # Quick session chooser
Ctrl+f     # Launch tmux-sessionizer (from zsh)
```

### Copy Mode
```bash
# Enter copy mode (prefix required)
Enter      # Enter copy mode

# Copy mode navigation (vi-style)
v          # Begin selection
y          # Copy and exit
r          # Rectangle toggle
Escape     # Cancel/exit
```

### Layout Management
```bash
# Quick layouts (prefix required)
Alt+1      # Even horizontal
Alt+2      # Even vertical  
Alt+3      # Main horizontal
Alt+4      # Main vertical
Alt+5      # Tiled

# Pane operations
z          # Zoom/unzoom current pane
```

### Productivity
```bash
# Utility (prefix required)
r          # Reload configuration
Ctrl+l     # Clear screen and history
u          # Open URLs with fzf selection
```

## 🔌 Plugin Architecture

### Core Plugins
```nix
tmuxPlugins.sensible              # Better defaults
tmuxPlugins.better-mouse-mode     # Enhanced mouse support
```

### Navigation & Window Management
```nix
tmuxPlugins.tilish               # i3/sway-like tiling
# Configuration:
# - Navigator integration enabled
# - Default layout: main-vertical
```

### Session Management
```nix
tmuxPlugins.t-smart-tmux-session-manager
# Features:
# - Fuzzy session switching
# - Project-aware session creation
# - Integration with tmux-sessionizer
```

### Productivity Tools
```nix
tmuxPlugins.tmux-fzf            # Enhanced fuzzy operations
tmuxPlugins.fzf-tmux-url        # URL handling with fzf
tmuxPlugins.tmux-thumbs         # Quick text copying
tmuxPlugins.extrakto            # Enhanced text extraction
```

### Theme
```nix
tmux-gruvbox                    # Custom Gruvbox theme
# Features:
# - Modern icon set
# - Consistent with Starship theme
# - Development workflow status modules
```

## 🎨 Visual Configuration

### Gruvbox Theme Features
```bash
# Window status icons
󰖰  # Last window
󰖯  # Current window  
󰁌  # Zoomed window
󰃀  # Marked window
󰂛  # Silent window
󰖲  # Activity window
󰂞  # Bell window
```

### Status Line Modules
- **Directory**: Shows current path (with ~ for home)
- **Session**: Current session name
- **Date/Time**: Formatted timestamp
- **Git status**: When in git repositories (via integration)

### Color Scheme
- **Background**: `#282828` (Gruvbox dark)
- **Foreground**: `#ebdbb2` (Gruvbox light)
- **Accent colors**: Gruvbox palette for consistent theming

## 🔧 Configuration Sections

### Terminal Display Settings
```bash
# True color support for modern terminals
TERM=tmux-256color with RGB support
# Terminal overrides for: xterm-256color, alacritty, kitty, foot, wezterm

# Performance optimizations
escape-time: 0ms              # Immediate ESC key response
repeat-time: 600ms            # Key repeat timeout
focus-events: enabled         # Window focus detection
```

### Base Configuration
```bash
# Indexing
base-index: 1                 # Windows start at 1
pane-base-index: 1           # Panes start at 1
renumber-windows: enabled     # Auto-renumber on close

# History and scrollback
history-limit: 50000         # Large scrollback buffer
display-time: 4000ms         # Message display duration
status-interval: 5s          # Status update frequency
```

### Mouse and Clipboard
```bash
# Mouse support
mouse: enabled                # Full mouse integration

# Clipboard integration (Wayland)
copy-command: wl-copy        # Wayland clipboard
paste-command: wl-paste      # Wayland paste
```

## 🚀 Enhanced Session Manager

### tmux-sessionizer Features
- **Smart project detection** in configured directories
- **Fuzzy selection** with file tree previews
- **Session name generation** with tmux compatibility
- **State-aware operation** (handles all tmux scenarios)

### Search Paths
```bash
~/Source/GitHub              # GitHub projects
~/Documents                  # Documentation projects  
~/.config/nixos             # NixOS configuration
~/Projects                  # General projects
~/workspace                 # Workspace directory
~/dev                       # Development directory
```

### Usage
```bash
# Interactive project selection
tmux-sessionizer

# Direct project path
tmux-sessionizer /path/to/project

# Help and options
tmux-sessionizer --help
```

### Integration Points
- **Zsh keybinding**: `Ctrl+F` launches sessionizer
- **fzf integration**: Beautiful project selection interface
- **eza previews**: Tree view of project contents
- **Smart session naming**: Automatic tmux-compatible names

## 🔗 Integration Features

### Shell Integration
- **Zsh integration**: Seamless with enhanced zsh configuration
- **Starship compatibility**: Prompt works correctly in tmux
- **Environment passing**: Proper environment variable inheritance

### Development Tools
- **Neovim integration**: Seamless editor integration
- **Git awareness**: Status and branch information
- **Language servers**: Proper LSP functionality in tmux
- **Claude Code**: Full integration with AI coding assistant

### Modern Terminal Features
- **Image preview**: Supports terminal image protocols
- **True color**: Full 24-bit color support
- **Font rendering**: Proper Nerd Font icon display
- **Clipboard**: Native Wayland clipboard integration

## 🎯 Development Workflows

### Project-Based Sessions
1. **Launch sessionizer**: `Ctrl+F` or `tmux-sessionizer`
2. **Select project**: Use fuzzy finder with previews
3. **Automatic setup**: Session created with project name and directory
4. **Smart switching**: Attach to existing or create new as needed

### Multi-Pane Development
1. **Split for editor**: `|` to create vertical split for editor
2. **Add terminal**: `-` to create horizontal split for terminal/logs
3. **Quick layouts**: `Alt+1-5` for predefined layouts
4. **Tiling management**: Use tilish commands for i3-like control

### Session Management
1. **Multiple projects**: Each project gets its own session
2. **Quick switching**: `Alt+s` for fast session selection
3. **Persistent sessions**: Sessions survive terminal closure
4. **Smart naming**: Automatic session names from project directories

## 📊 Performance Features

### Startup Optimization
- **Fast plugin loading**: Essential plugins only
- **Efficient theming**: Optimized status line updates
- **Smart caching**: Reduced redundant operations

### Memory Management
- **Controlled history**: Large but bounded scrollback
- **Efficient status**: Minimal status line overhead
- **Plugin efficiency**: Careful plugin selection for performance

### Responsiveness
- **Zero escape time**: Immediate key response
- **Focus events**: Proper window focus handling
- **Aggressive resizing**: Optimal terminal resizing

## 🔧 Customization

### Adding Custom Keybindings
```nix
# Add to extraConfig in tmux configuration
bind <key> <command>
```

### Plugin Management
```nix
# Add new plugins to the plugins array
{
  plugin = tmuxPlugins.plugin-name;
  extraConfig = ''
    # Plugin-specific configuration
  '';
}
```

### Theme Customization
```nix
# Modify gruvbox theme settings in plugin configuration
set -g @gruvbox_option "value"
```

## 🐛 Troubleshooting

### Common Issues

#### Colors Not Working
1. **Check terminal**: Ensure terminal supports true color
2. **Verify TERM**: Should be `tmux-256color`
3. **Test colors**: Use `tmux show-environment` to check variables

#### Keybindings Not Working
1. **Check conflicts**: Use `tmux list-keys` to see all bindings
2. **Verify prefix**: Ensure prefix key is working
3. **Plugin conflicts**: Disable plugins to isolate issues

#### Session Manager Issues
1. **Check paths**: Verify search paths exist and are accessible
2. **fzf dependency**: Ensure fzf is properly installed
3. **Permissions**: Check directory access permissions

#### Performance Issues
1. **Plugin optimization**: Disable non-essential plugins
2. **History limits**: Reduce if experiencing slowdowns
3. **Status updates**: Increase status-interval if needed

### Debug Commands
```bash
# Show current configuration
tmux show-options -g

# List all keybindings  
tmux list-keys

# Show environment variables
tmux show-environment

# Display plugin status
tmux display-message "#{plugin_status}"
```

## 📚 References

- [Tmux Manual](https://man7.org/linux/man-pages/man1/tmux.1.html)
- [Tilish Plugin](https://github.com/jabirali/tmux-tilish)
- [tmux-thumbs](https://github.com/fcsonline/tmux-thumbs)
- [Gruvbox Theme](https://github.com/morhetz/gruvbox)
- [Session Manager](https://github.com/joshmedeski/t-smart-tmux-session-manager)