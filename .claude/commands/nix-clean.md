# NixOS Cleanup & Maintenance

Comprehensive cleanup operations for Nix store, old generations, and system maintenance.

**Replaces Justfile recipes**: `gc`, `gc-aggressive`, `optimize`, `full-cleanup`, `clean-all`, `cleanup-dead-code`

## Quick Usage

**Standard garbage collection** (30 seconds):

```
/nix-clean
```

**Aggressive cleanup** (2 minutes):

```
/nix-clean
Aggressive cleanup
```

**Full cleanup** (5 minutes):

```
/nix-clean
Full cleanup
```

**Optimize store** (3 minutes):

```
/nix-clean
Optimize store
```

## Features

### Cleanup Modes

**Standard GC** (~30 seconds):

- ✅ Delete generations older than 30 days
- ✅ Garbage collect unreachable store paths
- ✅ Keep current and previous generation (safe)
- ✅ Typical savings: 5-15GB

**Aggressive GC** (~2 minutes):

- ✅ Delete generations older than 7 days
- ✅ Aggressive garbage collection
- ✅ Keep only current generation
- ✅ Remove build dependencies
- ✅ Typical savings: 20-40GB

**Full Cleanup** (~5 minutes):

- ✅ Everything in Aggressive GC
- ✅ Optimize Nix store (deduplication)
- ✅ Remove dead code and unused imports
- ✅ Clean build caches
- ✅ Verify store integrity
- ✅ Typical savings: 30-60GB

**Optimize Store** (~3 minutes):

- ✅ Hard-link identical files (deduplication)
- ✅ Reclaim disk space from duplicates
- ✅ Verify store paths
- ✅ No generation deletion
- ✅ Typical savings: 10-25GB

### Specific Operations

**Remove Old Generations**:

```
/nix-clean
Remove generations older than 30 days
```

**Clean Dead Code**:

```
/nix-clean
Remove dead code
```

**Verify Store**:

```
/nix-clean
Verify store integrity
```

## Cleanup Workflow

### Weekly Maintenance

```bash
# Standard cleanup once a week
/nix-clean

# Check savings
/nix-info
Disk usage
```

### Monthly Deep Clean

```bash
# Full cleanup once a month
/nix-clean
Full cleanup

# Check results
du -sh /nix/store
```

### Before Low Disk Space

```bash
# When disk is getting full
/nix-clean
Aggressive cleanup

# If still need more space
/nix-clean
Full cleanup
```

## Output Format

### Standard GC Success

```
🧹 NixOS Cleanup - Standard GC

📊 Before Cleanup
   Store size: 87.5 GB
   Generations: 23 (oldest: 45 days)
   Disk available: 42 GB

🗑️  Removing Old Generations (10s)
   Deleted 15 generations (older than 30 days)
   Kept: current + 7 recent generations

♻️  Garbage Collection (20s)
   Freeing unused store paths...
   ✅ Freed 12.3 GB

📊 After Cleanup
   Store size: 75.2 GB
   Generations: 8
   Disk available: 54.3 GB

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Cleanup Complete
Freed: 12.3 GB
Time: 30 seconds
```

### Aggressive GC Output

```
🧹 NixOS Cleanup - Aggressive GC

📊 Before Cleanup
   Store size: 87.5 GB
   Generations: 23
   Build cache: 8.2 GB
   Disk available: 42 GB

🗑️  Removing Old Generations (15s)
   Deleted 21 generations (older than 7 days)
   Kept: current generation only

♻️  Aggressive Garbage Collection (45s)
   Removing build dependencies...
   Removing cached downloads...
   ✅ Freed 28.7 GB

📊 After Cleanup
   Store size: 58.8 GB
   Generations: 2
   Build cache: 0 GB
   Disk available: 70.7 GB

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Aggressive Cleanup Complete
Freed: 28.7 GB
Time: 1min 45s
```

### Full Cleanup Output

```
🧹 NixOS Cleanup - Full Cleanup

📊 Before Cleanup
   Store size: 87.5 GB
   Duplicates: ~15 GB
   Generations: 23
   Dead code files: 147
   Disk available: 42 GB

🗑️  Removing Old Generations (15s)
   ✅ Deleted 21 generations

♻️  Aggressive Garbage Collection (45s)
   ✅ Freed 28.7 GB

🔧 Optimizing Store (120s)
   Hard-linking identical files...
   ✅ Deduplicated 14.2 GB

🧹 Cleaning Dead Code (30s)
   Removed 147 unused import files
   ✅ Cleaned 0.8 GB

✓  Verifying Store Integrity (45s)
   Checked 45,231 store paths
   ✅ No corruption detected

📊 After Cleanup
   Store size: 43.8 GB
   Duplicates: 0 GB
   Generations: 2
   Dead code files: 0
   Disk available: 85.7 GB

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Full Cleanup Complete
Freed: 43.7 GB (50% reduction!)
Time: 4min 15s
```

## Implementation Details

### Standard GC

```bash
# Remove old generations (30 days)
nix-collect-garbage --delete-older-than 30d

# Standard garbage collection
nix-collect-garbage

# Report savings
```

### Aggressive GC

```bash
# Remove old generations (7 days)
nix-collect-garbage --delete-older-than 7d

# Aggressive collection
nix-collect-garbage -d

# Clear build cache
rm -rf ~/.cache/nix

# Report savings
```

### Full Cleanup

```bash
# Aggressive GC first
nix-collect-garbage -d --delete-older-than 7d

# Optimize store (deduplication)
nix-store --optimize

# Remove dead code
just _cleanup-dead-code

# Verify store integrity
nix-store --verify --check-contents

# Report total savings
```

### Optimize Store Only

```bash
# Hard-link identical files
nix-store --optimize

# Report deduplication savings
```

## Disk Space Analysis

### Where Space Goes

**Typical 100GB Nix Store**:

- **40GB**: Current system packages
- **25GB**: Previous generations (rollback safety)
- **15GB**: Build dependencies (cached)
- **10GB**: Duplicated files (not optimized)
- **10GB**: Old unused packages

**After Standard GC (30 days)**:

- **40GB**: Current system packages (kept)
- **10GB**: Recent generations (kept for safety)
- **0GB**: Old generations (removed)
- **10GB**: Build dependencies (kept for speed)
- **10GB**: Duplicates (kept, no optimization)
- **Total**: ~70GB (30GB freed)

**After Aggressive GC**:

- **40GB**: Current system packages (kept)
- **0GB**: Old generations (all removed)
- **0GB**: Build dependencies (removed)
- **10GB**: Duplicates (kept, no optimization)
- **Total**: ~50GB (50GB freed)

**After Full Cleanup**:

- **40GB**: Current system packages (kept)
- **0GB**: Old generations (removed)
- **0GB**: Build dependencies (removed)
- **0GB**: Duplicates (removed via optimization)
- **Total**: ~40GB (60GB freed)

## Safety Features

### Generation Protection

**Standard GC**:

- ✅ Keeps current generation
- ✅ Keeps previous generation (rollback)
- ✅ Keeps all generations < 30 days
- ⚠️ **Safe**: Can always rollback

**Aggressive GC**:

- ✅ Keeps current generation
- ✅ Keeps previous generation
- ❌ Removes all older generations
- ⚠️ **Caution**: Limited rollback

**Custom Retention**:

```
/nix-clean
Keep generations for 14 days
# Keeps current + 14 days of generations
```

### Rollback After Cleanup

If you need to rollback after cleanup:

```bash
# If generation still exists
sudo nixos-rebuild switch --rollback

# If generation was deleted
# You'll need to rebuild from configuration
sudo nixos-rebuild switch
```

## Automation

### Automatic Weekly Cleanup

**Via Systemd Timer**:

```nix
# In configuration.nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};
```

**Via Cron**:

```bash
# Weekly cleanup at 3 AM Sunday
0 3 * * 0 /nix-clean
```

### Pre-Deployment Cleanup

```bash
# Clean before deploying
/nix-clean

# Then deploy
/nix-deploy p620
```

## Best Practices

### DO ✅

- Run standard GC weekly
- Run aggressive GC when low on disk
- Run full cleanup monthly
- Optimize store after major updates
- Check disk usage before and after
- Keep at least 2 recent generations

### DON'T ❌

- Delete current generation (breaks system!)
- Run aggressive GC without backups
- Optimize during active builds
- Clean before testing (need build cache)
- Remove all generations (lose rollback)
- Run full cleanup while low on disk (might fail)

## Troubleshooting

### Cleanup Fails

```bash
# Check available disk space first
df -h /nix/store

# If very low, use aggressive mode
/nix-clean
Aggressive cleanup

# If still fails, manually remove profiles
rm ~/.nix-profile/profile-*-link
```

### Store Optimization Hangs

```bash
# Check if optimization is running
ps aux | grep "nix-store --optimize"

# If hung, kill and retry
pkill -f "nix-store --optimize"

# Run with limited parallelism
nix-store --optimize --max-jobs 1
```

### Can't Free Enough Space

```bash
# 1. Aggressive cleanup
/nix-clean
Aggressive cleanup

# 2. Remove old profiles
nix-env --delete-generations old

# 3. Remove boot entries
sudo /nix/var/nix/profiles/system-*-link

# 4. Clean home-manager
home-manager expire-generations "-7 days"

# 5. Last resort: verify and repair
nix-store --verify --check-contents --repair
```

## Integration with Other Commands

### Before Deployment

```bash
# Clean up before deploying updates
/nix-clean

# Deploy new configuration
/nix-deploy p620
```

### After Testing

```bash
# Test builds create cache artifacts
/nix-test
Test all hosts

# Clean up test artifacts
/nix-clean
```

### With Optimization

```bash
# Clean first
/nix-clean
Aggressive cleanup

# Then optimize
/nix-optimize
# Analyzes what can be further optimized
```

## Disk Usage Monitoring

### Check Before Cleanup

```bash
# See current usage
/nix-info
Disk usage

# Detailed breakdown
du -sh /nix/store
nix path-info --all --json | jq -r '.[].narSize' | awk '{s+=$1} END {print s/1024/1024/1024 " GB"}'
```

### Track Savings Over Time

```bash
# Before cleanup
BEFORE=$(du -sb /nix/store | cut -f1)

# Run cleanup
/nix-clean
Full cleanup

# After cleanup
AFTER=$(du -sb /nix/store | cut -f1)

# Calculate savings
SAVED=$(( ($BEFORE - $AFTER) / 1024 / 1024 / 1024 ))
echo "Saved ${SAVED}GB"
```

## Related Commands

- `/nix-info` - Check disk usage and store size
- `/nix-optimize` - Performance optimization (different from store optimization)
- `/nix-deploy` - Deploy after cleanup
- `/nix-test` - Test before aggressive cleanup

---

**Pro Tip**: Set up automatic weekly cleanup to keep your system lean:

```nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};
```

This keeps your Nix store clean automatically! 🧹
