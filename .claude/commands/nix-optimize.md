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

**After Optimization:**

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

## Performance Analysis Modes (NEW!)

Run specific performance tests to measure and benchmark your configuration:

### Full Performance Test

```
/nix-optimize
Run full performance test
```

**What it does**:

- Runs comprehensive performance analysis across all areas
- Measures build times, memory usage, evaluation speed
- Tests cache efficiency and parallel build performance
- Generates complete performance report with baselines
  **Time**: ~5-10 minutes
  **Output**: Complete metrics across all categories

### Build Time Analysis

```
/nix-optimize
Analyze build times
```

**What it does**:

- Measures build times for all hosts
- Compares clean vs cached builds
- Identifies slow derivations and bottlenecks
- Provides per-host performance breakdown
  **Time**: ~2-3 minutes
  **Output**: Build time comparison table with recommendations

### Memory Usage Analysis

```
/nix-optimize
Analyze memory usage
```

**What it does**:

- Monitors memory usage during builds
- Identifies memory-intensive derivations
- Checks for potential OOM conditions
- Recommends memory optimization strategies
  **Time**: ~3-5 minutes
  **Output**: Memory usage graphs and recommendations

### Evaluation Performance

```
/nix-optimize
Test evaluation performance
```

**What it does**:

- Measures flake evaluation time
- Identifies slow module imports
- Detects evaluation inefficiencies
- Tests lazy evaluation effectiveness
  **Time**: ~1-2 minutes
  **Output**: Evaluation timing breakdown with bottlenecks

### Parallel Build Efficiency

```
/nix-optimize
Test parallel builds
```

**What it does**:

- Tests parallel build efficiency across cores
- Measures job distribution and utilization
- Identifies serialization bottlenecks
- Recommends optimal parallel build settings
  **Time**: ~3-5 minutes
  **Output**: Parallel efficiency metrics and core utilization

### Cache Performance

```
/nix-optimize
Test cache performance
```

**What it does**:

- Tests binary cache hit rates
- Measures cache download speeds
- Identifies uncached frequently-built derivations
- Recommends cache configuration improvements
  **Time**: ~2-3 minutes
  **Output**: Cache performance report with optimization suggestions

### Configuration Efficiency Report (NEW!)

```
/nix-optimize
Show efficiency report
```

**What it does**:

- Analyzes configuration code duplication
- Counts total .nix files and default.nix usage
- Detects potential duplicate files (via md5sum)
- Shows commented code statistics
- Reports feature flag usage patterns
- Lists host and user configuration counts
  **Time**: ~30 seconds
  **Output**: Complete efficiency metrics

## Performance Testing Scripts

All performance tests use `./scripts/performance-test.sh` with specific modes:

- **full** - Comprehensive performance testing
- **build-times** - Build time measurements
- **memory** - Memory usage analysis
- **eval** - Evaluation performance
- **parallel** - Parallel build efficiency
- **cache** - Cache performance testing

**Benchmark specific host**:

```
/nix-optimize
Benchmark p620 build time
```

Runs multiple build iterations (default: 3 runs) and provides average build time

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
