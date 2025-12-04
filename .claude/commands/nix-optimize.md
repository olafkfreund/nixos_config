# NixOS Performance Optimization

Analyze and optimize your NixOS configuration for maximum performance.

## 🚀 Quick Optimize

```
/nix-optimize
```

I'll automatically analyze your entire configuration and provide specific optimizations.

## What I'll Analyze

### 1. Build Performance (HIGH IMPACT)

**Import From Derivation (IFD) Detection:**
```nix
# ❌ SLOW - Forces build during evaluation
let configValue = builtins.readFile (pkgs.writeText "config" "value");

# ✅ FAST - Separate evaluation and build
let configValue = "value";  # Or use JSON config files
```

**Impact**: IFD blocks evaluation, adds 10-60s per occurrence

**Evaluation Efficiency:**
```nix
# ❌ SLOW - Deep recursion, multiple traversals
modules = map (f: import f) (readDir ./modules);

# ✅ FAST - Explicit imports, one traversal
imports = [
  ./modules/service1.nix
  ./modules/service2.nix
];
```

**Impact**: Saves 5-15s on evaluation

### 2. Store Optimization (DISK SPACE)

**Garbage Collection:**
```nix
# ❌ WASTEFUL - Manual GC, no automation
# Store grows to 100GB+

# ✅ OPTIMIZED - Automated cleanup
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};

# ✅ ADVANCED - Generation limits
nix.gc = {
  automatic = true;
  dates = "daily";
  options = "--delete-older-than 7d";
};
boot.loader.grub.configurationLimit = 10;  # Keep last 10 generations
```

**Impact**: Saves 20-80GB disk space

**Store Optimization:**
```nix
nix.settings = {
  auto-optimise-store = true;  # Hardlink identical files
};

# Manual optimization
nix-store --optimise  # Can save 10-30GB
```

**Impact**: Saves 10-30GB through deduplication

### 3. Build Caching (SPEED)

**Binary Cache Configuration:**
```nix
# ❌ SLOW - No caching, rebuild everything
nix.settings.substituters = [ "https://cache.nixos.org" ];

# ✅ FAST - Multi-tier caching
nix.settings = {
  substituters = [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
    "http://p620:5000"  # Local cache
  ];
  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "p620:YOUR_KEY"
  ];

  # Build settings
  max-jobs = "auto";  # Use all cores
  cores = 0;          # Parallel builds

  # Keep build artifacts
  keep-outputs = true;
  keep-derivations = true;
};
```

**Impact**: 50-90% faster builds with cache hits

### 4. Memory Optimization

**Swap Configuration:**
```nix
# ❌ SLOW - No swap or excessive swappiness
swapDevices = [ ];

# ✅ OPTIMIZED - SSD swap with tuning
swapDevices = [{
  device = "/swapfile";
  size = 16384;  # 16GB
}];

boot.kernel.sysctl = {
  "vm.swappiness" = 10;              # Prefer RAM
  "vm.vfs_cache_pressure" = 50;      # Cache efficiency
};
```

**Impact**: Prevents OOM kills, smoother performance

**Kernel Memory Management:**
```nix
boot.kernel.sysctl = {
  "vm.dirty_background_ratio" = 5;
  "vm.dirty_ratio" = 10;
  "vm.min_free_kbytes" = 65536;      # Reserve memory
};
```

**Impact**: Better I/O performance, system responsiveness

### 5. Network Performance

**TCP/IP Tuning:**
```nix
# ✅ OPTIMIZED - Modern congestion control
boot.kernel.sysctl = {
  "net.core.default_qdisc" = "fq";
  "net.ipv4.tcp_congestion_control" = "bbr";

  # Buffer sizes
  "net.core.rmem_max" = 134217728;    # 128MB
  "net.core.wmem_max" = 134217728;
  "net.ipv4.tcp_rmem" = "4096 87380 67108864";
  "net.ipv4.tcp_wmem" = "4096 65536 67108864";
};
```

**Impact**: 20-50% faster network transfers

### 6. Boot Performance

**systemd Service Optimization:**
```nix
# ❌ SLOW - Sequential service startup
systemd.services.myservice = {
  wantedBy = [ "multi-user.target" ];
  after = [ "network.target" ];  # Wait for network
};

# ✅ FAST - Parallel startup, minimal dependencies
systemd.services.myservice = {
  wantedBy = [ "multi-user.target" ];
  after = [ "network-online.target" ];  # Only if needed
  wants = [ "network-online.target" ];  # Optional dependency

  # Socket activation for even faster boot
  sockets.myservice = {
    listenStreams = [ "0.0.0.0:8080" ];
    wantedBy = [ "sockets.target" ];
  };
};
```

**Impact**: 10-30s faster boot time

**fstrim Optimization (SSD):**
```nix
# ❌ SLOW - fstrim at boot (8+ min delay)
services.fstrim.enable = true;  # Default: weekly at boot

# ✅ FAST - Background fstrim
services.fstrim = {
  enable = true;
  interval = "weekly";  # Runs in background, not at boot
};
```

**Impact**: Eliminates 8+ minute boot delays

### 7. Module Evaluation

**Feature Flag Efficiency:**
```nix
# ❌ SLOW - Complex conditionals, deep nesting
config = mkMerge [
  (mkIf cfg.enable {
    # ... deep nesting
  })
  (mkIf (cfg.enable && cfg.advanced) {
    # ... more nesting
  })
];

# ✅ FAST - Flat structure, simple conditions
config = mkIf cfg.enable {
  # Direct configuration
  services.myservice.enable = true;
  services.myservice.advanced = cfg.advanced;
};
```

**Impact**: 2-5s faster evaluation

### 8. Package Management

**Overlay Optimization:**
```nix
# ❌ SLOW - Rebuilds entire package set
nixpkgs.overlays = [
  (final: prev: {
    # Modifies lots of packages
  })
];

# ✅ FAST - Selective overlays
nixpkgs.overlays = [
  (final: prev: {
    mypackage = prev.mypackage.override {
      # Only affects this package
    };
  })
];
```

**Impact**: Faster builds, better caching

## Optimization Report

After analysis, you'll get:

```
╔════════════════════════════════════════════════╗
║     NIXOS PERFORMANCE OPTIMIZATION REPORT      ║
╚════════════════════════════════════════════════╝

📊 Current Performance: GOOD (75/100)

⚡ HIGH IMPACT Optimizations (Do First):

1. Enable Auto-Optimise Store [Saves: 15GB, Time: 5min]
   Location: hosts/common/nix-settings.nix

   Add:
   nix.settings.auto-optimise-store = true;

   Impact: 15GB disk savings, faster builds

2. Optimize fstrim Schedule [Saves: 8min boot time]
   Location: hosts/p510/configuration.nix

   Change:
   services.fstrim.interval = "weekly";

   Impact: Eliminates boot delay

3. Enable Binary Cache [Saves: 20min build time]
   Location: hosts/common/nix-settings.nix

   Add:
   nix.settings.substituters = [
     "https://cache.nixos.org"
     "http://p620:5000"
   ];

   Impact: 50-90% faster builds

⚡ MEDIUM IMPACT Optimizations (Do Soon):

4. Tune Swap Configuration [Improves: Responsiveness]
5. Optimize TCP/IP Settings [Improves: 30% faster transfers]
6. Reduce Module Evaluation [Saves: 3s per build]

💡 LOW IMPACT Optimizations (Nice to Have):

7. Service Socket Activation [Saves: 5s boot time]
8. Generation Cleanup Automation [Saves: 2GB/week]

📈 Performance Metrics:

Build Time:
  Current: 45s (cached), 8min (full)
  Optimized: 30s (cached), 4min (full)
  Improvement: 33% faster builds

Disk Usage:
  Current: 285GB (Nix store: 120GB)
  Optimized: 250GB (Nix store: 85GB)
  Savings: 35GB

Boot Time:
  Current: 2min 15s
  Optimized: 1min 30s
  Improvement: 45s faster

Memory:
  Current: 8.2GB / 16GB (51%)
  Optimized: 7.5GB / 16GB (47%)
  Improvement: 700MB freed
```

## Automatic Fixes

For each optimization, I'll provide:

```
Optimization #1: Enable Auto-Optimise Store

Location: hosts/common/nix-settings.nix:45

Current configuration:
  nix.settings = {
    substituters = [ "https://cache.nixos.org" ];
  };

Optimized configuration:
  nix.settings = {
    auto-optimise-store = true;  # NEW
    substituters = [ "https://cache.nixos.org" ];
  };

Why this helps:
Auto-optimise-store uses hard links to deduplicate identical
files in the Nix store. With your 120GB store and typical
15-25% duplication, this saves 15-30GB with no downside.

How to apply:
1. Edit hosts/common/nix-settings.nix
2. Add auto-optimise-store = true;
3. Run: sudo nix-store --optimise (one-time, takes 5-10min)
4. Future optimizations automatic

Expected results:
  Disk savings: 15-30GB
  Build time: Unchanged
  Maintenance: None (automatic)
```

## Performance Comparison

**Before Optimization:**
```
Build Times:
  Clean build: 8m 45s
  Cached build: 45s
  Evaluation: 12s

Disk Usage:
  Total: 285GB
  Nix store: 120GB
  Generations: 45 (8.5GB)

Boot Time: 2m 15s
Memory: 8.2GB baseline
```

**After Optimization:**
```
Build Times:
  Clean build: 4m 10s (-52%)
  Cached build: 28s (-38%)
  Evaluation: 7s (-42%)

Disk Usage:
  Total: 248GB (-37GB)
  Nix store: 85GB (-35GB)
  Generations: 10 (1.8GB) (-6.7GB)

Boot Time: 1m 28s (-47s)
Memory: 7.4GB baseline (-800MB)
```

**Total Improvement:**
- ⚡ 50% faster builds
- 💾 37GB disk savings
- 🚀 47s faster boots
- 🧠 800MB memory freed

## Usage Modes

**Full Analysis:**
```
/nix-optimize
```
Analyzes everything, provides complete report

**Quick Check:**
```
/nix-optimize
Quick check only
```
High-impact optimizations only (30s)

**Specific Area:**
```
/nix-optimize
Check build performance
```
Focus on specific optimization area

**Auto-Apply:**
```
/nix-optimize
Apply safe optimizations automatically
```
Applies optimizations that can't break anything

## Safety Levels

### 🟢 Safe (Auto-Apply)
- Auto-optimise store
- Garbage collection automation
- Generation limits
- Swap tuning
- TCP/IP tuning

### 🟡 Review Recommended
- Binary cache changes
- Module restructuring
- Service dependency changes

### 🔴 Requires Testing
- Kernel parameter changes
- Service architecture changes
- Major configuration refactoring

## Integration

Runs as part of:
- Weekly performance review (automatic)
- Before major deployments (suggested)
- After adding new hosts (recommended)

Ready to optimize? Just run `/nix-optimize`! ⚡
