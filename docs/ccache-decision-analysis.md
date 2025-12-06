# ccache Implementation Decision Analysis

> Issue: #59
> Date: 2025-12-05
> Status: Analysis Complete

## Executive Summary

ccache can provide **significant build time savings** (hours → minutes) for C/C++ packages, but comes with **implementation complexity** and **cache management overhead**. Recommendation depends on your development workflow.

## Benefits Analysis

### ✅ **High Value Scenarios** (Implement ccache)

Implement ccache if you:
- Frequently modify and rebuild **large C/C++ projects**
- Build **custom kernels** or kernel modules regularly
- Develop with **ROCm/CUDA** and rebuild GPU packages
- Maintain **custom Qt applications** or KDE software
- Do **iterative development** with large compiled dependencies
- Experience **multi-hour build times** for incremental changes

**Expected ROI**: 80-95% build time reduction on rebuilds

### ⚠️ **Low Value Scenarios** (Skip ccache)

ccache provides minimal benefit if you:
- Primarily use **pre-built binary caches** (cache.nixos.org, P620 cache)
- Rarely build packages from source
- Don't do iterative C/C++ development
- Have sufficient build time already (<10 minutes)
- Don't have spare disk space for cache (requires 10-50GB)

**Expected ROI**: <10% improvement, not worth complexity

### 📊 **Your Current Infrastructure Assessment**

Based on system analysis:

**Packages that would benefit:**
- ✅ Qt framework packages (qtbase, qtwayland, qtsvg, etc.)
- ✅ LLVM/Clang toolchain (for development)
- ✅ GCC toolchain
- ✅ PyQt bindings (if building from source)
- ✅ Rust/Go toolchains (if compiling LLVM backends)
- ⚠️ KDE applications (polkit-kde-agent)
- ⚠️ Browser (Google Chrome - likely binary)

**Binary cache coverage:**
- ✅ Most packages use nixpkgs binary cache
- ✅ P620 provides custom binary cache for other hosts
- ⚠️ Custom/modified packages would benefit from ccache

## Implementation Complexity

### 🔴 **Critical Challenges**

#### 1. **Random Seed Problem** (Severity: HIGH)
- **Issue**: NixOS adds `-frandom-seed` that changes with derivation hash
- **Impact**: Without workaround, cache hit rate is **0.35%** (useless)
- **Workaround**: `CCACHE_SLOPPINESS=random_seed`
- **Trade-off**: May affect reproducibility guarantees
- **Risk**: Potential cache poisoning

**Mitigation**: Accept reduced reproducibility or accept low cache hit rate

#### 2. **Sandbox Configuration** (Severity: HIGH)
- **Issue**: Cache directory must be exposed to Nix sandbox
- **Impact**: Silent build failures if misconfigured
- **Complexity**: Requires system-level configuration
- **Fragility**: Easy to break on system updates

**Required steps:**
```nix
# Must be exact:
nix.settings.extra-sandbox-paths = ["/nix/var/cache/ccache"];
# Directory permissions: 0770, owner: root:nixbld
```

#### 3. **Manual Package Management** (Severity: MEDIUM)
- **Issue**: Must manually specify every package
- **Impact**: Ongoing maintenance burden
- **Limitation**: Only works for top-level packages
- **Workaround**: None currently available

**Example:**
```nix
programs.ccache.packageNames = [
  "qtbase" "qtwayland" "qtsvg"  # Must list ALL
  # Any new package? Add here manually
];
```

#### 4. **Indirect stdenv Usage** (Severity: MEDIUM)
- **Issue**: Some packages don't use stdenv directly
- **Impact**: Must manually override build system
- **Complexity**: Requires deep package knowledge
- **Debugging**: Difficult to troubleshoot

#### 5. **Cache Management** (Severity: LOW)
- **Issue**: Cache can grow to 50GB+
- **Impact**: Disk space consumption
- **Maintenance**: Requires periodic cleanup
- **Monitoring**: Need to track cache efficiency

### 🟡 **Ongoing Maintenance**

**Required:**
- Monitor cache hit rates with `nix-ccache --show-stats`
- Clean cache periodically: `ccache --cleanup`
- Set size limits: `ccache --max-size 20G`
- Update package list as dependencies change
- Verify sandbox paths after system updates

**Time investment:**
- Initial setup: 4-8 hours
- Monthly maintenance: 30 minutes
- Per-package configuration: 15-30 minutes

## Package Selection Strategy

### Method 1: Build Time Analysis

**Step 1**: Identify packages that take longest to build
```bash
# Run provided script:
./scripts/identify-ccache-candidates.sh
```

**Step 2**: Measure actual build times
```bash
# Time a rebuild without ccache
time nix build .#nixosConfigurations.p620.config.system.build.toplevel

# Compare with ccache enabled (after initial cache population)
```

### Method 2: Development Workflow Analysis

**Consider enabling ccache for packages you:**
1. Build from source locally (not from binary cache)
2. Modify frequently during development
3. Have incremental changes to
4. Experience long build times with

### Method 3: System-Specific Packages

**P620 (AMD workstation) priorities:**
- ROCm packages (if building from source) - **HIGHEST**
- Mesa drivers (if custom builds)
- Qt development packages
- Language toolchains

**Razer/P510 (NVIDIA systems) priorities:**
- CUDA packages (if building from source)
- NVIDIA drivers (if custom)
- Development toolchains

**All hosts:**
- Custom kernels (if applicable)
- Local Qt applications
- Development projects

### Method 4: Monitoring Approach

**Start small, expand based on metrics:**

Phase 1: Enable for 1-2 packages with known long build times
```nix
programs.ccache.packageNames = [ "qtbase" ];
```

Phase 2: Monitor cache hit rate
```bash
nix-ccache --show-stats
# Target: >70% cache hit rate
```

Phase 3: Expand to more packages if successful
```nix
programs.ccache.packageNames = [ "qtbase" "qtwayland" "qtsvg" ];
```

Phase 4: Measure ROI
- Build time before: X hours
- Build time after: Y minutes
- ROI: (X - Y) / setup time

## Cost-Benefit Matrix

| Factor | Without ccache | With ccache | Difference |
|--------|---------------|-------------|------------|
| **Build time** (first) | 2-4 hours | 2-4 hours | No change |
| **Build time** (incremental) | 2-4 hours | 5-20 minutes | **95% reduction** |
| **Disk usage** | Current | +10-50GB | Increase |
| **Configuration complexity** | Simple | Complex | Increase |
| **Maintenance time** | None | 30min/month | Increase |
| **Reproducibility** | Guaranteed | Reduced | Decrease |
| **Setup time** | None | 4-8 hours | Increase |

## Recommendation

### ✅ **IMPLEMENT ccache IF:**

1. You build **ROCm, CUDA, or kernel** packages from source regularly
2. You do **active C/C++ development** with long build times
3. You have **spare disk space** (50GB+ recommended)
4. You're willing to **trade reproducibility** for speed
5. You can **invest 4-8 hours** in setup and testing

**Expected benefit**: 80-95% build time reduction on incremental rebuilds

### ❌ **SKIP ccache IF:**

1. You primarily use **binary caches** (cache.nixos.org, P620)
2. You rarely build packages from source
3. Current build times are **acceptable** (<10 minutes)
4. You need **strict reproducibility** guarantees
5. You don't have disk space for cache

**Expected benefit**: <10% improvement, not worth the complexity

### 🤔 **TEST FIRST IF:**

1. You're **unsure** about your build patterns
2. You want to **validate** the benefit before full commitment
3. You have **one specific package** with long build times

**Recommended approach**:
```bash
# Phase 0: Test with ONE package
programs.ccache = {
  enable = true;
  packageNames = [ "qtbase" ];  # Start with one
};

# Measure results for 2 weeks
# Then decide: expand, maintain, or remove
```

## Implementation Roadmap (If Proceeding)

### Phase 1: Minimal Viable Implementation (1 day)
- [ ] Enable `programs.ccache.enable = true`
- [ ] Configure sandbox paths
- [ ] Create cache directory with correct permissions
- [ ] Test with ONE package
- [ ] Measure baseline cache hit rate

### Phase 2: Optimization (2-3 days)
- [ ] Add ccacheWrapper overlay with environment variables
- [ ] Configure CCACHE_SLOPPINESS=random_seed
- [ ] Set cache size limits
- [ ] Expand to 3-5 high-value packages
- [ ] Document configuration

### Phase 3: Monitoring (ongoing)
- [ ] Set up cache statistics monitoring
- [ ] Create maintenance procedures
- [ ] Measure ROI (build time savings)
- [ ] Adjust package list based on metrics

### Phase 4: Scale or Rollback (week 2)
- [ ] If ROI > 50%: Expand to more packages
- [ ] If ROI < 20%: Rollback and close issue
- [ ] Document lessons learned

## Alternatives to Consider

### Alternative 1: Binary Cache Optimization
**Instead of ccache**, optimize binary cache usage:
- Ensure P620 nix-serve is properly configured
- Use aggressive substituters configuration
- Build once, distribute to all hosts

**Benefit**: Simpler, more reliable, better for your multi-host setup

### Alternative 2: Nix Build Optimization
**Focus on nix-specific optimizations:**
- Parallel builds: `nix.settings.max-jobs = "auto"`
- More cores: `nix.settings.cores = 0`
- Keep outputs: `nix.settings.keep-outputs = true`

**Benefit**: Faster builds without ccache complexity

### Alternative 3: Selective Package Versions
**Use binary versions** for development packages:
- Don't build Qt from source, use binary
- Don't customize LLVM, use upstream
- Accept some impurity for speed

**Benefit**: Zero build time for most packages

## Conclusion

**For your infrastructure:**

Given that:
1. You have **multi-host setup** with binary cache (P620)
2. You're focused on **NixOS configuration**, not C++ development
3. You have **existing performance optimizations** in place
4. Most packages likely come from **nixpkgs binary cache**

**Recommendation**: **⚠️ DEFER implementation**

**Instead, consider:**
1. Optimize binary cache usage across hosts
2. Profile actual build times to identify bottlenecks
3. Only implement ccache if you identify **specific packages** with >1 hour rebuild times
4. Start with **test phase** for ONE package before system-wide rollout

**Close issue #59 with**:
- "Evaluated, deferred pending specific use case"
- "Will reconsider if ROCm/kernel development becomes primary workflow"
- "Current binary cache strategy is more appropriate for infrastructure focus"

## References

- [NixOS Wiki: CCache](https://nixos.wiki/wiki/CCache)
- [NixOS Discourse: CCache system wide](https://discourse.nixos.org/t/ccache-system-wide/27305)
- [GitHub Issue: CCache system wide support](https://github.com/NixOS/nixpkgs/issues/227940)
- [NixOS Discourse: Low cache hit rates](https://discourse.nixos.org/t/really-low-ccache-hit-rates-when-overriding-a-package/47421)
