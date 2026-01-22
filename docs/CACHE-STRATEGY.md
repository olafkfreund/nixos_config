# NixOS Binary Cache Strategy

> **Complete guide to multi-tier caching for optimal build performance**

## 🎯 Overview

Your NixOS infrastructure uses a sophisticated three-tier cache strategy:

1. **P620 Local Cache** (fastest) - Your own nix-serve cache server
2. **Official NixOS Cache** (always available) - cache.nixos.org
3. **Nix Community Cache** (comprehensive) - nix-community.cachix.org
4. **Optional: Personal Cachix** (5GB free) - your-username.cachix.org

## 🏗️ Cache Architecture

### Current Setup

```
Samsung/Razer/P510 (clients)
    ↓
    1. Check P620 cache (local network) - FASTEST
    ↓
    2. Check NixOS official cache - RELIABLE
    ↓
    3. Check Nix community cache - COMPREHENSIVE
    ↓
    4. Build locally - SLOWEST (fallback)
```

### P620 Cache Server

**What it is:**

- Binary cache server running on your P620 workstation
- Stores built packages for reuse across all hosts
- Accessible via Tailscale (anywhere) and LAN (fastest)

**Configuration:**

- Service: `nix-serve`
- Port: `5000`
- Secret key: `/etc/nix/secret-key`
- Public key: `p620-nix-serve:mZR6o5z5KcWeu4PVXgjHA7vb1sHQgRdWMKQt8x3a4rU=`
- Firewall: Open (automatic)

**Access Points:**

- Tailscale: `http://p620.lan:5000`
- LAN: `http://p620.lan:5000`

## 🚀 Deployment Strategies

### Strategy 1: Direct Deployment (Build on Target)

**When to use:**

- P620 workstation (powerful, doesn't matter)
- Quick config changes on any host

**How to use:**

```bash
# Standard deployment (builds on target host)
just p620
just razer
just samsung
just p510
```

**Pros:** Simple, direct
**Cons:** Slow on laptops, drains battery

---

### Strategy 2: Deploy via P620 Cache (RECOMMENDED for Samsung)

**When to use:**

- Samsung laptop (save battery!)
- Razer laptop (when on the go)
- Any host with slow builds

**How to use:**

```bash
# Build on P620, deploy to Samsung
just deploy-via-p620 samsung

# Quick Samsung-specific command
just samsung-deploy

# Build only (test before deploy)
just build-on-p620 samsung
just deploy-via-p620 samsung
```

**What happens:**

1. 🏗️ **Build Phase**: P620 builds Samsung's configuration
2. 📦 **Cache Phase**: Build artifacts stored in P620's cache
3. 📡 **Deploy Phase**: Samsung downloads from P620 cache (fast!)
4. 🔄 **Switch Phase**: Samsung activates new configuration

**Pros:**

- ✅ Fast deployment (download vs build)
- ✅ Saves battery on laptops
- ✅ Consistent builds across hosts
- ✅ P620 has better cooling/performance

**Cons:**

- ⚠️ Requires P620 to be online
- ⚠️ Network dependency

---

### Strategy 3: Smart Deployment (Only if Changed)

**When to use:**

- Development iteration
- Testing configurations
- Avoiding unnecessary rebuilds

**How to use:**

```bash
# Only deploy if configuration changed
just quick-deploy samsung
just quick-deploy razer
```

**Pros:** Skip unchanged deployments
**Cons:** Slightly slower check phase

---

### Strategy 4: Parallel Deployment (All Hosts)

**When to use:**

- Rolling out changes to all hosts
- Weekly updates

**How to use:**

```bash
# Test all, deploy all if tests pass
just quick-all

# Deploy to all hosts in parallel (fastest)
just deploy-all-parallel
```

---

## 📊 Performance Comparison

| Method             | Samsung Build Time | Network Usage | Battery Impact |
| ------------------ | ------------------ | ------------- | -------------- |
| **Direct Deploy**  | ~15-20 min         | Low           | High ⚠️        |
| **Via P620 Cache** | ~3-5 min           | Medium        | Low ✅         |
| **With Cachix**    | ~2-3 min           | High          | Low ✅         |

## 🆓 Free Cachix Setup (Optional)

Cachix provides **5GB free storage** with unlimited downloads. Great for:

- External access (when not on your network)
- Backup cache (redundancy)
- Sharing builds across locations

### Setup Instructions

**1. Create Cachix Account**

```bash
# Sign up at https://cachix.org (free tier)
```

**2. Install Cachix**

```bash
# Already installed via development.nix
which cachix  # Should show: /run/current-system/sw/bin/cachix
```

**3. Authenticate**

```bash
# Get your auth token from https://app.cachix.org/personal-auth-tokens
cachix authtoken YOUR_AUTH_TOKEN
```

**4. Create Your Cache**

```bash
# Create a new cache (e.g., "olafkfreund-nixos")
cachix create olafkfreund-nixos
```

**5. Configure Automatic Uploads**

Add to `modules/nix/nix.nix`:

```nix
# Add to substituters list
substituters = [
  "https://cache.nixos.org"
  "https://nix-community.cachix.org"
  "https://olafkfreund-nixos.cachix.org"  # Your Cachix cache
  # ... P620 cache entries
];

# Add to trusted-public-keys
trusted-public-keys = [
  "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  "olafkfreund-nixos.cachix.org-1:YOUR_PUBLIC_KEY"  # From cachix.org
  # ... P620 cache key
];
```

**6. Upload to Cachix**

```bash
# Push current system to Cachix
nix-store -qR --include-outputs $(nix-store -qd $(readlink -f /run/current-system)) | cachix push olafkfreund-nixos

# Or push specific build
nix build .#nixosConfigurations.samsung.config.system.build.toplevel --json \
  | jq -r '.[].outputs.out' \
  | cachix push olafkfreund-nixos
```

**7. Automatic Upload on Build** (Optional)

Add to `/etc/nixos/configuration.nix`:

```nix
nix.settings.post-build-hook = pkgs.writeShellScript "cachix-push" ''
  set -eu
  set -f # disable globbing
  export IFS=' '
  echo "Uploading paths" $OUT_PATHS
  exec ${pkgs.cachix}/bin/cachix push olafkfreund-nixos $OUT_PATHS
'';
```

---

## 🔧 Troubleshooting

### P620 Cache Not Working

**Check service status:**

```bash
# On P620
systemctl status nix-serve

# Should show: active (running)
```

**Test cache access:**

```bash
# From Samsung
curl http://p620.freundcloud.com:5000/nix-cache-info
# Should return cache information

# Or via LAN
curl http://192.168.1.97:5000/nix-cache-info
```

**Verify firewall:**

```bash
# On P620
sudo nft list ruleset | grep 5000
# Should show rule allowing port 5000
```

### Cache Not Being Used

**Check substituters configuration:**

```bash
# On Samsung
nix show-config | grep substituters
# Should include P620 cache URLs

nix show-config | grep trusted-public-keys
# Should include P620 public key
```

**Force cache usage:**

```bash
# Test with explicit cache
nix build .#nixosConfigurations.samsung.config.system.build.toplevel \
  --option substituters "http://p620.freundcloud.com:5000 https://cache.nixos.org" \
  --option trusted-public-keys "p620-nix-serve:mZR6o5z5KcWeu4PVXgjHA7vb1sHQgRdWMKQt8x3a4rU= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
```

### Network Issues

**Tailscale not working:**

```bash
# Check Tailscale status
tailscale status | grep p620

# Test connectivity
ping p620.freundcloud.com
```

**LAN access issues:**

```bash
# Check if on same network
ip route get 192.168.1.97

# Test LAN connectivity
ping 192.168.1.97
```

---

## 📋 Quick Reference

### Daily Workflow (Samsung)

```bash
# Make configuration changes
vim hosts/samsung/configuration.nix

# Validate
just validate-quick

# Deploy via P620 cache (RECOMMENDED)
just samsung-deploy
```

### Weekly Maintenance

```bash
# Update flake inputs
just update-flake

# Build everything on P620
just build-all-parallel

# Deploy to all hosts
just deploy-all-parallel
```

### Emergency Deployment

```bash
# Direct deploy (bypass cache)
sudo nixos-rebuild switch --flake .#samsung
```

---

## 🎓 Best Practices

1. **Always use P620 cache for Samsung deployments**
   - Saves battery and time
   - Command: `just samsung-deploy`

2. **Keep P620 running during work hours**
   - Cache only works when P620 is online
   - Consider wake-on-LAN if needed

3. **Regular cache maintenance**
   - P620 garbage collection runs weekly
   - Old builds automatically cleaned up

4. **Test before deploying**
   - Use `just build-on-p620 samsung` to test
   - Then `just deploy-via-p620 samsung` if successful

5. **Monitor cache usage**

   ```bash
   # On P620
   du -sh /nix/store
   nix-store --gc --print-dead
   ```

---

## 🔗 Related Documentation

- **Deployment Guide**: `docs/deployment-guide.md`
- **NixOS Patterns**: `docs/PATTERNS.md`
- **Performance Optimization**: `modules/system/performance.nix`
- **P620 Configuration**: `hosts/p620/configuration.nix`

---

**Last Updated**: 2025-01-13
**Status**: Production Ready
**Maintainer**: Infrastructure Team
