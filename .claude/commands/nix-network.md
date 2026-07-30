# NixOS Network Management

Comprehensive network monitoring, diagnostics, and stability management across all infrastructure hosts.

**Replaces Justfile recipes**: `network-monitor`, `network-check`, `ping-hosts`, `status-all`

## Quick Usage

**Monitor network continuously**:

```
/nix-network
Monitor network
```

**Check network stability**:

```
/nix-network
Check stability
```

**Ping all hosts**:

```
/nix-network
Ping all hosts
```

**Show host status**:

```
/nix-network
Status all hosts
```

## Features

### Network Monitoring Operations

**Monitor** (continuous):

- ✅ Real-time network interface monitoring
- ✅ DNS resolution verification
- ✅ Default route change detection
- ✅ Comprehensive logging to ~/network-monitor.log
- ✅ Automatic log rotation (10MB max)
- ✅ Interface addition/removal detection
- ✅ Route table change tracking
- ✅ 10-second check intervals

**Check Stability** (continuous service):

- ✅ Network interface change detection
- ✅ Automatic DNS resolution recovery
- ✅ systemd-resolved restart on DNS failures
- ✅ Application notification system
- ✅ Event logging to systemd journal
- ✅ 5-second stability checks
- ✅ Network stabilization measures
- ✅ Background service operation

**Ping Hosts** (instant):

- ✅ Check all infrastructure hosts reachability
- ✅ Tests: p620, razer, p510
- ✅ 2-second timeout per host
- ✅ Clear reachability status
- ✅ Parallel ping execution
- ✅ Color-coded results (✅/❌)

**Status All** (5 seconds):

- ✅ Comprehensive host status overview
- ✅ Network connectivity check
- ✅ Service availability
- ✅ DNS resolution status
- ✅ Interface health
- ✅ Summary statistics

### Diagnostic Operations

**Check DNS**:

- ✅ Test resolution for multiple domains
- ✅ Verifies: cloudflare.com, google.com, nixos.org
- ✅ 2-second timeout per domain
- ✅ systemd-resolved status check
- ✅ /etc/resolv.conf verification

**Check Interfaces**:

- ✅ List all network interfaces (excluding loopback)
- ✅ Show interface status (UP/DOWN)
- ✅ Display IP addresses
- ✅ Interface type identification
- ✅ Link state information

**Check Routes**:

- ✅ Display default gateway routes
- ✅ Show routing table
- ✅ Identify primary interface
- ✅ Metric comparison
- ✅ Multi-path route detection

## Network Monitoring Workflow

### Continuous Monitoring Setup

```bash
# 1. Start continuous monitoring
/nix-network
Monitor network

# Monitor runs in foreground with real-time output
# Logs everything to ~/network-monitor.log

# 2. Check the log file
tail -f ~/network-monitor.log

# 3. Stop monitoring (Ctrl+C)
```

### Stability Service Setup

```bash
# 1. Enable network stability checking
/nix-network
Check stability

# Service runs in background
# Automatically restarts DNS on failures
# Creates /run/network-stability-event for apps

# 2. Check service status
systemctl status network-stability

# 3. View service logs
journalctl -u network-stability -f
```

### Quick Host Check

```bash
# Check all hosts are reachable
/nix-network
Ping all hosts

# Sample output:
# p620: ✅ reachable
# razer: ✅ reachable
# p510: ✅ reachable
```

### Comprehensive Status

```bash
# Get full infrastructure status
/nix-network
Status all hosts

# Shows:
# - Host reachability
# - Network interfaces
# - DNS resolution
# - Route configuration
```

## Output Format

### Monitor Network Output

```
🌐 Network Stability Monitor

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Starting Monitoring
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Log File: ~/network-monitor.log
Check Interval: 10 seconds
Max Log Size: 10 MB

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Network Interfaces
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
eth0    UP    192.168.1.100/24
wlan0   UP    192.168.1.101/24
tailscale0 UP 100.64.0.1/32

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Default Routes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
default via 192.168.1.1 dev eth0 proto dhcp metric 100

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DNS Servers
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
nameserver 100.100.100.100  (Tailscale)
nameserver 192.168.1.1       (Router)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Live Monitoring
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2025-01-15 10:23:15 - Starting network stability monitor
2025-01-15 10:23:25 - DNS check: ✅ All domains resolved
2025-01-15 10:23:35 - No network changes detected
2025-01-15 10:23:45 - DNS check: ✅ All domains resolved

[Continues monitoring every 10 seconds...]

Press Ctrl+C to stop monitoring
```

### Network Change Detected Output

```
2025-01-15 10:24:15 - Network interface change detected:
2025-01-15 10:24:15 - Before:
2025-01-15 10:24:15 -   eth0    UP    192.168.1.100/24
2025-01-15 10:24:15 -   wlan0   DOWN
2025-01-15 10:24:15 - After:
2025-01-15 10:24:15 -   eth0    UP    192.168.1.100/24
2025-01-15 10:24:15 -   wlan0   UP    192.168.1.101/24

2025-01-15 10:24:17 - Default route change detected:
2025-01-15 10:24:17 - Before:
2025-01-15 10:24:17 -   default via 192.168.1.1 dev eth0
2025-01-15 10:24:17 - After:
2025-01-15 10:24:17 -   default via 192.168.1.1 dev eth0 metric 100
2025-01-15 10:24:17 -   default via 192.168.1.1 dev wlan0 metric 200
```

### DNS Resolution Failure Output

```
2025-01-15 10:25:30 - DNS resolution failed for cloudflare.com
2025-01-15 10:25:30 - DNS resolution issues detected
2025-01-15 10:25:32 - Restarting systemd-resolved
2025-01-15 10:25:35 - DNS check: ✅ All domains resolved
```

### Ping All Hosts Output

```
🏓 Pinging Infrastructure Hosts

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Host Reachability
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

p620:    ✅ reachable (1.2ms)
razer:   ✅ reachable (2.4ms)
p510:    ✅ reachable (0.8ms)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Reachable: 3/3 hosts (100%)
```

### Status All Hosts Output

```
📊 Infrastructure Network Status

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Host Connectivity
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

p620 (AMD Workstation):
  Status:      ✅ Online
  IP:          192.168.1.100
  Tailscale:   100.64.0.1
  Latency:     1.2ms
  Services:    Monitoring server, binary cache

razer (Intel/NVIDIA Laptop):
  Status:      ✅ Online
  IP:          192.168.1.101
  Tailscale:   100.64.0.2
  Latency:     2.4ms
  Services:    Mobile development

p510 (Intel Xeon Server):
  Status:      ✅ Online
  IP:          192.168.1.127
  Tailscale:   100.64.0.3
  Latency:     0.8ms
  Services:    Media server, headless

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Network Health
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ DNS Resolution: Working
✅ Default Gateway: 192.168.1.1
✅ Tailscale VPN: Active

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Interface Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
eth0:       UP (192.168.1.100/24)
tailscale0: UP (100.64.0.1/32)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Hosts: 3
Online: 3 (100%)
Offline: 0 (0%)
Network Health: Good
```

## Implementation Details

### Monitor Network Command

```bash
# Run continuous monitoring script
./scripts/network-monitor.sh

# What it does:
# - Logs to ~/network-monitor.log
# - Checks interfaces every 10s
# - Verifies DNS every 10s
# - Tracks route changes
# - Rotates logs at 10MB
```

### Check Stability Command

```bash
# Run stability helper as background service
./scripts/network-stability-helper.sh &

# What it does:
# - Monitors interfaces every 5s
# - Restarts DNS on failures
# - Creates /run/network-stability-event
# - Logs to systemd journal
```

### Ping Hosts Command

```bash
# Ping all infrastructure hosts
for host in p620 razer p510; do
  echo -n "$host: "
  ping -c 1 -W 2 $host >/dev/null 2>&1 && \
    echo "✅ reachable" || echo "❌ unreachable"
done
```

### Status All Command

```bash
# Get comprehensive status
ping-hosts  # Check connectivity
ip -brief address show  # Interface status
ip route show default  # Default routes
resolvectl status  # DNS configuration
```

## Network Diagnostic Commands

### Check DNS Resolution

```bash
# Test DNS for multiple domains
/nix-network
Check DNS

# Tests:
host -W 2 cloudflare.com
host -W 2 google.com
host -W 2 nixos.org

# Also checks systemd-resolved status
```

### Check Network Interfaces

```bash
# Show all interfaces
/nix-network
Check interfaces

# Shows:
ip -brief address show
# Excludes loopback (lo)
```

### Check Routing

```bash
# Display routing table
/nix-network
Check routes

# Shows:
ip route show
ip route show default
```

### Test Specific Host

```bash
# Ping individual host
/nix-network
Ping p620

# Shows:
ping -c 1 -W 2 p620
# Result with latency
```

## Network Troubleshooting

### Host Unreachable

```bash
# 1. Check if host is reachable
/nix-network
Ping p620

# 2. Check network status
/nix-network
Status all hosts

# 3. Check routing
/nix-network
Check routes

# 4. Verify Tailscale
tailscale status
```

### DNS Resolution Failing

```bash
# 1. Check DNS
/nix-network
Check DNS

# 2. If failing, check systemd-resolved
systemctl status systemd-resolved
resolvectl status

# 3. Restart DNS if needed
sudo systemctl restart systemd-resolved

# 4. Verify resolution works
/nix-network
Check DNS
```

### Interface Changes Causing Issues

```bash
# 1. Start monitoring to see changes
/nix-network
Monitor network

# 2. Watch for interface events in real-time
tail -f ~/network-monitor.log

# 3. Enable stability service
/nix-network
Check stability

# 4. Check if issues persist
journalctl -u network-stability -f
```

### Network Instability

```bash
# 1. Enable both monitoring tools
/nix-network
Monitor network
# (In another terminal)
/nix-network
Check stability

# 2. Review logs for patterns
tail -100 ~/network-monitor.log
journalctl -u network-stability -n 100

# 3. Check for common issues:
# - Multiple default routes
# - Interface flapping
# - DNS timeouts
# - Route metric conflicts
```

## Best Practices

### DO ✅

- Run monitoring when diagnosing network issues
- Enable stability checking for Electron apps
- Regularly ping hosts to verify connectivity
- Check logs when network issues occur
- Monitor during network configuration changes
- Use Tailscale for reliable host-to-host communication
- Keep logs rotated automatically (10MB max)
- Check DNS resolution when experiencing connectivity issues

### DON'T ❌

- Leave monitoring running indefinitely (use for diagnostics only)
- Ignore network change notifications in logs
- Skip DNS checks when troubleshooting
- Modify network scripts without testing
- Disable systemd-resolved without replacement
- Ignore repeated interface change events
- Let log files grow unbounded
- Assume all hosts are always reachable

## Integration with Other Commands

### With Deployment

```bash
# Before deploying to remote hosts
/nix-network
Ping all hosts

# If hosts unreachable, check network
/nix-network
Status all hosts

# Deploy when network is stable
/nix-deploy
Deploy to p620
```

### With Monitoring

```bash
# Check network before starting monitoring
/nix-network
Status all hosts

# If network unstable, enable stability
/nix-network
Check stability

# Monitor network during infrastructure changes
/nix-network
Monitor network
```

### With Testing

```bash
# Verify hosts reachable before testing
/nix-network
Ping all hosts

# Run tests on available hosts
/nix-test p620
/nix-test razer
```

## Related Commands

- `/nix-deploy` - Deploy requires network connectivity
- `/nix-info` - System information includes network status
- `/nix-validate` - Validation may check network configuration

---

**Pro Tip**: Enable network stability checking as a systemd service for continuous monitoring:

```bash
# Create systemd service
sudo systemctl edit --force --full network-stability.service

# Add:
[Unit]
Description=Network Stability Monitor
After=network.target

[Service]
Type=simple
ExecStart=/home/olafkfreund/.config/nixos/scripts/network-stability-helper.sh
Restart=always

[Install]
WantedBy=multi-user.target

# Enable and start
sudo systemctl enable --now network-stability.service

# Check status
systemctl status network-stability
```

Monitor your network proactively for stable infrastructure! 🌐
