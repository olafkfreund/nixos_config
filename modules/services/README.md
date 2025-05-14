# Network Stability Modules for NixOS

This directory contains modules designed to improve network stability and resolve common issues such as the `net::ERR_NETWORK_CHANGED` error in Electron applications.

## Modules Overview

### 1. secure-dns.nix

A DNS resolution enhancement module that provides stable DNS resolution even during network transitions.

**Key features:**
- DNS-over-TLS support
- DNSSEC validation
- Large DNS cache for better reliability
- Integration with NetworkManager and systemd-networkd
- Monitoring and automatic recovery

**Example usage:**
```nix
{
  services.secure-dns = {
    enable = true;
    dnssec = "true";
    fallbackProviders = [
      "1.1.1.1#cloudflare-dns.com"
      "8.8.8.8#dns.google"
    ];
    useStubResolver = true;
  };
}
```

### 2. network-monitoring.nix

A monitoring service that tracks network changes and helps diagnose connectivity issues.

**Key features:**
- Monitors interface changes
- Tracks DNS resolution
- Detects route changes
- Maintains comprehensive logs

**Example usage:**
```nix
{
  services.network-monitoring = {
    enable = true;
    monitorIntervalSeconds = 30;
    logDir = "/var/log/network-monitoring";
  };
}
```

### 3. network-stability.nix

A comprehensive module that ties together all stability enhancements.

**Key features:**
- Connection stability improvements
- Secure DNS integration
- Electron app optimizations
- Tailscale enhancement
- Network monitoring
- TCP/IP stack tuning

**Example usage:**
```nix
{
  services.network-stability = {
    enable = true;
    
    # Optional configuration adjustments
    monitoring.interval = 60;
    secureDns.providers = ["9.9.9.9#dns.quad9.net"];
    tailscale.acceptDns = false;
    connectionStability.switchDelayMs = 3000;
  };
}
```

## Resolving `net::ERR_NETWORK_CHANGED` Error

The `net::ERR_NETWORK_CHANGED` error occurs when an Electron application detects that the network connection has changed during an HTTP request. These modules work together to:

1. Stabilize network connections with delay timers
2. Enhance DNS resolution to prevent interruptions
3. Configure Electron apps to better handle network transitions
4. Optimize TCP/IP stack parameters for connection resilience
5. Monitor network changes to diagnose recurring issues

## Prerequisites

These modules have been integrated into the main NixOS configuration and can be enabled through the options shown in the examples.