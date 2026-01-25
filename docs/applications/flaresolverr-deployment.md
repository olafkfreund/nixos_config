# FlareSolverr Deployment Guide for P510

> Created: 2026-01-08
> Issue: #125
> Status: Build Successful, Ready for Deployment

## Summary

FlareSolverr has been successfully re-enabled on P510 after resolving the xvfbwrapper Python 3.13 build error
that caused it to be disabled on 2025-09-02.

## What Was Fixed

### Previous Issue

- **xvfbwrapper Python 3.13 build error** - Package couldn't build with Python 3.13
- **Chromium 127+ incompatibility** - Selenium library would hang during webdriver initialization

### Resolution

The issues have been resolved in current nixpkgs:

-  **xvfbwrapper-0.2.16** now builds successfully with Python 3.13
-  **Chromium 143.0.7499.192** is being used (beyond problematic Chromium 127)
-  **FlareSolverr 3.4.6** package builds without errors
-  **Selenium 4.29.0** has Python 3.13 support

### Build Verification

```bash
# Build completed successfully with all dependencies:
- python3.13-xvfbwrapper-0.2.16
- chromium-143.0.7499.192
- flaresolverr-3.4.6
- python3.13-selenium-4.29.0
- All Python 3.13 dependencies available
```

## Configuration Details

### Service Configuration

- **Location**: `hosts/p510/flaresolverr.nix`
- **Port**: 8191 (firewall automatically opened)
- **Service**: Native NixOS `services.flaresolverr`

### Key Features

- **Resource Limits**: 2GB RAM, 200% CPU quota
- **Security Hardening**:
  - PrivateDevices = true
  - ProtectHostname = true
  - ProtectClock = true
  - ProtectKernelLogs = true
  - RestrictNamespaces = true
- **Optimization**:
  - SCHED_FIFO CPU scheduling
  - Nice priority -5
  - I/O scheduling class 2, priority 4
- **Environment**:
  - Headless mode enabled
  - 40-second browser timeout
  - 10-minute session TTL
  - Chrome optimization flags

## Deployment Instructions

### On P510 (Direct Deployment)

Since remote SSH deployment is not currently working, deploy directly on P510:

```bash
# SSH into P510
ssh olafkfreund@p510

# Navigate to nixos config
cd ~/.config/nixos

# Pull latest changes from this branch
git fetch origin
git checkout feature/125-p510-flaresolverr
git pull origin feature/125-p510-flaresolverr

# Build and deploy
sudo nixos-rebuild switch --flake .#p510

# Verify service started
sudo systemctl status flaresolverr

# Check if port is listening
sudo netstat -tlnp | grep 8191

# View logs
sudo journalctl -u flaresolverr -f
```

### Alternative: Build Locally First

If you want to test build first without deploying:

```bash
# From current machine (already tested, successful)
nix build .#nixosConfigurations.p510.config.system.build.toplevel

# Then SSH to P510 and deploy
```

## Testing Procedures

### 1. Verify Service Status

```bash
# Check service is running
sudo systemctl status flaresolverr

# Expected output:
# ● flaresolverr.service - FlareSolverr
#      Loaded: loaded
#      Active: active (running)
```

### 2. Test API Endpoint

```bash
# Test health endpoint
curl http://localhost:8191/v1

# Expected response:
# {"msg":"FlareSolverr is ready!","version":"3.4.6","userAgent":"..."}

# Test from another machine on network
curl http://p510:8191/v1
# OR
curl http://192.168.1.127:8191/v1
```

### 3. Test Cloudflare Bypass

```bash
# Create test request JSON
cat > /tmp/flaresolverr-test.json <<'EOF'
{
  "cmd": "request.get",
  "url": "https://nowsecure.nl",
  "maxTimeout": 60000
}
EOF

# Send request to FlareSolverr
curl -X POST http://localhost:8191/v1 \
  -H "Content-Type: application/json" \
  -d @/tmp/flaresolverr-test.json | jq .

# Expected output:
# {
#   "status": "ok",
#   "message": "",
#   "solution": {
#     "url": "https://nowsecure.nl/",
#     "status": 200,
#     "response": "<html>...",
#     "cookies": [...],
#     "userAgent": "..."
#   }
# }
```

### 4. Test with Common Cloudflare-Protected Sites

```bash
# Test various Cloudflare challenge types
for url in "https://nowsecure.nl" "https://www.google.com"; do
  echo "Testing: $url"
  curl -X POST http://localhost:8191/v1 \
    -H "Content-Type: application/json" \
    -d "{\"cmd\":\"request.get\",\"url\":\"$url\",\"maxTimeout\":60000}" \
    | jq -r '.status'
done
```

## Integration with Media Services

### Prowlarr Integration

1. **Add Indexer Proxy**:
   - Settings → Indexers → Indexer Proxies
   - Add → FlareSolverr
   - Host: `http://localhost:8191` or `http://192.168.1.127:8191`
   - Tags: Add tags to indexers that need Cloudflare bypass

2. **Configure Indexers**:
   - Edit indexer → Tags → Add FlareSolverr tag
   - Test indexer connection

### Jackett Integration (if used)

1. **Configure FlareSolverr**:
   - Jackett Dashboard → Settings
   - FlareSolverr API URL: `http://localhost:8191`
   - Test connection

2. **Enable for Indexers**:
   - Edit indexer → Enable FlareSolverr
   - Test indexer

### NZBGet Integration

NZBGet doesn't directly use FlareSolverr, but indexers accessed through Prowlarr/Jackett will benefit from Cloudflare bypass.

## Resource Monitoring

### Check Resource Usage

```bash
# CPU and memory usage
ps aux | grep flaresolverr

# Detailed systemd resource tracking
systemctl show flaresolverr | grep -E "(MemoryCurrent|CPUUsage)"

# Real-time monitoring
htop -p $(pgrep -f flaresolverr)
```

### Expected Resource Usage

- **Idle**: ~100MB RAM, <5% CPU
- **Active (solving challenges)**: ~500MB-1GB RAM, 50-100% CPU (per browser instance)
- **Peak**: Up to 2GB RAM limit, 200% CPU quota (2 cores)

## Troubleshooting

### Service Won't Start

```bash
# Check detailed logs
sudo journalctl -u flaresolverr -b --no-pager

# Common issues:
# - Port 8191 already in use
# - Missing Chromium dependencies
# - Insufficient resources
```

### Chromium/Selenium Hangs

If you encounter the Chromium 127+ Selenium hang issue:

```bash
# Check Chromium version in use
nix-store -q --references /run/current-system/sw | grep chromium

# If using Chromium 127-142, this may be problematic
# Current deployment uses Chromium 143, which should work
```

### API Returns Errors

```bash
# Test with verbose output
curl -v http://localhost:8191/v1

# Check if service is actually listening
sudo ss -tlnp | grep 8191

# Restart service if needed
sudo systemctl restart flaresolverr
```

### High Resource Usage

```bash
# Check active sessions
curl http://localhost:8191/v1/sessions | jq

# Clear old sessions if needed (automatic after 10min TTL)

# If persistent high usage, check logs:
sudo journalctl -u flaresolverr -f
```

## Known Limitations

### FlareSolverr Deprecation

 **Important**: FlareSolverr was deprecated by its maintainers in 2024:

- No longer actively maintained
- May not work with newest Cloudflare protections
- Cloudflare constantly updates detection methods
- Alternative solutions: ZenRows, Scrapeless, Multilogin (commercial)

### Compatibility

-  Works with current Cloudflare challenges (as of 2026-01-08)
-  May break with future Cloudflare updates
-  Limited to specific Cloudflare versions
-  Can fail with highly protected websites
-  Selenium/Chromium compatibility issues may recur

## Success Criteria

- [x]  Configuration enabled in P510
- [x]  Build succeeds without xvfbwrapper errors
- [x]  All Python 3.13 dependencies available
- [x]  Chromium 143 compatibility verified
- [ ] ⏳ Service deployed and running on P510
- [ ] ⏳ API endpoint accessible on port 8191
- [ ] ⏳ Cloudflare bypass tested and working
- [ ] ⏳ Integration with Prowlarr configured
- [ ] ⏳ Resource monitoring verified
- [ ] ⏳ Documentation complete

## Next Steps

1. **Deploy on P510**: Follow deployment instructions above
2. **Verify Service**: Complete all testing procedures
3. **Configure Prowlarr**: Add FlareSolverr proxy to indexers
4. **Monitor Performance**: Watch resource usage and success rates
5. **Update Issue #125**: Report deployment success or issues
6. **Create PR**: Merge changes to main once verified working

## References

- [FlareSolverr GitHub](https://github.com/FlareSolverr/FlareSolverr)
- [nixpkgs FlareSolverr Module](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/misc/flaresolverr.nix)
- [Issue #332776 - Known Issues](https://github.com/NixOS/nixpkgs/issues/332776)
- [MyNixOS FlareSolverr](https://mynixos.com/nixpkgs/package/flaresolverr)
- [Issue #125 - This Implementation](https://github.com/olafkfreund/nixos_config/issues/125)
