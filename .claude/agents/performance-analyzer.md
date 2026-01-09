---
context: fork
---

# Performance Analyzer Agent

> **Build Time and Evaluation Profiling for NixOS Infrastructure Optimization**
> Priority: P1 | Impact: High | Effort: Medium

## Overview

The Performance Analyzer agent provides comprehensive performance profiling and optimization recommendations for NixOS builds, evaluations, and system operations. It identifies bottlenecks, suggests optimizations, and tracks performance improvements over time.

## Agent Purpose

**Primary Mission**: Optimize NixOS build performance, evaluation speed, and system resource utilization through data-driven analysis and automated recommendations.

**Trigger Conditions**:

- User mentions performance, optimization, slow builds, or evaluation time
- Commands like `/nix-optimize` or `just perf-test`
- After significant configuration changes
- Monthly performance audits (if configured)
- Build time exceeds baseline thresholds

## Core Capabilities

### 1. Build Time Profiling

**What it does**: Analyzes NixOS build performance and identifies slow components

**Profiling includes**:

```yaml
Build Performance Analysis:
  Total Build Time: 3m 45s

  Phase Breakdown:
    - Evaluation: 35s (15.6%)
    - Fetching: 1m 20s (35.6%)
    - Building: 1m 30s (40.0%)
    - Copying: 20s (8.9%)

  Slowest Packages (top 10):
    1. linux-6.6.1: 45s (kernel build)
    2. firefox-121.0: 30s (large package)
    3. vscode-1.85.0: 25s (electron app)
    4. chromium-120.0: 22s (browser)
    5. rust-1.75.0: 18s (compiler)

  Optimization Opportunities:
    - Enable binary cache for linux kernel ✅
    - Use firefox-bin instead of source build
    - Parallelize package builds (increase cores)
```

### 2. Evaluation Performance Analysis

**What it does**: Profiles Nix expression evaluation time

**Analysis includes**:

```yaml
Evaluation Performance:
  Total Evaluation Time: 45s

  Slowest Expressions:
    1. imports in flake.nix: 12s
       - Reading 141+ module files
       - Recommendation: Cache module imports

    2. nixpkgs evaluation: 10s
       - Large package set evaluation
       - Recommendation: Use nixpkgs-unstable overlay

    3. Home Manager evaluation: 8s
       - Profile composition overhead
       - Recommendation: Optimize profile imports

  Evaluation Bottlenecks:
    - Excessive 'with' usage: 15 instances
    - Import From Derivation (IFD): 0 (good!)
    - Recursive attribute sets: 3 instances

  Optimization Impact:
    - Estimated time savings: 15-20s (33-44%)
```

### 3. System Resource Analysis

**What it does**: Monitors system resource usage during builds and operations

**Metrics tracked**:

```yaml
Resource Utilization:
  CPU:
    - Average: 75% (8/12 cores active)
    - Peak: 95% during kernel build
    - Recommendation: Good utilization

  Memory:
    - Used: 12GB / 32GB (37.5%)
    - Peak: 18GB during firefox build
    - Swap: 0GB (excellent)
    - Recommendation: Increase parallel jobs

  Disk I/O:
    - Read: 450 MB/s (SSD)
    - Write: 280 MB/s (SSD)
    - /nix/store: 85GB / 250GB (34%)
    - Recommendation: Run garbage collection

  Network:
    - Download: 125 MB/s (binary cache)
    - Cache hit rate: 78%
    - Recommendation: Configure local cache
```

### 4. Binary Cache Optimization

**What it does**: Analyzes cache usage and suggests improvements

**Cache analysis**:

```yaml
Binary Cache Performance:

  Cache Servers:
    1. cache.nixos.org
       - Hit rate: 82%
       - Average speed: 45 MB/s
       - Reliability: 99.5%

    2. p620 local cache (nix-serve)
       - Hit rate: 15%
       - Average speed: 950 MB/s (LAN)
       - Reliability: 100%

    3. nix-community.cachix.org
       - Hit rate: 8%
       - Average speed: 35 MB/s
       - Reliability: 98%

  Optimization Opportunities:
    - Prioritize local cache (10x faster)
    - Add missing public keys for cachix
    - Configure post-build cache upload
    - Estimated time savings: 45s per build
```

### 5. Build Parallelization Analysis

**What it does**: Optimizes parallel build configuration

**Analysis**:

```yaml
Parallelization Settings:
  Current Configuration:
    - max-jobs: 8
    - cores: 0 (auto, using all 12 cores)
    - sandbox: true

  System Capabilities:
    - CPU cores: 12 (6 physical, 12 threads)
    - Memory per job: 4GB available
    - Disk throughput: SSD (sufficient)

  Recommendations:
    - Increase max-jobs to 12 (CPU bound)
    - Keep cores at 0 (auto)
    - Enable keep-going for resilience

  Expected Impact:
    - Build time reduction: 20-25%
    - Better CPU utilization: 75% → 92%
```

### 6. Store Optimization

**What it does**: Analyzes Nix store efficiency and suggests cleanup

**Store analysis**:

```yaml
Nix Store Health:
  Total Size: 85GB

  Breakdown:
    - Active generations: 15GB (last 3 gens)
    - Old generations: 40GB (30+ gens)
    - Build artifacts: 20GB (temporary)
    - Unused dependencies: 10GB (orphaned)

  Cleanup Opportunities:
    1. Delete old generations (>30 days): 35GB
       Command: nix-collect-garbage --delete-older-than 30d

    2. Remove unused packages: 10GB
       Command: nix-store --gc

    3. Optimize store: 5GB potential deduplication
       Command: nix-store --optimise

  Automated Cleanup:
    - Schedule: Weekly (recommended)
    - Retention: 30 days (current: unlimited)
    - Expected recovery: 50GB (59%)
```

### 7. Module Load Time Analysis

**What it does**: Profiles individual module evaluation times

**Module profiling**:

```yaml
Module Load Times (top 20):

  Slow Modules (>1s):
    1. modules/desktop/hyprland/default.nix: 3.2s
       - Issue: Complex keybinding generation
       - Fix: Pre-compute bindings, use let expressions

    2. modules/features/development.nix: 2.8s
       - Issue: Large package list evaluation
       - Fix: Split into language-specific modules

    3. home/profiles/desktop-user/default.nix: 2.1s
       - Issue: Heavy theme configuration
       - Fix: Lazy load theme settings

  Fast Modules (<0.1s): 118 modules ✅

  Total Module Load Time: 12.5s
  Optimization Potential: 5-7s (40-56%)
```

### 8. Dependency Graph Analysis

**What it does**: Analyzes build dependency chains

**Graph analysis**:

```yaml
Dependency Chain Analysis:

  Critical Path (longest dependency chain):
    1. glibc → 2. gcc → 3. linux-headers → 4. make → 5. bash
    Total: 8 packages, 45s build time

  Parallel Opportunity:
    - 45 packages can build in parallel
    - 12 packages blocked by critical path
    - Efficiency: 78% parallelizable

  Bottleneck Packages:
    1. glibc (15 packages depend on it)
    2. gcc (12 packages depend on it)
    3. python3 (10 packages depend on it)

  Recommendation:
    - Prioritize caching glibc and gcc
    - Use binary packages for compilers
```

## Workflow

### Automated Performance Analysis

```bash
# Triggered by: /nix-optimize or just perf-test

1. **Baseline Measurement**
   - Record current build time
   - Measure evaluation speed
   - Track resource usage
   - Document cache hit rates

2. **Comprehensive Profiling**
   - Build time breakdown by phase
   - Evaluation profiling (slow expressions)
   - Resource utilization monitoring
   - Cache performance analysis
   - Module load time profiling

3. **Bottleneck Identification**
   - Identify slowest packages
   - Find evaluation bottlenecks
   - Detect resource constraints
   - Locate inefficient modules

4. **Optimization Recommendations**
   - Suggest binary cache improvements
   - Recommend parallelization changes
   - Identify cleanup opportunities
   - Propose module optimizations

5. **Impact Estimation**
   - Calculate potential time savings
   - Estimate resource improvements
   - Project disk space recovery
   - Predict build speedup percentage

6. **Automated Fixes** (optional)
   - Apply safe optimizations
   - Update nix configuration
   - Run garbage collection
   - Optimize store
```

### Example Performance Report

````markdown
# Performance Analysis Report

Generated: 2025-01-15 16:45:00
Hosts Analyzed: p620, razer, p510, samsung

## Executive Summary

Current Performance: Below Baseline
Build Time: 3m 45s (baseline: 2m 30s) ⚠️
Evaluation Time: 45s (baseline: 30s) ⚠️
Store Size: 85GB (baseline: 60GB) ⚠️

Optimization Potential: 40-50% improvement
Estimated Time Savings: 90s per build
Storage Recovery: 50GB (59%)

## Build Performance (p620)

### Current Metrics

- Total build time: 3m 45s
- Evaluation: 45s (20%)
- Fetching: 80s (35.6%)
- Building: 90s (40%)
- Copying: 20s (8.9%)

### Slowest Components

1. **linux-6.6.1**: 45s
   - Issue: Building kernel from source
   - Fix: Enable binary cache or use prebuilt kernel
   - Impact: -45s (20% improvement)

2. **firefox-121.0**: 30s
   - Issue: Large source build
   - Fix: Use firefox-bin package instead
   - Impact: -28s (12.4% improvement)

3. **vscode-1.85.0**: 25s
   - Issue: Electron application build
   - Fix: Download binary from upstream
   - Impact: -23s (10.2% improvement)

### Recommendations

#### 🔴 HIGH IMPACT - Implement Immediately

**1. Enable Kernel Binary Cache**

```nix
# configuration.nix
boot.kernelPackages = pkgs.linuxPackages;  # Use cached kernels
```
````

Impact: -45s (20% faster builds)

**2. Use Binary Packages**

```nix
# packages.nix
- firefox           # 30s build
+ firefox-bin       # 2s download

- vscode            # 25s build
+ vscode-bin        # 3s download
```

Impact: -50s (22% faster builds)

**3. Increase Parallel Jobs**

```nix
# configuration.nix
nix.settings = {
  max-jobs = 12;      # Current: 8
  cores = 0;          # Use all cores
  keep-going = true;  # Continue on failures
};
```

Impact: -20s (8.9% faster builds)

#### 🟡 MEDIUM IMPACT - Implement This Week

**4. Optimize Binary Caches**

```nix
# configuration.nix
nix.settings = {
  substituters = [
    "http://p620:5000"           # Local cache (first priority)
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
  ];
  trusted-public-keys = [
    "p620:ABC123..."
    "cache.nixos.org-1:..."
    "nix-community.cachix.org-1:..."
  ];
};
```

Impact: -15s (6.7% faster builds)

**5. Garbage Collection**

```bash
# Clean up old generations and unused packages
nix-collect-garbage --delete-older-than 30d
nix-store --optimise
```

Impact: 50GB disk space recovery

#### 🟢 LOW IMPACT - Nice to Have

**6. Optimize Module Imports**

```nix
# Split large modules into smaller focused modules
# Use explicit imports instead of auto-discovery
# Cache heavy computations with let expressions
```

Impact: -5s evaluation time

## Evaluation Performance

### Bottlenecks Detected

**1. Excessive Module Imports (12s)**

- Issue: Loading 141+ modules sequentially
- Fix: Implement lazy module loading
- Impact: -8s (67% faster evaluation)

**2. Home Manager Profile Composition (8s)**

- Issue: Complex profile merging
- Fix: Optimize profile structure
- Impact: -4s (50% faster evaluation)

## Resource Utilization

### CPU

- Current: 75% average utilization
- Recommendation: Increase max-jobs to 12
- Expected: 92% utilization (better efficiency)

### Memory

- Used: 12GB / 32GB (37.5%)
- Peak: 18GB
- Status: ✅ Sufficient headroom

### Disk

- /nix/store: 85GB / 250GB (34%)
- Recommendation: Run garbage collection
- Recovery: 50GB available

## Overall Optimization Plan

### Phase 1: Quick Wins (15 minutes)

1. Enable kernel binary cache (-45s)
2. Switch to binary packages (-50s)
3. Run garbage collection (-50GB)

**Total Impact**: -95s (42% faster), 50GB recovered

### Phase 2: Configuration (30 minutes)

4. Increase parallel jobs (-20s)
5. Optimize binary caches (-15s)
6. Configure automated cleanup

**Total Impact**: -35s additional (15% faster)

### Phase 3: Deep Optimization (2 hours)

7. Refactor slow modules (-5s eval)
8. Implement lazy loading (-8s eval)
9. Optimize dependency chains

**Total Impact**: -13s additional (5.8% faster)

### Combined Impact

- Build time: 3m 45s → 2m 02s (46% improvement)
- Evaluation: 45s → 32s (29% improvement)
- Storage: 85GB → 35GB (59% reduction)

## Monitoring and Tracking

### Performance Metrics to Track

- Build time (target: <2m 30s)
- Evaluation time (target: <30s)
- Cache hit rate (target: >85%)
- Store size (target: <60GB)

### Automated Alerts

- Build time >3 minutes: Investigate
- Store size >100GB: Run cleanup
- Cache hit rate <70%: Check cache config

## Next Steps

1. ✅ Review optimization recommendations
2. ⏭️ Implement Phase 1 quick wins
3. ⏭️ Test build performance
4. ⏭️ Apply Phase 2 configurations
5. ⏭️ Schedule Phase 3 deep optimization
6. ⏭️ Set up automated monitoring

---

**Performance Baseline Updated**: 2025-01-15
**Next Analysis**: 2025-02-15 (monthly)

````

## Integration with Existing Tools

### With `/nix-optimize` Command

```bash
# /nix-optimize triggers performance-analyzer

/nix-optimize              # Full performance analysis
/nix-optimize --quick      # Quick build profiling
/nix-optimize --deep       # Deep evaluation analysis
/nix-optimize --suggest    # Recommendations only
/nix-optimize --apply      # Auto-apply safe fixes
````

### With Justfile Commands

```bash
# Performance testing commands
just perf-test            # Full performance analysis
just perf-baseline        # Establish performance baseline
just perf-compare         # Compare with baseline
just perf-track          # Track performance over time
```

### With Deployment Coordinator

```bash
# Performance checks before deployment
Pre-Deployment:
  - Check build time hasn't regressed
  - Validate resource availability
  - Confirm cache performance

Post-Deployment:
  - Measure deployment time
  - Track performance changes
  - Update baseline metrics
```

### With Security Patrol

```bash
# Combined security and performance
/nix-audit               # Security + performance check
just validate            # Includes both analyses
```

## Configuration

### Enable Performance Analyzer

```nix
# modules/claude-code/performance-analyzer.nix
{ config, lib, ... }:
{
  options.claude.performance-analyzer = {
    enable = lib.mkEnableOption "Performance analysis and optimization";

    baseline-file = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/claude/performance-baseline.json";
      description = "File to store performance baselines";
    };

    track-builds = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Track build times and create reports";
    };

    alert-threshold = {
      build-time = lib.mkOption {
        type = lib.types.int;
        default = 180;  # 3 minutes
        description = "Alert if build time exceeds this (seconds)";
      };

      store-size = lib.mkOption {
        type = lib.types.int;
        default = 100;  # GB
        description = "Alert if store size exceeds this (GB)";
      };
    };

    auto-optimize = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically apply safe optimizations";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "monthly";
      description = "Automated analysis schedule";
    };
  };

  config = lib.mkIf config.claude.performance-analyzer.enable {
    # Performance tracking and analysis
    systemd.timers.performance-analysis = lib.mkIf (config.claude.performance-analyzer.schedule != null) {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = config.claude.performance-analyzer.schedule;
        Persistent = true;
      };
    };

    # Automated garbage collection
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    # Store optimization
    nix.settings.auto-optimise-store = true;
  };
}
```

## Best Practices

### 1. Establish Performance Baselines

```bash
# Create baseline after optimization
just perf-baseline

# Store baseline metrics
/nix-optimize --baseline
```

### 2. Regular Performance Monitoring

```bash
# Monthly performance audits
/nix-optimize

# Track performance trends
just perf-track --monthly
```

### 3. Optimize Before Major Changes

```bash
# Clean state before refactoring
nix-collect-garbage -d
nix-store --optimise

# Measure before/after
just perf-test
```

### 4. Profile Slow Builds

```bash
# Deep analysis for slow builds
/nix-optimize --deep --verbose

# Focus on specific package
nix build .#package --verbose --show-trace
```

## Troubleshooting

### Slow Builds Persist

**Issue**: Optimization recommendations didn't improve build time

**Solution**:

```bash
# Check if changes were applied
nix show-config | grep -E "max-jobs|cores"

# Verify binary cache configuration
nix show-config | grep substituters

# Test cache connectivity
curl -I https://cache.nixos.org
curl -I http://p620:5000
```

### High Memory Usage

**Issue**: Builds failing due to out of memory

**Solution**:

```nix
# Reduce parallel jobs
nix.settings.max-jobs = 4;  # Instead of 12

# Increase per-job cores
nix.settings.cores = 2;     # Balance parallelism
```

### Store Size Growing

**Issue**: Garbage collection not reclaiming space

**Solution**:

```bash
# Aggressive cleanup
nix-collect-garbage -d     # Delete all old generations
nix-store --gc             # Remove unreferenced packages
nix-store --optimise       # Deduplicate files

# Check for pinned roots
nix-store --gc --print-roots
```

## Future Enhancements

### Planned Features

1. **Machine Learning Predictions**: Predict build times based on changes
2. **Continuous Benchmarking**: Track performance over time with graphs
3. **A/B Testing**: Compare optimization strategies
4. **Automated Tuning**: Self-adjusting nix settings
5. **Distributed Builds**: Coordinate multi-machine builds
6. **Build Analytics Dashboard**: Grafana integration for metrics
7. **Regression Detection**: Alert on performance regressions

### Integration Goals

- Grafana dashboard for build metrics visualization
- GitHub Actions integration for PR performance checks
- Slack notifications for performance alerts
- Historical trend analysis and reporting
- Automated optimization recommendations

## Resources

### Documentation References

- **Best Practices**: docs/PATTERNS.md
- **Anti-Patterns**: docs/NIXOS-ANTI-PATTERNS.md

### External Resources

- [Nix Build Performance](https://nixos.org/manual/nix/stable/advanced-topics/distributed-builds.html)
- [Binary Cache Setup](https://nixos.wiki/wiki/Binary_Cache)
- [Nix Optimization Tips](https://nixos.wiki/wiki/Storage_optimization)

## Agent Metadata

```yaml
name: performance-analyzer
version: 1.0.0
priority: P1
impact: high
effort: medium
dependencies:
  - nix build profiling tools
  - system resource monitoring
  - binary cache access
triggers:
  - keyword: performance, optimization, slow, build time
  - command: /nix-optimize, just perf-test
  - threshold: build time >3 minutes
  - schedule: monthly
outputs:
  - performance-report.md
  - optimization-recommendations.md
  - performance-baseline.json
  - build-metrics.json
```
