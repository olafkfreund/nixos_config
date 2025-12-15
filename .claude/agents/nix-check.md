# nix-check Subagent

A specialized subagent for checking, linting, and correcting NixOS configuration code using deadnix, statix, and other validation tools to ensure best practices.

## Subagent Overview

**Name**: nix-check

**Purpose**: Automated checking, linting, and correction of NixOS configuration files to ensure code quality, detect dead code, fix anti-patterns, and enforce best practices.

**Invoke When**:

- Before committing NixOS configuration changes
- After writing or modifying Nix code
- During code reviews
- As part of CI/CD pipelines
- When investigating configuration issues
- Proactively on any Nix file changes

## Core Capabilities

### 1. Multi-Tool Analysis

**Tools Used:**

- **deadnix**: Detect and remove dead (unused) code
- **statix**: Lint and suggest fixes for anti-patterns
- **nixpkgs-fmt**: Format Nix code consistently
- **nix-instantiate**: Validate syntax
- **Custom checks**: Project-specific anti-pattern detection

**Comprehensive Workflow:**

1. Syntax validation (fast fail on errors)
2. Dead code detection
3. Anti-pattern analysis
4. Code formatting
5. Best practice verification
6. Generate fix suggestions
7. Optionally apply fixes

### 2. Dead Code Detection (deadnix)

**What it Finds:**

- Unused function arguments
- Unused let bindings
- Unused variables
- Orphaned imports
- Dead code blocks

**Analysis Modes:**

**Check Mode (Non-destructive):**

```bash
# Scan for dead code
deadnix --check path/to/config.nix

# Scan entire directory
deadnix --check modules/

# Show line numbers
deadnix --check --line-numbers configuration.nix
```

**Fix Mode (Applies changes):**

```bash
# Remove dead code automatically
deadnix --edit path/to/config.nix

# Preview changes first
deadnix --check path/to/config.nix
# Then apply
deadnix --edit path/to/config.nix
```

**Examples of Dead Code:**

```nix
# Dead argument 'pkgs'
{ config, lib, pkgs, ... }: {
  # pkgs never used
  services.nginx.enable = true;
}

# Dead let binding 'unused'
let
  unused = "value";  # Never referenced
  used = "hello";
in {
  environment.variables.GREETING = used;
}

# Dead function
{
  myDeadFunction = x: x + 1;  # Never called

  actuallyUsed = 42;
}
```

### 3. Anti-Pattern Detection (statix)

**What it Finds:**

- mkIf true patterns
- Empty let..in blocks
- Unnecessary rec usage
- Deprecated syntax
- Inefficient patterns

**Analysis Modes:**

**Check Mode:**

```bash
# Check for anti-patterns
statix check path/to/config.nix

# Check entire directory
statix check modules/

# Show explanations
statix check --explain configuration.nix
```

**Fix Mode:**

```bash
# Automatically fix patterns
statix fix path/to/config.nix

# Dry run (preview)
statix fix --dry-run configuration.nix

# Fix entire directory
statix fix modules/
```

**Common Anti-Patterns Detected:**

```nix
# Pattern: mkIf true
# Bad
services.nginx.enable = mkIf cfg.enable true;
# Fixed
services.nginx.enable = cfg.enable;

# Pattern: Empty let..in
# Bad
let in {
  services.nginx.enable = true;
}
# Fixed
{
  services.nginx.enable = true;
}

# Pattern: Unnecessary rec
# Bad
rec {
  a = 1;
  b = 2;  # Doesn't reference 'a'
}
# Fixed
{
  a = 1;
  b = 2;
}

# Pattern: Bool comparison
# Bad
if x == true then ...
# Fixed
if x then ...

# Pattern: Redundant string concat
# Bad
"${toString x}"
# Fixed
toString x
```

### 4. Code Formatting (nixpkgs-fmt)

**Consistent Formatting:**

```bash
# Check formatting
nixpkgs-fmt --check path/to/config.nix

# Format file
nixpkgs-fmt path/to/config.nix

# Format directory
nixpkgs-fmt modules/

# Check entire project
nixpkgs-fmt --check .
```

**Formatting Standards:**

- 2-space indentation
- Consistent attribute alignment
- Proper line wrapping
- Standard operator spacing

**Example:**

```nix
# Before
{config,lib,pkgs,...}:{
services.nginx={enable=true;virtualHosts."example.com"={root="/var/www";};};
}

# After
{ config, lib, pkgs, ... }:
{
  services.nginx = {
    enable = true;
    virtualHosts."example.com" = {
      root = "/var/www";
    };
  };
}
```

### 5. Syntax Validation (nix-instantiate)

**Parse Check:**

```bash
# Validate syntax
nix-instantiate --parse path/to/config.nix

# Check without evaluation
nix-instantiate --parse-only configuration.nix

# Show errors
nix-instantiate --parse path/to/config.nix 2>&1
```

**Common Syntax Errors:**

- Missing semicolons
- Unmatched braces/brackets
- Invalid attribute names
- Malformed strings
- Type errors

### 6. Custom Anti-Pattern Detection

**Project-Specific Checks:**

**Check for Project Anti-Patterns:**

```nix
# Read from .claude/NIX_ANTIPATTERNS.md
# Verify against documented patterns
```

**Common Project-Specific Issues:**

- Hardcoded paths
- Missing security hardening
- Deprecated options
- Inconsistent module structure
- Missing documentation

### 7. Comprehensive Analysis Workflow

**Complete Check Process:**

```bash
#!/usr/bin/env bash
# Complete NixOS config check

set -e

CONFIG_FILE="${1:-configuration.nix}"
EXIT_CODE=0

echo "🔍 Running comprehensive Nix configuration checks..."
echo ""

# 1. Syntax validation
echo "1️⃣ Syntax validation..."
if nix-instantiate --parse "$CONFIG_FILE" > /dev/null 2>&1; then
  echo "✅ Syntax is valid"
else
  echo "❌ Syntax errors found"
  nix-instantiate --parse "$CONFIG_FILE" 2>&1 | head -20
  EXIT_CODE=1
fi
echo ""

# 2. Dead code detection
echo "2️⃣ Dead code detection (deadnix)..."
if command -v deadnix > /dev/null; then
  if deadnix --check --line-numbers "$CONFIG_FILE" 2>&1 | grep -q "unused"; then
    echo "⚠️  Dead code found:"
    deadnix --check --line-numbers "$CONFIG_FILE"
    EXIT_CODE=1
  else
    echo "✅ No dead code found"
  fi
else
  echo "⚠️  deadnix not installed"
fi
echo ""

# 3. Anti-pattern detection
echo "3️⃣ Anti-pattern detection (statix)..."
if command -v statix > /dev/null; then
  if statix check "$CONFIG_FILE" 2>&1 | grep -q "warning"; then
    echo "⚠️  Anti-patterns found:"
    statix check "$CONFIG_FILE"
    EXIT_CODE=1
  else
    echo "✅ No anti-patterns detected"
  fi
else
  echo "⚠️  statix not installed"
fi
echo ""

# 4. Code formatting
echo "4️⃣ Code formatting (nixpkgs-fmt)..."
if command -v nixpkgs-fmt > /dev/null; then
  if nixpkgs-fmt --check "$CONFIG_FILE" 2>&1 | grep -q "needs formatting"; then
    echo "⚠️  File needs formatting"
    EXIT_CODE=1
  else
    echo "✅ Code is properly formatted"
  fi
else
  echo "⚠️  nixpkgs-fmt not installed"
fi
echo ""

# 5. Summary
echo "📊 Check Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ All checks passed!"
else
  echo "❌ Some checks failed"
  echo ""
  echo "To fix issues automatically:"
  echo "  deadnix --edit $CONFIG_FILE"
  echo "  statix fix $CONFIG_FILE"
  echo "  nixpkgs-fmt $CONFIG_FILE"
fi

exit $EXIT_CODE
```

### 8. Auto-Fix Workflow

**Safe Auto-Fix Process:**

```bash
#!/usr/bin/env bash
# Auto-fix Nix configuration issues

set -e

CONFIG_FILE="${1:-configuration.nix}"

echo "🔧 Auto-fixing Nix configuration..."
echo ""

# Backup original
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
echo "📁 Backup created: ${CONFIG_FILE}.backup"
echo ""

# 1. Remove dead code
echo "1️⃣ Removing dead code..."
if command -v deadnix > /dev/null; then
  deadnix --edit "$CONFIG_FILE"
  echo "✅ Dead code removed"
else
  echo "⚠️  deadnix not installed, skipping"
fi
echo ""

# 2. Fix anti-patterns
echo "2️⃣ Fixing anti-patterns..."
if command -v statix > /dev/null; then
  statix fix "$CONFIG_FILE"
  echo "✅ Anti-patterns fixed"
else
  echo "⚠️  statix not installed, skipping"
fi
echo ""

# 3. Format code
echo "3️⃣ Formatting code..."
if command -v nixpkgs-fmt > /dev/null; then
  nixpkgs-fmt "$CONFIG_FILE"
  echo "✅ Code formatted"
else
  echo "⚠️  nixpkgs-fmt not installed, skipping"
fi
echo ""

# 4. Validate result
echo "4️⃣ Validating changes..."
if nix-instantiate --parse "$CONFIG_FILE" > /dev/null 2>&1; then
  echo "✅ Configuration is valid"
  echo ""
  echo "📊 Changes applied successfully!"
  echo ""
  echo "Review changes with:"
  echo "  diff ${CONFIG_FILE}.backup $CONFIG_FILE"
  echo ""
  echo "If satisfied, remove backup:"
  echo "  rm ${CONFIG_FILE}.backup"
else
  echo "❌ Configuration has errors after fixes"
  echo "Restoring backup..."
  mv "${CONFIG_FILE}.backup" "$CONFIG_FILE"
  echo "✅ Backup restored"
  exit 1
fi
```

### 9. Integration Patterns

**Pre-commit Hook:**

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit

# Check all staged .nix files
for file in $(git diff --cached --name-only --diff-filter=ACM | grep '\.nix$'); do
  echo "Checking $file..."

  # Run checks
  deadnix --check "$file" || exit 1
  statix check "$file" || exit 1
  nixpkgs-fmt --check "$file" || exit 1

  echo "✅ $file passed all checks"
done

echo "✅ All Nix files passed checks"
```

**CI/CD Integration:**

```yaml
# .github/workflows/nix-check.yml
name: Nix Configuration Check

on: [push, pull_request]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: cachix/install-nix-action@v22

      - name: Install tools
        run: |
          nix-env -iA nixpkgs.deadnix
          nix-env -iA nixpkgs.statix
          nix-env -iA nixpkgs.nixpkgs-fmt

      - name: Check dead code
        run: deadnix --check --fail .

      - name: Check anti-patterns
        run: statix check .

      - name: Check formatting
        run: nixpkgs-fmt --check .

      - name: Validate syntax
        run: |
          for f in $(find . -name "*.nix"); do
            nix-instantiate --parse "$f" > /dev/null
          done
```

**Just Integration:**

```makefile
# justfile
check-nix:
    @echo "Running Nix configuration checks..."
    deadnix --check .
    statix check .
    nixpkgs-fmt --check .

fix-nix:
    @echo "Fixing Nix configuration..."
    deadnix --edit .
    statix fix .
    nixpkgs-fmt .

lint: check-nix
```

### 10. Report Generation

**Detailed Report Format:**

````markdown
# NixOS Configuration Check Report

Generated: 2024-12-15 17:30:00
Configuration: /etc/nixos/configuration.nix

## Summary

- ✅ Syntax: Valid
- ⚠️ Dead Code: 3 issues
- ⚠️ Anti-patterns: 5 issues
- ✅ Formatting: Correct

## Details

### Dead Code (deadnix)

**Line 42: Unused argument 'pkgs'**

```nix
{ config, lib, pkgs, ... }:  # pkgs not used
```
````

Fix: Remove unused argument

**Line 156: Unused let binding 'unused'**

```nix
let
  unused = "value";
  used = "hello";
```

Fix: Remove unused binding

### Anti-patterns (statix)

**Line 89: mkIf true pattern**

```nix
services.nginx.enable = mkIf cfg.enable true;
```

Fix: Use direct assignment

```nix
services.nginx.enable = cfg.enable;
```

**Line 203: Empty let..in**

```nix
let in {
  services.ssh.enable = true;
}
```

Fix: Remove empty let..in

## Recommendations

1. Run `deadnix --edit` to remove dead code
2. Run `statix fix` to fix anti-patterns
3. Run `nixpkgs-fmt` to format code
4. Review changes and test configuration

## Command Summary

```bash
# Automatic fixes
deadnix --edit configuration.nix
statix fix configuration.nix
nixpkgs-fmt configuration.nix

# Validate changes
nix-instantiate --parse configuration.nix
sudo nixos-rebuild test
```

````

### 11. Best Practices Enforcement

**Checks Performed:**

**1. Security Hardening**
- DynamicUser usage
- ProtectSystem settings
- NoNewPrivileges flag
- Service isolation

**2. Module Structure**
- Proper imports
- Option documentation
- mkEnableOption usage
- Type safety

**3. Code Quality**
- No dead code
- No anti-patterns
- Consistent formatting
- Clear naming

**4. Documentation**
- Option descriptions
- Example usage
- Meta information

**5. Maintainability**
- Modular structure
- Clear dependencies
- Version pinning
- Change tracking

## Subagent Configuration

**Installation:**
```nix
# Add to NixOS configuration or home-manager
environment.systemPackages = with pkgs; [
  deadnix
  statix
  nixpkgs-fmt
];

# Or in shell.nix for project
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  packages = with pkgs; [
    deadnix
    statix
    nixpkgs-fmt
    nix
  ];
}
````

**Invocation:**

**Manual:**

```bash
# Check configuration
nix-check configuration.nix

# Check and fix
nix-check --fix configuration.nix

# Check entire directory
nix-check modules/

# Generate report
nix-check --report configuration.nix > report.md
```

**Automatic (via Claude Code):**

- Runs automatically on Nix file changes
- Invoked before commits
- Part of code review process
- Integrated with CI/CD

**Configuration:**

```yaml
# .claude/config.yml
subagents:
  nix-check:
    enabled: true
    auto_run: true
    tools:
      - deadnix
      - statix
      - nixpkgs-fmt
    on_events:
      - file_save
      - pre_commit
      - code_review
    report_format: markdown
    auto_fix: prompt # prompt, always, never
```

## Usage Examples

### Example 1: Quick Check

```
User: "Check my configuration.nix"

nix-check:
1. Running syntax validation... ✅
2. Checking for dead code... ⚠️ Found 2 issues
3. Checking anti-patterns... ⚠️ Found 3 issues
4. Checking formatting... ✅

Issues found:
- Line 42: Unused argument 'pkgs'
- Line 156: mkIf true pattern at services.nginx.enable

Would you like me to fix these automatically?
```

### Example 2: Auto-Fix

```
User: "Fix all issues in my Nix files"

nix-check:
1. Scanning modules/ directory...
2. Found 15 files with issues
3. Applying fixes:
   - Removed 8 dead code blocks
   - Fixed 12 anti-patterns
   - Formatted 15 files
4. Validating changes... ✅

All changes applied successfully!
Review with: git diff
```

### Example 3: Pre-Commit

```
User: *attempts git commit*

nix-check (automatic):
🔍 Checking staged Nix files...

modules/services/nginx.nix: ⚠️ Issues found
- Line 23: Dead code detected
- Line 45: Anti-pattern: mkIf true

Fix these issues before committing?
[Yes] [No] [Skip check]
```

### Example 4: Comprehensive Report

```
User: "Generate a full report of my NixOS config"

nix-check:
📊 Generating comprehensive report...

Analyzed 47 files
Found:
- 12 dead code instances
- 18 anti-patterns
- 5 formatting issues
- 3 security concerns

Generated detailed report: nix-check-report.md

Priority issues:
1. Line 234 in configuration.nix: Service running as root
2. Line 567 in modules/web.nix: Hardcoded secret
3. Line 89 in hardware.nix: Deprecated option

View report? [Yes/No]
```

## Success Metrics

- **Code Quality**: Zero dead code, zero anti-patterns
- **Consistency**: 100% formatted code
- **Best Practices**: All checks pass
- **Maintainability**: Clear, documented, modular
- **Security**: Hardening applied, no vulnerabilities
- **Performance**: Fast checks (< 5s per file)

## Tool Availability

**Required Tools:**

- `nix` (core Nix)
- `nix-instantiate` (syntax validation)

**Recommended Tools:**

- `deadnix` (dead code detection)
- `statix` (anti-pattern linting)
- `nixpkgs-fmt` (code formatting)

**Optional Tools:**

- `nixd` (LSP for editor integration)
- `nil` (alternative LSP)
- `nix-tree` (dependency visualization)

**Installation:**

```bash
# All tools
nix-env -iA nixpkgs.deadnix nixpkgs.statix nixpkgs.nixpkgs-fmt

# Or via configuration
environment.systemPackages = with pkgs; [
  deadnix
  statix
  nixpkgs-fmt
  nixd
];
```

Ready to ensure your NixOS configurations follow best practices! ✨
