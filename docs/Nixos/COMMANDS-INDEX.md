# NixOS Commands - Complete Index

This document provides a complete index of all available custom commands with quick access links and summaries.

## Quick Navigation

- [Getting Started](#getting-started)
- [Command Reference](#command-reference)
- [Documentation](#documentation)
- [Usage Examples](#usage-examples)
- [Integration](#integration)

## Getting Started

### First Time Setup

1. **Verify installation:**
   ```bash
   ls -la .claude/commands/
   # Should show 10 command files
   ```

2. **Read documentation:**
   ```bash
   cat docs/Nixos/README.md
   ```

3. **Try your first command:**
   ```bash
   claude
   /system-health-check
   ```

### Quick Start Guide

```bash
# Daily: Check system health
/system-health-check

# Weekly: Update flake inputs
/flake-update

# Monthly: Quality audit
/config-audit

# As needed: Deploy changes
/deploy-all
```

## Command Reference

### System Maintenance Commands

#### `/flake-update` - Flake Input Management
**File:** `.claude/commands/flake-update.md`
**Purpose:** Safely update NixOS flake inputs with testing and deployment

| Attribute | Value |
|-----------|-------|
| **Frequency** | Weekly |
| **Duration** | 10-15 minutes |
| **Risk Level** | Medium |
| **Auto-Deploy** | Yes |
| **GitHub Integration** | Yes |

**Key Features:**
- Pre-update system checks
- Parallel host testing
- Smart deployment (only changed hosts)
- Post-deployment verification
- Automatic rollback on failure
- Detailed commit documentation

**When to Use:**
- Weekly maintenance schedule
- After upstream security updates
- When new features needed from nixpkgs
- Before major infrastructure changes

---

#### `/system-health-check` - Infrastructure Monitoring
**File:** `.claude/commands/system-health-check.md`
**Purpose:** Comprehensive health assessment across all infrastructure

| Attribute | Value |
|-----------|-------|
| **Frequency** | Weekly |
| **Duration** | 5-10 minutes |
| **Risk Level** | None (read-only) |
| **Auto-Deploy** | No |
| **GitHub Integration** | Optional |

**Key Features:**
- Multi-host connectivity testing
- Service status verification
- Resource utilization analysis
- Monitoring stack validation
- Media server health (Plex/NZBGet)
- Security audit
- Comprehensive report generation

**When to Use:**
- Weekly scheduled checks
- After major deployments
- When investigating issues
- Before starting new projects

---

#### `/deploy-all` - Multi-Host Deployment
**File:** `.claude/commands/deploy-all.md`
**Purpose:** Deploy configuration changes to all hosts with comprehensive testing

| Attribute | Value |
|-----------|-------|
| **Frequency** | As needed |
| **Duration** | 5-15 minutes |
| **Risk Level** | Medium-High |
| **Auto-Deploy** | Yes |
| **GitHub Integration** | Optional |

**Key Features:**
- Pre-deployment validation
- Multiple deployment strategies (parallel/sequential/phased)
- Post-deployment verification
- Monitoring integration
- Emergency rollback procedures
- Deployment documentation

**When to Use:**
- After configuration changes
- Post-testing deployment
- System-wide updates
- Coordinated rollouts

---

### Package Management Commands

#### `/update-claude-code` - Claude Code Updates
**File:** `.claude/commands/update-claude-code.md`
**Purpose:** Update Claude Code package with proper testing

| Attribute | Value |
|-----------|-------|
| **Frequency** | Monthly |
| **Duration** | 8-12 minutes |
| **Risk Level** | Low |
| **Auto-Deploy** | Yes |
| **GitHub Integration** | Yes |

**Key Features:**
- Automatic version research
- Hash calculation
- Multi-host testing
- GitHub issue/PR creation
- Deployment verification

**When to Use:**
- New release available
- Bug fixes needed
- Feature updates desired
- Monthly maintenance

---

#### `/update-package` - Generic Package Updates
**File:** `.claude/commands/update-package.md`
**Purpose:** Update any package in the configuration

| Attribute | Value |
|-----------|-------|
| **Frequency** | As needed |
| **Duration** | 10-20 minutes |
| **Risk Level** | Medium |
| **Auto-Deploy** | Yes |
| **GitHub Integration** | Yes |

**Key Features:**
- Flexible package selection
- Multiple update strategies
- Comprehensive testing
- GitHub workflow integration
- Rollback procedures

**When to Use:**
- Security updates
- Bug fixes
- Feature requirements
- Dependency updates

---

### Quality Assurance Commands

#### `/config-audit` - Configuration Quality Audit
**File:** `.claude/commands/config-audit.md`
**Purpose:** Audit configuration for anti-patterns and quality

| Attribute | Value |
|-----------|-------|
| **Frequency** | Monthly |
| **Duration** | 15-25 minutes |
| **Risk Level** | None (analysis only) |
| **Auto-Deploy** | No |
| **GitHub Integration** | Yes |

**Key Features:**
- Anti-pattern detection
- Security audit
- Module system review
- Performance analysis
- Code quality metrics
- Comprehensive reporting
- Issue creation for findings

**When to Use:**
- Monthly quality checks
- Before major releases
- After large changes
- Code review processes

---

## Documentation

### Core Documentation Files

#### `README.md`
**Location:** `docs/Nixos/README.md`
**Size:** 7.8 KB

**Contents:**
- Command system overview
- Quick start guide
- Command categories
- Why use custom commands
- Benefits and productivity impact
- Getting started instructions
- Weekly/monthly workflows
- Best practices

**Read this:** When starting with the command system

---

#### `Command-System-Overview.md`
**Location:** `docs/Nixos/Command-System-Overview.md`
**Size:** 15 KB

**Contents:**
- Complete architecture explanation
- Command catalog with detailed descriptions
- Integration with infrastructure
- Command development workflow
- Best practices and patterns
- Safety features and risk mitigation
- Troubleshooting guide
- Performance optimization
- Future enhancements

**Read this:** For deep understanding of the system

---

#### `Quick-Reference.md`
**Location:** `docs/Nixos/Quick-Reference.md`
**Size:** 7.6 KB

**Contents:**
- Command cheat sheet
- Common workflows
- Just commands reference
- Emergency procedures
- Monitoring access
- GitHub operations
- File locations
- Troubleshooting quick fixes

**Read this:** For quick lookups during work

---

#### `COMMANDS-INDEX.md`
**Location:** `docs/Nixos/COMMANDS-INDEX.md` (this file)
**Size:** Variable

**Contents:**
- Complete command index
- Command details and attributes
- Documentation index
- Usage examples
- Integration guides

**Read this:** For comprehensive reference

---

## Usage Examples

### Example 1: Weekly Maintenance Routine

```bash
# Monday morning
/system-health-check
# Review report, create issues for any problems

# Wednesday afternoon
/flake-update
# Review changes, test, deploy

# Friday EOD
/check_tasks
# Review progress, plan next week
```

### Example 2: Package Update Workflow

```bash
# User reports outdated package or security alert

# Step 1: Update the package
/update-package
# Select package, reason, affected hosts
# Creates GitHub issue #123

# Step 2: Review the changes
/review
# AI reviews code against patterns

# Step 3: Deploy after approval
/deploy-all
# Deploy to all hosts with testing

# Step 4: Verify
/system-health-check
# Confirm everything operational
```

### Example 3: Monthly Quality Check

```bash
# First day of month

# Step 1: Run audit
/config-audit
# Comprehensive quality analysis

# Step 2: Create issues for findings
/new_task
# Create issue for each critical/high item

# Step 3: Plan fixes
# Prioritize and schedule fixes

# Step 4: Verify improvements
/config-audit
# Re-run audit to confirm improvements
```

### Example 4: Emergency Response

```bash
# Production issue detected

# Step 1: Immediate health check
/system-health-check
# Identify affected components

# Step 2: Check recent changes
git log --oneline -10

# Step 3: Rollback if needed
ssh HOST "sudo nixos-rebuild switch --rollback"

# Step 4: Verify recovery
/system-health-check

# Step 5: Document incident
/new_task
# Create issue for investigation
```

## Integration

### GitHub Workflow Integration

Commands integrate with existing GitHub workflow:

```bash
# Commands use:
/new_task         # Create tracked issues
/check_tasks      # Review open tasks
/review           # Code review before PR

# Commands create:
- GitHub issues with proper labels
- Branches following conventions
- PRs with testing evidence
- Commit messages following standards
```

### Just Command Integration

Commands leverage Just automation:

```bash
# Commands use:
just check-syntax       # Syntax validation
just validate-quick     # Configuration validation
just quick-test         # Parallel testing
just quick-deploy       # Smart deployment
just test-host          # Individual host testing
```

### Monitoring Integration

Commands interact with monitoring:

```bash
# Commands check:
grafana-status          # Dashboard health
prometheus-status       # Metrics collection
node-exporter-status    # Exporter status

# Commands access:
http://p620:9090        # Prometheus
http://p620:3001        # Grafana
http://p620:9093        # Alertmanager
```

### Documentation Integration

Commands reference:

```bash
@docs/PATTERNS.md              # Best practices
@docs/NIXOS-ANTI-PATTERNS.md   # Anti-patterns
@docs/GITHUB-WORKFLOW.md       # GitHub workflow
@.agent-os/product/roadmap.md  # Roadmap
```

## Command Comparison Matrix

| Command | Weekly | Monthly | As Needed | Duration | Risk | GitHub |
|---------|--------|---------|-----------|----------|------|--------|
| `/flake-update` | ✅ | | | 10-15m | Med | ✅ |
| `/system-health-check` | ✅ | | | 5-10m | None | Optional |
| `/update-claude-code` | | ✅ | | 8-12m | Low | ✅ |
| `/update-package` | | | ✅ | 10-20m | Med | ✅ |
| `/deploy-all` | | | ✅ | 5-15m | Med-High | Optional |
| `/config-audit` | | ✅ | | 15-25m | None | ✅ |

## Productivity Metrics

### Time Savings

```bash
# Traditional workflow per operation: 30-45 minutes
# - Manual research: 5-10 min
# - File updates: 5-10 min
# - Hash calculation: 5 min
# - Testing: 10 min
# - GitHub workflow: 10 min
# - Deployment: 5 min

# Command workflow per operation: 5-15 minutes
# - Everything automated
# - Built-in validation
# - Integrated testing
# - Automatic documentation

# Result: 70-80% time reduction
```

### Annual Impact

```bash
# Estimated operations per year:
/flake-update: 52 (weekly)
/system-health-check: 52 (weekly)
/update-package: 24 (monthly)
/config-audit: 12 (monthly)
/deploy-all: 100 (as needed)

# Total operations: ~240/year
# Time saved per operation: ~20 minutes average
# Total time saved: ~80 hours/year
```

### Quality Improvements

```bash
# Before commands:
- Anti-patterns: Variable
- Testing coverage: Inconsistent
- Documentation: Often skipped
- Rollback procedures: Not standardized

# After commands:
- Anti-patterns: Detected automatically
- Testing coverage: Always comprehensive
- Documentation: Always generated
- Rollback procedures: Always available
```

## Best Practices

### Command Usage

✅ **Do:**
- Read command documentation first
- Follow all validation steps
- Monitor after deployment
- Create GitHub issues
- Review command output

❌ **Don't:**
- Skip prerequisite checks
- Ignore warnings
- Deploy without testing
- Forget rollback plans

### Customization

✅ **Do:**
- Customize for your needs
- Add new commands
- Improve existing workflows
- Share improvements

❌ **Don't:**
- Remove safety checks
- Skip validation steps
- Bypass GitHub integration
- Forget documentation

## Support and Resources

### Getting Help

1. **Documentation**
   - Read relevant command guide
   - Check quick reference
   - Review patterns docs

2. **Command Files**
   - Read command source
   - Check examples
   - Follow troubleshooting

3. **GitHub Issues**
   - Search existing issues
   - Create new issue with `/new_task`
   - Link related issues

### Providing Feedback

```bash
# Improve commands
vim .claude/commands/COMMAND.md

# Update documentation
vim docs/Nixos/COMMAND-Guide.md

# Commit improvements
git add .
git commit -m "feat(commands): improve /COMMAND"
git push
```

## Version History

- **2025-01-03**: Initial command system creation
  - 6 core commands
  - 3 documentation files
  - Complete integration

## Next Steps

1. **Read**: [README.md](./README.md) for getting started
2. **Understand**: [Command-System-Overview.md](./Command-System-Overview.md) for details
3. **Reference**: [Quick-Reference.md](./Quick-Reference.md) for quick lookups
4. **Try**: Run `/system-health-check` to test
5. **Adopt**: Integrate into your workflow
6. **Customize**: Adapt to your needs
7. **Share**: Contribute improvements

---

**Remember:** Commands are tools to enhance your workflow. Always understand what they do and why.
