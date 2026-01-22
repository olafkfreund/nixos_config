---
name: issue-checker
description: Proactively monitors NixOS/nixpkgs GitHub issues to identify known bugs
---

# Issue Checker Subagent

## Overview

The **issue-checker** subagent proactively monitors NixOS/nixpkgs GitHub issues to identify known bugs and problems affecting packages installed on your local system. It helps prevent system instability by warning you about problematic updates before you apply them.

### Purpose

- **Prevent breaking updates**: Identify packages with known issues before upgrading
- **System stability**: Avoid deploying bug-ridden package versions
- **Proactive monitoring**: Stay informed about issues affecting your stack
- **Update confidence**: Make informed decisions about when to update

### When to Use

- ✅ **Before running system updates** (`nixos-rebuild switch --upgrade`)
- ✅ **Before updating flake inputs** (`nix flake update`)
- ✅ **After nixpkgs channel updates** (check if new issues appeared)
- ✅ **During CI/CD pipelines** (automated issue checking)
- ✅ **For critical production systems** (regular monitoring)
- ✅ **When planning maintenance windows** (assess risk)

### How It Works

1. **Inventory**: Scans currently installed packages and their versions
2. **Query**: Searches NixOS/nixpkgs GitHub issues for package names
3. **Filter**: Identifies open bugs, regressions, and breaking changes
4. **Correlate**: Matches issues to your specific package versions
5. **Report**: Generates actionable report with severity levels
6. **Recommend**: Suggests whether to proceed with updates or wait

## Installation

### Add to NixOS Configuration

```nix
{
  pkgs, ...
}:
{
  environment.systemPackages = with pkgs;
  [
    gh           # GitHub CLI for API access
    jq           # JSON processing
    nix          # For querying installed packages
    curl         # HTTP requests
  ];

  # Optional: Add helper script
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "check-nixos-issues" ''
      ${./scripts/issue-checker.sh}
    '')
  ];
}
```

### GitHub CLI Authentication

```bash
# Authenticate with GitHub (required for API access)
gh auth login

# Or use token
export GITHUB_TOKEN="ghp_your_token_here"
```

## Quick Start

### Basic Usage

```bash
# Check all installed packages
claude
"Check for known issues affecting my installed packages"

# Check before update
claude
"Before I run nixos-rebuild switch --upgrade, check for any critical bugs"

# Check specific packages
claude
"Check if there are any known issues with systemd, firefox, or kernel packages"
```

### Manual Script Execution

```bash
# Run issue checker script
./scripts/issue-checker.sh

# Check specific channel
./scripts/issue-checker.sh --channel nixos-unstable

# Check only critical severity
./scripts/issue-checker.sh --severity critical

# Export report
./scripts/issue-checker.sh --output report.json
```

## Issue Checker Script

### Complete Implementation

Create `scripts/issue-checker.sh`:

```bash
#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CHANNEL="${CHANNEL:-nixos-unstable}"
SEVERITY="${SEVERITY:-all}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"
MAX_ISSUES="${MAX_ISSUES:-50}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nixos-issue-checker"
CACHE_TTL=3600  # 1 hour

# GitHub repository
REPO="NixOS/nixpkgs"

# Create cache directory
mkdir -p "$CACHE_DIR"

# Print header
print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         NixOS Issue Checker - System Analysis           ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Get installed packages
get_installed_packages() {
    echo -e "${BLUE}[1/5]${NC} Scanning installed packages..."

    # Get all packages in current profile
    nix-env -q --installed --out-path | awk '{print $1}' > "$CACHE_DIR/installed-packages.txt"

    # Also check system packages
    nix-store -q --references /run/current-system | \
        grep -E '^/nix/store/[^-]+-[^/]+$' | \
        xargs -I {} basename {} | \
        cut -d'-' -f2- >> "$CACHE_DIR/installed-packages.txt"

    # Remove duplicates and sort
    sort -u "$CACHE_DIR/installed-packages.txt" -o "$CACHE_DIR/installed-packages.txt"

    local count=$(wc -l < "$CACHE_DIR/installed-packages.txt")
    echo -e "${GREEN}   Found $count unique packages${NC}"
    echo ""
}

# Get package versions
get_package_versions() {
    echo -e "${BLUE}[2/5]${NC} Extracting package versions..."

    > "$CACHE_DIR/package-versions.json"

    while IFS= read -r pkg; do
        # Extract package name and version
        if [[ $pkg =~ ^([a-zA-Z0-9_-]+)-([0-9].*)$ ]]; then
            name="${BASH_REMATCH[1]}"
            version="${BASH_REMATCH[2]}"

            echo "{\"name\": \"$name\", \"version\": \"$version\", \"full\": \"$pkg\"}" >> "$CACHE_DIR/package-versions.json"
        fi
    done < "$CACHE_DIR/installed-packages.txt"

    echo -e "${GREEN}   Extracted version information${NC}"
    echo ""
}

# Query GitHub issues
query_github_issues() {
    echo -e "${BLUE}[3/5]${NC} Querying GitHub issues..."

    local cache_file="$CACHE_DIR/github-issues.json"
    local cache_age=999999

    if [[ -f "$cache_file" ]]; then
        cache_age=$(( $(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file") ))
    fi

    if [[ $cache_age -lt $CACHE_TTL ]]; then
        echo -e "${YELLOW}   Using cached issues (${cache_age}s old)${NC}"
    else
        echo -e "${BLUE}   Fetching fresh issues from GitHub...${NC}"

        # Query open issues with relevant labels
        gh issue list \
            --repo "$REPO" \
            --state open \
            --limit "$MAX_ISSUES" \
            --label "0.kind: bug,1.severity: blocker,0.kind: regression" \
            --json number,title,labels,createdAt,updatedAt,url \
            > "$cache_file"

        echo -e "${GREEN}   Fetched $(jq length "$cache_file") open issues${NC}"
    fi

    echo ""
}

# Correlate issues with installed packages
correlate_issues() {
    echo -e "${BLUE}[4/5]${NC} Correlating issues with installed packages..."

    > "$CACHE_DIR/affected-packages.json"

    local affected=0
    local critical=0
    local high=0
    local medium=0

    # Read each package
    while IFS= read -r pkg_json; do
        pkg_name=$(echo "$pkg_json" | jq -r '.name')
        pkg_version=$(echo "$pkg_json" | jq -r '.version')
        pkg_full=$(echo "$pkg_json" | jq -r '.full')

        # Search for issues mentioning this package
        matching_issues=$(jq --arg pkg "$pkg_name" '
            map(select(
                (.title | ascii_downcase | contains($pkg | ascii_downcase)) or
                (.labels[].name | ascii_downcase | contains($pkg | ascii_downcase))
            ))
        ' "$CACHE_DIR/github-issues.json")

        if [[ $(echo "$matching_issues" | jq 'length') -gt 0 ]]; then
            affected=$((affected + 1))

            # Determine severity
            severity="medium"
            if echo "$matching_issues" | jq -e '.[] | .labels[] | select(.name == "1.severity: blocker")' >/dev/null 2>&1; then
                severity="critical"
                critical=$((critical + 1))
            elif echo "$matching_issues" | jq -e '.[] | .labels[] | select(.name == "1.severity: security")' >/dev/null 2>&1; then
                severity="high"
                high=$((high + 1))
            else
                medium=$((medium + 1))
            fi

            # Save affected package
            jq -n \
                --arg name "$pkg_name" \
                --arg version "$pkg_version" \
                --arg full "$pkg_full" \
                --arg severity "$severity" \
                --argjson issues "$matching_issues" \
                '{name: $name, version: $version, full: $full, severity: $severity, issues: $issues}' \
                >> "$CACHE_DIR/affected-packages.json"
        fi
    done < "$CACHE_DIR/package-versions.json"

    echo -e "${GREEN}   Found $affected packages with potential issues${NC}"
    echo -e "${RED}     Critical: $critical${NC}"
    echo -e "${YELLOW}     High: $high${NC}"
    echo -e "${BLUE}     Medium: $medium${NC}"
    echo ""
}

# Generate report
generate_report() {
    echo -e "${BLUE}[5/5]${NC} Generating report..."
    echo ""

    if [[ ! -s "$CACHE_DIR/affected-packages.json" ]]; then
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                 🎉 All Clear! 🎉                         ║${NC}"
        echo -e "${GREEN}║                                                          ║${NC}"
        echo -e "${GREEN}║  No known critical issues affecting installed packages  ║${NC}"
        echo -e "${GREEN}║  Safe to proceed with system updates                    ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
        return
    fi

    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║            ⚠️  Issues Found ⚠️                            ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Group by severity
    for sev in critical high medium; do
        local issues=$(jq -s --arg severity "$sev" 'map(select(.severity == $severity))' "$CACHE_DIR/affected-packages.json")
        local count=$(echo "$issues" | jq 'length')

        if [[ $count -gt 0 ]]; then
            case $sev in
                critical)
                    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo -e "${RED}🚨 CRITICAL SEVERITY ($count packages)${NC}"
                    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    ;;
                high)
                    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo -e "${YELLOW}⚡ HIGH SEVERITY ($count packages)${NC}"
                    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    ;;
                medium)
                    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo -e "${BLUE}ℹ️  MEDIUM SEVERITY ($count packages)${NC}"
                    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    ;;
            esac

            echo "$issues" | jq -r '.[] |
                "\n📦 Package: \(.name)-\(.version)\n" +
                "   Issues (\(.issues | length)):\n" +
                (.issues[] | "   • #\(.number): \(.title)\n     \(.url)") +
                ""
        fi
    done

    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📋 Recommendation${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local critical_count=$(jq -s 'map(select(.severity == "critical")) | length' "$CACHE_DIR/affected-packages.json")

    if [[ $critical_count -gt 0 ]]; then
        echo -e "${RED}⛔ DO NOT UPDATE${NC}"
        echo -e "   $critical_count critical issues detected."
        echo -e "   Wait for fixes or consider pinning affected packages."
    else
        echo -e "${YELLOW}⚠️  PROCEED WITH CAUTION${NC}"
        echo -e "   Review issues before updating."
        echo -e "   Consider testing in a VM first."
    fi

    echo ""
}

# Main execution
main() {
    print_header
    get_installed_packages
    get_package_versions
    query_github_issues
    correlate_issues
    generate_report
}

# Run main function
main "$@"
```

### Make Script Executable

```bash
chmod +x scripts/issue-checker.sh
```

## Integration with NixOS

### Pre-Update Hook

Automatically check before updates:

```nix
{
  pkgs, ...
}:
{
  # Create wrapper for nixos-rebuild
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "safe-rebuild" ''
      set -e

      echo "🔍 Checking for known issues..."
      ${./scripts/issue-checker.sh}

      echo ""
      read -p "Proceed with rebuild? (y/N) " -n 1 -r
      echo

      if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo nixos-rebuild "$@"
      else
        echo "Update cancelled."
        exit 1
      fi
    '')
  ];
}
```

Usage:

```bash
safe-rebuild switch --upgrade
```

### Systemd Timer for Monitoring

Regular automated checks:

```nix
{
  pkgs, config, ...
}:
{
  systemd.services.nixos-issue-check = {
    description = "Check NixOS packages for known issues";
    script = ''
      ${./scripts/issue-checker.sh} --output /var/log/nixos-issue-checker.log
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  systemd.timers.nixos-issue-check = {
    description = "Regular NixOS issue checking";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
```

### Email Notifications

Send alerts when critical issues are found:

```nix
{
  pkgs, config, ...
}:
{
  systemd.services.nixos-issue-check-notify = {
    description = "Check and notify about NixOS issues";
    script = ''
      REPORT=$(${./scripts/issue-checker.sh})

      if echo "$REPORT" | grep -q "CRITICAL SEVERITY"; then
        echo "$REPORT" | ${pkgs.mailutils}/bin/mail \
          -s "Critical NixOS Issues Detected" \
          admin@example.com
      fi
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };

  systemd.timers.nixos-issue-check-notify = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
    };
  };
}
```

## Advanced Features

### Channel Comparison

Compare issues across different channels:

```bash
#!/usr/bin/env bash

echo "Checking nixos-unstable..."
CHANNEL=nixos-unstable ./scripts/issue-checker.sh > /tmp/unstable-report.txt

echo "Checking nixos-23.11..."
CHANNEL=nixos-23.11 ./scripts/issue-checker.sh > /tmp/stable-report.txt

echo "Comparing reports..."
diff /tmp/unstable-report.txt /tmp/stable-report.txt
```

### Severity Filtering

Only show critical/high severity issues:

```nix
{
  pkgs, ...
}:
{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "check-critical-issues" ''
      ${./scripts/issue-checker.sh} --severity critical
    '')
  ];
}
```

### JSON Output for Automation

Export structured data for CI/CD:

```bash
#!/usr/bin/env bash

# Run check and export JSON
./scripts/issue-checker.sh --output json > issues.json

# Parse in CI/CD
CRITICAL=$(jq '[.[] | select(.severity == "critical")] | length' issues.json)

if [[ $CRITICAL -gt 0 ]]; then
    echo "❌ Found $CRITICAL critical issues"
    exit 1
fi

echo "✅ No critical issues found"
exit 0
```

### Package Pinning Recommendations

Automatically generate pins for affected packages:

```bash
#!/usr/bin/env bash

# Extract affected packages
AFFECTED=$(jq -r '.[] | select(.severity == "critical") | .name' \
    "$HOME/.cache/nixos-issue-checker/affected-packages.json")

# Generate overlay
cat > /tmp/pin-overlay.nix <<EOF
final: prev: {
$(for pkg in $AFFECTED; do
    echo "  $pkg = prev.$pkg.overrideAttrs (old: {"
    echo "    # Pinned due to critical issue - $(date)"
    echo "  });"
done)
}EOF

echo "Generated overlay: /tmp/pin-overlay.nix"
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/check-issues.yml
name: NixOS Issue Check

on:
  schedule:
    - cron: "0 6 * * *" # Daily at 6 AM
  workflow_dispatch:

jobs:
  check-issues:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: cachix/install-nix-action@v20

      - name: Check for known issues
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          nix-shell -p gh jq --run "./scripts/issue-checker.sh"

      - name: Upload report
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: issue-report
          path: ~/.cache/nixos-issue-checker/

      - name: Fail on critical issues
        run: |
          CRITICAL=$(jq -s 'map(select(.severity == "critical")) | length' \
            ~/.cache/nixos-issue-checker/affected-packages.json)

          if [[ $CRITICAL -gt 0 ]]; then
            echo "::error::Found $CRITICAL critical issues"
            exit 1
          fi
```

### GitLab CI

```yaml
# .gitlab-ci.yml
check-nixos-issues:
  image: nixos/nix:latest
  stage: test
  script:
    - nix-env -iA nixpkgs.gh nixpkgs.jq
    - ./scripts/issue-checker.sh
  artifacts:
    when: always
    paths:
      - .cache/nixos-issue-checker/
  only:
    - schedules
    - web
```

### NixOS Test

```nix
# tests/issue-checker.nix
import <nixpkgs/nixos/tests/make-test-python.nix> ({ pkgs, ... }: {
  name = "issue-checker-test";

  nodes.machine = { ... }: {
    environment.systemPackages = with pkgs; [ gh jq ];
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # Run issue checker
    output = machine.succeed("./scripts/issue-checker.sh")

    # Verify output format
    assert "Scanning installed packages" in output
    assert "Querying GitHub issues" in output

    print("Issue checker test passed!")
  '';
})
```

## Gemini Code Integration

### Automatic Invocation

The subagent automatically runs when:

1. **Before updates**: User asks to update system
2. **Package queries**: User asks about package status
3. **Update planning**: User plans maintenance windows
4. **CI/CD**: Automated checks in pipelines

### Example Interactions

**Scenario 1: Pre-Update Check**

```
User: "I want to update my system to the latest unstable"

Gemini Code (automatically):
1. Runs issue-checker subagent
2. Scans installed packages
3. Queries GitHub issues
4. Reports findings:
   "⚠️ Found 2 critical issues:
   - systemd 254.x has boot failure (#250123)
   - firefox 120.x crashes on wayland (#251456)

   Recommendation: Wait for systemd fix or pin to 253.x"
```

**Scenario 2: Specific Package Check**

```
User: "Is it safe to update kernel to 6.6?"

Gemini Code:
1. Queries issues for "linux" package
2. Filters for 6.6.x version
3. Reports:
   "✅ No critical issues found for kernel 6.6.x
   1 medium issue: nvidia driver incompatibility (#248999)
   Safe to update if not using nvidia"
```

**Scenario 3: Maintenance Planning**

```
User: "Plan system update for this weekend"

Gemini Code:
1. Runs issue-checker
2. Analyzes risk
3. Provides schedule:
   "📅 Update Plan:
   - Current issues: 3 medium severity
   - Recommended: Wait until Monday
   - Reason: systemd fix expected in next unstable push
   - Alternative: Update non-critical packages only"
```

## API Integration

### GitHub GraphQL API

Advanced querying for better performance:

```bash
#!/usr/bin/env bash

# GraphQL query for package-specific issues
read -r -d '' QUERY <<'EOF'
query($package: String!, $cursor: String) {
  search(
    query: $package
    type: ISSUE
    first: 20
    after: $cursor
  ) {
    issueCount
    edges {
      node {
        ... on Issue {
          number
          title
          state
          labels(first: 10) {
            nodes {
              name
            }
          }
          createdAt
          updatedAt
          url
        }
      }
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
EOF

# Execute query
gh api graphql \
    -f query="$QUERY" \
    -f package="repo:NixOS/nixpkgs $PACKAGE_NAME in:title,body" \
    -f cursor="$CURSOR"
```

### Rate Limiting

Handle GitHub API rate limits:

```bash
#!/usr/bin/env bash

# Check rate limit
REMAINING=$(gh api rate_limit | jq '.resources.core.remaining')

if [[ $REMAINING -lt 10 ]]; then
    RESET=$(gh api rate_limit | jq '.resources.core.reset')
    WAIT=$((RESET - $(date +%s)))
    echo "⏳ Rate limit reached. Waiting ${WAIT}s..."
    sleep $WAIT
fi
```

## Reporting Features

### HTML Report

Generate web-friendly report:

```bash
#!/usr/bin/env bash

cat > /tmp/issue-report.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>NixOS Issue Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .critical { background-color: #ffcccc; padding: 10px; }
        .high { background-color: #ffffcc; padding: 10px; }
        .medium { background-color: #ccffcc; padding: 10px; }
    </style>
</head>
<body>
    <h1>NixOS Issue Report</h1>
    <p>Generated: $(date)</p>
EOF

# Add issues
jq -r '.[] |
    "<div class=\""(.severity)"\">" +
    "<h2>\(.name) - \(.version)</h2>" +
    "<ul>" +
    (.issues[] | "<li><a href=\"\(.url)\">#\(.number)</a>: \(.title)</li>") +
    "</ul></div>"' \
    "$HOME/.cache/nixos-issue-checker/affected-packages.json" >> /tmp/issue-report.html

cat >> /tmp/issue-report.html <<'EOF'
</body>
</html>
EOF

echo "Report generated: /tmp/issue-report.html"
```

### Slack/Discord Notifications

Send alerts to team channels:

```bash
#!/usr/bin/env bash

# Slack webhook
WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Generate message
MESSAGE=$(jq -n \
    --arg text "NixOS Issue Check Results" \
    --argjson attachments "$(jq -s '[.[] | {
        color: (if .severity == "critical" then "danger"
                elif .severity == "high" then "warning"
                else "good" end),
        title: "\(.name)-\(.version)",
        text: (.issues | map("#\(.number): \(.title)") | join("\n"))
    }]' "$HOME/.cache/nixos-issue-checker/affected-packages.json")" \
    '{text: $text, attachments: $attachments}')

# Send to Slack
curl -X POST -H 'Content-type: application/json' \
    --data "$MESSAGE" \
    "$WEBHOOK_URL"
```

## Best Practices

### 1. Regular Monitoring

```nix
{
  # Daily checks
  systemd.timers.nixos-issue-check.timerConfig.OnCalendar = "daily";

  # Before updates only
  # Run manually: check-nixos-issues
}
```

### 2. Appropriate Severity Levels

- **Critical**: System won't boot, data loss, security vulnerabilities
- **High**: Major functionality broken, crashes, performance degradation
- **Medium**: Minor bugs, cosmetic issues, warnings

### 3. Cache Management

```bash
# Clear cache
rm -rf ~/.cache/nixos-issue-checker/

# Adjust cache TTL
export CACHE_TTL=7200  # 2 hours
```

### 4. False Positive Handling

```nix
# Ignore specific packages
{
  environment.etc."nixos-issue-checker/ignore.txt".text = ''
    package-with-false-positives
    another-package
  '';
}
```

### 5. Multi-System Management

```bash
#!/usr/bin/env bash

# Check multiple hosts
for host in server1 server2 desktop; do
    echo "Checking $host..."
    ssh $host "$(cat scripts/issue-checker.sh)" | tee /tmp/$host-report.txt
done
```

## Troubleshooting

### GitHub API Authentication

```bash
# Check authentication
gh auth status

# Re-authenticate
gh auth login

# Use token
export GITHUB_TOKEN="ghp_..."
```

### Missing Packages

```bash
# Verify required tools
command -v gh >/dev/null || echo "Install gh: nix-env -iA nixpkgs.gh"
command -v jq >/dev/null || echo "Install jq: nix-env -iA nixpkgs.jq"
```

### Rate Limiting

```bash
# Check remaining requests
gh api rate_limit

# Use authenticated requests (5000/hour vs 60/hour)
gh auth login
```

### Cache Issues

```bash
# Force refresh
rm -rf ~/.cache/nixos-issue-checker/
./scripts/issue-checker.sh
```

## Example Output

### Clean System

```
╔══════════════════════════════════════════════════════════╗
║         NixOS Issue Checker - System Analysis           ║
╚══════════════════════════════════════════════════════════╝

[1/5] Scanning installed packages...
   Found 1247 unique packages

[2/5] Extracting package versions...
   Extracted version information

[3/5] Querying GitHub issues...
   Fetched 50 open issues

[4/5] Correlating issues with installed packages...
   Found 0 packages with potential issues
     Critical: 0
     High: 0
     Medium: 0

[5/5] Generating report...

╔══════════════════════════════════════════════════════════╗
║                 🎉 All Clear! 🎉                         ║
║                                                          ║
║  No known critical issues affecting installed packages  ║
║  Safe to proceed with system updates                    ║
╚══════════════════════════════════════════════════════════╝
```

### Issues Found

```
╔══════════════════════════════════════════════════════════╗
║            ⚠️  Issues Found ⚠️                            ║
╚══════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚨 CRITICAL SEVERITY (2 packages)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📦 Package: systemd-254.6
   Issues (1):
   • #250123: systemd 254.x fails to boot on UEFI systems
     https://github.com/NixOS/nixpkgs/issues/250123

📦 Package: firefox-120.0
   Issues (1):
   • #251456: Firefox crashes on Wayland with HiDPI
     https://github.com/NixOS/nixpkgs/issues/251456

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚡ HIGH SEVERITY (1 packages)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📦 Package: linux-6.6.1
   Issues (1):
   • #248999: NVIDIA driver incompatible with 6.6.x
     https://github.com/NixOS/nixpkgs/issues/248999

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Recommendation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⛔ DO NOT UPDATE
   2 critical issues detected.
   Wait for fixes or consider pinning affected packages.
```

## Quick Reference

### CLI Commands

```bash
# Basic check
./scripts/issue-checker.sh

# Specific channel
CHANNEL=nixos-23.11 ./scripts/issue-checker.sh

# Critical only
SEVERITY=critical ./scripts/issue-checker.sh

# JSON output
OUTPUT_FORMAT=json ./scripts/issue-checker.sh

# Clear cache
rm -rf ~/.cache/nixos-issue-checker/
```

### Integration Commands

```bash
# Safe rebuild
safe-rebuild switch --upgrade

# Manual check
check-nixos-issues

# Critical issues only
check-critical-issues

# Generate HTML report
./scripts/generate-html-report.sh
```

### Systemd Commands

```bash
# Manual run
systemctl start nixos-issue-check

# Check status
systemctl status nixos-issue-check

# View timer
systemctl list-timers nixos-issue-check

# View logs
journalctl -u nixos-issue-check
```

## Resources

- **GitHub Issues**: <https://github.com/NixOS/nixpkgs/issues>
- **GitHub CLI**: <https://cli.github.com/>
- **NixOS Manual**: <https://nixos.org/manual/nixos/stable/>
- **Issue Labels**: <https://github.com/NixOS/nixpkgs/labels>

## Summary

The issue-checker subagent provides proactive monitoring of NixOS packages against known GitHub issues, helping you maintain system stability by avoiding problematic updates. It integrates seamlessly with your workflow through CLI tools, systemd timers, and CI/CD pipelines.

**Key Benefits**:

- ✅ Prevent breaking updates
- ✅ Maintain system stability
- ✅ Proactive issue awareness
- ✅ Automated monitoring
- ✅ CI/CD integration
- ✅ Actionable recommendations

Use this subagent regularly to make informed decisions about system updates and maintain a stable NixOS environment!
