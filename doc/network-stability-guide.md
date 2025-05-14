# Fixing net::ERR_NETWORK_CHANGED Errors in NixOS

This guide explains the solution for the `net::ERR_NETWORK_CHANGED` error that commonly affects Electron applications.

## Understanding the Error

The `net::ERR_NETWORK_CHANGED` error occurs when:

1. Your Electron application initiates a network request
2. During that request, your network connection changes in some way
3. Chromium (which powers Electron) detects this change and aborts the request

This error is especially common in environments with multiple network interfaces (wired/wireless), VPNs like Tailscale, or unstable connections.

## Implemented Solution

Our NixOS configuration now includes a comprehensive solution to address this error through several complementary modules:

### Network Stability Framework

A set of modules has been implemented to solve this issue:

- **Stable Connection Management**: Adds delays before switching network interfaces to prevent rapid switching
- **Enhanced DNS Resolution**: Configures DNS to be more resilient during network transitions
- **TCP/IP Stack Optimization**: Kernel parameters tuned for connection stability
- **Electron Application Patching**: Special configuration for Electron apps to better handle network changes
- **Tailscale Enhancement**: Improved Tailscale VPN configuration that doesn't disrupt connections
- **Network Monitoring**: Tools to track and diagnose network stability issues

### How to Enable the Solution

The solution can be enabled on any host by:

1. Either importing the example configuration:
   ```nix
   imports = [
     ../../modules/services/network-stability-example.nix
   ];
   ```

2. Or by directly enabling the network stability service:
   ```nix
   services.network-stability.enable = true;
   ```

### Fine-tuning for Your System

You can adjust parameters based on your specific system:

```nix
services.network-stability = {
  enable = true;
  
  # Monitoring configuration
  monitoring = {
    enable = true;
    interval = 30; # Seconds between checks
  };
  
  # Connection stability settings
  connectionStability = {
    switchDelayMs = 5000; # Milliseconds to wait before switching networks
  };
  
  # Other customizable parameters
  secureDns.providers = [
    "1.1.1.1#cloudflare-dns.com"
    "8.8.8.8#dns.google"
  ];
  
  tailscale.acceptDns = false;
  electron.improve = true;
};
```

## Troubleshooting

If you're still experiencing the error after enabling the solution:

1. Run the monitoring script to diagnose network issues:
   ```bash
   sudo network-monitor
   ```

2. Check logs for network changes:
   ```bash
   journalctl -u network-monitoring -f
   ```

3. Try increasing the `connectionStability.switchDelayMs` value to a higher setting.

4. For specific Electron applications, you can launch them with enhanced stability:
   ```bash
   electron-wayland-launcher /path/to/app
   ```

## Technical Details

The solution works by implementing the following strategies:

- **Delay Network Transitions**: Add delay timers before interface switching
- **DNS Redundancy**: Multiple DNS providers with DNS-over-TLS and caching
- **Connection Persistence**: TCP keepalive and stability optimizations
- **Electron Resilience**: Custom Electron flags for better network handling
- **Proactive Monitoring**: Early detection of network changes

These solutions are designed to work together to prevent the underlying conditions that cause the `net::ERR_NETWORK_CHANGED` error.

## Module Locations

- `/modules/services/network-stability.nix`: Main stability service
- `/modules/services/dns/secure-dns.nix`: Enhanced DNS resolution
- `/modules/services/network-monitoring.nix`: Network monitoring service
- `/modules/common/networking.nix`: Enhanced networking module
- `/modules/common/electron.nix`: Electron app improvements
- `/modules/services/tailscale/default.nix`: Tailscale enhancements

The implementation follows NixOS best practices with proper module structure, option documentation, and functional programming patterns.