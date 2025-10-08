# NixOS Configuration Deduplication Report

> **Scan Date**: 2025-01-15
> **Total Files Analyzed**: 557 .nix files
> **Status**: Critical issues identified, action plan ready

## Executive Summary

Comprehensive deep scan completed of the entire NixOS configuration repository. Analysis identified **300-500 lines of potential code reduction** through strategic consolidation of duplicate configurations and packages.

### Key Findings

- **Total .nix files scanned:** 557
- **Duplicate packages found:** 157 (41 are false positives - script builders)
- **Duplicate services found:** 10 (5 critical, 3 acceptable)
- **Duplicate imports found:** 89
- **Duplicate options found:** 106
- **Critical issues requiring action:** 5
- **High-priority optimizations:** 3

### Impact Summary

| Priority    | Issues | Lines Saved | Effort     | Risk    |
| ----------- | ------ | ----------- | ---------- | ------- |
| 🔴 Critical | 5      | 200-250     | Low        | Low     |
| 🟠 High     | 3      | 100-150     | Medium     | Low     |
| 🟡 Medium   | 3      | 50-100      | Medium     | Medium  |
| **TOTAL**   | **11** | **350-500** | **Medium** | **Low** |

---

## 🔴 CRITICAL PRIORITY - Immediate Action Required

### 1. Service Duplication (5 instances)

**Impact**: 200+ lines saved | **Effort**: Low | **Risk**: Low

#### Problem: Multiple Service Definitions

Services configured in both host-specific files AND modules, causing potential conflicts.

| Service                   | Duplicate Locations                                                                                           | Severity |
| ------------------------- | ------------------------------------------------------------------------------------------------------------- | -------- |
| **loki**                  | • `hosts/dex5550/nixos/loki.nix`<br>• `modules/monitoring/loki.nix`                                           | HIGH     |
| **flaresolverr**          | • `hosts/p510/flaresolverr.nix`<br>• `modules/services/flaresolverr/default.nix`                              | HIGH     |
| **spice-vdagentd**        | • `modules/virt/spice.nix`<br>• `modules/virt/virt.nix`                                                       | MEDIUM   |
| **tailscale-autoconnect** | • `hosts/samsung/configuration.nix`<br>• `home/network/tailscale.nix`<br>• `modules/networking/tailscale.nix` | HIGH     |
| **mpd**                   | • `hosts/p510/nixos/mpd.nix`<br>• `hosts/p620/nixos/mpd.nix`                                                  | REVIEW   |

#### Recommended Actions

**Step 1: Remove host-specific service files**

```bash
# Backup first
git add .
git commit -m "chore: Backup before deduplication"

# Remove duplicate service configurations
rm hosts/dex5550/nixos/loki.nix
rm hosts/p510/flaresolverr.nix

# Test affected hosts
just test-host dex5550
just test-host p510
```

**Step 2: Edit module conflicts**

```nix
# In modules/virt/virt.nix
# Remove the spice-vdagentd service configuration
# Keep only in modules/virt/spice.nix

# In hosts/samsung/configuration.nix
# Remove tailscale-autoconnect systemd service
# Rely on modules/networking/tailscale.nix only
```

**Step 3: Review MPD configuration**

```bash
# Compare the two MPD configurations
diff hosts/p510/nixos/mpd.nix hosts/p620/nixos/mpd.nix

# If identical: Create common module
# If different: Document why host-specific needed
```

**Expected Outcome**: 200-250 lines removed, cleaner architecture, no conflicts

---

### 2. Browser Package Duplication

**Impact**: 30+ lines saved | **Effort**: Low | **Risk**: Low

#### Problem: google-chrome in 6 locations

Browser packages scattered across profile and user home files instead of using the dedicated browser module.

**Current Situation**:

- ✅ `home/browsers/chrome.nix` exists (CORRECT)
- ❌ Listed again in 5 other files

**Files to Edit**:

1. `home/profiles/desktop-user/default.nix`
2. `home/profiles/laptop-user/default.nix`
3. `Users/olafkfreund/p620_home_profile.nix`
4. `Users/olafkfreund/p620_home.nix`
5. `Users/olafkfreund/razer_home_profile.nix`

#### Solution

**Remove package listings, ensure module is imported**:

```nix
# In home/profiles/desktop-user/default.nix
# BEFORE:
home.packages = with pkgs; [
  google-chrome  # ❌ Remove this
  firefox
  # ...
];

# AFTER:
imports = [
  ../../browsers/chrome.nix  # ✅ Import module instead
];
```

**Implementation**:

```bash
# Edit each file to remove google-chrome from packages list
# Verify chrome module is imported in profile

just test-all-parallel
```

---

## 🟠 HIGH PRIORITY - Significant Optimization

### 3. Theme Configuration Duplication

**Impact**: 100-150 lines saved | **Effort**: Medium | **Risk**: Low

#### Problem: Theme packages duplicated across 5+ hosts

Common theme packages repeated in every host's stylix/theme configuration:

- `bibata-cursors` (6 files)
- `base16-schemes` (6 files)
- `nerd-fonts` (6 files)
- `noto-fonts` (5 files)

**Current Locations**:

```
hosts/samsung/themes/stylix.nix
hosts/hp/themes/stylix.nix
hosts/razer/themes/stylix.nix
hosts/p620/themes/stylix.nix
hosts/p510/themes/stylix.nix
home/desktop/gnome/theme.nix
```

#### Solution

**Create common theme module**:

```nix
# Create: modules/desktop/theme/default.nix
{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.features.desktop.theme;
in {
  options.features.desktop.theme = {
    enable = mkEnableOption "Common desktop theme configuration";

    cursorTheme = mkOption {
      type = types.str;
      default = "Bibata-Modern-Classic";
      description = "Cursor theme name";
    };

    fontPackages = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [
        (nerdfonts.override { fonts = [ "FiraCode" "Hack" ]; })
        noto-fonts
        noto-fonts-cjk
        noto-fonts-emoji
      ];
      description = "Font packages to install";
    };
  };

  config = mkIf cfg.enable {
    fonts.packages = cfg.fontPackages;

    environment.systemPackages = with pkgs; [
      bibata-cursors
      base16-schemes
    ];

    # Common cursor configuration
    home-manager.users = lib.mkMerge (map (user: {
      ${user}.home.pointerCursor = {
        name = cfg.cursorTheme;
        package = pkgs.bibata-cursors;
        size = 24;
      };
    }) config.hostUsers);
  };
}
```

**Update host configurations**:

```nix
# In each host's configuration.nix
features.desktop.theme = {
  enable = true;
  # Host-specific overrides if needed
};
```

**Remove theme packages from individual host theme files**.

#### Implementation

```bash
# 1. Create common module
mkdir -p modules/desktop/theme
# Create modules/desktop/theme/default.nix (see above)

# 2. Add to modules/default.nix
# ./desktop/theme/default.nix

# 3. Update each host configuration
# Remove duplicate theme packages
# Enable common theme module

# 4. Test all hosts
just test-all-parallel

# 5. Clean up old theme files if now empty
```

---

### 4. Terminal Configuration Duplication

**Impact**: 50+ lines saved | **Effort**: Medium | **Risk**: Low

#### Problem: Terminal packages referenced in non-terminal modules

Terminal packages appearing in shell configurations and scripts instead of relying on terminal modules.

| Terminal      | Occurrences | Module Exists                      | Action                   |
| ------------- | ----------- | ---------------------------------- | ------------------------ |
| **zsh**       | 11 files    | N/A (shell)                        | Review for consolidation |
| **kitty**     | 7 files     | ✅ `home/desktop/terminals/kitty/` | Remove from scripts      |
| **foot**      | 6 files     | ✅ `home/desktop/terminals/foot/`  | Remove from scripts      |
| **alacritty** | 4 files     | N/A                                | Consolidate to module    |

#### Problematic References

```
home/shell/zsh.nix                    # Should not reference kitty/foot
home/shell/claude-integration.nix     # Should not reference terminals
home/desktop/rofi/default.nix         # Terminal launcher - OK
```

#### Solution

**Ensure separation of concerns**:

- Terminal modules: Provide terminal emulators
- Shell configs: Configure shell behavior only
- Scripts: Use `$TERMINAL` environment variable, not hardcoded paths

```nix
# In home/shell/zsh.nix
# BEFORE:
home.packages = with pkgs; [
  kitty  # ❌ Terminal - wrong place
  foot   # ❌ Terminal - wrong place
];

# AFTER:
# Let profiles handle terminals via imports
# Shell config focuses on shell only
```

---

### 5. Kernel Sysctl Settings Consolidation

**Impact**: Conflict prevention | **Effort**: High | **Risk**: Medium

#### Problem: boot.kernel.sysctl in 19 files

Potential for conflicting kernel parameters when same settings defined in multiple places.

**Current Locations** (19 files):

- `hosts/p620/nixos/load.nix`
- `hosts/p510/nixos/memory.nix`
- `modules/networking/performance-tuning.nix`
- `modules/storage/performance-optimization.nix`
- `modules/programs/steam.nix`
- ...and 14 more

#### Risk Analysis

**Potential Conflicts**:

- Memory settings (`vm.swappiness`, `vm.vfs_cache_pressure`)
- Network settings (`net.ipv4.tcp_*`, `net.core.*`)
- Storage settings (`vm.dirty_ratio`, `vm.dirty_background_ratio`)

#### Solution

**Consolidate with conditional logic**:

```nix
# Create: modules/system/kernel-tuning/default.nix
{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.features.performance;
in {
  options.features.performance = {
    network = mkEnableOption "Network performance tuning";
    memory = mkEnableOption "Memory performance tuning";
    storage = mkEnableOption "Storage performance tuning";
    gaming = mkEnableOption "Gaming optimizations";
  };

  config = {
    boot.kernel.sysctl = mkMerge [
      # Always enabled
      {
        "kernel.sysrq" = 1;
        "net.ipv4.ip_forward" = mkDefault 0;
      }

      # Network performance
      (mkIf cfg.network {
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";
        "net.core.rmem_max" = 134217728;
        "net.core.wmem_max" = 134217728;
      })

      # Memory optimization
      (mkIf cfg.memory {
        "vm.swappiness" = 10;
        "vm.vfs_cache_pressure" = 50;
        "vm.dirty_ratio" = 10;
        "vm.dirty_background_ratio" = 5;
      })

      # Storage optimization
      (mkIf cfg.storage {
        "vm.dirty_writeback_centisecs" = 1500;
        "vm.dirty_expire_centisecs" = 3000;
      })

      # Gaming optimizations
      (mkIf cfg.gaming {
        "vm.max_map_count" = 2147483642;
        "fs.file-max" = 524288;
      })
    ];
  };
}
```

**Host configurations**:

```nix
# hosts/p620/configuration.nix
features.performance = {
  network = true;
  memory = true;
  storage = true;
  gaming = true;
};
```

**Remove sysctl settings from**:

- Individual host files
- Specific service modules (move to kernel-tuning)
- Performance modules (consolidate)

#### Implementation

```bash
# 1. Create consolidated module
mkdir -p modules/system/kernel-tuning
# Create modules/system/kernel-tuning/default.nix

# 2. Audit all 19 files with sysctl settings
# Document what each setting does
# Categorize: network, memory, storage, gaming, security

# 3. Gradually migrate settings to new module
# Test after each migration

# 4. Remove old sysctl definitions
# Verify no conflicts with: nix eval

# 5. Test all hosts thoroughly
just test-all-parallel
```

---

## 🟡 MEDIUM PRIORITY - Optimization Opportunities

### 6. Shell Alias Consolidation

**Impact**: Improved maintainability | **Effort**: Medium | **Risk**: Low

#### Current Situation

`programs.zsh.shellAliases` appears in 8 files with overlapping definitions.

**Recommendation**: Implement **suites concept** from usmcamp0811 research with `convertAlias` function.

Defer to **Phase 2** of implementation plan from research document.

---

### 7. Firewall Port Management

**Impact**: Better organization | **Effort**: Low | **Risk**: Low

#### Current Situation

`networking.firewall.allowedTCPPorts` in 13 files - each module declares its required ports.

**Assessment**: ✅ **This is actually CORRECT pattern**

- Services declare their own port requirements
- NixOS merges all port lists automatically
- No consolidation needed

**Documentation Only**: Add comment explaining this is intentional.

---

## 🟢 LOW PRIORITY - False Positives

### 8. Script Builders (NOT Duplicates)

**Assessment**: ✅ **CORRECT NixOS PATTERN**

The following are NOT duplicates but standard NixOS patterns:

- `writeShellScriptBin` (41 files) ✅
- `writeShellScript` (34 files) ✅
- `writeScriptBin` (7 files) ✅
- `writeText` (7 files) ✅

Each module creates its own scripts - this is intentional and correct.

**Action**: None required

---

### 9. Common Utility Packages

**Assessment**: ✅ **ACCEPTABLE PATTERN**

Packages appearing in many files due to legitimate needs:

- `curl` (12 files) - HTTP client for scripts
- `jq` (7 files) - JSON processing
- `coreutils` (9 files) - Basic utilities
- `bash` (11 files) - Shell for scripts

**Action**: None required - these are dependencies

---

## 📋 Implementation Roadmap

### Phase 1: Critical Fixes (Week 1)

**Goal**: Remove service duplications and browser package duplication

**Tasks**:

1. ✅ Backup configuration: `git add . && git commit -m "Pre-deduplication backup"`
2. Remove duplicate service files:
   - `hosts/dex5550/nixos/loki.nix`
   - `hosts/p510/flaresolverr.nix`
3. Edit `modules/virt/virt.nix` - remove spice-vdagentd
4. Edit `hosts/samsung/configuration.nix` - remove tailscale-autoconnect
5. Remove `google-chrome` from 5 profile/user files
6. Test: `just test-all-parallel`
7. Deploy if tests pass

**Expected Outcome**:

- 200-250 lines removed
- Cleaner module architecture
- No service conflicts

### Phase 2: High-Priority Optimizations (Week 2)

**Goal**: Theme consolidation and terminal cleanup

**Tasks**:

1. Create `modules/desktop/theme/default.nix`
2. Migrate theme packages from 6 host files
3. Update host configurations to use new module
4. Clean up terminal references in non-terminal modules
5. Test: `just test-all-parallel`
6. Deploy if tests pass

**Expected Outcome**:

- 100-150 lines removed
- Centralized theme management
- Better separation of concerns

### Phase 3: Medium-Priority Consolidations (Week 3-4)

**Goal**: Kernel tuning consolidation and shell improvements

**Tasks**:

1. Audit all 19 sysctl configurations
2. Create `modules/system/kernel-tuning/default.nix`
3. Migrate kernel settings with categories
4. Test extensively on all hosts
5. Document remaining edge cases

**Expected Outcome**:

- 50-100 lines removed
- No kernel parameter conflicts
- Better performance tuning organization

---

## 📊 Detailed Analysis

### Duplicate Packages by Frequency

| Package             | Count | Severity  | Action                           |
| ------------------- | ----- | --------- | -------------------------------- |
| writeShellScriptBin | 41    | ✅ OK     | None - correct pattern           |
| writeShellScript    | 34    | ✅ OK     | None - correct pattern           |
| curl                | 12    | ✅ OK     | Dependency - keep                |
| zsh                 | 11    | 🟡 REVIEW | Consider consolidation           |
| bash                | 11    | ✅ OK     | Shell dependency - keep          |
| coreutils           | 9     | ✅ OK     | Utilities - keep                 |
| jq                  | 7     | ✅ OK     | JSON processing - keep           |
| kitty               | 7     | 🟡 MEDIUM | Remove from non-terminal modules |
| google-chrome       | 6     | 🔴 HIGH   | **Action required**              |
| bibata-cursors      | 6     | 🔴 HIGH   | **Action required**              |
| base16-schemes      | 6     | 🔴 HIGH   | **Action required**              |
| nerd-fonts          | 6     | 🔴 HIGH   | **Action required**              |

### Duplicate Options by Frequency

| Option                              | Count | Severity  | Action                     |
| ----------------------------------- | ----- | --------- | -------------------------- |
| systemd.tmpfiles.rules              | 37    | ✅ OK     | Different rules per module |
| boot.kernel.sysctl                  | 19    | 🔴 HIGH   | **Consolidate**            |
| windowManager.hyprland.extraConfig  | 14    | ✅ OK     | Modular config             |
| networking.firewall.allowedTCPPorts | 13    | ✅ OK     | Each module declares ports |
| programs.zsh.shellAliases           | 8     | 🟡 MEDIUM | Consider suites approach   |
| programs.zsh.interactiveShellInit   | 8     | ✅ OK     | Multiple AI providers      |

---

## 🎯 Success Metrics

### Before Deduplication

- Total .nix files: 557
- Estimated duplicate lines: 350-500
- Service conflicts: 5 critical
- Package duplication: 157 instances

### After Deduplication (Target)

- Lines removed: 350-500
- Service conflicts: 0
- Package duplication: <50 (only dependencies)
- Code maintainability: Significantly improved

### Testing Criteria

- ✅ All hosts build successfully: `just test-all-parallel`
- ✅ No service conflicts in journalctl
- ✅ All features work as expected
- ✅ Performance unchanged or improved

---

## ⚠️ Important Considerations

### What's NOT a Duplicate

1. **Script Builders**: `writeShellScriptBin`, `writeScript` etc. are function calls, not package duplicates
2. **Service Declarations**: Each module should declare its service requirements
3. **Firewall Ports**: Each service declares required ports - NixOS merges them
4. **Option Merging**: NixOS uses `lib.mkMerge` - multiple definitions are intentional
5. **Dependencies**: Packages like `curl`, `jq` are needed in multiple contexts

### What IS a Duplicate (and needs fixing)

1. **Same Service in Multiple Files**: Service should be in ONE module only
2. **UI Packages in Multiple Profiles**: Use imports instead of listing packages
3. **Theme Packages Repeated**: Centralize common theme elements
4. **Conflicting Kernel Settings**: Consolidate to avoid parameter conflicts

---

## 📖 References

- Full scan reports: `/tmp/nixos_duplicate_report.txt`, `/tmp/enhanced_report.txt`
- Research analysis: `docs/RESEARCH_USMCAMP_DOTFILES.md`
- Anti-patterns guide: `docs/NIXOS-ANTI-PATTERNS.md`

---

## 🚀 Next Steps

**Immediate Actions** (This Week):

1. Review this report
2. Start Phase 1 implementation
3. Test each change incrementally
4. Document any edge cases discovered

**Questions to Answer**:

1. Is MPD configuration intentionally host-specific? (Review needed)
2. Are there any custom modifications in duplicate service files?
3. Which kernel settings are host-specific vs. global?

---

**Report Generated**: 2025-01-15
**Status**: Ready for implementation
**Estimated Effort**: 3-4 weeks total
**Risk Level**: Low (with proper testing)
**Expected Benefit**: 350-500 lines removed, improved maintainability
