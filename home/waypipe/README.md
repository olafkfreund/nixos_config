# WayPipe for NixOS

WayPipe enables you to run graphical applications remotely and display them locally under a Wayland compositor. This is similar to X11 forwarding but designed specifically for the Wayland protocol.

## Overview

This NixOS Home Manager configuration sets up WayPipe with both client and server systemd services that run automatically, making remote Wayland application usage seamless.

## Features

- **Client Mode**: Runs a WayPipe client socket for receiving remote applications
- **Server Mode**: Runs a WayPipe server with dedicated Wayland display for sending applications
- **Automatic Setup**: Both components start automatically with your desktop session
- **SSH Integration**: Works with standard SSH connections

## How It Works

The configuration creates:

1. A client socket at `~/.waypipe/client.sock` that receives application data
2. A server socket at `~/.waypipe/server.sock` that sends application data
3. A dedicated Wayland display named `wayland-waypipe` for remote applications

## Usage

### Run a Remote Graphical Program

```bash
waypipe ssh user@remote-server program-name
```

This will:

1. Connect to the remote server via SSH
2. Run the specified program on the remote server
3. Display its GUI locally on your machine

### Open an SSH Tunnel for Multiple Programs

```bash
waypipe ssh user@remote-server
```

This will:

1. Open an SSH connection to the remote server
2. Allow you to run multiple graphical programs over that connection
3. Each program will appear as a local window on your machine

### Session Management

Both client and server components are managed by systemd:

- The client service starts with your graphical session (e.g., when you log in)
- The server service runs continuously in the background

## Configuration Details

The setup consists of two systemd user services:

1. **waypipe-client**:
   - Creates and manages the client socket
   - Automatically starts with your graphical session
   - Cleans up when the session ends

2. **waypipe-server**:
   - Creates a dedicated Wayland display `wayland-waypipe`
   - Adds a hostname prefix to window titles for easy identification
   - Runs continuously in the background

## Troubleshooting

If you experience issues:

1. Check socket availability:

   ```bash
   ls -la ~/.waypipe/
   ```

2. Verify the services are running:

   ```bash
   systemctl --user status waypipe-client
   systemctl --user status waypipe-server
   ```

3. Restart the services if needed:

   ```bash
   systemctl --user restart waypipe-client
   systemctl --user restart waypipe-server
   ```

## Additional Resources

- [WayPipe GitHub Repository](https://gitlab.freedesktop.org/mstoeckl/waypipe)
- [Wayland Documentation](https://wayland.freedesktop.org/)
