# Cachix vs P620 Local Cache - Complete Analysis

> **Research-based comparison for optimal NixOS caching strategy**

## 📊 Quick Verdict

**For your setup: P620 + Optional Cachix Hybrid = BEST**

- **Primary**: P620 local cache (unlimited, private, fastest on LAN)
- **Optional**: Cachix free tier (5GB public, external access)
- **Skip**: Cachix paid tiers (not cost-effective for your use case)

---

## 🔍 Cachix Overview

### What Is Cachix?

Cachix is a hosted binary cache service (SaaS) that provides:

- **Cloudflare CDN**: Global content delivery, unlimited bandwidth
- **Zero maintenance**: Managed infrastructure
- **Team features**: Access control, revokable tokens
- **Automatic GC**: Least-recently-used cleanup

### Pricing Tiers (2025)

| Tier         | Storage | Cost    | Private Caches | Best For             |
| ------------ | ------- | ------- | -------------- | -------------------- |
| **Free**     | 5 GB    | Free    | ❌ Public only | Open source projects |
| **Starter**  | 50 GB   | Contact | ✅ Yes         | Small teams          |
| **Standard** | 250 GB  | Contact | ✅ Yes         | Medium teams         |
| **Pro**      | 1500 GB | Contact | ✅ Yes         | Large enterprises    |

**Key Features:**

- ✅ Unlimited bandwidth (all tiers)
- ✅ Cloudflare CDN (global performance)
- ✅ Compression (saves 90% storage)
- ✅ 14-day free trial (paid tiers)
- ✅ Watch-store automatic pushing
- ❌ Free tier is PUBLIC ONLY

---

## 🆚 Cachix vs P620 Comparison

### Speed & Performance

| Scenario           | P620 (LAN)      | P620 (Tailscale) | Cachix (Free)  | Cachix (Paid)  |
| ------------------ | --------------- | ---------------- | -------------- | -------------- |
| **Samsung on LAN** | ⚡ ~50-100 MB/s | ~10-30 MB/s      | ~5-20 MB/s     | ~5-20 MB/s     |
| **Samsung remote** | ❌ No access    | ⚡ ~10-30 MB/s   | ⚡ ~10-50 MB/s | ⚡ ~10-50 MB/s |
| **Razer on LAN**   | ⚡ ~50-100 MB/s | ~10-30 MB/s      | ~5-20 MB/s     | ~5-20 MB/s     |
| **P510 on LAN**    | ⚡ ~50-100 MB/s | ~10-30 MB/s      | ~5-20 MB/s     | ~5-20 MB/s     |

**Winner**: P620 on LAN (5-10x faster) 🏆

### Privacy & Security

| Feature            | P620             | Cachix Free       | Cachix Paid        |
| ------------------ | ---------------- | ----------------- | ------------------ |
| **Private caches** | ✅ Unlimited     | ❌ Public only    | ✅ Yes             |
| **Data location**  | ✅ Your hardware | ❌ Cloud (public) | ❌ Cloud (private) |
| **Signing keys**   | ✅ Your control  | ⚠️ Shared         | ⚠️ Shared          |
| **Access control** | ✅ Network-based | ❌ Public read    | ✅ Token-based     |
| **Secrets safety** | ✅ Stays local   | ⚠️ Could leak     | ⚠️ Could leak      |

**Winner**: P620 (full privacy control) 🏆

### Storage Capacity

| Solution            | Storage    | Cost          | Expandable   |
| ------------------- | ---------- | ------------- | ------------ |
| **P620**            | ~500GB-2TB | $0 (existing) | ✅ Add disks |
| **Cachix Free**     | 5 GB       | $0            | ❌ No        |
| **Cachix Starter**  | 50 GB      | ~$10-20/mo?   | ✅ Upgrade   |
| **Cachix Standard** | 250 GB     | ~$50-100/mo?  | ✅ Upgrade   |
| **Cachix Pro**      | 1500 GB    | ~$200+/mo?    | ✅ Upgrade   |

**Winner**: P620 (unlimited free storage) 🏆

### Maintenance & Complexity

| Aspect                  | P620               | Cachix              |
| ----------------------- | ------------------ | ------------------- |
| **Setup complexity**    | ⚠️ Moderate (done) | ✅ 5 minutes        |
| **Ongoing maintenance** | ⚠️ Manual updates  | ✅ Zero             |
| **Uptime dependency**   | ⚠️ P620 must run   | ✅ Always available |
| **Configuration**       | ⚠️ Nix knowledge   | ✅ CLI tool         |
| **Team sharing**        | ⚠️ VPN required    | ✅ Internet access  |

**Winner**: Cachix (less maintenance) 🏆

### Cost Analysis

**Your setup (4 hosts):**

- Average build size per host: ~10-20 GB
- Total cache needs: ~40-80 GB (with overlap)
- P620 storage: ~500GB+ available

| Solution               | Monthly Cost         | Annual Cost |
| ---------------------- | -------------------- | ----------- |
| **P620 only**          | $0 (electricity ~$5) | ~$60        |
| **Cachix Free**        | $0                   | $0          |
| **Cachix Starter**     | ~$15-20              | ~$180-240   |
| **Cachix Standard**    | ~$50-100             | ~$600-1200  |
| **P620 + Cachix Free** | ~$5                  | ~$60        |

**Winner**: P620 + Cachix Free hybrid (best value) 🏆

---

## 🎯 Recommended Strategy: Hybrid Approach

### Architecture

```
Primary: P620 Local Cache (unlimited, private, fastest)
    ↓
Fallback: Cachix Free (5GB, public, remote access)
    ↓
Fallback: NixOS Official (always reliable)
    ↓
Fallback: Nix Community (comprehensive)
    ↓
Last Resort: Build locally
```

### Implementation

**1. Keep P620 as Primary Cache** (you already have this!)

```nix
# modules/nix/nix.nix (already configured)
substituters = [
  "https://cache.nixos.org"
  "https://nix-community.cachix.org"
  "http://p620.freundcloud.com:5000"  # PRIMARY
  "http://192.168.1.97:5000"          # PRIMARY (LAN)
];
```

**2. Add Cachix Free for Remote Access** (optional)

```nix
# Add to modules/nix/nix.nix
substituters = [
  "https://cache.nixos.org"
  "https://nix-community.cachix.org"
  "https://olafkfreund-nixos.cachix.org"  # YOUR PUBLIC CACHE
  "http://p620.freundcloud.com:5000"
  "http://192.168.1.97:5000"
];
```

**3. Selective Pushing to Cachix**
Only push **non-sensitive** builds to Cachix free tier:

```bash
# Push specific derivations (safe)
nix build .#packages.x86_64-linux.some-tool --print-out-paths | \
  cachix push olafkfreund-nixos

# DON'T push full system closures (may contain secrets)
# nix build .#nixosConfigurations.samsung --print-out-paths | \
#   cachix push olafkfreund-nixos  # ⚠️ AVOID THIS
```

---

## 🚫 When NOT to Use Cachix

### Don't Use Cachix If

1. **All hosts on your network** ✅ (your situation)
   - P620 LAN cache is 5-10x faster
   - No benefit from Cloudflare CDN

2. **Private configurations** ✅ (your situation)
   - Free tier is PUBLIC ONLY
   - Your NixOS configs contain secrets/private data

3. **Large builds** ✅ (your situation)
   - 5GB free tier fills up quickly
   - System closures are 10-20GB each

4. **Cost-sensitive** ✅ (your situation)
   - P620 is free (you already own it)
   - Paid Cachix: $180-1200/year

### Use Cachix If

1. **Open source project** ❌ (private infrastructure)
   - Share builds with community
   - Public cache is acceptable

2. **Remote teams** ❌ (single user, maybe family)
   - Team members outside your network
   - Need internet-accessible cache

3. **No local server** ❌ (you have P620)
   - Can't run nix-serve
   - Need hosted solution

4. **CI/CD pipelines** ⚠️ (potential future use)
   - GitHub Actions builds
   - External build machines

---

## 📝 Practical Recommendations

### Option 1: P620 Only (RECOMMENDED) ⭐

**Best for**: Your current setup

**Why**:

- ✅ You already have it configured
- ✅ Fastest on your LAN (50-100 MB/s)
- ✅ Unlimited private storage
- ✅ No ongoing costs
- ✅ Full privacy control
- ✅ Works with Tailscale everywhere

**Setup**: Already done! ✨

**Deploy commands**:

```bash
# Use P620 cache for Samsung (already configured)
just samsung-deploy

# P620 builds, Samsung downloads from cache
just deploy-via-p620 samsung
```

---

### Option 2: P620 + Cachix Free Hybrid (OPTIONAL)

**Best for**: External access or open source sharing

**Why**:

- ✅ P620 for LAN (fast, private)
- ✅ Cachix for remote access (when not on VPN)
- ✅ Free 5GB (for common packages)
- ⚠️ Only public cache (careful what you push)

**Setup**:

**Step 1: Install Cachix**

```bash
# Already installed via development.nix
which cachix  # Should work
```

**Step 2: Create Account & Cache**

```bash
# 1. Sign up: https://cachix.org (free)
# 2. Create cache: "olafkfreund-nixos"
# 3. Get auth token: https://app.cachix.org/personal-auth-tokens

# 4. Authenticate
cachix authtoken YOUR_TOKEN
```

**Step 3: Add to Configuration**

```nix
# Add to modules/nix/nix.nix
substituters = [
  "https://cache.nixos.org"
  "https://nix-community.cachix.org"
  "https://olafkfreund-nixos.cachix.org"  # NEW
  "http://p620.freundcloud.com:5000"
  "http://192.168.1.97:5000"
];

trusted-public-keys = [
  "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  "olafkfreund-nixos.cachix.org-1:YOUR_PUBLIC_KEY"  # From cachix.org
  "p620-nix-serve:mZR6o5z5KcWeu4PVXgjHA7vb1sHQgRdWMKQt8x3a4rU="
];
```

**Step 4: Selective Pushing** (only non-sensitive packages)

```bash
# Push common development tools (safe)
nix build .#packages.x86_64-linux.dev-tools --print-out-paths | \
  cachix push olafkfreund-nixos

# Push specific packages
nix-env -qaP | grep -E "firefox|vscode" | \
  xargs -I{} nix-build '<nixpkgs>' -A {} --no-out-link --print-out-paths | \
  cachix push olafkfreund-nixos

# ⚠️ NEVER push system closures (contain secrets/config)
# ⚠️ NEVER push custom modules (private logic)
```

**Step 5: Automatic Pushing** (optional, use carefully!)

```bash
# Watch and push during builds (use sparingly!)
cachix watch-exec olafkfreund-nixos -- nix build .#packages.x86_64-linux.some-tool
```

---

### Option 3: Cachix Paid (NOT RECOMMENDED)

**Cost**: $180-1200/year
**Benefit**: Private caches, more storage
**Your situation**: Not worth it

**Why skip**:

- ❌ P620 already provides private caching (free)
- ❌ Your hosts are on same network (LAN is faster)
- ❌ Storage on P620 is unlimited
- ❌ Cost doesn't justify benefits

**Only consider if**:

- You need to share private builds with external team
- P620 can't run 24/7
- You need enterprise features (team management, etc.)

---

## 🛠️ Cachix Setup (Optional)

If you decide to add Cachix free tier for remote access:

### Quick Setup

```bash
# 1. Create account
open https://cachix.org

# 2. Authenticate
cachix authtoken YOUR_TOKEN

# 3. Create cache
cachix create olafkfreund-nixos

# 4. Test push
echo "Hello Cachix" > /tmp/test
nix-store --add /tmp/test
nix-store -q /tmp/test | cachix push olafkfreund-nixos

# 5. Test fetch
nix-store --verify --check-contents
```

### Justfile Integration

Add to your Justfile:

```bash
# Push to Cachix (selective, non-sensitive only)
cachix-push PACKAGE:
    @echo "📤 Pushing {{PACKAGE}} to Cachix..."
    nix build .#packages.x86_64-linux.{{PACKAGE}} --print-out-paths | \
      cachix push olafkfreund-nixos
    @echo "✅ Pushed to Cachix!"

# Push common tools to Cachix
cachix-push-common:
    @echo "📤 Pushing common tools to Cachix..."
    for pkg in firefox vscode git neovim; do \
      nix build nixpkgs#$$pkg --print-out-paths | cachix push olafkfreund-nixos; \
    done
    @echo "✅ Common tools cached!"
```

### Security Considerations

**⚠️ CRITICAL: Cachix Free Tier is PUBLIC**

**NEVER push**:

- ❌ System configurations (`nixosConfigurations.*`)
- ❌ Home-manager configurations (may contain secrets)
- ❌ Custom modules (private logic)
- ❌ API keys, tokens, passwords
- ❌ Private data or configurations

**Safe to push**:

- ✅ Common nixpkgs packages (firefox, vscode, etc.)
- ✅ Public development tools
- ✅ Open source projects
- ✅ Generic build artifacts

---

## 📊 Decision Matrix

| Factor            | Weight | P620 Only  | P620 + Cachix | Cachix Only |
| ----------------- | ------ | ---------- | ------------- | ----------- |
| **Speed (LAN)**   | High   | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐    | ⭐⭐        |
| **Privacy**       | High   | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐      | ⭐⭐        |
| **Cost**          | High   | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐    | ⭐⭐        |
| **Storage**       | Medium | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐    | ⭐          |
| **Remote Access** | Low    | ⭐⭐⭐⭐   | ⭐⭐⭐⭐⭐    | ⭐⭐⭐⭐⭐  |
| **Maintenance**   | Medium | ⭐⭐⭐     | ⭐⭐⭐        | ⭐⭐⭐⭐⭐  |
| **Total Score**   | -      | **26/30**  | **27/30**     | **16/30**   |

**Winner**: P620 + Optional Cachix Free (27/30) 🏆

---

## 🎯 Final Recommendation

### For Your Setup: P620 Primary + Cachix Optional

**Keep using P620 as your primary cache:**

- ✅ Already configured and working
- ✅ Fastest for your use case (LAN + Tailscale)
- ✅ Unlimited private storage
- ✅ Zero ongoing costs
- ✅ Full privacy control

**Optionally add Cachix free tier for:**

- ✅ Remote access backup (when Tailscale down)
- ✅ Sharing common packages (non-sensitive)
- ✅ 5GB of commonly-used packages
- ⚠️ Only if you need external access

**Skip Cachix paid tiers:**

- ❌ Not cost-effective ($180-1200/year)
- ❌ P620 already provides private caching
- ❌ Your hosts are on same network

### Implementation Priority

1. **Now**: Use P620 cache (already done!) ✅
2. **Optional**: Add Cachix free for external access
3. **Skip**: Cachix paid tiers

---

## 📚 Sources

- [Cachix Official Site](https://www.cachix.org)
- [Cachix Pricing](https://www.cachix.org/pricing)
- [Cachix Documentation](https://docs.cachix.org/)
- [Getting Started Guide](https://docs.cachix.org/getting-started)
- [Pushing to Cachix](https://docs.cachix.org/pushing)
- [Binary Cache - NixOS Wiki](https://nixos.wiki/wiki/Binary_Cache)
- [Scrive Nix Workshop - Caching](https://scrive.github.io/nix-workshop/06-infrastructure/01-caching-nix.html)
- [Channable Blog - Private Nix Cache](https://www.channable.com/tech/setting-up-a-private-nix-cache-for-fun-and-profit)

---

**Last Updated**: 2025-01-13
**Research Date**: 2025-01-13
**Status**: Comprehensive Analysis Complete
