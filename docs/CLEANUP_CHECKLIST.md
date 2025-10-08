# Dead Code Cleanup Checklist

> Date: 2025-10-08
> Status: Ready for Review
> Total Items: 30+ files + 15+ code blocks

## Phase 1: Safe Immediate Removal ✅

### 1.1 Inactive User Configurations (3 files)

- [ ] `Users/htpcuser/dex5550_home.nix` - htpcuser not in hostUsers
- [ ] `Users/serveruser/p510_home.nix` - serveruser not in hostUsers
- [ ] `Users/workuser/p620_home.nix` - workuser not in hostUsers

**Status**: VERIFIED SAFE - Not in flake.nix hostUsers mapping
**Action**: `rm -v Users/{htpcuser,serveruser,workuser}/*.nix`

### 1.2 Dead Feature Files (7 items)

- [ ] `home/browsers/floorp.nix` - Floorp browser never referenced
- [ ] `home/desktop/git-sync/` - Git sync feature not imported
- [ ] `home/media/rnoise.nix` - Noise reduction not imported
- [ ] `home/profiles-compat.nix` - Compatibility layer obsolete
- [ ] `home/shell/ai-task-integration.nix` - AI task integration unused
- [ ] `home/development/ai-productivity.nix` - AI productivity unused
- [ ] `home/desktop/file-associations.nix` - File associations unused

**Status**: VERIFIED UNREFERENCED - Not imported anywhere
**Action**: `rm -v home/browsers/floorp.nix home/media/rnoise.nix ...`

### 1.3 Obsolete MicroVM Configs (3 files)

- [ ] `hosts/p510/nixos/microvm/k3s-agent-1.nix`
- [ ] `hosts/p510/nixos/microvm/k3s-agent-2.nix`
- [ ] `hosts/p510/nixos/microvm/nixvm.nix`

**Status**: SUPERSEDED - New MicroVMs in modules/microvms/
**Action**: `rm -v hosts/p510/nixos/microvm/*.nix`

### 1.4 Test After Section 1

```bash
just check-syntax
just quick-test
```

---

## Phase 2: Verification Required ⚠️

### 2.1 User Config Naming Convention (10 files)

**Current State**: Both patterns exist

- [ ] Verify flake.nix line 299: Which pattern is used?

  ```nix
  # Option A: _home.nix
  value = import (./Users + "/${user}/${host}_home.nix");

  # Option B: _home_profile.nix
  value = import (./Users + "/${user}/${host}_home_profile.nix");
  ```

**Files to migrate** (if Option B is correct):

- [ ] `Users/olafkfreund/dex5550_home.nix` → Already have \_profile version
- [ ] `Users/olafkfreund/p510_home.nix` → Already have \_profile version
- [ ] `Users/olafkfreund/p620_home.nix` → Already have \_profile version
- [ ] `Users/olafkfreund/razer_home.nix` → Already have \_profile version
- [ ] `Users/olafkfreund/samsung_home.nix` → Only \_home.nix exists

**Action**:

1. Check flake.nix line 299
2. If using \_profile.nix, remove old_home.nix files
3. If using \_home.nix, remove_profile.nix files

### 2.2 Host-Specific Files (6 files)

- [ ] `hosts/p620/home-manager-options.nix` - Check if imported
- [ ] `hosts/p620/nixos/glance.nix` - Glance dashboard config
- [ ] `hosts/p620/nixos/syncthing.nix` - Syncthing config
- [ ] `hosts/p620/nixos/vfio.nix` - VFIO passthrough config
- [ ] `hosts/razer/home-manager-options.nix` - Check if imported
- [ ] `hosts/samsung/home-manager-options.nix` - Check if imported

**Action**:

1. Search for imports: `grep -r "file_name" hosts/*/configuration.nix`
2. If not imported, review contents
3. Delete if confirmed unused

### 2.3 Test After Section 2

```bash
just test-all-parallel
```

---

## Phase 3: Commented Code Review 📝

### 3.1 Large Commented Blocks (15+ locations)

**Priority 1: Large blocks (20+ lines)**

- [ ] `hosts/dex5550/configuration.nix:146` (24 lines)
- [ ] `hosts/dex5550/configuration.nix:670` (16 lines)
- [ ] `home/desktop/terminals/ghostty/default.nix:44` (20 lines)
- [ ] `home/desktop/theme/qt.nix:28` (20 lines)

**Priority 2: Medium blocks (10-19 lines)**

- [ ] `home/desktop/walker/default.nix` (multiple 10-20 line blocks)
- [ ] `modules/tools/nixpkgs-monitors.nix:649` (15 lines)
- [ ] `hosts/razer/nixos/boot.nix:31` (17 lines)
- [ ] `hosts/razer/configuration.nix:90` (11 lines)

**Priority 3: Small blocks (6-9 lines)**

- [ ] `modules/secrets/api-keys.nix` (multiple 6 line blocks)
- [ ] `modules/security/secrets.nix` (multiple 6-7 line blocks)
- [ ] `hosts/p510/nixos/network.nix` (multiple 8-9 line blocks)

**Action for each block**:

1. Review commented code
2. Decide: Delete / Restore / Document
3. Add explanation if keeping

### 3.2 Test After Section 3

```bash
just validate
```

---

## Phase 4: Configuration Conflicts 🔧

### 4.1 Walker Configuration (CRITICAL)

**Current Issue**: Inconsistent state

- Flake input: COMMENTED (line 85)
- Cache servers: ACTIVE (lines 24-25, 33-34)
- Configuration: ACTIVE (home/desktop/walker/default.nix)
- Package source: pkgs.walker (nixpkgs)

**Option 1 (Recommended)**: Use nixpkgs walker

- [x] Keep: home/desktop/walker/default.nix (uses pkgs.walker) ✅
- [ ] Remove: walker cache servers from flake.nix lines 24-25, 33-34
- [x] Keep: walker flake input commented ✅

**Option 2**: Enable walker flake input

- [ ] Uncomment: line 85 in flake.nix
- [ ] Keep: walker cache servers
- [ ] Wait: for walker flake.nix to be available

**Decision**: Choose Option 1 or 2
**Action**: Edit flake.nix accordingly

### 4.2 Remaining Anti-Patterns (4 occurrences)

Find remaining `mkIf true` patterns:

```bash
grep -rn "mkIf.*true" modules/ --include="*.nix"
```

- [ ] Fix pattern 1
- [ ] Fix pattern 2
- [ ] Fix pattern 3
- [ ] Fix pattern 4

**Replace with**: Direct boolean assignment

```nix
# Before
services.myservice.enable = mkIf cfg.enable true;

# After
services.myservice.enable = cfg.enable;
```

### 4.3 Test After Section 4

```bash
just check-syntax
just test-all-parallel
just validate
```

---

## Phase 5: Documentation 📚

### 5.1 Untracked Research Documents (4 files)

- [ ] `.claude/NIX_ANTIPATTERNS.md` - Review and add to git
- [ ] `docs/DEDUPLICATION_REPORT.md` - Review and add to git
- [ ] `docs/RESEARCH_NIX_BOOK.md` - Decide: keep/remove
- [ ] `docs/RESEARCH_USMCAMP_DOTFILES.md` - Decide: keep/remove

**Action**:

```bash
git add docs/DEDUPLICATION_REPORT.md
git add .claude/NIX_ANTIPATTERNS.md
# Review others before adding
```

### 5.2 Architecture Documentation

- [x] Dead code analysis report ✅
- [x] Architecture hierarchy documentation ✅
- [x] Review summary ✅
- [ ] Add visual architecture diagrams
- [ ] Document profile composition examples
- [ ] Add feature flag usage guide

---

## Final Validation ✨

### Pre-Deployment Checklist

- [ ] All dead files removed
- [ ] All commented blocks reviewed
- [ ] Walker configuration resolved
- [ ] Anti-patterns eliminated
- [ ] User config naming consistent
- [ ] Documentation updated

### Testing Pipeline

```bash
# 1. Syntax validation
just check-syntax

# 2. Quick parallel test
just quick-test

# 3. Full validation
just validate

# 4. Test specific hosts if needed
just test-host p620
just test-host razer
just test-host p510
just test-host dex5550
just test-host samsung

# 5. Deploy
just quick-deploy p620  # Smart deployment per host
# or
just deploy-all-parallel  # Deploy all hosts
```

### Verification

- [ ] All hosts build successfully
- [ ] No new warnings or errors
- [ ] All tests pass
- [ ] Documentation complete
- [ ] Git commit created

---

## Cleanup Statistics

**Before Cleanup**:

- Total files: 557
- Dead files: 30+
- Commented blocks: 15+
- Anti-patterns: 4

**After Cleanup** (Target):

- Dead files: 0
- Commented blocks: 0 (or documented)
- Anti-patterns: 0

**Code Quality**: A- → A+

---

## Commands Quick Reference

```bash
# Run cleanup script
./scripts/cleanup-dead-code.sh

# Find anti-patterns
grep -r "mkIf.*true" modules/ --include="*.nix"

# Check imports
grep -r "import.*floorp" . --include="*.nix"

# Test workflow
just check-syntax
just quick-test
just validate
just deploy-all-parallel

# Git operations
git status
git add -A
git commit -m "chore: Remove dead code and clean configuration"
```

---

**Started**: 2025-10-08
**Completed**: [ In Progress ]
**Next Review**: After cleanup completion
