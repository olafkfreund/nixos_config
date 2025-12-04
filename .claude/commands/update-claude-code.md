# Update Claude Code to Latest Version

You are a NixOS package update specialist. Update the claude-code package to the latest version following NixOS best practices.

## Task Overview

Update the Claude Code package derivation with proper hash calculation, testing, and GitHub workflow integration.

## Prerequisites

- [ ] Check for existing issues: `/check_tasks`
- [ ] Ensure clean git state: `git status`
- [ ] Review current version: `claude --version`

## Step 1: Research Latest Version

```bash
# Use WebSearch to find latest release
```

**Search for:**
1. NPM package page: https://www.npmjs.com/package/@anthropic-ai/claude-code
2. GitHub releases: https://github.com/anthropics/claude-code/releases
3. Changelog: Check for breaking changes

**Record:**
- Latest version number: `X.X.X`
- Release date
- Notable changes from changelog
- Breaking changes (if any)

## Step 2: Read Current Package Configuration

```bash
# Read the current derivation
cat home/development/claude-code/default.nix
```

**Note current:**
- Version number
- npmDepsHash value
- Any custom patches or modifications

## Step 3: Update Package Derivation

### Update Version Number

Edit `home/development/claude-code/default.nix`:

```nix
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  ...
}:
buildNpmPackage rec {
  pname = "claude-code";
  version = "X.X.X";  # <-- Update this

  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-code";
    rev = "v${version}";
    hash = "sha256-AAAA...";  # May need update
  };

  npmDepsHash = "sha256-TEMP...";  # <-- Will update next

  # ... rest of derivation
}
```

### Calculate New npmDepsHash

```bash
# Method 1: Set empty hash and get correct one from error
# Edit default.nix and set: npmDepsHash = "";

# Try to build
nix-build -A packages.x86_64-linux.claude-code 2>&1 | grep "got:" | awk '{print $2}'

# Method 2: Use nix-prefetch-url
cd /tmp
git clone https://github.com/anthropics/claude-code --branch vX.X.X --depth 1
cd claude-code
nix hash convert --to sri $(nix-prefetch-url --unpack "file://$(npm pack)")

# Method 3: Use prefetch-npm-deps (if available)
nix run nixpkgs#prefetch-npm-deps home/development/claude-code/package-lock.json
```

### Update the Hash

Edit `home/development/claude-code/default.nix` with correct hash:

```nix
npmDepsHash = "sha256-ACTUAL_HASH_HERE";
```

## Step 4: Test the Update

### Syntax Check

```bash
just check-syntax
```

### Build Test

```bash
# Test on primary host
just test-host p620

# If successful, test on other hosts
just quick-test
```

### Verify Binary Works

```bash
# Build and test the package
result/bin/claude --version

# Should show: X.X.X
```

## Step 5: Create GitHub Issue

Use the `/new_task` command:

```bash
/new_task
```

**Issue details:**
- **Type:** chore
- **Priority:** medium
- **Title:** "Update Claude Code to version X.X.X"
- **Description:**
  ```
  Update claude-code package from vOLD to vNEW

  Changes:
  - Updated version from OLD → NEW
  - Recalculated npmDepsHash
  - Tested on all hosts

  Breaking changes: [None/List them]

  Release notes: [Link to changelog]
  ```

## Step 6: Create Branch and Commit

```bash
# Get issue number from /new_task output
ISSUE_NUM=123

# Create feature branch
git checkout -b chore/${ISSUE_NUM}-update-claude-code-X.X.X

# Stage changes
git add home/development/claude-code/default.nix

# Commit with detailed message
git commit -m "chore(claude-code): update to version X.X.X (#${ISSUE_NUM})

Update Claude Code package derivation:
- Version: OLD → X.X.X
- npmDepsHash: recalculated for new version
- Source hash: [updated/unchanged]

Changes in this release:
- [Notable feature 1]
- [Notable feature 2]
- [Bug fixes]

Testing:
- Built successfully on all hosts
- Binary verified: claude --version shows X.X.X
- No breaking changes detected

Closes #${ISSUE_NUM}"

# Push branch
git push -u origin chore/${ISSUE_NUM}-update-claude-code-X.X.X
```

## Step 7: Create Pull Request

```bash
# Create PR with GitHub CLI
gh pr create --fill --base main

# Or use web interface with pre-filled template
```

**PR Template:**

```markdown
## Summary

Update Claude Code to version X.X.X

## Changes

- ✅ Updated version from OLD → X.X.X
- ✅ Recalculated npmDepsHash
- ✅ Tested on all hosts (p620, razer, p510, samsung)
- ✅ Verified binary functionality

## Testing Evidence

```bash
# Build successful
just test-host p620 ✅

# Version check
$ result/bin/claude --version
claude-code X.X.X ✅

# All hosts tested
just quick-test ✅
```

## Release Notes

[Link to release notes]

**Notable changes:**
- Feature 1
- Feature 2
- Bug fixes

**Breaking changes:** None

## Checklist

- [x] Version updated in default.nix
- [x] npmDepsHash recalculated
- [x] Build tested on all hosts
- [x] Binary verified functional
- [x] GitHub issue created
- [x] Commit message follows conventional commits
- [x] No anti-patterns introduced (checked against @docs/NIXOS-ANTI-PATTERNS.md)

Closes #${ISSUE_NUM}
```

## Step 8: Code Review

Run code review before merging:

```bash
/review
```

**Review focus:**
- Package derivation follows @docs/PATTERNS.md
- No anti-patterns from @docs/NIXOS-ANTI-PATTERNS.md
- Hash calculations are correct
- Testing was comprehensive

## Step 9: Merge and Deploy

```bash
# After PR approval
gh pr merge ${ISSUE_NUM} --squash --delete-branch

# Deploy to hosts
just quick-deploy p620
just quick-deploy razer
just quick-deploy p510
just quick-deploy samsung
```

## Step 10: Verify Deployment

```bash
# Check version on each host
ssh p620 "claude --version"
ssh razer "claude --version"
ssh p510 "claude --version"
ssh samsung "claude --version"

# All should show: X.X.X
```

## Success Criteria

- [ ] Latest version identified from npm/GitHub
- [ ] npmDepsHash calculated correctly
- [ ] Build succeeds on all hosts
- [ ] Binary verified functional
- [ ] GitHub issue created and linked
- [ ] Branch created following naming convention
- [ ] Commit message follows conventional commits
- [ ] PR created with comprehensive description
- [ ] Code review passed
- [ ] PR merged to main
- [ ] Deployed to all hosts
- [ ] Version verified on all hosts

## Rollback Procedure

If issues occur after deployment:

```bash
# Revert the commit
git revert COMMIT_HASH

# Or rollback system generation
sudo nixos-rebuild switch --rollback

# Report issue on GitHub
gh issue create --title "Claude Code X.X.X causing issues" --body "Description of issue..."
```

## Common Issues

### Hash Mismatch

```bash
# Clear cache and retry
nix-collect-garbage -d
nix-store --verify --check-contents

# Recalculate hash
nix-prefetch-url --unpack "URL"
```

### Build Failure

```bash
# Check build logs
nix-build -A packages.x86_64-linux.claude-code --show-trace

# Check for missing dependencies
nix-build -A packages.x86_64-linux.claude-code --keep-failed

# Review failed build directory
cd /tmp/nix-build-*
cat build.log
```

### Binary Not Working

```bash
# Test in nix-shell
nix-shell -p packages.x86_64-linux.claude-code
claude --version

# Check for missing runtime dependencies
ldd result/bin/claude
```

## Documentation References

- @docs/PATTERNS.md - Package writing patterns
- @docs/NIXOS-ANTI-PATTERNS.md - Avoid these
- @docs/GITHUB-WORKFLOW.md - PR workflow
- @home/development/claude-code/default.nix - Current derivation

## Notes

- Always test on all hosts before deploying
- Document breaking changes in commit message
- Update roadmap if significant features added
- Keep old generation for rollback capability
- Monitor for issues after deployment (24h)

## Example Complete Workflow

```bash
# 1. Research
# Use WebSearch for latest version

# 2. Update
vim home/development/claude-code/default.nix
# Update version and calculate hash

# 3. Test
just test-host p620

# 4. GitHub workflow
/new_task
git checkout -b chore/123-update-claude-code-X.X.X
git add home/development/claude-code/default.nix
git commit -m "chore(claude-code): update to X.X.X (#123)"
git push -u origin chore/123-update-claude-code-X.X.X
gh pr create --fill

# 5. Review and merge
/review
gh pr merge 123 --squash

# 6. Deploy
just deploy-all-parallel

# 7. Verify
for host in p620 razer p510 samsung; do
  ssh $host "claude --version"
done
```
