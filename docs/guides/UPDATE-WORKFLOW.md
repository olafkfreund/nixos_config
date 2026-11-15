# NixOS Update Workflow Guide

> Complete guide to preview, track, and apply NixOS updates with detailed package visibility

## Overview

This guide covers the enhanced update workflow using **nvd** (Nix Version Diff) to preview changes before building and
deploying. The workflow provides detailed visibility into package updates, newly added packages, and system changes.

## Tools Used

- **nvd** - Human-readable package version diff tool
- **preview-updates.sh** - Preview system updates with detailed package changes
- **system-diff.sh** - Compare the two most recent deployed system generations
- **Justfile commands** - Integrated workflow automation

## Quick Start

### Basic Update Preview

```bash
# Preview updates for current host
just preview-updates

# Preview updates for specific host
just preview-updates p620
just preview-updates razer
```

### Compare Deployed Generations

After deployment, run `just system-diff` to compare the two most recent system generations.

### Complete Workflow

```bash
# Update, test, commit, and deploy
just update-commit-deploy

# For specific host
just update-commit-deploy p620
```

## Detailed Workflow

### Step 1: Preview Updates

```bash
just preview-updates p620
```

**What This Does:**

1. **Backs up** current `flake.lock` to `flake.lock.backup`
2. **Updates** nixpkgs input to latest version
3. **Shows** commit range with GitHub comparison link
4. **Builds** new system configuration
5. **Displays** detailed package changes using nvd

**Example Output:**

```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  NixOS Update Preview for: p620
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/5]  Backing up current flake.lock...
[2/5]  Checking for nixpkgs updates...
   Found updates available
[3/5]  Analyzing nixpkgs changes...
  Previous: 7e9b0dff974c
  Latest:   8a3354191c6e
  GitHub:   https://github.com/NixOS/nixpkgs/compare/7e9b0dff...8a3354191c6e
[4/5]  Building new system configuration...
   Build successful
[5/5]  Package changes:

[U.]  #1 gcc: 13.2.0 -> 13.3.0, -12.3 MiB
[U.]  #2 firefox: 122.0 -> 123.0, +45.2 MiB
[U.]  #3 linux: 6.6.15 -> 6.6.18, +2.1 MiB
[A.]  #4 neovim-plugin-copilot: ∅ -> unstable-2024-02-01, +6.5 MiB

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Preview Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Next steps:
  • Review the changes above
  • To apply: just quick-deploy p620
  • To revert: mv flake.lock.backup flake.lock

  System reboot recommended (kernel or systemd updated)
```

**Legend:**

- `[U.]` - Package updated (version change)
- `[A.]` - Package added (new to your system)
- `[R.]` - Package removed
- `+` - Size increase
- `-` - Size decrease

### Step 2: Compare Deployed Generations (Optional)

After the update has been deployed, `just system-diff` compares the two most
recent system generations. It reports added, removed, and upgraded packages in
your system closure. It does not list packages newly added to nixpkgs.

### Step 3: Apply Updates

If you're satisfied with the preview:

```bash
# Apply updates to specific host
just quick-deploy p620

# Or revert changes
mv flake.lock.backup flake.lock
```

### Step 4: Verify Deployment

Check what actually changed after deployment:

```bash
# Compare booted vs current system
nvd diff /run/booted-system /run/current-system

# If reboot needed, check differences
nvd diff /run/booted-system /run/current-system | grep -E 'linux-|systemd'
```

## Complete Interactive Workflow

For maximum convenience, use the combined workflow:

```bash
just update-commit-deploy p620
```

**What This Does:**

1. Runs `preview-updates` to show changes
2. Prompts for confirmation
3. If approved:
   - Deploys with `quick-deploy`
   - Shows new packages with `new-packages`
4. If cancelled:
   - Keeps preview for review
   - Provides revert instructions

## Understanding nvd Output

### Version Changes

```text
[U.]  #1 firefox: 122.0 -> 123.0, +45.2 MiB
```

- **U** = Updated (package version changed)
- **122.0 -> 123.0** = Old version → New version
- **+45.2 MiB** = Size change (positive = larger, negative = smaller)

### New Packages

```text
[A.]  #4 neovim-plugin-copilot: ∅ -> unstable-2024-02-01, +6.5 MiB
```

- **A** = Added (new package in your configuration)
- **∅** = Previously absent
- Shows new version and size

### Removed Packages

```text
[R.]  #8 old-package: 1.0.0 -> ∅, -2.3 MiB
```

- **R** = Removed (package no longer in configuration)
- Size freed

## Advanced Usage

### Compare Specific Revisions

```bash
# Manually specify nixpkgs revisions
OLD_REV="7e9b0dff974c"
NEW_REV="8a3354191c6e"

# Compare at package level
nix build "github:NixOS/nixpkgs/${NEW_REV}#hello"
nvd diff \
  "$(nix build "github:NixOS/nixpkgs/${OLD_REV}#hello" --no-link --print-out-paths)" \
  "$(nix build "github:NixOS/nixpkgs/${NEW_REV}#hello" --no-link --print-out-paths)"
```

### Check Specific Package Versions

```bash
# Current version
nix eval nixpkgs#firefox.version

# Version in specific revision
nix eval "github:NixOS/nixpkgs/8a3354191c6e#firefox.version"
```

### Track Package History

```bash
# Find when package was added
cd /tmp
git clone --depth 1000 https://github.com/NixOS/nixpkgs.git
cd nixpkgs
git log --all --oneline -- pkgs/applications/editors/neovim/default.nix
```

## Integration with Existing Commands

### Current Commands (Still Available)

```bash
# Check flake input changes (your existing command)
just check-updates

# Show diff using built-in tool
just diff p620

# Update the lockfile only
nix flake update
```

### New Commands (Enhanced Visibility)

```bash
# Preview before building
just preview-updates p620

# Compare the last two system generations
just system-diff

# Update, test, commit, and deploy
just update-commit-deploy p620
```

## Troubleshooting

### nvd Not Found

If you see "nvd is not installed":

```bash
# Enable in configuration
nix.development.enable = true;

# Or install directly
nix-env -i nvd
```

### Build Failures

If preview-updates fails during build:

```bash
# Check the error message
# The script automatically restores flake.lock.backup on failure

# Manually revert if needed
mv flake.lock.backup flake.lock
```

### New Packages Script Fails

If find-new-packages.sh fails:

```bash
# Ensure you ran preview-updates first
just preview-updates p620

# Or the script will try to use git history
# Make sure your config is in a git repository
```

## Best Practices

### Before Deploying

1. **Always preview first**: `just preview-updates`
2. **Review critical packages**: Check kernel, systemd, drivers
3. **Check size changes**: Large increases may need investigation
4. **Note reboot requirements**: Kernel/systemd updates need reboot

### For Production Hosts

```bash
# Test on one host first
just preview-updates p620
just quick-deploy p620

# Verify success
ssh p620 "nvd diff /run/booted-system /run/current-system"

# Then deploy to others
just preview-updates razer
just quick-deploy razer
```

### Weekly Update Routine

```bash
# Monday: Preview updates
just preview-updates

# Review changes, check release notes

# Wednesday: Deploy to non-critical host
just update-commit-deploy p620

# Friday: Deploy to remaining hosts
just update-commit-deploy razer
just update-commit-deploy p510   # owner only; agents ask first
```

## Comparison: Old vs New Workflow

### Traditional Workflow

```bash
# Old method (limited visibility)
just check-updates          # Shows commit hashes only
just diff p620             # Uses nix store diff-closures
just quick-deploy p620     # Deploy without detailed preview
```

### Enhanced Workflow

```bash
# New method (detailed visibility)
just preview-updates p620   # Shows exact package changes with nvd
just system-diff          # Compare the last two system generations
just quick-deploy p620     # Deploy after informed review
```

**Benefits:**

- See exact package versions before building
- Understand size impacts
- Identify new packages added to your system
- Compare the last two system generations available in nixpkgs
- Make informed deployment decisions

## Additional Resources

- **nvd Documentation**: <https://sr.ht/~khumba/nvd/>
- **NixOS Releases**: <https://nixos.org/manual/nixos/stable/release-notes.html>
- **Nixpkgs Updates**: <https://github.com/NixOS/nixpkgs/commits/nixos-unstable>
- **Package Search**: <https://search.nixos.org/packages>

## Summary

The enhanced update workflow provides:

1. **Detailed package visibility** with nvd's human-readable output
2. **New package discovery** to stay current with nixpkgs additions
3. **Safe preview** before committing to builds
4. **Integrated workflow** with your existing just commands
5. **Informed decisions** about when to deploy

Use `just preview-updates` before every `just quick-deploy` for maximum safety and visibility!
