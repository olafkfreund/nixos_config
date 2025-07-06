# 📱 Enhanced Zellij Configuration

## Overview

Zellij is a modern terminal multiplexer with built-in session management, layouts, and plugins. This configuration provides a seamless alternative to tmux with vim-style navigation and comprehensive developer productivity features.

## 🚀 Key Features

### Modern Architecture
- **Built-in session management** with persistence
- **Plugin system** with first-class plugin support
- **Layout management** with predefined development layouts
- **Floating panes** for temporary work
- **Smart keybindings** consistent with tmux/vim

### Developer Experience
- **File manager integration** with built-in strider
- **Session management** with advanced persistence
- **Development layouts** optimized for coding workflows
- **Gruvbox theming** consistent with the shell ecosystem

### Integration
- **Zsh integration** for seamless shell experience
- **Clipboard support** with Wayland integration
- **Scrollback editor** using Neovim
- **Modern terminal support** with true color

## 🎹 Keybindings

### Core Navigation
```bash
# Pane navigation (vim-style)
h/j/k/l    # Move focus between panes

# Pane resizing
H/J/K/L    # Resize panes (increase left/down/up/right)

# Pane management
|          # Split pane right (vertical split)
-          # Split pane down (horizontal split)
x          # Close current pane
```

### Tab Management
```bash
# Tab operations
t          # Create new tab
x          # Close current tab
1-5        # Switch to tab 1-5
r          # Rename current tab
```

### Session Management
```bash
# Session operations
s          # Open session manager
d          # Detach from session (Ctrl+p + d in normal mode)
```

### Special Features
```bash
# Floating panes
f          # Toggle floating panes
z          # Toggle focus fullscreen
e          # Open file manager (strider)
```

### Modes
Zellij operates in different modes accessed via `Ctrl+p`:

#### Normal Mode (Default)
- Standard pane navigation and management
- Most operations available without mode switching

#### Scroll Mode (`Ctrl+p + s`)
```bash
h/j/k/l    # Navigate in scrollback
d          # Half-page down
u          # Half-page up  
Ctrl+f     # Full page down
Ctrl+b     # Full page up
```

#### Search Mode (`Ctrl+p + /`)
```bash
n          # Next search result
N          # Previous search result
```

## 🔌 Plugin Architecture

### Essential Plugins
```nix
plugins = [
  "status-bar"           # Bottom status information
  "tab-bar"             # Top tab management
  "strider"             # Built-in file manager
  "compact-bar"         # Minimal UI mode
  "session-manager"     # Advanced session handling
  "filepicker"          # File selection interface
]
```

### Plugin Features

#### Status Bar
- **Session information**: Current session name and status
- **Tab indicators**: Active and background tabs
- **Mode display**: Current operating mode
- **Time/date**: System time display

#### Strider (File Manager)
- **Tree navigation**: Directory browsing
- **File operations**: Basic file management
- **Quick access**: Integrated with file picker
- **Vim-style navigation**: Familiar keybindings

#### Session Manager
- **Session persistence**: Automatic session saving
- **Multiple sessions**: Support for multiple concurrent sessions
- **Session switching**: Quick session selection
- **Layout restoration**: Restore pane layouts on attach

## 🎨 Visual Configuration

### Gruvbox Theme
```bash
# Color scheme matching shell environment
bg: "#282828"           # Dark background
fg: "#ebdbb2"           # Light foreground
red: "#cc241d"          # Error states
green: "#98971a"        # Success states
yellow: "#d79921"       # Warning states
blue: "#458588"         # Information
magenta: "#b16286"      # Special elements
orange: "#d65d0e"       # Accents
cyan: "#689d6a"         # Secondary info
```

### UI Configuration
```bash
# Modern UI settings
simplified_ui: true     # Clean interface
pane_frames: true      # Visual pane separation
rounded_corners: true   # Modern appearance
hide_session_name: false # Show context
```

## 📐 Layout System

### Development Layout
**Optimized for coding workflows:**
```
┌─────────────────┬───────────┐
│                 │           │
│    Editor       │ Terminal  │
│     (70%)       │   (30%)   │
│                 │           │
├─────────────────┴───────────┤
│           Logs              │
│           (25%)             │
└─────────────────────────────┘
```

**Usage**: Automatically applies when working in development projects

### Simple Layout
**For general terminal use:**
```
┌─────────────────────────────┐
│                             │
│         Terminal            │
│                             │
│                             │
└─────────────────────────────┘
```

**Usage**: Default layout for general terminal work

### Custom Layouts
Create custom layouts by:
1. Setting up desired pane configuration
2. Saving layout with session manager
3. Accessing via session management interface

## 🔧 Configuration Structure

### Core Settings
```nix
settings = {
  default-shell = "zsh";           # Use enhanced zsh
  simplified_ui = true;            # Clean interface
  copy_command = "wl-copy";        # Wayland clipboard
  copy_on_select = false;          # Manual copy
  hide_session_name = false;       # Show session context
  session_serialization = true;    # Persist sessions
  pane_frames = true;             # Visual separation
  default_layout = "compact";      # Default layout
  theme = "gruvbox-dark";         # Consistent theming
  scrollback_editor = "nvim";     # Use Neovim for scrollback
  default_mode = "normal";        # Start in normal mode
  mouse_mode = true;              # Enable mouse support
}
```

### Keybinding Customization
```nix
keybinds = {
  normal = {
    # Custom keybindings for normal mode
  };
  scroll = {
    # Custom keybindings for scroll mode  
  };
  search = {
    # Custom keybindings for search mode
  };
}
```

## 🚀 Shell Integration

### Zsh Aliases
```bash
zj="zellij"                    # Quick access
zja="zellij attach"            # Attach to session
zjd="zellij delete-session"    # Delete session
zjl="zellij list-sessions"     # List sessions
zjk="zellij kill-session"      # Kill session
zjr="zellij run"              # Run command in new pane
zje="zellij edit"             # Edit file in new pane
```

### Environment Integration
- **Shell**: Uses enhanced zsh configuration
- **Editor**: Integrates with Neovim setup
- **Clipboard**: Native Wayland support
- **Colors**: Consistent with terminal theme

## 🎯 Workflow Examples

### Starting a Development Session
```bash
# Create new session for project
zj new-session project-name

# Or attach to existing
zja project-name

# Use development layout
# (automatically applied for development directories)
```

### File Management Workflow
```bash
# Open file manager
e          # Opens strider in floating pane

# Navigate and select files
# Use vim-style navigation in strider

# Open selected file in editor pane
# File opens in appropriate pane automatically
```

### Multi-Pane Development
```bash
# Start with development layout
# Split for additional terminal if needed
-          # Horizontal split for logs/terminal

# Use floating panes for temporary work  
f          # Toggle floating pane for quick tasks

# Focus management
z          # Fullscreen current pane when needed
```

## 📊 Performance Features

### Startup Optimization
- **Fast initialization**: Minimal startup overhead
- **Efficient plugins**: Optimized plugin loading
- **Smart defaults**: Performance-oriented configuration

### Memory Management
- **Session persistence**: Efficient session storage
- **Plugin management**: Controlled plugin resource usage
- **Scrollback limits**: Reasonable buffer sizes

### Responsiveness
- **Native performance**: Written in Rust for speed
- **Efficient rendering**: Optimized terminal rendering
- **Low latency**: Minimal input lag

## 🔗 Integration Points

### Development Tools
- **Neovim**: Seamless editor integration
- **Git**: Status awareness and integration
- **Language servers**: Proper LSP functionality
- **Debuggers**: Debug session management

### Shell Environment
- **Zsh**: Full integration with enhanced zsh config
- **Starship**: Prompt compatibility
- **Modern tools**: Integration with eza, bat, fzf, etc.

### System Integration
- **Clipboard**: Native Wayland/X11 support
- **Notifications**: Desktop notification integration
- **File associations**: Proper file type handling

## 🔧 Customization

### Adding Custom Layouts
Create layout files in `~/.config/zellij/layouts/`:
```kdl
layout {
    pane split_direction="vertical" {
        pane size="70%" {
            name "main"
        }
        pane size="30%" {
            name "side"
        }
    }
}
```

### Custom Keybindings
Modify keybindings in configuration:
```nix
keybinds = {
  normal = {
    "bind \"key\"" = { Action = "parameter"; };
  };
}
```

### Plugin Configuration
Add plugins to the plugins array:
```nix
plugins = [
  "existing-plugins"
  "new-plugin-name"
]
```

## 🆚 Comparison with Tmux

### Advantages of Zellij
- **Modern architecture**: Built-in features vs plugins
- **Better defaults**: Less configuration needed
- **Plugin system**: First-class plugin support
- **Layouts**: Built-in layout management
- **Session management**: Advanced session features

### When to Use Zellij vs Tmux
**Use Zellij when:**
- Starting fresh with terminal multiplexing
- Preferring modern defaults and architecture
- Wanting built-in session management
- Needing advanced layout features

**Use Tmux when:**
- Already comfortable with tmux workflows
- Requiring specific tmux plugins
- Working in environments where tmux is standard
- Needing maximum compatibility

## 🐛 Troubleshooting

### Common Issues

#### Session Not Persisting
1. **Check permissions**: Ensure zellij can write to config directory
2. **Verify settings**: Confirm `session_serialization = true`
3. **Storage space**: Check available disk space

#### Keybindings Not Working
1. **Mode awareness**: Ensure you're in correct mode
2. **Check conflicts**: Verify no conflicting keybindings
3. **Terminal compatibility**: Some terminals may intercept keys

#### Layout Issues
1. **Layout files**: Check layout file syntax
2. **Permissions**: Verify layout files are readable
3. **Plugin status**: Ensure layout plugins are loaded

#### Performance Issues
1. **Plugin optimization**: Disable unnecessary plugins
2. **Terminal performance**: Check terminal emulator performance
3. **Session cleanup**: Remove old unused sessions

### Debug Information
```bash
# Show current configuration
zellij setup --dump-config

# List active sessions
zellij list-sessions

# Session information
zellij attach --create-if-not-exists debug

# Plugin status
# (Available within zellij session)
```

## 📚 References

- [Zellij Documentation](https://zellij.dev/documentation/)
- [Zellij Layouts](https://zellij.dev/documentation/layouts.html)
- [Plugin Development](https://zellij.dev/documentation/plugins.html)
- [Configuration Guide](https://zellij.dev/documentation/configuration.html)
- [Gruvbox Theme](https://github.com/morhetz/gruvbox)