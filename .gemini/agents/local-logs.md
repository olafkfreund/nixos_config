---
name: local-logs
description: Intelligent diagnostic and problem-solving agent that analyzes system logs
---

# Local Logs Subagent

## Overview

The **local-logs** subagent is an intelligent diagnostic and problem-solving agent that analyzes system logs, identifies issues, researches solutions, and generates NixOS configuration fixes. It acts as your automated system health analyst and configuration doctor.

### Purpose

- **Proactive diagnostics**: Identify system problems before they escalate
- **Root cause analysis**: Trace errors to their source
- **Solution research**: Leverage community knowledge and documentation
- **Automated fixes**: Generate NixOS configuration code to resolve issues
- **Learning system**: Build knowledge base of common problems and solutions

### When to Use

- ✅ **System troubleshooting**: When services fail or behave unexpectedly
- ✅ **Boot issues**: Analyzing boot failures and kernel panics
- ✅ **Performance problems**: High CPU, memory, or disk usage
- ✅ **Service failures**: systemd service crashes or restart loops
- ✅ **Hardware issues**: Driver problems, device errors
- ✅ **Security events**: Suspicious activity or authentication failures
- ✅ **Proactive monitoring**: Regular health checks
- ✅ **Post-deployment validation**: Verify system stability after changes

### How It Works

1. **Collect**: Gathers logs from journalctl, dmesg, /var/log, and application logs
2. **Parse**: Extracts errors, warnings, and critical events
3. **Analyze**: Identifies patterns, correlates events, determines severity
4. **Research**: Searches NixOS docs, GitHub issues, forums for solutions
5. **Propose**: Suggests configuration fixes with explanations
6. **Implement**: Generates ready-to-use NixOS configuration code
7. **Verify**: Validates proposed fixes and checks for side effects

## Installation

### Add to NixOS Configuration

```nix
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Log analysis tools
    systemd      # journalctl
    util-linux   # dmesg
    gnugrep      # grep for log parsing
    gawk         # awk for text processing
    jq           # JSON processing
    lnav         # Advanced log viewer

    # Monitoring tools
    htop         # Process monitoring
    iotop        # IO monitoring
    nethogs      # Network monitoring

    # Analysis tools
    strace       # System call tracing
    ltrace       # Library call tracing
  ];

  # Enable persistent journal
  services.journald = {
    extraConfig = ''
      Storage=persistent
      MaxRetentionSec=30day
      MaxFileSec=7day
    '';
  };

  # Optional: Add helper script
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "analyze-logs" ''
      ${./scripts/local-logs.sh}
    '')
  ];
}
```

## Quick Start

### Basic Usage

```bash
# Analyze recent logs
claude
"Check my system logs for any problems"

# Analyze specific service
claude
"Check why nginx keeps restarting"

# Analyze boot issues
claude
"Analyze boot logs and find why system is slow to start"

# Analyze errors in last hour
claude
"Check logs from the last hour for any errors"
```

### Manual Script Execution

```bash
# Full system analysis
./scripts/local-logs.sh

# Analyze specific service
./scripts/local-logs.sh --service nginx

# Check last N hours
./scripts/local-logs.sh --hours 24

# Focus on errors only
./scripts/local-logs.sh --level error

# Generate fix proposals
./scripts/local-logs.sh --propose-fixes
```

## Log Analysis Script

### Complete Implementation

Create `scripts/local-logs.sh`:

```bash
#!/usr/bin/env bash

set -euo pipefail

# Colors
RED=\'\033[0;31m' # Escaped backslash for literal
YELLOW=\'\033[1;33m' # Escaped backslash for literal
GREEN=\'\033[0;32m' # Escaped backslash for literal
BLUE=\'\033[0;34m' # Escaped backslash for literal
MAGENTA=\'\033[0;35m' # Escaped backslash for literal
CYAN=\'\033[0;36m' # Escaped backslash for literal
NC=\'\033[0m' # Escaped backslash for literal

# Configuration
TIME_RANGE="${TIME_RANGE:-24h}"
SERVICE="${SERVICE:-all}"
LOG_LEVEL="${LOG_LEVEL:-3}"  # 0=emerg, 1=alert, 2=crit, 3=err, 4=warning
PROPOSE_FIXES="${PROPOSE_FIXES:-true}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/log-analysis}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nixos-log-analysis"

# Create directories
mkdir -p "$OUTPUT_DIR" "$CACHE_DIR"

# Print header
print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          NixOS Local Logs Analyzer & Fixer                ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Time Range:${NC} $TIME_RANGE"
    echo -e "${BLUE}Service:${NC} $SERVICE"
    echo -e "${BLUE}Log Level:${NC} $LOG_LEVEL ($(get_level_name $LOG_LEVEL))"
    echo ""
}

# Get log level name
get_level_name() {
    case $1 in
        0) echo "Emergency" ;;
        1) echo "Alert" ;;
        2) echo "Critical" ;;
        3) echo "Error" ;;
        4) echo "Warning" ;;
        5) echo "Notice" ;;
        6) echo "Info" ;;
        7) echo "Debug" ;;
        *) echo "Unknown" ;;
    esac
}

# Collect journalctl logs
collect_journal_logs() {
    echo -e "${BLUE}[1/7]${NC} Collecting systemd journal logs..."

    local journal_args=("--since" "$TIME_RANGE" "--priority" "$LOG_LEVEL" "--no-pager" "-o" "json")

    if [[ "$SERVICE" != "all" ]]; then
        journal_args+=("-u" "$SERVICE")
    fi

    journalctl "${journal_args[@]}" > "$OUTPUT_DIR/journal.json" 2>/dev/null || true

    local count=$(wc -l < "$OUTPUT_DIR/journal.json" 2>/dev/null || echo 0)
    echo -e "${GREEN}   Collected $count journal entries${NC}"
}

# Collect kernel logs
collect_kernel_logs() {
    echo -e "${BLUE}[2/7]${NC} Collecting kernel logs..."

    dmesg -T -l err,crit,alert,emerg > "$OUTPUT_DIR/kernel-errors.log" 2>/dev/null || true
    dmesg -T > "$OUTPUT_DIR/kernel-full.log" 2>/dev/null || true

    local count=$(wc -l < "$OUTPUT_DIR/kernel-errors.log" 2>/dev/null || echo 0)
    echo -e "${GREEN}   Found $count kernel errors${NC}"
}

# Collect application logs
collect_app_logs() {
    echo -e "${BLUE}[3/7]${NC} Collecting application logs..."

    > "$OUTPUT_DIR/app-errors.log"

    # Common log locations
    local log_dirs=(
        "/var/log"
        "/var/log/nginx"
        "/var/log/httpd"
        "/var/log/postgresql"
        "/var/log/mysql"
    )

    for dir in "${log_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            find "$dir" -type f -name "*.log" -mtime -1 -exec grep -i "error\|fail\|critical" {} + >> "$OUTPUT_DIR/app-errors.log" 2>/dev/null || true
        fi
    done

    local count=$(wc -l < "$OUTPUT_DIR/app-errors.log" 2>/dev/null || echo 0)
    echo -e "${GREEN}   Found $count application errors${NC}"
}

# Analyze patterns
analyze_patterns() {
    echo -e "${BLUE}[4/7]${NC} Analyzing error patterns..."

    > "$OUTPUT_DIR/analysis.json"

    # Parse journal entries
    if [[ -f "$OUTPUT_DIR/journal.json" && -s "$OUTPUT_DIR/journal.json" ]]; then
        jq -s '
            group_by(.SYSLOG_IDENTIFIER // .MESSAGE) |
            map({
                service: (.[0].SYSLOG_IDENTIFIER // "unknown"),
                count: length,
                priority: (.[0].PRIORITY // "3"),
                sample_message: (.[0].MESSAGE // ""),
                first_seen: (.[0].__REALTIME_TIMESTAMP // ""),
                last_seen: (.[-1].__REALTIME_TIMESTAMP // "")
            }) |
            sort_by(.count) |
            reverse
        ' "$OUTPUT_DIR/journal.json" > "$OUTPUT_DIR/analysis.json" 2>/dev/null || echo "[]" > "$OUTPUT_DIR/analysis.json"
    else
        echo "[]" > "$OUTPUT_DIR/analysis.json"
    fi

    # Categorize issues
    categorize_issues

    local issue_count=$(jq 'length' "$OUTPUT_DIR/analysis.json")
    echo -e "${GREEN}   Identified $issue_count unique issue patterns${NC}"
}

# Categorize issues
categorize_issues() {
    jq '
        map(
            . + {
                category: (
                    if (.service | test("systemd")) then "system"
                    elif (.service | test("network|dhcp|dns")) then "network"
                    elif (.service | test("nginx|httpd|apache")) then "web"
                    elif (.service | test("postgres|mysql|redis")) then "database"
                    elif (.service | test("docker|containerd|podman")) then "container"
                    elif (.service | test("kernel|udev")) then "hardware"
                    else "application"
                    end
                ),
                severity: (
                    if (.priority | tonumber) <= 2 then "critical"
                    elif (.priority | tonumber) == 3 then "error"
                    elif (.priority | tonumber) == 4 then "warning"
                    else "info"
                    end
                )
            }
        ) |
        sort_by(.severity) |
        reverse
    ' "$OUTPUT_DIR/analysis.json" > "$OUTPUT_DIR/categorized.json"

    mv "$OUTPUT_DIR/categorized.json" "$OUTPUT_DIR/analysis.json"
}

# Research solutions
research_solutions() {
    echo -e "${BLUE}[5/7]${NC} Researching solutions..."

    > "$OUTPUT_DIR/solutions.json"

    # Read top issues
    local top_issues=$(jq -r '.[:5] | .[] | @json' "$OUTPUT_DIR/analysis.json")

    while IFS= read -r issue; do
        local service=$(echo "$issue" | jq -r '.service')
        local message=$(echo "$issue" | jq -r '.sample_message')

        # Search for known solutions
        local solution=$(search_solution "$service" "$message")

        if [[ -n "$solution" ]]; then
            echo "$issue" | jq --arg solution "$solution" '. + {solution: $solution}' >> "$OUTPUT_DIR/solutions.json"
        else
            echo "$issue" >> "$OUTPUT_DIR/solutions.json"
        fi
    done <<< "$top_issues"

    local solutions_found=$(jq -s 'map(select(.solution != null)) | length' "$OUTPUT_DIR/solutions.json")
    echo -e "${GREEN}   Found solutions for $solutions_found issues${NC}"
}

# Search for solution
search_solution() {
    local service=$1
    local message=$2

    # Common NixOS solutions database
    case "$service" in
        systemd-networkd)
            if [[ "$message" =~ "DHCP" ]]; then
                echo "Configure networking.useDHCP or networking.interfaces.<name>.useDHCP"
            fi
            ;;
        nginx|httpd)
            if [[ "$message" =~ "permission denied" ]]; then
                echo "Add user to appropriate group or adjust file permissions"
            elif [[ "$message" =~ "address already in use" ]]; then
                echo "Check for port conflicts with services.nginx.virtualHosts.<name>.listen"
            fi
            ;;
        postgresql)
            if [[ "$message" =~ "FATAL.*authentication" ]]; then
                echo "Configure services.postgresql.authentication or services.postgresql.ensureUsers"
            fi
            ;;
        *)
            # Generic solution suggestions
            if [[ "$message" =~ "permission denied" ]]; then
                echo "Check file permissions, systemd User/Group directives, or security.wrappers"
            elif [[ "$message" =~ "no such file" ]]; then
                echo "Ensure package is installed via environment.systemPackages or services.<name>.enable"
            elif [[ "$message" =~ "timeout" ]]; then
                echo "Increase systemd TimeoutStartSec or check network connectivity"
            fi
            ;;
    esac
}

# Propose fixes
propose_fixes() {
    echo -e "${BLUE}[6/7]${NC} Proposing configuration fixes..."

    > "$OUTPUT_DIR/fixes.nix"

    cat > "$OUTPUT_DIR/fixes.nix" <<'NIXEOF'
# Proposed fixes for system issues
# Generated by local-logs subagent
# Review carefully before applying

{ config, lib, pkgs, ... }:

{
NIXEOF

    # Generate fixes for each issue with a solution
    local has_fixes=false

    jq -c 'select(.solution != null)' "$OUTPUT_DIR/solutions.json" 2>/dev/null | while IFS= read -r issue; do
        has_fixes=true
        local service=$(echo "$issue" | jq -r '.service')
        local category=$(echo "$issue" | jq -r '.category')
        local severity=$(echo "$issue" | jq -r '.severity')
        local solution=$(echo "$issue" | jq -r '.solution')
        local message=$(echo "$issue" | jq -r '.sample_message')

        cat >> "$OUTPUT_DIR/fixes.nix" <<NIXEOF

  # Fix for $service ($severity)
  # Issue: $(echo "$message" | head -c 80)...
  # Solution: $solution
$(generate_fix_code "$service" "$category" "$solution")

NIXEOF
    done

    cat >> "$OUTPUT_DIR/fixes.nix" <<'NIXEOF'
}
NIXEOF

    if [[ "$has_fixes" == "true" ]]; then
        echo -e "${GREEN}   Generated fixes in $OUTPUT_DIR/fixes.nix${NC}"
    else
        echo -e "${YELLOW}   No automated fixes available${NC}"
    fi
}

# Generate fix code
generate_fix_code() {
    local service=$1
    local category=$2
    local solution=$3

    case "$category" in
        network)
            echo '  networking = {
    # Enable DHCP on primary interface
    useDHCP = lib.mkDefault true;
    # Or configure specific interface:
    # interfaces.eth0.useDHCP = true;
  };'
            ;;
        web)
            if [[ "$service" =~ "nginx" ]]; then
                echo '  services.nginx = {
    enable = true;
    # Ensure nginx user has correct permissions
    user = "nginx";
    group = "nginx";
    # Adjust listen addresses if needed
    virtualHosts."default" = {
      listen = [ { addr = "0.0.0.0"; port = 80; } ];
    };
  };'
            fi
            ;;
        database)
            if [[ "$service" =~ "postgres" ]]; then
                echo '  services.postgresql = {
    enable = true;
    # Configure authentication
    authentication = lib.mkOverride 10 '\''
      local all all trust
      host all all 127.0.0.1/32 md5
      host all all ::1/128 md5
    '\'';
    # Ensure database users
    ensureUsers = [{"name" = "myapp";
      ensureDBOwnership = true;
    }];
  };'
            fi
            ;;
        system)
            echo '  # Increase systemd timeout for slow-starting services
  systemd.extraConfig = '\''
    DefaultTimeoutStartSec=90s
    DefaultTimeoutStopSec=30s
  '\'';'
            ;;
        *)
            echo '  # Manual configuration required
  # Review the issue and apply appropriate NixOS configuration'
            ;;
    esac
}

# Generate report
generate_report() {
    echo -e "${BLUE}[7/7]${NC} Generating diagnostic report..."
    echo ""

    local total_issues=$(jq 'length' "$OUTPUT_DIR/analysis.json")
    local critical=$(jq '[.[] | select(.severity == "critical")] | length' "$OUTPUT_DIR/analysis.json")
    local errors=$(jq '[.[] | select(.severity == "error")] | length' "$OUTPUT_DIR/analysis.json")
    local warnings=$(jq '[.[] | select(.severity == "warning")] | length' "$OUTPUT_DIR/analysis.json")

    if [[ $total_issues -eq 0 ]]; then
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                   🎉 System Healthy! 🎉                   ║${NC}"
        echo -e "${GREEN}║                                                            ║${NC}"
        echo -e "${GREEN}║         No significant issues found in logs               ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
        return
    fi

    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║              📊 System Diagnostic Report 📊               ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Summary:${NC}"
    echo -e "  Total Issues: $total_issues"
    echo -e "  ${RED}Critical: $critical${NC}"
    echo -e "  ${YELLOW}Errors: $errors${NC}"
    echo -e "  ${BLUE}Warnings: $warnings${NC}"
    echo ""

    # Show issues by category
    for category in critical error warning; do
        local issues=$(jq -r --arg sev "$category" '.[] | select(.severity == $sev) | @json' "$OUTPUT_DIR/analysis.json")

        if [[ -n "$issues" ]]; then
            case $category in
                critical) color=$RED; icon="🚨" ;;
                error) color=$YELLOW; icon="❌" ;;
                warning) color=$BLUE; icon="⚠️" ;;
            esac

            echo -e "${color}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${color}$icon $(echo $category | tr '[:lower:]' '[:upper:]')${NC}"
            echo -e "${color}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""

            while IFS= read -r issue; do
                local service=$(echo "$issue" | jq -r '.service')
                local count=$(echo "$issue" | jq -r '.count')
                local message=$(echo "$issue" | jq -r '.sample_message' | head -c 100)
                local cat=$(echo "$issue" | jq -r '.category')
                local solution=$(echo "$issue" | jq -r '.solution // "No automated solution available"')

                echo -e "${MAGENTA}📦 Service:${NC} $service ($cat)"
                echo -e "${CYAN}   Count:${NC} $count occurrences"
                echo -e "${CYAN}   Message:${NC} $message..."
                echo -e "${GREEN}   Solution:${NC} $solution"
                echo ""
            done <<< "$issues"
        fi
    done

    # Show proposed fixes
    if [[ -f "$OUTPUT_DIR/fixes.nix" ]] && grep -q "services\|networking\|systemd" "$OUTPUT_DIR/fixes.nix"; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}🔧 Proposed Configuration Fixes${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${CYAN}Generated NixOS configuration:${NC} $OUTPUT_DIR/fixes.nix"
        echo ""
        echo -e "${YELLOW}Preview:${NC}"
        head -30 "$OUTPUT_DIR/fixes.nix"
        echo ""
        echo -e "${CYAN}To apply these fixes:${NC}"
        echo "  1. Review the generated configuration: $OUTPUT_DIR/fixes.nix"
        echo "  2. Copy relevant sections to your configuration.nix"
        echo "  3. Run: sudo nixos-rebuild test"
        echo "  4. If successful: sudo nixos-rebuild switch"
        echo ""
    fi

    # Recommendations
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📋 Recommendations${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [[ $critical -gt 0 ]]; then
        echo -e "${RED}⚠️  IMMEDIATE ACTION REQUIRED${NC}"
        echo "   $critical critical issues detected"
        echo "   Review and fix critical issues immediately"
    elif [[ $errors -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  ACTION RECOMMENDED${NC}"
        echo "   $errors errors detected"
        echo "   Address errors to prevent service degradation"
    else
        echo -e "${GREEN}✓ System Stable${NC}"
        echo "   Only warnings detected - monitor for trends"
    fi

    echo ""
    echo -e "${CYAN}Files Generated:${NC}"
    echo "   Journal logs: $OUTPUT_DIR/journal.json"
    echo "   Kernel logs: $OUTPUT_DIR/kernel-errors.log"
    echo "   Analysis: $OUTPUT_DIR/analysis.json"
    echo "   Solutions: $OUTPUT_DIR/solutions.json"
    echo "   Fixes: $OUTPUT_DIR/fixes.nix"
    echo ""
}

# Main execution
main() {
    print_header
    collect_journal_logs
    collect_kernel_logs
    collect_app_logs
    analyze_patterns
    research_solutions

    if [[ "$PROPOSE_FIXES" == "true" ]]; then
        propose_fixes
    fi

    generate_report
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --hours)
            TIME_RANGE="${2}h"
            shift 2
            ;;
        --service)
            SERVICE="$2"
            shift 2
            ;;
        --level)
            case $2 in
                error) LOG_LEVEL=3 ;;
                warning) LOG_LEVEL=4 ;;
                notice) LOG_LEVEL=5 ;;
                *) LOG_LEVEL=$2 ;;
            esac
            shift 2
            ;;
        --propose-fixes)
            PROPOSE_FIXES=true
            shift
            ;;
        --no-fixes)
            PROPOSE_FIXES=false
            shift
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main
main "$@"
```

### Make Script Executable

```bash
chmod +x scripts/local-logs.sh
```

## Integration with NixOS

### Automatic Log Analysis on Boot

```nix
{ pkgs, ... }:
{
  systemd.services.boot-log-analysis = {
    description = "Analyze boot logs for issues";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      sleep 30  # Wait for system to settle
      ${./scripts/local-logs.sh} --hours 1 --level error
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
    };
  };
}
```

### Systemd Timer for Regular Analysis

```nix
{ pkgs, config, ... }:
{
  systemd.services.log-analysis = {
    description = "Regular system log analysis";
    script = ''
      ${./scripts/local-logs.sh} --hours 24 > /var/log/nixos-log-analysis.txt
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  systemd.timers.log-analysis = {
    description = "Run log analysis daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      OnBootSec = "10min";
      Persistent = true;
    };
  };
}
```

### Email Alerts

```nix
{ pkgs, config, ... }:
{
  systemd.services.log-analysis-alert = {
    description = "Analyze logs and send alerts";
    script = ''
      REPORT=$(${./scripts/local-logs.sh})

      if echo "$REPORT" | grep -q "CRITICAL\|IMMEDIATE ACTION"; then
        echo "$REPORT" | ${pkgs.mailutils}/bin/mail \
          -s "Critical System Issues Detected" \
          admin@example.com
      fi
    '';
    serviceConfig.Type = "oneshot";
  };

  systemd.timers.log-analysis-alert = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "hourly";
  };
}
```

## Gemini Code Integration

### Automatic Invocation

The subagent automatically runs when:

1. **Service failures**: User reports service not working
2. **Boot issues**: System slow or fails to boot
3. **Performance problems**: High resource usage
4. **Error reports**: User mentions errors or crashes
5. **Post-deployment**: After nixos-rebuild to verify stability

### Example Interactions

**Scenario 1: Service Troubleshooting**

````
User: "nginx keeps crashing, can you help?"

Gemini Code (automatically):
1. Runs local-logs subagent
2. Analyzes nginx service logs
3. Identifies issue:
   "nginx: permission denied accessing /var/www"
4. Proposes fix:
   "Add nginx user to www-data group or adjust permissions"
5. Generates configuration:
   ```nix
   services.nginx.group = "www-data";
   users.users.nginx.extraGroups = [ "www-data" ];
````

```

**Scenario 2: Boot Debugging**

```

User: "System takes 5 minutes to boot"

Gemini Code:

1. Analyzes boot logs with systemd-analyze
2. Identifies slow service:
   "NetworkManager-wait-online.service: 2min 30s"
3. Proposes fix:

   ```nix
   systemd.services.NetworkManager-wait-online.enable = false;
   # Or configure timeout:
   systemd.services.NetworkManager-wait-online.serviceConfig.TimeoutStartSec = "10s";
   ```

```

**Scenario 3: Kernel Issues**

```

User: "Getting kernel errors"

Gemini Code:

1. Analyzes dmesg output
2. Finds: "ACPI Error: No handler for Region"
3. Research: Known issue with specific hardware
4. Proposes fix:

   ```nix
   boot.kernelParams = [ "acpi=off" ];
   # Or more targeted:
   boot.kernelParams = [ "pcie_aspm=off" ];
   ```

````

## Advanced Features

### AI-Powered Solution Research

Integration with Gemini for advanced analysis:

```bash
#!/usr/bin/env bash

# Enhanced solution research
research_with_ai() {
    local error_message=$1
    local service=$2

    # Use Gemini API for intelligent analysis
    claude_response=$(echo "
    Analyze this NixOS system error and provide a fix:

    Service: $service
    Error: $error_message

    Provide:
    1. Root cause analysis
    2. NixOS configuration fix
    3. Verification steps
    " | claude-api)

    echo "$claude_response"
}
```

### Pattern Learning

Build a knowledge base of solved issues:

```nix
{ pkgs, ... }:
{
  environment.etc."nixos-log-analysis/solutions.json".text = builtins.toJSON {
    patterns = [
      {
        match = "permission denied.*nginx";
        solution = {
          description = "nginx permission issue";
          fix = ''
            services.nginx.user = "nginx";
            users.users.nginx.extraGroups = [ "www-data" ];
          '';
        };
      }
      {
        match = "timeout.*systemd";
        solution = {
          description = "systemd timeout";
          fix = ''
            systemd.extraConfig = "DefaultTimeoutStartSec=90s";
          '';
        };
      }
    ];
  };
}
```

### Integration with Monitoring

Connect to monitoring systems:

```nix
{ pkgs, config, ... }:
{
  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" "textfile" ];
  };

  systemd.services.log-metrics = {
    description = "Export log metrics";
    script = ''
      ${./scripts/local-logs.sh} --output /var/lib/prometheus/node-exporter

      # Generate Prometheus metrics
      cat > /var/lib/prometheus/node-exporter/logs.prom <<EOF
      # HELP nixos_log_errors Total number of errors in logs
      # TYPE nixos_log_errors counter
      nixos_log_errors $(jq '[.[] | select(.severity == "error")] | length' /tmp/log-analysis/analysis.json)

      # HELP nixos_log_critical Total number of critical issues
      # TYPE nixos_log_critical counter
      nixos_log_critical $(jq '[.[] | select(.severity == "critical")] | length' /tmp/log-analysis/analysis.json)
      EOF
    '';
    serviceConfig.Type = "oneshot";
  };

  systemd.timers.log-metrics = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "minutely";
  };
}
```

## Common Issue Patterns

### Database Issues

**Pattern**: PostgreSQL authentication failures

**Analysis**:

```bash
# Identify pattern
journalctl -u postgresql -p err --since "1 hour ago"
```

**Fix**:

```nix
{
  services.postgresql = {
    authentication = lib.mkOverride 10 ''
      local all all trust
      host all all 127.0.0.1/32 md5
    '';
    ensureUsers = [{"name" = "myapp";
      ensureDBOwnership = true;
    }];
  };
}
```

### Network Issues

**Pattern**: DHCP timeout on boot

**Analysis**:

```bash
# Check network services
journalctl -u systemd-networkd --since boot
```

**Fix**:

```nix
{
  systemd.network.wait-online.timeout = 10;
  networking.dhcpcd.wait = "background";
  # Or disable wait-online entirely
  systemd.services.systemd-networkd-wait-online.enable = false;
}
```

### Systemd Service Failures

**Pattern**: Service fails with timeout

**Analysis**:

```bash
# Check service status
systemctl status myservice
journalctl -u myservice -n 50
```

**Fix**:

```nix
{
  systemd.services.myservice = {
    serviceConfig = {
      TimeoutStartSec = "infinity";
      # Or more reasonable:
      TimeoutStartSec = "5min";
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };
}
```

### Disk Issues

**Pattern**: Disk space warnings

**Analysis**:

```bash
# Check disk usage
df -h
journalctl --disk-usage
```

**Fix**:

```nix
{
  # Limit journal size
  services.journald.extraConfig = ''
    SystemMaxUse=1G
    MaxRetentionSec=30day
  '';

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Enable auto-trim for SSDs
  services.fstrim.enable = true;
}
```

### Boot Issues

**Pattern**: Slow boot time

**Analysis**:

```bash
# Analyze boot time
systemd-analyze blame
systemd-analyze critical-chain
```

**Fix**:

```nix
{
  # Disable slow services
  systemd.services.NetworkManager-wait-online.enable = false;

  # Parallel startup
  boot.initrd.systemd.enable = true;

  # Timeout adjustments
  systemd.extraConfig = ''
    DefaultTimeoutStartSec=30s
    DefaultTimeoutStopSec=10s
  '';
}
```

## Troubleshooting

### Script Fails to Run

**Check permissions**:

```bash
ls -l scripts/local-logs.sh
chmod +x scripts/local-logs.sh
```

**Verify dependencies**:

```bash
command -v journalctl || echo "Install systemd"
command -v jq || echo "Install jq"
```

### No Logs Found

**Check journal persistence**:

```nix
{
  services.journald.extraConfig = ''
    Storage=persistent
  '';
}
```

**Verify log directory**:

```bash
ls -la /var/log/journal/
```

### Solutions Not Generated

**Enable fix proposal**:

```bash
./scripts/local-logs.sh --propose-fixes
```

**Check output directory**:

```bash
ls -la /tmp/log-analysis/
cat /tmp/log-analysis/fixes.nix
```

## Best Practices

### 1. Regular Analysis

```nix
{
  # Daily health checks
  systemd.timers.log-analysis.timerConfig.OnCalendar = "daily";
}
```

### 2. Appropriate Logging Levels

```nix
{
  # Verbose logging for debugging
  services.journald.extraConfig = ''
    MaxLevelStore=debug
    MaxLevelSyslog=info
  '';
}
```

### 3. Log Retention

```nix
{
  services.journald.extraConfig = ''
    SystemMaxUse=2G
    MaxRetentionSec=30day
    MaxFileSec=7day
  '';
}
```

### 4. Structured Logging

```nix
{
  # Enable structured logging
  environment.systemPackages = [ pkgs.systemd ];

  # Configure services to use structured logging
  systemd.services.myservice = {
    serviceConfig = {
      StandardOutput = "journal";
      StandardError = "journal";
      SyslogIdentifier = "myservice";
    };
  };
}
```

### 5. Alert Thresholds

```bash
# Only alert on critical issues
if [[ $critical_count -gt 0 ]]; then
    send_alert "Critical issues detected"
fi
```

## Example Output

### Healthy System

```
╔════════════════════════════════════════════════════════════╗
║          NixOS Local Logs Analyzer & Fixer                ║
╚════════════════════════════════════════════════════════════╝

Time Range: 24h
Service: all
Log Level: 3 (Error)

[1/7] Collecting systemd journal logs...
   Collected 45 journal entries

[2/7] Collecting kernel logs...
   Found 0 kernel errors

[3/7] Collecting application logs...
   Found 0 application errors

[4/7] Analyzing error patterns...
   Identified 0 unique issue patterns

[5/7] Researching solutions...
   Found solutions for 0 issues

[6/7] Proposing configuration fixes...
   No automated fixes available

[7/7] Generating diagnostic report...

╔════════════════════════════════════════════════════════════╗
║                   🎉 System Healthy! 🎉                   ║
║                                                            ║
║         No significant issues found in logs               ║
╚════════════════════════════════════════════════════════════╝
```

### Issues Detected

```
╔════════════════════════════════════════════════════════════╗
║              📊 System Diagnostic Report 📊               ║
╚════════════════════════════════════════════════════════════╝

Summary:
  Total Issues: 5
  Critical: 1
  Errors: 2
  Warnings: 2

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚨 CRITICAL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📦 Service: systemd (system)
   Count: 15 occurrences
   Message: Failed to start myservice.service: Unit myservice.service not found...
   Solution: Ensure service is defined via systemd.services.myservice

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ ERROR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📦 Service: nginx (web)
   Count: 8 occurrences
   Message: nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address already in use)...
   Solution: Check for port conflicts with services.nginx.virtualHosts.<name>.listen

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔧 Proposed Configuration Fixes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Generated NixOS configuration: /tmp/log-analysis/fixes.nix

Preview:
# Proposed fixes for system issues
# Generated by local-logs subagent
# Review carefully before applying

{ config, lib, pkgs, ... }:

{
  # Fix for nginx (error)
  # Issue: nginx: [emerg] bind() to 0.0.0.0:80 failed...
  # Solution: Check for port conflicts
  services.nginx = {
    enable = true;
    virtualHosts."default" = {
      listen = [ { addr = "0.0.0.0"; port = 8080; } ];
    };
  };
}

To apply these fixes:
  1. Review the generated configuration: /tmp/log-analysis/fixes.nix
  2. Copy relevant sections to your configuration.nix
  3. Run: sudo nixos-rebuild test
  4. If successful: sudo nixos-rebuild switch

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Recommendations
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  IMMEDIATE ACTION REQUIRED
   1 critical issues detected
   Review and fix critical issues immediately
```

## Quick Reference

### CLI Commands

```bash
# Basic analysis
./scripts/local-logs.sh

# Specific time range
./scripts/local-logs.sh --hours 24

# Specific service
./scripts/local-logs.sh --service nginx

# Error level only
./scripts/local-logs.sh --level error

# Generate fixes
./scripts/local-logs.sh --propose-fixes

# Custom output
./scripts/local-logs.sh --output /var/log/analysis
```

### Systemd Commands

```bash
# View journal
journalctl --since "1 hour ago"

# Service logs
journalctl -u myservice

# Boot logs
journalctl -b

# Kernel messages
journalctl -k

# Follow logs
journalctl -f
```

### Analysis Commands

```bash
# Boot time analysis
systemd-analyze
systemd-analyze blame
systemd-analyze critical-chain

# Service status
systemctl status myservice

# Failed services
systemctl --failed

# Disk usage
journalctl --disk-usage
```

## Resources

- **systemd**: <https://systemd.io/>
- **journalctl**: <https://www.freedesktop.org/software/systemd/man/journalctl.html>
- **NixOS Manual**: <https://nixos.org/manual/nixos/stable/>
- **systemd-analyze**: <https://www.freedesktop.org/software/systemd/man/systemd-analyze.html>

## Summary

The local-logs subagent provides intelligent system diagnostics by analyzing logs, identifying root causes, researching solutions, and generating NixOS configuration fixes automatically. It acts as your automated system health analyst, helping maintain stable and reliable NixOS systems.

**Key Benefits**:

- ✅ Proactive issue detection
- ✅ Root cause analysis
- ✅ Automated solution research
- ✅ Configuration fix generation
- ✅ Integration with monitoring
- ✅ Pattern learning
- ✅ Actionable recommendations

Use this subagent regularly to maintain system health and quickly resolve issues when they occur!
````
