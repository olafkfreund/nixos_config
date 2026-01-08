# rescreenshot-mcp NixOS Package

Cross-platform screenshot MCP server for Claude Desktop with Wayland, X11, and Windows support.

## Overview

This package provides the `rescreenshot-mcp` MCP server, allowing Claude Desktop to capture
screenshots of your desktop and applications. It's particularly well-suited for NixOS Hyprland
setups with proper portal-based consent flows.

## Installation

### Option 1: Using the NixOS Module (Recommended)

Enable the service in your NixOS configuration:

```nix
# In your host configuration (e.g., hosts/p620/configuration.nix)
services.rescreenshot-mcp = {
  enable = true;
  user = "yourusername";  # Replace with your username
  logLevel = "info";      # Options: trace, debug, info, warn, error
};
```

This will:

- Install the `rescreenshot-mcp` package
- Enable required runtime dependencies (PipeWire, xdg-desktop-portal)
- Automatically configure Claude Desktop

Rebuild and switch:

```bash
sudo nixos-rebuild switch
```

### Option 2: Manual Package Installation

Add to your system packages:

```nix
environment.systemPackages = with pkgs; [
  (callPackage ./pkgs/rescreenshot-mcp { })
];
```

Then manually configure Claude Desktop (see Configuration section below).

## Configuration

### Claude Desktop Configuration

If not using the automatic module configuration, edit:

- Linux: `~/.config/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

Add:

```json
{
  "mcpServers": {
    "screenshot": {
      "command": "/run/current-system/sw/bin/rescreenshot-mcp",
      "env": {
        "RUST_LOG": "info"
      }
    }
  }
}
```

### Wayland Consent Flow

On first use, you'll see a portal dialog requesting permission to capture your screen. This is a
one-time consent flow - the permission is stored securely and reused.

## Features

- **Production-ready**: Stable, tested cross-platform screenshot functionality
- **Portal-based security**: Uses xdg-desktop-portal for secure Wayland screen capture
- **Multiple formats**: WebP (default), PNG, or JPEG with configurable quality
- **Advanced options**: Region cropping, cursor inclusion, resize capabilities
- **High performance**: P95 latency ~300ms on Wayland

## MCP Tools

The server provides the following tools:

- `health_check` - Detects platform and backend availability
- `list_windows` - Enumerates capturable windows
- `capture_window` - Screenshots windows with crop/scale options
- `prime_wayland_consent` - Initiates Wayland permission flow

## Troubleshooting

### Portal not running

```bash
systemctl --user status xdg-desktop-portal
systemctl --user start xdg-desktop-portal
```

### Permission denied errors

Run the consent priming command:

```bash
rescreenshot-mcp prime_wayland_consent
```

### Check server status

```bash
journalctl --user -u configure-rescreenshot-mcp
```

## System Requirements

- NixOS with Wayland (Hyprland, Sway, etc.) or X11
- PipeWire (enabled by default with the module)
- xdg-desktop-portal-gtk (or -kde for KDE users)

## Dependencies

This package requires the following system libraries:

- openssl
- wayland
- libportal
- libsecret
- libxkbcommon
- libX11
- libxcb
- pipewire
- libGL
- mesa
- libgbm
- clang (build-time only)

All dependencies are automatically handled by the Nix package.

## Security

- Uses portal-based consent flow (much safer than full input control)
- One-time permission with secure token storage
- No external API keys or services required
- Runs with minimal privileges

## License

MIT License - See upstream repository for details.

## Upstream

- Repository: <https://github.com/becksclair/rescreenshot-mcp>
- Version: 0.6.0-unstable-2025-01-08
- Commit: 5c23e28613ac3f93b31038ca692510e7521f04a0
