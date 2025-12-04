# Update Specific NixOS Package

You are a NixOS package maintenance specialist. Update a specific package in the configuration following best practices.

## Task Overview

Update a specific package to its latest version with proper testing, documentation, and GitHub workflow integration.

## Step 1: Gather Package Information

**Ask the user for:**

1. **Which package to update?**
   - Package name (e.g., `firefox`, `neovim`, `prometheus`)

2. **Update scope:**
   - [ ] System package (in `environment.systemPackages`)
   - [ ] User package (in user configurations)
   - [ ] Custom derivation (in `pkgs/` directory)
   - [ ] Service package (managed by NixOS module)

3. **Affected hosts:**
   - [ ] All hosts
   - [ ] Specific hosts: [list]

4. **Update reason:**
   - [ ] Security update
   - [ ] Bug fix
   - [ ] New features needed
   - [ ] Dependency requirement
   - [ ] Regular maintenance

## Step 2: Locate Package Definition

```bash
# Find where package is defined
rg "PACKAGE_NAME" --type nix

# Common locations:
# - home/packages/ - User packages
# - modules/services/*.nix - Service configurations
# - pkgs/ - Custom derivations
# - hosts/*/configuration.nix - Host-specific packages
```

**Identify package type:**

### A. Package from nixpkgs (no custom derivation)
```nix
# Simply referenced in configuration
environment.systemPackages = with pkgs; [
  firefox
  neovim
];
```
**Action:** Update flake input (nixpkgs)

### B. Custom Package Derivation
```nix
# Custom package in pkgs/
pkgs.callPackage ./pkgs/mypackage {}
```
**Action:** Update derivation directly

### C. Overridden Package
```nix
# Package with overrides
(pkgs.package.override { enableFeature = true; })
```
**Action:** Update override or nixpkgs

## Step 3: Check Current and Latest Versions

### For nixpkgs packages:

```bash
# Current version in configuration
nix eval .#nixosConfigurations.p620.pkgs.PACKAGE_NAME.version

# Latest in nixpkgs unstable
nix search nixpkgs#PACKAGE_NAME --json | jq '.[].version'

# Latest in nixpkgs stable
nix search nixpkgs/nixos-24.11#PACKAGE_NAME --json | jq '.[].version'

# Check upstream releases
# GitHub: https://github.com/owner/repo/releases
# GitLab: https://gitlab.com/owner/repo/-/releases
```

### For custom derivations:

```bash
# Read current version from derivation
cat pkgs/PACKAGE_NAME/default.nix | grep version

# Check upstream for latest
# Use WebSearch or curl to check release page
```

## Step 4: Update Strategy Selection

Choose update method based on package type:

### Strategy A: Update flake input (nixpkgs package)

```bash
# Update nixpkgs to get latest packages
nix flake lock --update-input nixpkgs

# Or use specific nixpkgs version
nix flake lock --override-input nixpkgs github:NixOS/nixpkgs/nixos-unstable
```

**Pros:** Gets all package updates at once
**Cons:** May cause other changes

### Strategy B: Update custom derivation

**Follow pattern from @docs/PATTERNS.md:**

```nix
{ lib, stdenv, fetchFromGitHub, ... }:

stdenv.mkDerivation rec {
  pname = "package-name";
  version = "NEW_VERSION";  # <-- Update this

  src = fetchFromGitHub {
    owner = "owner";
    repo = "repo";
    rev = "v${version}";
    hash = "sha256-XXXXXXX";  # <-- Update this
  };

  # Update other fields if needed

  meta = with lib; {
    description = "Package description";
    homepage = "https://example.com";
    license = licenses.mit;
    maintainers = with maintainers; [ yourname ];
    platforms = platforms.linux;
  };
}
```

### Strategy C: Pin specific package version

```nix
# Create override for specific package
nixpkgs.config.packageOverrides = pkgs: {
  PACKAGE_NAME = pkgs.PACKAGE_NAME.overrideAttrs (old: rec {
    version = "X.Y.Z";
    src = pkgs.fetchurl {
      url = "https://example.com/package-${version}.tar.gz";
      hash = "sha256-XXXX";
    };
  });
};
```

## Step 5: Update Implementation

### For Custom Derivations:

1. **Update version:**
   ```bash
   # Edit derivation file
   vim pkgs/PACKAGE_NAME/default.nix
   ```

2. **Calculate new hash:**
   ```bash
   # Method 1: nix-prefetch-url
   nix-prefetch-url --unpack https://github.com/owner/repo/archive/refs/tags/vX.Y.Z.tar.gz

   # Method 2: Set empty hash and build
   # Set: hash = "";
   # Run build and copy correct hash from error

   # Method 3: nix-prefetch-git (for git sources)
   nix-prefetch-git --url https://github.com/owner/repo --rev vX.Y.Z
   ```

3. **Update dependencies if needed:**
   ```nix
   buildInputs = with pkgs; [
     # Add new dependencies
     # Update version requirements
   ];
   ```

### For nixpkgs Updates:

```bash
# Update flake input
nix flake lock --update-input nixpkgs

# Or update to specific commit
nix flake lock --override-input nixpkgs github:NixOS/nixpkgs/COMMIT_HASH
```

## Step 6: Test the Update

### Syntax Validation:

```bash
# Check Nix syntax
just check-syntax

# Validate configuration
just validate-quick
```

### Build Test:

```bash
# Test on affected hosts
just test-host p620

# Test all hosts if system-wide change
just quick-test
```

### Package-Specific Testing:

```bash
# Build the package
nix build .#packages.x86_64-linux.PACKAGE_NAME

# Test the binary
result/bin/PACKAGE_NAME --version
result/bin/PACKAGE_NAME --help

# Run package tests if available
nix build .#packages.x86_64-linux.PACKAGE_NAME.tests
```

### Runtime Testing:

For services:
```bash
# Deploy to test host
just quick-deploy p620

# Check service status
ssh p620 "systemctl status SERVICE_NAME"

# Check service logs
ssh p620 "journalctl -u SERVICE_NAME -n 50"
```

## Step 7: Create GitHub Issue

```bash
/new_task
```

**Issue template:**

- **Type:** chore (for maintenance) or feat (for feature-related updates)
- **Priority:**
  - critical: Security updates
  - high: Bug fixes
  - medium: Regular updates
  - low: Optional improvements

- **Title:** "Update PACKAGE_NAME to version X.Y.Z"

- **Description:**
  ```markdown
  Update PACKAGE_NAME from vOLD to vNEW

  ## Reason
  [Security fix / Bug fix / New features / Regular maintenance]

  ## Changes
  - Version: OLD → NEW
  - Hash: [updated/unchanged]
  - Dependencies: [added/removed/unchanged]

  ## Testing
  - [ ] Builds successfully
  - [ ] Package tests pass
  - [ ] Service starts correctly (if applicable)
  - [ ] No breaking changes detected

  ## Affected Hosts
  - [ ] P620
  - [ ] Razer
  - [ ] P510
  - [ ] Samsung

  ## Release Notes
  [Link to upstream changelog]

  ## Breaking Changes
  [None / List changes]
  ```

## Step 8: Create Branch and Commit

```bash
# Get issue number
ISSUE_NUM=123

# Determine commit type
# - chore: Regular maintenance updates
# - fix: Bug fix updates
# - feat: Feature-adding updates
# - security: Security updates
COMMIT_TYPE="chore"

# Create branch
git checkout -b ${COMMIT_TYPE}/${ISSUE_NUM}-update-PACKAGE_NAME-X.Y.Z

# Stage changes
git add [affected files]

# Create detailed commit
git commit -m "${COMMIT_TYPE}(PACKAGE_NAME): update to version X.Y.Z (#${ISSUE_NUM})

Update PACKAGE_NAME package:
- Version: OLD → X.Y.Z
- [Hash updated / Dependencies added / etc.]

Changes in this release:
- [Feature/fix 1]
- [Feature/fix 2]

Testing:
- Built successfully on [hosts]
- [Service tests passed / Binary verified functional]
- No breaking changes detected

[Fixes #${ISSUE_NUM}]
[Security advisory: CVE-XXXX-XXXX] (if applicable)"

# Push branch
git push -u origin ${COMMIT_TYPE}/${ISSUE_NUM}-update-PACKAGE_NAME-X.Y.Z
```

## Step 9: Create Pull Request

```bash
# Create PR
gh pr create --fill --base main
```

**PR checklist:**

```markdown
## Summary
Update PACKAGE_NAME to version X.Y.Z

## Changes
- ✅ Version updated from OLD → X.Y.Z
- ✅ Hash recalculated (if needed)
- ✅ Dependencies updated (if needed)
- ✅ Tested on affected hosts

## Testing Evidence
\```bash
# Build successful
just test-host HOST ✅

# Package tests passed
nix build .#packages.x86_64-linux.PACKAGE_NAME ✅

# Service operational (if applicable)
systemctl status SERVICE_NAME ✅
\```

## Release Notes
[Link to changelog]

**Key changes:**
- Change 1
- Change 2

**Breaking changes:** [None/List]

## Security
[No security implications / Security advisory CVE-XXXX-XXXX addressed]

## Checklist
- [ ] Version updated
- [ ] Hash recalculated (if needed)
- [ ] Tested on all affected hosts
- [ ] Service verified operational (if applicable)
- [ ] Documentation updated (if needed)
- [ ] No anti-patterns introduced
- [ ] Follows @docs/PATTERNS.md

Closes #${ISSUE_NUM}
```

## Step 10: Code Review

```bash
# Request code review
/review
```

**Focus areas:**
- Package derivation correctness
- Hash calculation accuracy
- Testing thoroughness
- Breaking changes handled
- Documentation completeness

## Step 11: Merge and Deploy

```bash
# After approval
gh pr merge ${ISSUE_NUM} --squash --delete-branch

# Deploy to affected hosts
just quick-deploy p620  # If affects P620
just quick-deploy razer  # If affects Razer
just quick-deploy p510  # If affects P510
just quick-deploy samsung  # If affects Samsung

# Or deploy to all
just deploy-all-parallel
```

## Step 12: Post-Deployment Verification

```bash
# Verify package version
for host in p620 razer p510 samsung; do
  echo "=== $host ==="
  ssh $host "PACKAGE_NAME --version" || echo "Not installed"
done

# Verify service if applicable
for host in AFFECTED_HOSTS; do
  echo "=== $host ==="
  ssh $host "systemctl status SERVICE_NAME"
done

# Monitor for issues (24h)
# Check Grafana dashboards
# Watch for alerts in Alertmanager
```

## Success Criteria

- [ ] Package updated to latest/target version
- [ ] All affected hosts tested successfully
- [ ] GitHub issue created and tracked
- [ ] Branch follows naming convention
- [ ] Commit message follows conventional commits
- [ ] PR created with comprehensive testing evidence
- [ ] Code review passed
- [ ] PR merged to main
- [ ] Deployed to all affected hosts
- [ ] Version verified post-deployment
- [ ] Service operational (if applicable)
- [ ] Monitoring shows no issues
- [ ] Documentation updated if needed

## Rollback Procedure

If issues occur:

```bash
# Option 1: Revert commit
git revert COMMIT_HASH
git push

# Option 2: Rollback system generation
ssh HOST "sudo nixos-rebuild switch --rollback"

# Option 3: Pin old version temporarily
# Add package override with old version

# Report issue
gh issue create --title "PACKAGE_NAME X.Y.Z regression" \
  --body "Description of issue after update..."
```

## Common Issues

### Hash Mismatch
```bash
# Clear cache
nix-collect-garbage -d

# Recalculate hash
nix-prefetch-url --unpack SOURCE_URL
```

### Build Failure
```bash
# Check build log
nix build --show-trace

# Keep failed build for inspection
nix build --keep-failed
cd /tmp/nix-build-*
```

### Service Won't Start
```bash
# Check service logs
journalctl -u SERVICE_NAME -n 100

# Check configuration
systemctl cat SERVICE_NAME

# Test service manually
# Run service command directly to see errors
```

### Breaking Changes
```bash
# Review changelog for migration guide
# Update configuration for new options
# Test thoroughly before deploying to all hosts
```

## Documentation References

- @docs/PATTERNS.md - Package writing patterns
- @docs/NIXOS-ANTI-PATTERNS.md - What to avoid
- @docs/GITHUB-WORKFLOW.md - Issue/PR workflow

## Example Workflows

### Example 1: Update Firefox

```bash
/update-package
# Package: firefox
# Scope: System package
# Hosts: p620, razer
# Reason: Security update

# Updates nixpkgs to get latest firefox
# Tests on both hosts
# Creates issue + PR
# Deploys after approval
```

### Example 2: Update Custom Package

```bash
/update-package
# Package: claude-code
# Scope: Custom derivation
# Hosts: All
# Reason: New features

# Updates derivation version and hash
# Tests on all hosts
# Full GitHub workflow
# Deploys to all hosts
```

### Example 3: Update Service

```bash
/update-package
# Package: prometheus
# Scope: Service package
# Hosts: p620 (monitoring server)
# Reason: Bug fix

# Updates service configuration
# Tests prometheus service
# Verifies metrics collection
# Monitors after deployment
```
