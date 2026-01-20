---
name: tailscale
version: 1.0
description: Tailscale Skill
---

# Tailscale Skill

> **NixOS Tailscale VPN Configuration, Testing, and Monitoring**
>
> Comprehensive guide for configuring, securing, testing, and monitoring Tailscale mesh VPN on NixOS infrastructure.

## Overview

This skill provides expertise in Tailscale VPN configuration on NixOS, covering:

- **Configuration**: Service setup, routing features, firewall integration
- **Security**: Network hardening, DNS management, privacy settings
- **Testing**: Connection validation, performance testing, routing verification
- **Monitoring**: Status checks, connectivity monitoring, troubleshooting
- **Integration**: Network stability, systemd services, multi-host management

## Quick Reference

### Current Infrastructure Setup

**Active Hosts with Tailscale:**

- **P620**: AMD workstation - `useRoutingFeatures = "both"` (router + client)
- **P510**: Intel Xeon server - `useRoutingFeatures = "both"` (router + client)
- **Razer**: Intel/NVIDIA laptop - `useRoutingFeatures = "client"` (client only)
- **Samsung**: Intel laptop - `useRoutingFeatures = "client"` (client only)

**Common Configuration Pattern:**

```nix
services.tailscale = {
  enable = true;
  useRoutingFeatures = "both" | "client" | "server";
  openFirewall = true;
};

networking.firewall = {
  checkReversePath = "loose";  # Required for exit nodes
  trustedInterfaces = [ "tailscale0" ];
};
```

## Configuration Patterns

### 1. Basic Service Setup

**Standard Configuration:**

```nix
# In hosts/HOSTNAME/configuration.nix
services.tailscale = {
  enable = true;
  openFirewall = true;
};

# Required firewall adjustments
networking.firewall = {
  checkReversePath = "loose";  # Fixes exit node connectivity
  trustedInterfaces = [ "tailscale0" ];
};
```

**After deployment, authenticate:**

```bash
sudo tailscale up --auth-key=tskey-auth-XXXXX
# Or interactive: sudo tailscale up
```

### 2. Routing Features

**Subnet Router (Server):**

```nix
services.tailscale = {
  enable = true;
  useRoutingFeatures = "server";  # Can advertise routes
  openFirewall = true;
};
```

**Exit Node Client:**

```nix
services.tailscale = {
  enable = true;
  useRoutingFeatures = "client";  # Can use exit nodes
  openFirewall = true;
};
```

**Both Capabilities:**

```nix
services.tailscale = {
  enable = true;
  useRoutingFeatures = "both";  # Router + client
  openFirewall = true;
};
```

### 3. Advanced Configuration Options

**Privacy Mode (Disable Telemetry):**

```nix
services.tailscale = {
  enable = true;
  extraDaemonFlags = [ "--no-logs-no-support" ];
};
```

**Custom Port:**

```nix
services.tailscale = {
  enable = true;
  port = 41641;  # Default port (can be changed)
};
```

**Userspace Networking (Containers):**

```nix
services.tailscale = {
  enable = true;
  interfaceName = "userspace-networking";
};
```

**Firewall Bypass Prevention:**

```nix
services.tailscale = {
  enable = true;
  extraSetFlags = [ "--netfilter-mode=nodivert" ];
};
```

### 4. DNS Management

**Option A: Let Tailscale Manage DNS (Simple):**

```nix
services.tailscale = {
  enable = true;
};
# Then run: sudo tailscale up --accept-dns=true
```

**Option B: Disable Tailscale DNS (Recommended for Complex Setups):**

```nix
# In host configuration
services.tailscale = {
  enable = true;
};

# Configure network-stability with DNS control
services.network-stability = {
  enable = true;
  secureDns = {
    enable = true;
    providers = [
      "1.1.1.1#cloudflare-dns.com"
      "8.8.8.8#dns.google"
    ];
  };
};

# Then run: sudo tailscale up --accept-dns=false
```

**Enable systemd-resolved (Recommended):**

```nix
services.resolved = {
  enable = true;
  dnssec = "allow-downgrade";
  dnsovertls = "opportunistic";
};
```

### 5. Auto-Connect Service

**Automated Connection on Boot:**

```nix
systemd.services.tailscale-autoconnect = {
  description = "Automatic connection to Tailscale";
  after = [ "network-pre.target" "tailscale.service" ];
  wants = [ "network-pre.target" "tailscale.service" ];
  wantedBy = [ "multi-user.target" ];
  serviceConfig.Type = "oneshot";

  script = ''
    # Wait for tailscaled to settle
    echo "Waiting for tailscale.service start completion..."
    sleep 5

    # Check if already connected
    status="$(${pkgs.tailscale}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -r .BackendState)"
    if [ "$status" != "Running" ]; then
      echo "Starting Tailscale connection..."
      ${pkgs.tailscale}/bin/tailscale up --accept-routes
    fi
  '';
};
```

### 6. HTTPS Certificates

**Provision Tailscale Certificates:**

```bash
# Get certificate for your machine
sudo tailscale cert ${MACHINE_NAME}.${TAILNET_NAME}.ts.net

# Certificates saved to:
# - /var/lib/tailscale/${MACHINE_NAME}.${TAILNET_NAME}.ts.net.crt
# - /var/lib/tailscale/${MACHINE_NAME}.${TAILNET_NAME}.ts.net.key
```

**Caddy Integration:**

```nix
services.tailscale = {
  enable = true;
  permitCertUid = "caddy";  # Allow Caddy to access certs
};
```

## Security Best Practices

### 1. Firewall Configuration

**Essential Firewall Rules:**

```nix
networking.firewall = {
  enable = true;  # Never disable!

  # Required for Tailscale
  checkReversePath = "loose";  # Allows exit node traffic
  trustedInterfaces = [ "tailscale0" ];  # Trust Tailscale interface

  # Optional: Restrict access
  allowedUDPPorts = [ ];  # Tailscale uses autodetected ports
  allowedTCPPorts = [ ];  # Add specific services if needed
};
```

**Service-Specific Opening:**

```nix
services.tailscale = {
  enable = true;
  openFirewall = true;  # Only opens required Tailscale ports
};
```

### 2. Access Control

**Use Tailscale ACLs (Admin Console):**

- Define which devices can access which services
- Implement zero-trust networking
- Use tags for grouping devices
- Enable MFA for sensitive operations

**Example ACL Policy:**

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:admin"],
      "dst": ["*:22", "*:80", "*:443"]
    },
    {
      "action": "accept",
      "src": ["tag:laptop"],
      "dst": ["tag:server:*"]
    }
  ]
}
```

### 3. Privacy Hardening

**Disable Logging and Telemetry:**

```nix
services.tailscale = {
  enable = true;
  extraDaemonFlags = [
    "--no-logs-no-support"  # Disable telemetry
  ];
};
```

**Key Expiry Management:**

```bash
# Set key expiry (default: 180 days)
sudo tailscale up --authkey=tskey-auth-XXX

# Disable key expiry (use carefully!)
sudo tailscale up --authkey=tskey-auth-XXX --force-reauth
```

### 4. Network Isolation

**Prevent Firewall Bypass:**

```nix
services.tailscale = {
  enable = true;
  extraSetFlags = [
    "--netfilter-mode=nodivert"  # Don't bypass firewall
  ];
};
```

## Testing and Validation

### 1. Connection Status

**Check Tailscale Status:**

```bash
# Basic status
sudo tailscale status

# Detailed status with JSON
sudo tailscale status --json | jq

# Check specific peer
sudo tailscale status | grep HOSTNAME

# Show listening ports
sudo tailscale status --peers
```

**Verify Network Configuration:**

```bash
# Check Tailscale IP
ip addr show tailscale0

# Check routing table
ip route show | grep tailscale

# Test DNS resolution
resolvectl status tailscale0
```

### 2. Connectivity Testing

**Ping Tests:**

```bash
# Ping another Tailscale device by hostname
ping p620.tailXXXXX.ts.net

# Ping by Tailscale IP
ping 100.x.x.x

# Test with different packet sizes
ping -s 1400 p510.tailXXXXX.ts.net
```

**Connection Quality:**

```bash
# Check latency
sudo tailscale ping p620

# Check path and DERP relay
sudo tailscale ping --verbose p620

# Netcheck (STUN/connection quality)
sudo tailscale netcheck
```

### 3. Route Testing

**Subnet Router Verification:**

```bash
# On router: Advertise routes
sudo tailscale up --advertise-routes=192.168.1.0/24

# On client: Accept routes
sudo tailscale up --accept-routes

# Verify route propagation
ip route | grep via | grep 100.
```

**Exit Node Testing:**

```bash
# On server: Advertise as exit node
sudo tailscale up --advertise-exit-node

# On client: Use exit node
sudo tailscale up --exit-node=p620

# Verify external IP (should be exit node's public IP)
curl ifconfig.me

# Check exit node status
sudo tailscale status | grep "exit node"
```

### 4. Performance Testing

**Bandwidth Testing:**

```bash
# Install iperf3
nix-shell -p iperf3

# On server
iperf3 -s

# On client (via Tailscale)
iperf3 -c p620.tailXXXXX.ts.net

# UDP test
iperf3 -c p620.tailXXXXX.ts.net -u -b 100M
```

**Latency Testing:**

```bash
# Continuous ping test
ping -c 100 -i 0.2 p620.tailXXXXX.ts.net | \
  tail -1 | awk '{print $4}' | cut -d'/' -f2

# MTR (traceroute + ping)
mtr --report --report-cycles 10 p620.tailXXXXX.ts.net
```

### 5. DNS Testing

**DNS Resolution Verification:**

```bash
# Check if Tailscale DNS is working
nslookup p620.tailXXXXX.ts.net

# Check MagicDNS
dig +short p620.tailXXXXX.ts.net

# Verify DNS configuration
resolvectl status

# Check systemd-resolved
systemd-resolve --status tailscale0
```

## Monitoring

### 1. Service Health

**Systemd Status:**

```bash
# Check Tailscale service
systemctl status tailscaled

# Check for errors
journalctl -u tailscaled -f

# Recent logs
journalctl -u tailscaled --since "10 minutes ago"

# Service failures
systemctl --failed | grep tailscale
```

**Connection State:**

```bash
# Watch connection status
watch -n 5 'tailscale status --peers'

# Monitor in background
while true; do
  tailscale status --json | jq -r '.BackendState'
  sleep 30
done
```

### 2. Network Monitoring Script

**Create Monitoring Script:**

```bash
#!/usr/bin/env bash
# /usr/local/bin/monitor-tailscale.sh

echo "=== Tailscale Status ==="
sudo tailscale status --peers

echo -e "\n=== Connection Health ==="
for host in p620 p510 razer samsung; do
  echo -n "$host: "
  if sudo tailscale ping --c 1 "$host" &>/dev/null; then
    echo "✓ OK"
  else
    echo "✗ FAILED"
  fi
done

echo -e "\n=== DERP Connection ==="
sudo tailscale netcheck | grep -E "DERP|Latency"

echo -e "\n=== Service Status ==="
systemctl is-active tailscaled
```

### 3. Integration with Network Stability

**Tailscale + Network Stability Module:**

```nix
# Enable comprehensive monitoring
services.network-stability = {
  enable = true;

  # Monitor DNS and network health
  monitoring = {
    enable = true;
    interval = 30;  # Check every 30 seconds
  };

  # Secure DNS to avoid conflicts
  secureDns = {
    enable = true;
    providers = [
      "1.1.1.1#cloudflare-dns.com"
      "8.8.8.8#dns.google"
    ];
  };

  # Stability improvements
  connectionStability = {
    enable = true;
    switchDelayMs = 5000;
  };
};

# Tailscale with DNS control
services.tailscale = {
  enable = true;
  useRoutingFeatures = "both";
  openFirewall = true;
};

# Disable Tailscale DNS management
# Run: sudo tailscale up --accept-dns=false
```

### 4. Automated Health Checks

**Systemd Timer for Monitoring:**

```nix
systemd.timers.tailscale-health = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnBootSec = "5min";
    OnUnitActiveSec = "5min";
    Unit = "tailscale-health.service";
  };
};

systemd.services.tailscale-health = {
  serviceConfig = {
    Type = "oneshot";
    ExecStart = pkgs.writeShellScript "tailscale-health" ''
      #!/bin/sh
      status=$(${pkgs.tailscale}/bin/tailscale status --json | \
               ${pkgs.jq}/bin/jq -r .BackendState)

      if [ "$status" != "Running" ]; then
        echo "Tailscale not running: $status" | \
          ${pkgs.systemd}/bin/systemd-cat -t tailscale-health -p err
        ${pkgs.systemd}/bin/systemctl restart tailscaled
      fi
    '';
  };
};
```

## Troubleshooting

### Common Issues and Solutions

#### 1. No Internet via Exit Node

**Problem**: Can't access internet when using exit node

**Solution:**

```nix
# Add to configuration.nix
networking.firewall.checkReversePath = "loose";
```

**Verification:**

```bash
# Rebuild and test
sudo nixos-rebuild switch
sudo tailscale up --exit-node=p620
curl ifconfig.me  # Should show exit node's IP
```

#### 2. DNS Resolution Failures

**Problem**: Can't resolve .ts.net hostnames

**Solution A - Enable systemd-resolved:**

```nix
services.resolved = {
  enable = true;
  dnssec = "allow-downgrade";
  dnsovertls = "opportunistic";
};
```

**Solution B - Accept Tailscale DNS:**

```bash
sudo tailscale up --accept-dns=true
```

**Verification:**

```bash
resolvectl status tailscale0
nslookup p620.tailXXXXX.ts.net
```

#### 3. IPv6 Exit Node Issues

**Problem**: IPv6 doesn't work through exit nodes

**Solution:**

```nix
# Switch to nftables
networking.nftables.enable = true;

# May need to reboot
```

#### 4. High Latency / DERP Relay

**Problem**: Connection using DERP relay instead of direct

**Diagnosis:**

```bash
# Check connection path
sudo tailscale ping --verbose p620

# Check NAT traversal
sudo tailscale netcheck
```

**Solutions:**

- Port forward UDP 41641 on router
- Check firewall rules on both ends
- Verify UPnP is enabled on router
- Consider using Tailscale relay nodes

#### 5. Firewall Conflicts

**Problem**: Tailscale bypassing NixOS firewall rules

**Solution:**

```nix
services.tailscale = {
  enable = true;
  extraSetFlags = [ "--netfilter-mode=nodivert" ];
};
```

#### 6. Service Won't Start

**Diagnosis:**

```bash
# Check service status
systemctl status tailscaled

# View logs
journalctl -u tailscaled -n 50

# Check for port conflicts
ss -tulpn | grep 41641
```

**Solutions:**

```bash
# Reset Tailscale state
sudo systemctl stop tailscaled
sudo rm -rf /var/lib/tailscale/*
sudo systemctl start tailscaled
sudo tailscale up
```

#### 7. Key Expiration

**Problem**: Device disconnects after key expiry

**Solution:**

```bash
# Re-authenticate
sudo tailscale up --force-reauth

# Or disable key expiry in admin console
# Settings → Keys → Disable expiration
```

### Debug Commands

**Comprehensive Debug Output:**

```bash
# Full system status
sudo tailscale status --json | jq

# Network check
sudo tailscale netcheck

# DERP map
sudo tailscale netcheck --verbose

# Debug logs
sudo tailscale debug daemon-logs

# Local API status
curl -s --unix-socket /var/run/tailscale/tailscaled.sock \
  http://local-tailscaled.sock/localapi/v0/status | jq
```

## Advanced Configurations

### 1. Multi-Network Setup

**Configuration for Complex Networks:**

```nix
services.tailscale = {
  enable = true;
  useRoutingFeatures = "both";
  openFirewall = true;
  extraSetFlags = [
    "--advertise-routes=192.168.1.0/24,10.0.0.0/24"
    "--accept-routes"
  ];
};

# Trust multiple interfaces
networking.firewall = {
  checkReversePath = "loose";
  trustedInterfaces = [ "tailscale0" "br0" ];
};
```

### 2. Container/VM Integration

**Docker Container Access:**

```nix
# Enable Docker with Tailscale
virtualisation.docker.enable = true;

services.tailscale = {
  enable = true;
  useRoutingFeatures = "both";
};

# Containers can use host's Tailscale
# via --network host or by exposing ports
```

**MicroVM Integration:**

```nix
# In microvm configuration
services.tailscale = {
  enable = true;
  interfaceName = "userspace-networking";
};
```

### 3. Subnet Router Example

**Full Subnet Router Setup (P620):**

```nix
# P620 as primary router
services.tailscale = {
  enable = true;
  useRoutingFeatures = "server";
  openFirewall = true;
};

networking = {
  firewall = {
    checkReversePath = "loose";
    trustedInterfaces = [ "tailscale0" ];
    # Allow forwarding
    enable = true;
  };
  # Enable IP forwarding
  nat = {
    enable = true;
    externalInterface = "enp5s0";
    internalInterfaces = [ "tailscale0" ];
  };
};

# After deployment:
# sudo tailscale up --advertise-routes=192.168.1.0/24 \
#   --advertise-exit-node --accept-routes
```

## Integration Patterns

### 1. GitHub Workflow Integration

**Create Tailscale Configuration Issue:**

```bash
# Use the GitHub workflow
/nix-new-task

# Title: Configure Tailscale for new host
# Type: enhancement
# Priority: medium
# Description: Set up Tailscale VPN on new host with routing features
```

### 2. Deployment Workflow

**Safe Deployment Process:**

```bash
# 1. Test configuration locally
just check-syntax
just validate-quick

# 2. Test specific host
just test-host p620

# 3. Deploy with monitoring
just quick-deploy p620

# 4. Verify Tailscale
sudo tailscale status
sudo tailscale ping p510
```

### 3. Module Creation Pattern

**Create Tailscale Feature Module:**

```bash
# Use the module creation command
/nix-module

# Module name: tailscale-enhanced
# Location: modules/network/tailscale-enhanced.nix
# Features: Exit node, subnet router, monitoring
```

## Performance Optimization

### 1. DERP Server Selection

**Choose Optimal DERP:**

```bash
# Check all DERP servers
sudo tailscale netcheck

# Force specific DERP region
# Configure in admin console: Settings → DERP
```

### 2. MTU Optimization

**Adjust MTU for Performance:**

```bash
# Check current MTU
ip link show tailscale0

# Adjust if needed (usually auto-detected)
# Tailscale handles MTU automatically
```

### 3. Connection Optimization

**Network Tuning:**

```nix
boot.kernel.sysctl = {
  # Optimize for VPN traffic
  "net.core.rmem_max" = 134217728;
  "net.core.wmem_max" = 134217728;
  "net.ipv4.tcp_rmem" = "4096 87380 67108864";
  "net.ipv4.tcp_wmem" = "4096 65536 67108864";

  # Enable BBR congestion control
  "net.core.default_qdisc" = "fq";
  "net.ipv4.tcp_congestion_control" = "bbr";
};
```

## Quick Command Reference

### Essential Commands

```bash
# Status and Info
sudo tailscale status              # Connection status
sudo tailscale status --peers      # All peers
sudo tailscale status --json       # JSON output
sudo tailscale netcheck            # Network diagnostics

# Connection Management
sudo tailscale up                  # Connect/authenticate
sudo tailscale up --accept-routes  # Accept subnet routes
sudo tailscale up --exit-node=HOST # Use exit node
sudo tailscale down                # Disconnect
sudo tailscale logout              # Remove auth

# Testing
sudo tailscale ping HOST           # Test connectivity
sudo tailscale ping --c 5 HOST     # Ping count
sudo tailscale ping --verbose HOST # Detailed output

# Configuration
sudo tailscale set --accept-routes=true
sudo tailscale set --exit-node=p620
sudo tailscale set --advertise-routes=192.168.1.0/24

# Debugging
journalctl -u tailscaled -f        # Follow logs
sudo tailscale debug daemon-logs   # Debug output
sudo tailscale file get ~/Downloads # Receive files
```

### NixOS-Specific Commands

```bash
# Configuration validation
just check-syntax
just validate-quick
just test-host HOSTNAME

# Deployment
just quick-deploy HOSTNAME
nixos-rebuild switch --flake .#HOSTNAME

# Service management
systemctl status tailscaled
systemctl restart tailscaled
systemctl enable tailscaled
```

## References and Resources

### Official Documentation

- [Tailscale NixOS Wiki](https://nixos.wiki/wiki/Tailscale) - Official NixOS Tailscale documentation
- [Tailscale NixOS Guide](https://tailscale.com/kb/1096/nixos-minecraft) - Official Tailscale guide for NixOS
- [NixOS Search - Tailscale Options](https://search.nixos.org/options?query=services.tailscale) - Complete option reference

### Community Resources

- [Martin Baillie's Guide](https://martin.baillie.id/wrote/tailscale-support-for-nixos/) - Detailed Tailscale NixOS integration
- [Guekka's Server Guide](https://guekka.github.io/nixos-server-2/) - NixOS server with Tailscale setup

### Current Repository

- `home/network/tailscale.nix` - Current Tailscale module
- `hosts/p620/nixos/network-stability.nix` - Network stability integration
- `modules/services/network-stability.nix` - Network stability service
- `GEMINI.md` - Project-specific patterns and conventions

## Skill Usage

This skill activates automatically when you:

- Mention "Tailscale", "VPN", or "mesh network"
- Ask about networking, routing, or connectivity issues
- Request Tailscale configuration, testing, or monitoring
- Need help with Tailscale troubleshooting or optimization

**Example Prompts:**

- "Configure Tailscale on the new host with exit node support"
- "Why can't I access the internet through my Tailscale exit node?"
- "Test Tailscale connectivity between P620 and P510"
- "Monitor Tailscale connection health and create alerts"
- "Optimize Tailscale performance for high-latency connections"
- "Set up subnet routing from P620 to home network"
