# Network Stability Guide

This guide explains the comprehensive network stability improvements implemented in this NixOS configuration to prevent `net::ERR_NETWORK_CHANGED` errors in Electron applications.

## Overview

The network stability solution consists of several integrated components:

1. **Network Stability Module** - Core module with stability enhancement options
2. **Network Monitoring Service** - Monitors network interfaces and connections
3. **Network Stability Helper** - Provides active mitigation for network changes
4. **Electron Application Enhancements** - Environment variables for better network handling

## Configuration Options

### Basic Usage

Enable network stability in your host configuration:

```nix
{
  services.network-stability = {
    enable = true;
  };
}
```

### Full Configuration

```nix
{
  services.network-stability = {
    enable = true;

    # Monitoring configuration
    monitoring = {
      enable = true;        # Enable monitoring service
      interval = 30;        # Check interval in seconds
    };

    # Secure DNS configuration
    secureDns = {
      enable = true;
      providers = [
        "1.1.1.1#cloudflare-dns.com"
        "8.8.8.8#dns.google"
      ];
    };

    # Tailscale integration
    tailscale = {
      enhance = true;
      acceptDns = false;    # Don't let Tailscale manage DNS
    };

    # Electron application improvements
    electron = {
      improve = true;
    };

    # Connection stability settings
    connectionStability = {
      enable = true;
      switchDelayMs = 5000;  # Delay before switching interfaces
    };

    # Helper service configuration
    helperService = {
      enable = true;
      startDelay = 5;        # Delay before starting
      restartSec = 30;       # Restart interval on failure
    };

    # Custom script path if needed
    scriptPath = ./scripts/network-stability-helper.sh;
  };
}
```

## Environment Variables

For Electron applications, the following environment variables are set:

| Variable                                         | Value   | Purpose                                         |
| ------------------------------------------------ | ------- | ----------------------------------------------- |
| `DISABLE_REQUEST_THROTTLING`                     | `1`     | Prevents limiting concurrent requests           |
| `ELECTRON_FORCE_WINDOW_MENU_BAR`                 | `1`     | Improves UI stability during network changes    |
| `CHROME_NET_TCP_SOCKET_CONNECT_TIMEOUT_MS`       | `60000` | Increases connection timeouts to 60 seconds     |
| `CHROME_NET_TCP_SOCKET_CONNECT_ATTEMPT_DELAY_MS` | `2000`  | Adds 2-second delay between connection attempts |

## Monitoring and Troubleshooting

### View Network Stability Logs

```bash
# View network monitoring logs
journalctl -u network-monitoring -f

# View network stability helper logs
journalctl -u network-stability-helper -f

# Check network event logs
cat /var/log/network-monitoring/events.json
```

### Common Issues and Solutions

#### Electron App Still Disconnecting

If an application still shows `net::ERR_NETWORK_CHANGED` errors:

1. Increase the connection delay:

   ```nix
   services.network-stability.connectionStability.switchDelayMs = 10000;
   ```

2. Add more DNS providers:

   ```nix
   services.network-stability.secureDns.providers = [
     "1.1.1.1#cloudflare-dns.com"
     "8.8.8.8#dns.google"
     "9.9.9.9#dns.quad9.net"
   ];
   ```

3. Launch the application with the helper script:

   ```bash
   electron-net-stable your-electron-app
   ```

#### Network Interface Switching Issues

If experiencing problems with network interfaces switching too frequently:

1. Add interface priority in NetworkManager:

   ```nix
   networking.networkmanager.connectionConfig = {
     "connection.autoconnect-priority" = 10;  # Higher for preferred connections
   };
   ```

2. Adjust the TCP keepalive settings:

   ```nix
   boot.kernel.sysctl = {
     "net.ipv4.tcp_keepalive_time" = 600;
     "net.ipv4.tcp_keepalive_intvl" = 60;
   };
   ```

## Technical Details

### Network Monitoring

The network monitoring service regularly checks:

- Interface status changes
- Default route changes
- DNS resolution capability
- Connection stability

### Stability Helper

The helper service provides active mitigation:

- Detects network transitions
- Manages connection caching
- Prevents rapid interface switching
- Facilitates graceful handovers between connections

### Integration with systemd-networkd

For systems using systemd-networkd, these optimizations are applied:

- Link configuration for better stability
- Network configuration to handle carrier changes
- Proper dependency ordering between services

### Integration with NetworkManager

For systems using NetworkManager, these optimizations are applied:

- Connection ID stability across reboots
- Increased device timeout settings
- Enhanced mDNS resolution

## Hardware-Specific Optimizations

For optimal performance on specific hardware:

### AMD Systems (e.g., p620)

```nix
boot.kernel.sysctl = lib.mkMerge [
  # TCP optimizations for AMD
  {
    "net.ipv4.tcp_keepalive_time" = 600;
    "net.ipv4.tcp_keepalive_intvl" = 60;
    "net.ipv4.tcp_keepalive_probes" = 10;
    "net.ipv4.tcp_fin_timeout" = 30;
  }
  # BBR congestion control works well with AMD
  {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  }
];
```

### Intel Systems

```nix
boot.kernel.sysctl = lib.mkMerge [
  # TCP optimizations for Intel
  {
    "net.ipv4.tcp_keepalive_time" = 500;
    "net.ipv4.tcp_keepalive_intvl" = 45;
    "net.ipv4.tcp_keepalive_probes" = 8;
  }
  # CUBIC congestion control typically works well with Intel
  {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "cubic";
  }
];
```

## Further Customization

The network stability modules are designed to be customizable. Refer to the module options for additional configuration possibilities beyond the defaults presented here.
