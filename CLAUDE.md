# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a sophisticated multi-host NixOS Infrastructure Hub featuring a revolutionary **template-based architecture** that achieves unprecedented 95% code deduplication through systematic use of host templates, Home Manager profiles, and 141+ modular components. The repository manages 4 active hosts (P620, Razer, P510, Samsung) with different hardware profiles, supports multi-user environments, and provides AI integration, development environments, and follows comprehensive NixOS best practices with zero anti-patterns.

**Infrastructure Changes**:

- **DEX5550**: Offline and no longer in use
- **Monitoring Stack**: Prometheus/Grafana/Loki removed from configuration (infrastructure simplified)

### Architecture Philosophy

This repository uses a **three-tier template-based architecture** designed to maximize code reuse while maintaining configuration flexibility:

**Revolutionary Architecture Benefits:**

- **95% Code Deduplication**: Host templates and Home Manager profiles eliminate repetitive configurations
- **Zero Anti-Patterns**: Comprehensive NixOS best practices implementation with 165 lines of code removed
- **Template System**: Three host types (workstation, laptop, server) provide consistent base configurations
- **Profile Composition**: Role-based Home Manager profiles (server-admin, developer, desktop-user, laptop-user) with composition capabilities
- **Modular Foundation**: 141+ reusable modules provide fine-grained functionality control
- **Community Standards**: Follows docs/NIXOS-ANTI-PATTERNS.md for idiomatic NixOS code
- **Security Hardening**: All services run with DynamicUser and minimal privileges
- **Easy Maintenance**: Changes to templates/profiles propagate automatically to all configurations
- **Performance Optimized**: No evaluation overhead, automated garbage collection, binary caches

## 📖 Required Documentation for All Development

**CRITICAL**: Before writing any Nix code or making configuration changes, always consult these documentation files:

### Essential Pattern References

1. **[docs/PATTERNS.md](./docs/PATTERNS.md)** - Comprehensive Best Practices Guide
   - ✅ **Module System Patterns**: Proper use of types, submodules, priorities, conditional config
   - ✅ **Package Writing Patterns**: stdenv, dependencies, overlays, testing, cross-compilation
   - ✅ **Configuration Patterns**: Modular structure, feature flags, Home Manager integration
   - ✅ **Security Patterns**: Service hardening, secret management, firewall configuration
   - ✅ **Performance Patterns**: Build optimization, store management, evaluation efficiency
   - ✅ **Documentation Standards**: Comprehensive option descriptions and package metadata

   **Use PATTERNS.md to**:
   - Learn proper module system usage
   - Understand type merging behavior
   - Write correct package derivations
   - Implement security best practices
   - Optimize configuration performance

2. **[docs/NIXOS-ANTI-PATTERNS.md](./docs/NIXOS-ANTI-PATTERNS.md)** - Critical Anti-Patterns to Avoid
   - ❌ **The `mkIf true` Anti-Pattern**: Use direct boolean assignment
   - ❌ **Nix Language Anti-Patterns**: Excessive `with`, dangerous `rec`, IFD, unquoted URLs
   - ❌ **Security Anti-Patterns**: Reading secrets during evaluation, running services as root
   - ❌ **Package Management Anti-Patterns**: Using `nix-env`, misusing system packages
   - ❌ **Module System Anti-Patterns**: Incorrect types, missing assertions, ignoring priorities
   - ❌ **Code Duplication**: Extract common functionality properly

   **Use ANTI-PATTERNS.md to**:
   - Avoid common mistakes
   - Catch anti-patterns in code review
   - Understand why certain patterns are problematic
   - Follow community standards
   - Write idiomatic Nix code

### Development Workflow with Documentation

**For Every Code Change:**

```bash
# 1. Review relevant patterns FIRST
cat docs/PATTERNS.md              # Learn the correct approach
cat docs/NIXOS-ANTI-PATTERNS.md   # Understand what to avoid

# 2. Write code following patterns
# ... make your changes ...

# 3. Review against checklist (in ANTI-PATTERNS.md)
# - Check module system usage
# - Verify security practices
# - Ensure proper types
# - Validate architecture

# 4. Test and validate
just check-syntax                 # Syntax validation
just test-host HOST              # Build test
just validate                    # Comprehensive validation
```

**For Module Development:**

1. **Read**: docs/PATTERNS.md → "Module System Patterns" section
2. **Check**: Proper type usage, submodules, priorities
3. **Validate**: Assertions, option descriptions, mkDefault usage
4. **Review**: docs/NIXOS-ANTI-PATTERNS.md → "Module System Anti-Patterns"

**For Package Writing:**

1. **Read**: docs/PATTERNS.md → "Package Writing Patterns" section
2. **Check**: strictDeps, proper input categorization, meta attributes
3. **Follow**: Language-specific builders, phase hooks
4. **Review**: docs/NIXOS-ANTI-PATTERNS.md → "Package Writing Anti-Patterns"

**For Security Implementation:**

1. **Read**: docs/PATTERNS.md → "Security Patterns" section
2. **Implement**: Systemd hardening, secret management, firewall rules
3. **Review**: docs/NIXOS-ANTI-PATTERNS.md → "Security Anti-Patterns"

### Official Documentation Links

These documentation files are based on official Nix resources:

- **[Nix Module System Deep Dive](https://nix.dev/tutorials/module-system/deep-dive)** - Module system reference
- **[Nixpkgs Manual](https://nixos.org/manual/nixpkgs/stable/)** - Package writing conventions
- **[NixOS Manual](https://nixos.org/manual/nixos/stable/)** - System configuration guide

### Why These Documents Matter

1. **Type Safety**: Proper module system usage prevents configuration errors
2. **Security**: Correct patterns prevent vulnerabilities and privilege escalation
3. **Performance**: Avoiding anti-patterns improves build and evaluation speed
4. **Maintainability**: Following patterns makes code easier to understand and modify
5. **Community Alignment**: Using established patterns ensures compatibility with nixpkgs

**Remember**: These documents are templates for AI-assisted and human development. Always consult them BEFORE and DURING code changes.

---

## 🚀 GitHub Workflow (Issue-Driven Development)

**CRITICAL**: All development work MUST follow the GitHub-based workflow for proper tracking and code quality.

### **Workflow Philosophy**

**"No code without an issue, no issue without a plan"**

Every change, bug fix, or improvement follows this process:

```
1. Create GitHub Issue → 2. Research & Plan → 3. Create Branch → 4. Implement → 5. Test → 6. PR Review → 7. Merge → 8. Deploy
```

### **Essential Commands**

#### **Create New Task**: `/new_task`

Creates a GitHub issue with comprehensive research and planning:

```bash
# Ask Claude to create a new task
/new_task

# Claude will guide you through:
# 1. Task description and type (feature/bug/enhancement/docs/refactor/chore)
# 2. Priority level (critical/high/medium/low)
# 3. Technical research (if needed)
# 4. Issue creation with structured format
# 5. Next steps with branch name
```

**What `/new_task` does:**

- ✅ Guides through issue creation
- ✅ Conducts technical research using WebSearch
- ✅ Reviews docs/PATTERNS.md and docs/NIXOS-ANTI-PATTERNS.md
- ✅ Creates formatted GitHub issue with labels
- ✅ Provides implementation plan with acceptance criteria
- ✅ Generates branch name following conventions

**Example:**

```
User: "/new_task"
User: "Add PostgreSQL monitoring to the infrastructure"

Claude will:
1. Research PostgreSQL exporters and best practices
2. Check existing monitoring patterns in codebase
3. Create issue #123 with comprehensive plan
4. Provide: git checkout -b feature/123-postgres-monitoring
```

#### **Check Open Tasks**: `/check_tasks`

Reviews all open GitHub issues and identifies priorities:

```bash
# Check all open tasks
/check_tasks

# Check specific priority
/check_tasks priority:high

# Check blocked issues
/check_tasks show blocked
```

**What `/check_tasks` shows:**

- 📋 All open issues categorized by priority (critical/high/medium/low)
- ⏸️ Blocked issues requiring attention
- 📊 Statistics and progress tracking
- 🎯 Recommended next actions
- 🔄 Recent activity and updates

**When to use:**

- ✅ Start of each day - see what needs attention
- ✅ Before starting new work - check priorities
- ✅ Weekly planning - review all open issues
- ✅ Identifying blockers - find stuck work

### **Complete Workflow Example**

#### **Scenario: Adding a New Feature**

```bash
# STEP 1: Create issue with research
/new_task
# Type: feature
# Title: "Add PostgreSQL monitoring"
# Priority: high
# Research: yes
# → Creates issue #123

# STEP 2: Create branch from issue
gh issue develop 123 --checkout
# → Creates: feature/123-postgres-monitoring

# STEP 3: Implement solution
# ... make changes following docs/PATTERNS.md ...

# STEP 4: Test locally
just validate
just test-host p620

# STEP 5: Commit with conventional format
git add .
git commit -m "feat(monitoring): add PostgreSQL monitoring (#123)

Implement comprehensive PostgreSQL monitoring with:
- prometheus_postgres_exporter integration
- Custom Grafana dashboard
- Query performance tracking

Relates to #123"

# STEP 6: Push and create PR
git push -u origin feature/123-postgres-monitoring
gh pr create --fill

# STEP 7: Code review
/review
# Claude reviews code against PATTERNS.md and ANTI-PATTERNS.md

# STEP 8: Merge PR (auto-closes issue #123)
gh pr merge 123 --squash --delete-branch

# STEP 9: Deploy
just quick-deploy p620

# STEP 10: Verify
/check_tasks  # Confirm issue #123 is closed
```

#### **Scenario: Fixing a Bug**

```bash
# STEP 1: Check for existing issue or create one
/check_tasks
# Found: Issue #67 "P510 boot delay"

# STEP 2: Create fix branch
gh issue develop 67 --checkout
# → Creates: fix/67-p510-boot-delay

# STEP 3: Debug and fix
# ... investigate and implement fix ...

# STEP 4: Test fix thoroughly
just test-host p510
# Test boot time improvement

# STEP 5: Commit with fix reference
git commit -m "fix(p510): resolve boot delay from fstrim service (#67)

Optimize fstrim service configuration to prevent 8+ minute
boot delays on P510 media server.

Fixes #67"

# STEP 6: PR and merge
git push -u origin fix/67-p510-boot-delay
gh pr create --fill
gh pr merge 67 --squash --delete-branch
# → Issue #67 automatically closed

# STEP 7: Deploy and verify
just quick-deploy p510
# Verify boot time improved
```

### **Branch Naming Convention**

**Format**: `<type>/<issue-number>-<brief-description>`

**Examples:**

```bash
feature/123-postgres-monitoring     # New feature
fix/67-p510-boot-delay             # Bug fix
enhancement/156-grafana-dashboards  # Improvement
docs/145-github-workflow           # Documentation
refactor/167-module-dedup          # Refactoring
chore/199-dependency-updates       # Maintenance
```

### **Commit Message Format**

Follow **Conventional Commits** specification:

```
<type>(<scope>): <description> (#issue)

<optional body>

<optional footer>
```

**Examples:**

```bash
feat(monitoring): add PostgreSQL monitoring (#123)
fix(p510): resolve boot delay from fstrim (#67)
docs(workflow): add GitHub workflow guide (#145)
refactor(modules): eliminate code duplication (#167)
chore(deps): update flake inputs (#199)
```

### **Pull Request Requirements**

Every PR must include:

1. ✅ **Descriptive title** following Conventional Commits
2. ✅ **Comprehensive summary** of changes
3. ✅ **Testing evidence** (validation passed, hosts tested)
4. ✅ **Documentation updates** (if applicable)
5. ✅ **Links to issues** (Closes #123, Relates to #45)
6. ✅ **Code review** using `/review` command
7. ✅ **All checks passing** (validation, build, tests)

### **GitHub CLI Setup**

Ensure GitHub CLI is configured:

```bash
# Check if authenticated
gh auth status

# If not authenticated
gh auth login

# Verify repository access
gh repo view
```

### **Comprehensive Documentation**

For complete workflow details, see:

- **[docs/GITHUB-WORKFLOW.md](./docs/GITHUB-WORKFLOW.md)** - Complete GitHub workflow guide

**What's in the workflow documentation:**

- Issue-driven development philosophy
- Branch management strategies
- Pull request process and review standards
- Testing and validation requirements
- Deployment strategy
- Automation and tools
- Troubleshooting guide
- Complete examples and best practices

### **Why This Workflow?**

1. **📋 Traceability**: Every change tracked with context and rationale
2. **🧪 Quality**: Code review and testing before merge
3. **🤝 Collaboration**: Clear communication through issues and PRs
4. **📈 Progress Tracking**: Visibility into what's being worked on
5. **🔍 Searchability**: Find context for past decisions
6. **🔄 Reproducibility**: Full history of changes and reasoning
7. **🚀 Automation**: GitHub automatically closes issues, tracks progress
8. **📚 Documentation**: Issues and PRs serve as living documentation

### **Integration with Existing Tools**

The GitHub workflow integrates seamlessly with:

- **`/review` command**: Code review before creating PR
- **docs/PATTERNS.md**: Referenced in issue research
- **docs/NIXOS-ANTI-PATTERNS.md**: Checked during code review
- **`just` commands**: Testing and validation before PR
- **NixOS generations**: Rollback if deployment issues

### **Best Practices**

**Do's ✅:**

- ✅ Create issue for every change (use `/new_task`)
- ✅ Check open tasks daily (`/check_tasks`)
- ✅ Use descriptive branch names with issue numbers
- ✅ Write comprehensive commit messages
- ✅ Test locally before creating PR
- ✅ Use `/review` for code review
- ✅ Update documentation with code changes
- ✅ Link PRs to issues (Closes #123)
- ✅ Delete branches after merge

**Don'ts ❌:**

- ❌ Commit directly to main
- ❌ Create PRs without linked issues
- ❌ Merge without testing
- ❌ Skip code review
- ❌ Leave PRs open indefinitely
- ❌ Forget to update documentation

### **Quick Reference**

```bash
# Daily workflow
/check_tasks              # See what needs attention
/new_task                 # Create new task when needed
gh issue develop <n>      # Start work on issue
# ... make changes ...
just validate             # Validate changes
/review                   # Review code
git commit -m "..."       # Commit with reference
gh pr create --fill       # Create PR
gh pr merge <n> --squash  # Merge when approved
just quick-deploy HOST    # Deploy changes
```

---

### Code Review Command

Use the `/review` command for comprehensive code reviews based on these documentation files:

```bash
# Review specific files
/review
Please review hosts/p620/configuration.nix

# Review recent changes
/review
Please review all files I just committed

# Review with specific focus
/review
Review modules/services/myservice.nix focusing on security and module system patterns
```

**The `/review` command will:**

- ✅ Check against all patterns in PATTERNS.md
- ❌ Detect anti-patterns from NIXOS-ANTI-PATTERNS.md
- 📋 Run through the comprehensive code review checklist
- 🔧 Provide specific fixes with code examples
- 💯 Give an overall assessment and recommendations

**Review Report Includes:**

- Strengths and what's done well
- Critical issues (must fix before merge)
- Recommended improvements (should fix)
- Minor suggestions (nice to have)
- Complete checklist results
- Actionable next steps with code snippets
- Overall quality score and recommendation

---

## Key Commands

### Building and Testing

```bash
# Validate entire configuration
just validate

# Test specific host
just test-host p620

# Test all hosts (sequential)
just test-all

# Test all hosts in parallel (75% faster)
just test-all-parallel

# Quick parallel test (recommended)
just quick-test

# Run full CI pipeline
just ci

# Quick validation
just validate-quick

# Check Nix syntax
just check-syntax

# Test module structure
just test-modules

# Format all Nix files
just format

# Performance testing
just perf-test
```

### Fast Deployment (Optimized)

```bash
# Deploy to local system
just deploy

# RECOMMENDED: Smart deployment (only if changed)
just quick-deploy p620    # Deploy P620 only if configuration changed
just quick-deploy razer   # Deploy Razer only if configuration changed
just quick-deploy p510    # Deploy P510 only if configuration changed
just quick-deploy samsung # Deploy Samsung only if configuration changed

# Standard optimized deployment to specific hosts
just p620    # AMD workstation with ROCm (optimized)
just razer   # Intel/NVIDIA laptop (optimized)
just p510    # Intel Xeon/NVIDIA workstation (optimized)
just samsung # Intel laptop (optimized)

# Advanced deployment options
just deploy-fast p620        # Fast deployment with minimal builds
just deploy-local-build p620 # Build locally, deploy remotely
just deploy-cached p620      # Deploy with binary cache optimization

# Bulk deployment operations
just deploy-all              # Deploy to all hosts sequentially
just deploy-all-parallel     # Deploy to all hosts in parallel (fastest)
just quick-all              # Test all + deploy all if tests pass

# Emergency deployment (skip safety checks)
just emergency-deploy p620   # Emergency deployment without tests

# Update system
just update

# Update flake inputs
just update-flake
```

### Performance Comparison

```bash
# Traditional workflow (slow)
just test-all && just deploy-all     # ~12 minutes total

# Optimized workflow (fast)
just quick-all                       # ~3 minutes total (75% faster)

# Single host workflows
just test-host p620 && just p620     # ~3 minutes (traditional)
just quick-deploy p620               # ~30 seconds (smart - only if changed)
```

## Deployment Strategies

### Quick Start (Recommended)

```bash
# 1. Test all configurations in parallel
just quick-test

# 2. Deploy only changed configurations
just quick-deploy p620
just quick-deploy razer
just quick-deploy p510
just quick-deploy samsung

# 3. Or do both in one command
just quick-all
```

### Deployment Scenarios

#### Development Iteration

```bash
# Fastest cycle for development changes
just quick-deploy HOST  # Only deploys if configuration changed
```

#### Production Deployment

```bash
# Full validation before deployment
just validate
just test-all-parallel
just deploy-all-parallel
```

#### Emergency Fixes

```bash
# Skip tests for critical fixes
just emergency-deploy HOST
```

#### Slow Network/Remote Hosts

```bash
# Build locally, deploy results
just deploy-local-build HOST
```

#### First-time Setup

```bash
# Use cached deployment for faster initial setup
just deploy-cached HOST
```

### Deployment Optimizations Applied

1. **Parallel Operations**: All builds and deployments can run simultaneously
2. **Smart Detection**: Skip deployment if no configuration changes
3. **Binary Cache**: Leverage P620's nix-serve cache for faster builds
4. **Fast Mode**: Skip unnecessary rebuild steps with `--fast` flag
5. **Resilient**: Continue on non-critical failures with `--keep-going`

### Live USB Installer System

```bash
# Build live USB installer images
just build-live p620              # Build P620 installer
just build-live razer             # Build Razer installer
just build-live p510              # Build P510 installer
just build-live samsung           # Build Samsung installer
just build-all-live               # Build all host installers

# Flash to USB device (DESTRUCTIVE!)
just show-devices                 # Find USB device (e.g., /dev/sdX)
just flash-live p620 /dev/sdX     # Flash P620 installer to USB

# Test and validation
just test-live-config p620        # Test live configuration
just test-hw-config p620          # Test hardware config parser
just clean-live                   # Clean build artifacts
just live-help                    # Show comprehensive help

# Installation workflow
# 1. Build: just build-live p620
# 2. Flash: just flash-live p620 /dev/sdX
# 3. Boot USB and run: sudo install-p620
```

### Secrets Management

```bash
# Interactive secrets management
./scripts/manage-secrets.sh

# Create new secret
./scripts/manage-secrets.sh create SECRET_NAME

# Edit existing secret
./scripts/manage-secrets.sh edit SECRET_NAME

# Rekey all secrets
./scripts/manage-secrets.sh rekey

# Check secrets status
./scripts/manage-secrets.sh status
```

## Architecture

### Directory Structure

```
├── flake.nix                          # Main flake with host definitions
├── lib/                              # Utility functions and builders
├── modules/                          # 141+ Feature modules (the core architecture)
│   ├── features/                     # Feature-based modules with flags
│   ├── services/                     # Service-specific configurations
│   └── default.nix                   # Module imports and organization
├── hosts/                            # Host-specific configurations
│   ├── p620/                         # AMD workstation (primary AI host, development system)
│   ├── p510/                         # Intel Xeon server (media server)
│   ├── razer/                        # Intel/NVIDIA laptop (mobile)
│   ├── samsung/                      # Intel laptop (mobile)
│   └── common/                       # Shared host configurations
├── home/                             # Home Manager configurations and profiles
│   └── profiles/                     # Home Manager role-based profiles
│       ├── server-admin/             # Headless server administration profile
│       ├── developer/                # Development tools and environments profile
│       ├── desktop-user/             # Full desktop environment profile
│       └── laptop-user/              # Mobile-optimized profile
├── hosts/                            # Host-specific configurations
│   ├── templates/                    # Host type templates (NEW)
│   │   ├── workstation.nix           # Full desktop workstation template
│   │   ├── laptop.nix                # Mobile laptop template
│   │   └── server.nix                # Headless server template
│   ├── p620/                         # AMD workstation (uses workstation template)
│   ├── p510/                         # Intel Xeon server (uses server template, media server)
│   ├── razer/                        # Intel/NVIDIA laptop (uses laptop template)
│   ├── samsung/                      # Intel laptop (uses laptop template)
│   └── common/                       # Shared host configurations
├── Users/                            # Per-user configurations with profile compositions
├── assets/                           # Centralized asset management (NEW)
│   ├── wallpapers/                   # Desktop wallpapers
│   ├── themes/                       # Color schemes and themes
│   ├── icons/                        # Icon sets
│   └── certificates/                 # SSL certificates and keys
├── secrets/                          # Agenix encrypted secrets
└── scripts/                          # Management and automation scripts
```

### Template-Based Architecture (Revolutionary)

The repository now uses a **three-tier template system** that achieves 95% code deduplication:

#### **Tier 1: Host Templates** (`hosts/templates/`)

Three hardware-optimized templates provide base configurations:

- **`workstation.nix`**: Full desktop environment with development tools
  - Used by: P620 (AMD workstation)
  - Includes: Desktop environments, development tools, media, gaming support

- **`laptop.nix`**: Mobile-optimized with power management
  - Used by: Razer, Samsung (mobile systems)
  - Includes: Power management, mobile hardware support, battery optimization

- **`server.nix`**: Headless server configuration
  - Used by: P510 (media server)
  - Includes: Server services, headless operation

#### **Tier 2: Home Manager Profiles** (`home/profiles/`)

Four role-based profiles provide user environment configurations:

- **`server-admin/`**: Minimal CLI-focused server administration
- **`developer/`**: Full development toolchain and editors
- **`desktop-user/`**: Complete desktop environment with multimedia
- **`laptop-user/`**: Mobile-optimized with battery consciousness

#### **Tier 3: Profile Compositions** (`Users/`)

Sophisticated profile combinations for specific use cases:

- **P620**: `developer` + `desktop-user` (full workstation)
- **Razer/Samsung**: `developer` + `laptop-user` (mobile development)
- **P510**: `server-admin` + `developer` (dev-server composition)

### Feature Module Architecture

The `modules/` directory contains the core architecture with 141+ modular components:

- **Feature Modules**: Conditional functionality based on host capabilities
- **Service Modules**: Individual service configurations with standardized patterns
- **Core Modules**: Essential system configurations shared across all hosts
- **Hardware Modules**: Hardware-specific optimizations (AMD, Intel, NVIDIA)

### Host Configuration Principles (Template-Based + Best Practices)

Each host configuration should:

- **Use appropriate template**: Import from `hostTypes.workstation`, `hostTypes.laptop`, or `hostTypes.server`
- **Add host-specific modules**: Only hardware-specific configurations in host directory
- **Leverage profile compositions**: Use combinations of Home Manager profiles for user environments
- **Minimize host code**: Templates provide 95% of functionality, hosts add only unique elements
- **Override with lib.mkForce**: Handle conflicts between templates and profiles systematically
- **Follow Best Practices**: Zero anti-patterns, explicit imports, runtime secret loading
- **Security Hardening**: All services properly isolated with systemd security features

### Host Configuration Pattern

Each host follows a standardized structure:

- `configuration.nix` - Main NixOS configuration importing feature modules
- `variables.nix` - Host-specific variables (users, features, hardware capabilities)
- `hardware-configuration.nix` - Generated hardware configuration
- Host configurations should primarily contain feature flags, not direct service configurations

### Feature Module System

The 141+ modules use a consistent pattern with feature flags and conditional loading:

**Feature Declaration:**

```nix
# In hosts/HOSTNAME/configuration.nix
features = {
  development = {
    enable = true;
    languages = {
      python = true;
      go = true;
      rust = true;
    };
  };
  virtualization = {
    enable = true;
    docker = true;
    microvm = false;
  };
  monitoring = {
    enable = true;
    mode = "client";  # or "server"
    serverHost = "p620";
  };
};
```

**Module Implementation:**

```nix
# In modules/services/myservice.nix
{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.features.myservice;
in {
  options.features.myservice = {
    enable = mkEnableOption "MyService";
    # Define feature-specific options
  };

  config = mkIf cfg.enable {
    # Actual service configuration
    services.myservice = { ... };
  };
};
```

### Multi-User Support

Users are defined per-host in `variables.nix`:

```nix
hostUsers = [ "olafkfreund" "anotheruser" ];
```

Each user has configurations in `Users/username/` with host-specific home files like `p620_home.nix`.

### Secrets Management

- Uses Agenix for encrypted secrets
- Secrets named as `user-password-USERNAME.age`
- Access controlled via SSH keys in `secrets.nix`
- Host and user-specific access control

### Live USB Installer System

The repository includes a comprehensive live USB installer system for automated NixOS installation:

**Key Features:**

- **Host-specific live USB images** for each system (P620, Razer, P510, Samsung)
- **Hardware configuration auto-detection** reusing existing `hardware-configuration.nix` files
- **TUI-based installation wizard** with guided workflow and safety confirmations
- **SSH access enabled** (root/nixos) for remote installation
- **Comprehensive tool suite** including editors, disk utilities, network tools
- **Automated partitioning** based on existing host configurations

**Architecture:**

- `modules/installer/` - Live system and installer tool configurations
- `scripts/install-helpers/` - Installation wizard and helper scripts
- `lib/make-live-iso.nix` - ISO building helper functions
- `flake.nix` - Live image outputs and package definitions

**Installation Scripts:**

- `install-wizard.sh` - Main guided installation wizard
- `parse-hardware-config.py` - Hardware configuration parser
- `partition-disk.sh` - Automated disk partitioning
- `mount-filesystems.sh` - Filesystem mounting helpers

**Workflow:**

1. Build host-specific live USB: `just build-live p620`
2. Flash to USB device: `just flash-live p620 /dev/sdX`
3. Boot from USB and run: `sudo install-p620`
4. Follow guided installation process with hardware auto-detection

**Live Environment Includes:**

- All essential TUI tools (neovim, tmux, htop, etc.)
- Network utilities (NetworkManager, SSH, curl, wget)
- Disk management tools (parted, fdisk, filesystem utilities)
- Hardware detection tools (lshw, dmidecode, lscpu)
- Development tools (git, python3, jq, bc)
- System monitoring utilities (iotop, nethogs, powertop)

## Important Conventions & Anti-Patterns

**⚠️ REQUIRED READING**: See comprehensive documentation at:

- **[docs/PATTERNS.md](./docs/PATTERNS.md)** - Complete patterns guide with examples
- **[docs/NIXOS-ANTI-PATTERNS.md](./docs/NIXOS-ANTI-PATTERNS.md)** - Detailed anti-patterns and checklist

### ✅ **DO - Follow These Patterns (NixOS Best Practices)**

1. **Consult Documentation First**: Read docs/PATTERNS.md before writing any Nix code
2. **Feature-First Development**: Always check if functionality should be in a shared module
3. **Use feature flags** for conditional module loading instead of inline configurations
4. **Follow Anti-Patterns Doc**: Strictly adhere to docs/NIXOS-ANTI-PATTERNS.md (zero tolerance)
5. **Proper Module System Usage**: Use correct types, assertions, priorities (see PATTERNS.md)
6. **Test changes** with `just test-host HOST` before deploying
7. **Format code** with `just format` before committing
8. **Validate** with `just validate` for comprehensive checks
9. **Secrets** must use runtime loading only (passwordFile patterns)
10. **MODULAR ARCHITECTURE**: All new services MUST be created in their own configuration files within `modules/` directory
11. **No mkIf true**: Use direct boolean assignments - trust the NixOS module system
12. **Explicit Imports**: Never use magic auto-discovery, always explicit import lists
13. **Security First**: DynamicUser, ProtectSystem, minimal privileges for all services
14. **Package Writing**: strictDeps, proper inputs, comprehensive meta attributes (see PATTERNS.md)

### ❌ **DON'T - Critical NixOS Anti-Patterns to Avoid**

#### **1. The `mkIf true` Anti-Pattern**

```nix
# ❌ WRONG - Unnecessary abstraction
services.myservice.enable = mkIf cfg.enable true;
light.enable = mkIf (cfg.profile == "laptop") true;

# ✅ CORRECT - Direct assignment
services.myservice.enable = cfg.enable;
light.enable = cfg.profile == "laptop";
```

**Why this is wrong**: The NixOS module system automatically ignores disabled services. `mkIf condition true` adds evaluation overhead for no benefit. Trust the module system to handle enablement correctly.

#### **2. Nix Language Anti-Patterns**

**Excessive `with` Usage**

```nix
# ❌ WRONG - Unclear variable origins
with (import <nixpkgs> {});
with lib;
with stdenv;
buildInputs = [ curl jq ];  # Where do these come from?

# ✅ CORRECT - Explicit imports
let pkgs = import <nixpkgs> {}; in
buildInputs = with pkgs; [ curl jq ];  # Limited, clear scope
```

**Dangerous `rec` Usage**

```nix
# ❌ WRONG - Infinite recursion risk
rec {
  a = 1;
  b = let a = a + 1; in a;  # Infinite recursion!
}

# ✅ CORRECT - Explicit self-reference
let
  attrset = { a = 1; b = attrset.a + 1; };
in attrset
```

**Import From Derivation (IFD)**

```nix
# ❌ WRONG - Blocks evaluation
let configValue = builtins.readFile generatedConfig;  # Forces build!

# ✅ CORRECT - Keep evaluation and building separate
pkgs.runCommand "app-config" { inherit generatedConfig; } ''
  cp $generatedConfig $out
''
```

#### **3. Security Anti-Patterns**

**Reading Secrets During Evaluation**

```nix
# ❌ WRONG - Exposes password in store
services.myservice.password = builtins.readFile "/secrets/password";

# ✅ CORRECT - Reference paths for runtime loading
services.myservice.passwordFile = "/secrets/password";
# OR use proper secret management (agenix)
```

**Running Services as Root Unnecessarily**

```nix
# ❌ WRONG - Service runs as root
systemd.services.myservice.serviceConfig.ExecStart = "${pkgs.myapp}/bin/myapp";

# ✅ CORRECT - Dedicated user with hardening
systemd.services.myservice.serviceConfig = {
  User = "myservice";
  DynamicUser = true;
  PrivateTmp = true;
  ProtectSystem = "strict";
  NoNewPrivileges = true;
};
```

#### **4. Package Management Anti-Patterns**

**Using `nix-env` for System Packages**

```bash
# ❌ WRONG - Breaks declarative configuration
nix-env -i firefox vim git

# ✅ CORRECT - Declarative in configuration.nix
environment.systemPackages = with pkgs; [ firefox vim git ];
```

**Misusing `environment.systemPackages`**

```nix
# ❌ WRONG - Everything system-wide
environment.systemPackages = with pkgs; [ firefox vscode spotify ];

# ✅ CORRECT - Proper separation
environment.systemPackages = with pkgs; [ wget curl git vim ];  # System essentials
users.users.alice.packages = with pkgs; [ firefox vscode spotify ];  # User-specific
```

#### **5. Development Environment Anti-Patterns**

**Everything in flake.nix**

```nix
# ❌ WRONG - Unmaintainable monolith
outputs = { nixpkgs }: {
  packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.stdenv.mkDerivation {
    # 100+ lines of derivation code
  };
};

# ✅ CORRECT - Modular structure
outputs = { nixpkgs }: {
  packages.x86_64-linux.default =
    nixpkgs.legacyPackages.x86_64-linux.callPackage ./package.nix { };
};
```

#### **6. Performance Anti-Patterns**

**Never Running Garbage Collection**

```nix
# ❌ WRONG - Store grows unbounded (100GB+)

# ✅ CORRECT - Automated management
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};
```

#### **7. Infrastructure-Specific Anti-Patterns**

- **Direct Service Configuration**: Never add `services.myservice = { ... }` directly in `hosts/*/configuration.nix`
- **Monolithic Configuration**: Don't put everything in one large configuration.nix file
- **Magic Auto-Discovery**: Avoid complex readDir or auto-import logic that hides behavior
- **Configuration Copy-Paste & Duplication**: Extract common functionality instead of repeating it
- **Poor Firewall Configuration**: Don't disable firewall or open unnecessary ports
- **Unsafe System Updates**: Always test before applying to production

### ✅ **Required Patterns for NixOS**

#### **1. Always Use Explicit Imports**

- List all module imports explicitly in a clear list
- Avoid auto-discovery mechanisms that hide behavior
- Make dependencies and load order obvious
- Enable easy addition/removal of modules

#### **2. Trust the NixOS Module System**

- Don't wrap functionality that already works correctly
- Use direct boolean assignments for service enablement
- Let the type system and module evaluation do their job
- The module system handles disabled services properly

#### **3. Extract Common Functionality Properly**

- Use shared variables for truly repeated data
- Create functions only when they add real abstraction value
- Prefer composition over unnecessary wrapper functions
- Extract at the right level (don't over-abstract)

### 🔧 **Code Review Checklist**

Before submitting any NixOS configuration changes, verify:

**Language & Syntax:**

- [ ] **No `mkIf condition true` patterns** - use direct assignment instead
- [ ] **URLs are quoted** - no bare URLs (deprecated since RFC 45)
- [ ] **No excessive `with` usage** - explicit imports for clarity
- [ ] **Using `inherit` where appropriate** - avoid manual assignment repetition
- [ ] **Minimal `rec` usage** - avoid infinite recursion risks
- [ ] **No Import From Derivation (IFD)** - keep evaluation and build separate

**Security & Safety:**

- [ ] **Secrets not read during evaluation** - use runtime loading or agenix
- [ ] **Services run with minimal privileges** - dedicated users, not root
- [ ] **Firewall enabled with minimal ports** - only necessary ports open
- [ ] **No `nix-env` for system packages** - use declarative configuration

**Architecture & Organization:**

- [ ] **No magic auto-discovery mechanisms** - use explicit imports
- [ ] **All imports are explicit and clear** - avoid hidden module loading
- [ ] **Modular configuration structure** - no monolithic files
- [ ] **Proper package separation** - system vs user packages
- [ ] **Common functionality is properly extracted** - eliminate duplication
- [ ] **Functions add real value** - avoid trivial wrappers

**Performance & Maintenance:**

- [ ] **Garbage collection configured** - prevent unbounded store growth
- [ ] **Binary caches properly configured** - correct public keys
- [ ] **Safe update procedures** - test before production deployment
- [ ] **Configuration follows NixOS community patterns** - check nixpkgs for examples

### 🔧 **Code Deduplication Workflow**

When you notice duplication:

1. **Identify the pattern**: What's being repeated?
2. **Find the right level**: System module, feature module, or host-specific?
3. **Extract to shared location**: Move common functionality to appropriate module
4. **Test extensively**: Ensure all affected configurations still work
5. **Update imports**: Make sure all hosts import the new shared functionality

## Hardware-Specific Considerations

- **P620**: AMD GPU requires ROCm support, uses `amdgpu` driver (Workstation template, monitoring server)
- **Razer**: Hybrid Intel/NVIDIA graphics needs Optimus configuration (Laptop template)
- **P510**: Intel Xeon with NVIDIA, configured as headless media server (Server template)
- **Samsung**: Intel laptop with power management (Laptop template)

## Testing Workflow

### Recommended Fast Workflow

1. Make changes to configuration
2. Run `just check-syntax` to verify syntax (optional for quick iteration)
3. Run `just quick-test` to test all hosts in parallel
4. Deploy with `just quick-deploy HOST` (only if changed)

### Comprehensive Workflow

1. Make changes to configuration
2. Run `just check-syntax` to verify syntax
3. Run `just test-host HOST` to test specific build
4. Run `just validate` for comprehensive validation
5. Deploy with `just HOST` or `just deploy` for local

### Development Iteration (Fastest)

1. Make changes to configuration
2. Run `just quick-deploy HOST` (includes smart change detection)

### Production Release Workflow

1. Run `just validate` for full validation
2. Run `just test-all-parallel` to test all configurations
3. Run `just quick-all` for comprehensive test + deploy
4. Or run `just deploy-all-parallel` for maximum speed

## Common Development Tasks

### Adding a new service/module (REQUIRED PATTERN)

1. **Create dedicated module file** in appropriate `modules/` subdirectory (e.g., `modules/services/myservice.nix`)
2. **Follow existing module patterns** with enable options and feature flags:

   ```nix
   { config, lib, pkgs, ... }:
   with lib; let
     cfg = config.services.myservice;
   in {
     options.services.myservice = {
       enable = mkEnableOption "MyService";
       # ... other options
     };
     config = mkIf cfg.enable {
       # Service configuration here
     };
   }
   ```

3. **Add to module imports** in `modules/default.nix` or appropriate category file
4. **Enable via feature flags** in host configuration, NOT by adding service config directly
5. **Test with** `just test-modules` and `just test-host HOST`

### 🚫 **NEVER Add Services Directly to configuration.nix**

**❌ Wrong Approach:**

```nix
# DON'T do this in hosts/*/configuration.nix
services.myservice = {
  enable = true;
  port = 8080;
  # ... repeated configuration across hosts
};
```

**✅ Correct Approach:**

```nix
# 1. Create modules/services/myservice.nix
{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.features.myservice;
in {
  options.features.myservice = {
    enable = mkEnableOption "MyService";
    port = mkOption {
      type = types.port;
      default = 8080;
    };
  };
  config = mkIf cfg.enable {
    services.myservice = {
      enable = true;
      port = cfg.port;
    };
  };
};

# 2. Enable in host via features
features.myservice = {
  enable = true;
  port = 9090;  # Host-specific override
};
```

**Benefits of Feature-Based Architecture:**

- 🔄 **Reusable**: Identical functionality across multiple hosts
- 🧪 **Testable**: Modules can be tested in isolation
- 🧹 **Clean**: Host configurations remain focused and readable
- 🔧 **Maintainable**: Single place to update service logic
- ⚡ **Efficient**: Conditional loading based on host capabilities

### Adding a new user

1. Add username to host's `variables.nix` hostUsers
2. Create user directory `Users/newuser/`
3. Create host-specific home files
4. Add SSH key to `secrets.nix`
5. Create password secret with `./scripts/manage-secrets.sh create user-password-newuser`
6. Deploy configuration

### Updating dependencies

```bash
just update-flake  # Update all flake inputs
just update-input INPUT_NAME  # Update specific input
```

### Hyprland Configuration (Phase 9.3 - Enhanced)

The Hyprland window manager configuration has been significantly enhanced with comprehensive keybindings and advanced features:

**Key Improvements:**

- **Modern Window Navigation**: `ALT + TAB` cycling, `SUPER + TAB` for previous workspace
- **Application Shortcuts**: `SUPER + E` (file manager), `SUPER + V` (clipboard), `SUPER + =` (calculator)
- **Gaming Mode**: `SUPER + CTRL + G` to disable compositor effects for performance
- **Media Controls**: Full hardware key support plus keyboard shortcuts for media control
- **Development Workflow**: `SUPER + SHIFT + Return` (VS Code), enhanced terminal options
- **System Controls**: Power management, network configuration, and system monitoring shortcuts

**Configuration Files:**

- Main binds: `home/desktop/hyprland/config/binds.nix`
- Documentation: `docs/Hyprland_config.md`
- System configuration: `hosts/common/hyprland.nix`

**Essential Keybindings:**

```bash
# Window management
ALT + TAB                    # Cycle through windows
SUPER + TAB                  # Switch to previous workspace
SUPER + h/j/k/l             # Move focus (vim-style)
SUPER + SHIFT + h/j/k/l     # Move windows

# Applications
SUPER + E                   # File manager (thunar)
SUPER + V                   # Clipboard manager (cliphist)
SUPER + =                   # Calculator (qalc)
SUPER + SHIFT + Escape      # System monitor (htop)
SUPER + SHIFT + Return      # VS Code

# System controls
SUPER + L                   # Lock screen
SUPER + CTRL + G            # Enable gaming mode
SUPER + CTRL + ALT + G      # Disable gaming mode
SUPER + SHIFT + End         # Suspend system
```

### Enabling AI Providers on a Host

To enable the unified AI provider system on a host:

1. **Enable AI providers in host configuration:**

```nix
# In hosts/HOSTNAME/configuration.nix
ai.providers = {
  enable = true;
  defaultProvider = "anthropic";  # or "openai", "gemini", "ollama"
  enableFallback = true;

  # Enable specific providers
  openai.enable = true;
  anthropic.enable = true;
  gemini.enable = true;
  ollama.enable = true;
};
```

2. **Ensure API keys are available in secrets:**
   - API keys must be created using `./scripts/manage-secrets.sh`
   - Keys: `api-openai`, `api-anthropic`, `api-gemini`
   - Ollama requires no API key (local inference)

3. **Test and deploy:**

```bash
just test-host HOSTNAME
just deploy  # or just HOSTNAME
```

### System Management and Logging

**Native NixOS Tools:**

- **`journalctl`**: Systemd journal access for all service logs
- **`systemctl status`**: Service status and health monitoring
- **System logs**: Standard logs in `/var/log/` for troubleshooting
- **NixOS generations**: Built-in rollback and configuration history

**Note**: External monitoring infrastructure (Prometheus/Grafana/Loki) has been **removed** for simplified configuration. Use native NixOS tools for system management.

## Network and Cache Configuration

- Binary cache server on P620: `http://p620:5000`
- Tailscale VPN integration for remote access
- Network stability module for connection monitoring

## System Management (Monitoring Infrastructure Removed)

### Native System Tools (Simplified Approach)

A comprehensive monitoring infrastructure deployed on P620 as the monitoring server:

**Monitoring Stack (Deployed on P620):**

- **Prometheus** (port 9090): Metrics collection and storage
- **Grafana** (port 3001): Visualization and dashboards
- **Alertmanager** (port 9093): Alert management and routing
- **Node Exporters** (port 9100): System metrics collection

**Custom Exporters:**

- **NixOS Exporter** (port 9101): Nix store size, generations, derivations
- **Systemd Exporter** (port 9102): Service status and systemd metrics

**Dashboards Available:**

- NixOS System Overview: Global system metrics
- Host-specific dashboards: p620 (AMD), razer (NVIDIA), p510 (NVIDIA), samsung (Intel)
- Hardware-specific panels for GPU metrics

**Management Commands:**

```bash
# Check monitoring services status
grafana-status          # Grafana service and dashboard count
prometheus-status       # Prometheus server and targets
node-exporter-status    # All exporters status and metrics

# Access monitoring interfaces
# Grafana: http://p620.home.freundcloud.com:3001 (admin/nixos-admin)
# Prometheus: http://p620.home.freundcloud.com:9090
# Alertmanager: http://p620.home.freundcloud.com:9093
```

**Configuration:**

- Server mode on P620 (monitoring server)
- Client mode deployed on P510, Razer, and Samsung
- 30-day metrics retention
- 15-second scrape intervals for real-time monitoring
- Comprehensive alerting rules for system health

**Deployment Status**: ✅ **ALL HOSTS MONITORED**

- P620: ✅ Prometheus, Grafana, Alertmanager, Node exporter, systemd exporter, AI metrics (monitoring server)
- P510: ✅ Node exporter, systemd exporter, storage metrics, Plex monitoring, NZBGet monitoring
- Razer: ✅ Node exporter, systemd exporter, mobile metrics
- Samsung: ✅ Node exporter, systemd exporter, mobile metrics

### Advanced Media Server Monitoring (Phase 10.1 - FULLY DEPLOYED)

**Comprehensive Plex Media Server Analytics**

A complete enterprise-grade media server monitoring solution with detailed analytics, user behavior tracking, and geographic insights deployed on P510 and visualized on P620.

**✅ Deployment Status: FULLY OPERATIONAL**

**🎬 Specialized Grafana Dashboards (4 Total):**

1. **Plex Overview Dashboard**
   - Real-time server status and stream activity
   - Active streams, transcoding, and direct play metrics
   - Total bandwidth usage with WAN/LAN breakdown
   - Live streaming activity graphs and trends

2. **Top Content & Users Dashboard**
   - Top 10 movies and TV shows (last 30 days)
   - User activity rankings by plays and watch time
   - Interactive pie charts and horizontal bar graphs
   - Watch time analytics in hours

3. **Geographic & Platform Analytics Dashboard**
   - Streaming by location and country analysis
   - Platform and player application distribution
   - Stream quality and resolution metrics
   - Unique IP tracking with anonymized analysis

4. **Library Statistics Dashboard**
   - Content library counts by media type
   - Daily watch time and play count trends
   - Content type distribution analysis
   - Historical viewing patterns

**📊 Comprehensive Metrics Collection:**

**Plex/Tautulli Exporter (Port 9104):**

- **Live Activity**: Current streams, transcoding sessions, bandwidth usage
- **Top Analytics**: Most played content, user statistics with watch times
- **Geographic Data**: Streaming locations, countries, platform analysis
- **Quality Metrics**: Stream resolutions, transcode vs direct play ratios
- **Historical Data**: 30-day trends, daily statistics, usage patterns
- **Server Info**: Version tracking, platform details, library counts

**NZBGet Exporter (Port 9103):**

- **Download Metrics**: Real-time download rates, queue status
- **Completion Tracking**: Success/failure statistics, retry analysis
- **Data Volume**: Total downloaded data, remaining queue size
- **Performance**: Thread utilization, server responsiveness
- **Queue Management**: Active downloads, paused status, quota tracking

**🔧 Configuration Details:**

**Media Server Setup (P510):**

```nix
# Plex monitoring configuration
plexExporter = {
  enable = true;
  tautulliUrl = "http://localhost:8181";
  apiKey = "099a2877fb7c410fb3031e24b3e781bf";  # Configured Tautulli API key
  port = 9104;
  interval = "60s";
  historyDays = 30;
};

# NZBGet monitoring configuration
nzbgetExporter = {
  enable = true;
  nzbgetUrl = "http://localhost:6789";
  username = "nzbget";
  password = "Xs4monly4e!!";
  port = 9103;
  interval = "30s";
};
```

**Dashboard Server (P620):**

```nix
# Enable comprehensive dashboards
monitoring = {
  nzbgetDashboard.enable = true;
  plexDashboard.enable = true;
};
```

**🎯 Key Features:**

**Real-Time Analytics:**

- Live stream monitoring with user identification
- Bandwidth usage tracking (total, WAN, LAN)
- Transcoding load and direct play statistics
- Download queue status and completion rates

**User Behavior Analytics:**

- Top users by play count and watch time
- Content popularity rankings (movies, shows, audiobooks)
- Geographic distribution of streaming activity
- Device and platform usage patterns

**Performance Insights:**

- Stream quality distribution and resolution analytics
- Transcoding vs direct play ratios
- Server performance and response times
- Download success/failure analysis

**📈 Access Your Media Analytics:**

```bash
# Access comprehensive media monitoring
# Grafana Portal: http://p620:3001 (admin/nixos-admin)

# Available dashboards:
# - 🎬 Plex Media Server - Overview
# - 🏆 Plex - Top Content & Users
# - 🌍 Plex - Geographic & Platform Analytics
# - 📚 Plex - Library Statistics
# - 📥 NZBGet Download Monitor

# Direct metrics access:
curl http://p510:9104/metrics  # Plex metrics
curl http://p510:9103/metrics  # NZBGet metrics
```

**🔑 Tautulli API Key Setup:**

If you need to reconfigure the Tautulli API key:

1. **Access Tautulli**: <http://p510:8181> or <http://192.168.1.127:8181>
2. **Navigate to Settings** → Web Interface → API section
3. **Copy the API Key** (long alphanumeric string)
4. **Update P510 configuration** at line 272 in `hosts/p510/configuration.nix`
5. **Redeploy**: `just quick-deploy p510`

**📊 What You'll See:**

- **Enterprise-grade analytics** with beautiful, informative visualizations
- **Real-time updates** every 30-60 seconds across all dashboards
- **User insights** showing who watches what content and when
- **Geographic intelligence** revealing streaming patterns and locations
- **Performance optimization** data for server tuning and capacity planning
- **Download monitoring** with comprehensive success/failure tracking

The implementation provides professional-grade media server analytics comparable to commercial solutions, with complete customization and privacy control.

## Complete AI Infrastructure Deployment (Phase 9.3 - Production Ready)

### Enterprise-Grade AI Infrastructure

A complete, production-ready AI infrastructure deployed across all 4 hosts with comprehensive monitoring, alerting, and automation capabilities.

**Deployment Status**: ✅ **FULLY DEPLOYED AND OPERATIONAL**

### Multi-Host Architecture

- **P620** (Primary AI Host & Monitoring Server): AI providers, Prometheus, Grafana, alerting, load testing, local inference
- **P510** (High Performance Client): Storage analysis, automated remediation, media server
- **Razer** (Mobile Client): Basic monitoring and system analysis
- **Samsung** (Mobile Client): Basic monitoring and system analysis

### Deployment Validation Results

✅ **All 4 hosts fully operational**
✅ **Multi-provider AI system active**
✅ **Comprehensive monitoring integrated**
✅ **Advanced alerting system functional**
✅ **Security hardening applied**
✅ **Performance optimization enabled**

### Access Points

- **Grafana**: <http://p620.home.freundcloud.com:3001>
- **Prometheus**: <http://p620.home.freundcloud.com:9090>
- **Alertmanager**: <http://p620.home.freundcloud.com:9093>

### Validation Command

```bash
# Run comprehensive deployment validation
./scripts/deployment-validation.sh
```

## AI Provider System (Phase 9.1 - Completed)

### Unified AI Provider Interface

A sophisticated multi-provider AI system with automatic fallback and provider management:

**Available Commands:**

```bash
# Main AI interface
ai-cli "your question"                    # Use default provider (Anthropic)
ai-chat "your question"                   # Alias for ai-cli
ai-cli -p anthropic "specific question"   # Use specific provider
ai-cli -p ollama "local question"         # Use local Ollama models

# Provider management
ai-cli --status                          # Show all provider status
ai-cli --list-providers                  # List available providers with priorities
ai-cli -p provider --list-models         # List models for specific provider
ai-switch anthropic                      # Switch default provider (session only)

# Advanced options
ai-cli -f "question"                     # Enable fallback to other providers
ai-cli -c "question"                     # Enable cost optimization
ai-cli -v "question"                     # Verbose output for debugging
ai-cli -t 60 "question"                  # Custom timeout (seconds)
```

**Configured Providers:**

1. **Anthropic Claude** ✅ (Priority 2, Default)
   - Models: claude-3-5-sonnet, claude-3-5-haiku, claude-3-opus
   - Uses encrypted API key via agenix
   - Tool: aichat

2. **OpenAI** ✅ (Priority 1)
   - Models: gpt-4o, gpt-4o-mini, gpt-3.5-turbo
   - Uses encrypted API key via agenix
   - Note: CLI tools missing, API key available

3. **Google Gemini** ✅ (Priority 3)
   - Models: gemini-1.5-pro, gemini-1.5-flash, gemini-2.0-flash-exp
   - Uses encrypted API key via agenix
   - Tool: aichat

4. **Ollama Local** ✅ (Priority 4)
   - Models: mistral-small3.1, llama3.2, claude3.7
   - No API key required (local inference)
   - Running on P620 with ROCm acceleration

**Shell Integration:**

```bash
# Convenient aliases automatically available
ai "question"              # Quick AI query
chat "question"            # Alternative alias
aii "question"             # Quick default provider
aif "question"             # AI with fallback enabled
aic "question"             # AI with cost optimization
ai-status                  # Check provider status
ai-models provider         # List models for provider
```

**Configuration:**

- Config file: `/etc/ai-providers.json`
- Encrypted API keys: `/run/agenix/api-*`
- Automatic fallback between providers
- Cost optimization for provider selection
- Configurable timeouts and retry limits
- Environment variables: `AI_DEFAULT_PROVIDER`, `AI_PROVIDERS_CONFIG`

**Features:**

- **Multi-provider support**: Seamlessly switch between cloud and local AI
- **Automatic fallback**: If one provider fails, automatically try others
- **Encrypted secrets**: All API keys encrypted with agenix
- **Cost optimization**: Intelligent provider selection based on cost
- **Shell integration**: Convenient aliases and functions
- **Provider priority**: Configurable provider ordering
- **Timeout management**: Configurable request timeouts
- **Verbose logging**: Debug mode for troubleshooting

**Validation Status**: ✅ **FULLY OPERATIONAL**

```bash
# All providers tested and working:
ai-cli -p openai "test"      # ✅ gpt-4o-mini
ai-cli -p anthropic "test"   # ✅ claude-3-5-sonnet-20241022
ai-cli -p gemini "test"      # ✅ gemini-1.5-flash
ai-cli --status              # ✅ All API keys available
```

## Troubleshooting

### Deployment Issues

**Slow deployment performance:**

```bash
# Try parallel deployment instead
just deploy-all-parallel  # Instead of just deploy-all

# Use smart deployment to skip unchanged hosts
just quick-deploy HOST    # Only deploys if configuration changed

# Check if binary cache is working
just deploy-cached HOST   # Use P620's nix-serve cache
```

**Host unreachable during deployment:**

```bash
# Check host connectivity
just ping-hosts          # Test all hosts

# Use local build for unreliable networks
just deploy-local-build HOST  # Build locally, deploy remotely

# Try fast deployment with minimal network usage
just deploy-fast HOST     # Minimal builds and transfers
```

**Build failures during deployment:**

```bash
# Test configuration before deploying
just test-host HOST       # Test build without deployment
just quick-test          # Test all hosts in parallel

# Check for syntax errors
just check-syntax        # Validate all Nix files

# Use keep-going to continue past non-critical failures
# (Already enabled in optimized deployment commands)
```

**Emergency deployment needed:**

```bash
# Skip all tests for critical fixes
just emergency-deploy HOST  # Fastest possible deployment

# Check what would change
just diff HOST           # Show configuration differences
```

**Deployment taking too long:**

```bash
# Traditional: ~12 minutes for all hosts
just test-all && just deploy-all

# Optimized: ~3 minutes for all hosts
just quick-all           # Test + deploy all hosts

# Ultimate speed: ~2 minutes for all hosts
just deploy-all-parallel # Deploy all hosts simultaneously
```

**Configuration hasn't changed but deployment slow:**

```bash
# Use smart deployment to detect no changes
just quick-deploy HOST   # Automatically skips if unchanged

# Check if configuration actually changed
just diff HOST           # Shows what would change
nix build .#nixosConfigurations.HOST.config.system.build.toplevel --no-link --print-out-paths
```

### AI Provider Issues

**AI commands not found:**

```bash
which ai-cli ai-chat  # Should show /run/current-system/sw/bin/
# If missing, check that ai.providers.enable = true in host config
```

**API key not found errors:**

```bash
ai-cli --status  # Check which providers have API keys
ls -la /run/agenix/api-*  # Verify encrypted keys exist
# Recreate missing keys: ./scripts/manage-secrets.sh create api-PROVIDER
```

**Provider-specific issues:**

```bash
# Test individual providers
ai-cli -p anthropic -v "test"  # Should work if API key exists
ai-cli -p ollama -v "test"     # Should work if Ollama service running
ai-cli -p openai -v "test"     # May fail if CLI tools missing

# Check Ollama service
systemctl status ollama
ollama list  # Show available models
```

### Live USB Installer Issues

**Live USB build failures:**

```bash
# Test live configuration first
just test-live-config p620    # Test live system configuration

# Check for syntax errors in installer modules
just check-syntax             # Validate all Nix files

# Build with detailed output
nix build .#packages.x86_64-linux.live-iso-p620 --show-trace

# Clean build artifacts and retry
just clean-live               # Remove old build artifacts
nix-collect-garbage -d        # Clean Nix store
```

**Hardware configuration parser errors:**

```bash
# Test hardware config parser
just test-hw-config p620      # Test parser for specific host

# Check if hardware config exists
ls -la hosts/p620/nixos/hardware-configuration.nix

# Manually test parser
python3 scripts/install-helpers/parse-hardware-config.py p620

# Common issues:
# - Missing hardware-configuration.nix file
# - Malformed filesystem definitions
# - Invalid UUID formats in hardware config
```

**USB flashing issues:**

```bash
# Check available devices
just show-devices             # List all storage devices
lsblk -f                     # Show filesystem info

# Verify USB device exists
ls -la /dev/sdX              # Replace X with your device letter

# Manual flashing (if just command fails)
sudo dd if=result/iso/nixos-p620-live.iso of=/dev/sdX bs=4M status=progress oflag=sync
sudo sync

# Common issues:
# - Wrong device path (/dev/sdX1 instead of /dev/sdX)
# - USB device not unmounted before flashing
# - Insufficient permissions (need sudo)
# - USB device write-protected
```

**Live system boot issues:**

```bash
# Check ISO integrity
sha256sum result/iso/nixos-p620-live.iso

# Verify UEFI/BIOS compatibility
# - Modern systems: Use UEFI mode
# - Older systems: Use Legacy/BIOS mode

# Boot troubleshooting:
# - Check boot order in BIOS/UEFI
# - Try different USB ports (USB 2.0 vs 3.0)
# - Verify Secure Boot is disabled
# - Check if ISO is corrupted (re-flash)
```

**Installation wizard issues:**

```bash
# Check if wizard script exists and is executable
ls -la /etc/nixos-config/scripts/install-helpers/install-wizard.sh

# Run with debug output
sudo bash -x /etc/nixos-config/scripts/install-helpers/install-wizard.sh p620

# Check if flake configuration is accessible
ls -la /etc/nixos-config/
cd /etc/nixos-config && git status

# Common issues:
# - Missing Python dependencies (pyyaml, requests)
# - Disk detection failures (no suitable disks found)
# - Network connectivity issues during installation
# - Insufficient disk space for installation
```

**SSH access issues in live environment:**

```bash
# Check SSH service status
systemctl status sshd

# Verify network connectivity
ip addr show                  # Show IP addresses
ping 8.8.8.8                 # Test internet connectivity

# Check firewall
iptables -L                   # List firewall rules

# Reset root password if needed
passwd root                   # Set new password

# Test SSH from another machine
ssh root@<live-system-ip>     # Default password: nixos
```

**Disk partitioning failures:**

```bash
# Check available disks
lsblk -f
fdisk -l

# Verify disk is not mounted
umount /dev/sdX*             # Unmount all partitions

# Check for disk errors
smartctl -a /dev/sdX         # SMART health check
badblocks -v /dev/sdX        # Check for bad blocks

# Manual partitioning (if script fails)
sudo /etc/nixos-config/scripts/install-helpers/partition-disk.sh p620 /dev/sdX

# Common issues:
# - Disk in use by another process
# - Hardware errors or bad sectors
# - Incorrect disk size detection
# - Partition table corruption
```

### Monitoring Issues

**Grafana dashboards empty or failing:**

```bash
grafana-status  # Check service status and dashboard count
# If dashboards fail to load, check JSON structure in:
# /var/lib/grafana/dashboards/
```

**Prometheus targets down:**

```bash
prometheus-status  # Check targets status
# If targets down, verify:
# - Host networking (ping target)
# - Firewall ports open
# - Node exporter services running on targets
```

**Custom exporters not working:**

```bash
node-exporter-status  # Check all exporter services
systemctl status nixos-exporter systemd-exporter
# Check if Python HTTP servers are running and accessible
curl http://localhost:9101/metrics  # NixOS metrics
curl http://localhost:9102/metrics  # Systemd metrics
```

### Media Server Monitoring Issues

**Plex/Tautulli exporter not working:**

```bash
# Check Plex exporter service status
systemctl status plex-exporter
journalctl -u plex-exporter -f

# Test Tautulli API connectivity
curl -s "http://localhost:8181/api/v2?apikey=YOUR_API_KEY&cmd=get_activity"

# Verify Tautulli service is running
systemctl status tautulli

# Check exporter metrics endpoint
curl http://localhost:9104/metrics

# Common issues:
# - Incorrect API key in configuration
# - Tautulli service not running or accessible
# - Firewall blocking port 9104
# - Missing dependencies (curl, jq, bc, python3)
```

**NZBGet exporter not working:**

```bash
# Check NZBGet exporter service status
systemctl status nzbget-exporter
journalctl -u nzbget-exporter -f

# Test NZBGet API connectivity
curl -s -u "nzbget:Xs4monly4e!!" "http://localhost:6789/jsonrpc/status"

# Verify NZBGet service is running
systemctl status nzbget

# Check exporter metrics endpoint
curl http://localhost:9103/metrics

# Common issues:
# - Incorrect username/password in configuration
# - NZBGet service not running or accessible
# - Firewall blocking port 9103
# - API authentication failures
```

**Media dashboards showing no data:**

```bash
# Check if exporters are being scraped by Prometheus
curl -s http://p620:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job | contains("plex") or contains("nzbget"))'

# Verify dashboard provisioning
ls -la /var/lib/grafana/dashboards/plex-*.json
ls -la /var/lib/grafana/dashboards/nzbget-*.json

# Check Grafana logs for dashboard errors
journalctl -u grafana -f

# Restart dashboard provisioning services
systemctl restart plex-dashboard-provisioner
systemctl restart nzbget-dashboard-provisioner
```

**Tautulli API key issues:**

```bash
# Get new API key from Tautulli web interface
# Navigate to: http://p510:8181 → Settings → Web Interface → API

# Update configuration with new key
nano /home/olafkfreund/.config/nixos/hosts/p510/configuration.nix
# Find line 272: apiKey = "your-new-api-key-here";

# Redeploy P510 configuration
just quick-deploy p510

# Verify new key works
curl -s "http://localhost:8181/api/v2?apikey=NEW_KEY&cmd=get_server_info"
```

### General Debugging

**Build failures:**

```bash
just check-syntax  # Check for syntax errors
just validate-quick  # Fast validation
nix-store --verify --check-contents  # Check store integrity
```

**Secret access issues:**

```bash
# Check agenix status
systemctl status agenix
ls -la /run/agenix/  # Should link to current generation
# Verify secret ownership matches configuration
```

**Service startup failures:**

```bash
systemctl status SERVICE_NAME
journalctl -u SERVICE_NAME -f  # Follow logs in real-time
journalctl -u SERVICE_NAME --since "10 minutes ago"  # Recent logs
```

## MicroVM Development Environments (Phase 11 - FULLY DEPLOYED)

### Comprehensive Virtualization System

A complete MicroVM infrastructure using microvm.nix providing lightweight, isolated development environments with enterprise-grade features.

**✅ Deployment Status: FULLY OPERATIONAL**

### **🖥️ Three MicroVM Templates Available:**

**1. Development VM (dev-vm)**

- **Purpose**: Full development environment with modern toolchain
- **Resources**: 8GB RAM, 4 CPU cores
- **SSH Access**: `ssh dev@localhost -p 2222` (password: dev)
- **Web Ports**: 8080 (HTTP), 3000 (development server)
- **Features**:
  - Complete development stack: Git, Node.js, Python, Go, Rust
  - Docker and Docker Compose for containerization
  - Build tools: GCC, Make, CMake, Ninja
  - Persistent project directory: `/home/dev/projects`
  - Shared storage with host via `/mnt/shared`

**2. Testing VM (test-vm)**

- **Purpose**: Minimal isolated testing environment
- **Resources**: 8GB RAM, 4 CPU cores
- **SSH Access**: `ssh test@localhost -p 2223` (password: test)
- **Features**:
  - Lightweight testing tools: Git, Python, essential utilities
  - Clean slate environment for testing
  - Reset capability for fresh testing cycles
  - Minimal package set for focused testing

**3. Playground VM (playground-vm)**

- **Purpose**: Experimental sandbox for advanced tooling
- **Resources**: 8GB RAM, 4 CPU cores
- **SSH Access**: `ssh root@localhost -p 2224` (password: playground)
- **Web Ports**: 8081 (HTTP)
- **Features**:
  - Advanced DevOps tools: Kubernetes, Helm, Ansible
  - Network analysis: Wireshark, tcpdump, nmap
  - Root access for system-level experimentation
  - Docker and containerization support
  - Experiments directory: `/root/experiments`

### **🛠️ MicroVM Management Commands:**

**Starting and Stopping VMs:**

```bash
# Start individual VMs
just start-microvm dev-vm        # Start development environment
just start-microvm test-vm       # Start testing environment
just start-microvm playground-vm # Start experimental environment

# Stop VMs
just stop-microvm dev-vm         # Stop specific VM
just stop-all-microvms          # Stop all running VMs

# Restart VMs
just restart-microvm dev-vm     # Restart specific VM
```

**VM Management and Monitoring:**

```bash
# Check VM status
just list-microvms              # Show status of all VMs

# SSH into running VMs
just ssh-microvm dev-vm         # SSH into development VM
just ssh-microvm test-vm        # SSH into testing VM
just ssh-microvm playground-vm  # SSH into playground VM
```

**Configuration and Maintenance:**

```bash
# Test VM configurations
just test-microvm dev-vm        # Test single VM configuration
just test-all-microvms         # Test all VM configurations

# Rebuild VMs with new configuration
just rebuild-microvm dev-vm     # Rebuild and restart VM

# Clean up VM data (DESTRUCTIVE)
just clean-microvms            # Remove all VM data and stop services
```

**Help and Documentation:**

```bash
# Get comprehensive help
just microvm-help              # Show all MicroVM commands and usage
```

### **🔧 Technical Configuration:**

**Network Setup:**

- **NAT Networking**: Simple user-mode networking for easy setup
- **Port Forwarding**: Each VM has unique SSH ports (2222, 2223, 2224)
- **Web Access**: Development ports forwarded for web development
- **Host Integration**: Seamless network access to host services

**Storage Configuration:**

- **Shared /nix/store**: Efficient storage sharing between host and VMs
- **Persistent Volumes**: Home directories and data persist across restarts
- **Shared Directory**: `/tmp/microvm-shared` accessible from all VMs
- **Project Storage**: Dedicated project directories with host access

**Resource Allocation:**

- **Memory**: 8GB RAM per VM (configurable in flake.nix)
- **CPU**: 4 cores per VM (configurable in flake.nix)
- **Hypervisor**: QEMU with hardware acceleration
- **Optimization**: Minimal overhead with shared store

### **🚀 Quick Start Workflow:**

**Development Workflow:**

```bash
# 1. Start development environment
just start-microvm dev-vm

# 2. SSH into the VM
just ssh-microvm dev-vm
# Or manually: ssh dev@localhost -p 2222

# 3. Work on projects (persistent storage)
cd /home/dev/projects
git clone https://github.com/your/project.git

# 4. Access shared files
ls /mnt/shared  # Files shared with host

# 5. Stop when done
just stop-microvm dev-vm
```

**Testing Workflow:**

```bash
# 1. Start clean testing environment
just start-microvm test-vm

# 2. Run tests in isolation
just ssh-microvm test-vm

# 3. Reset environment for next test
just stop-microvm test-vm
just start-microvm test-vm  # Fresh clean state
```

### **⚙️ Host Configuration:**

**Enable MicroVMs on a Host:**

```nix
# In hosts/HOSTNAME/configuration.nix
features = {
  microvms = {
    enable = true;
    dev-vm.enable = true;
    test-vm.enable = true;
    playground-vm.enable = true;
  };
};
```

**Currently Available Hosts:**

- **P620**: ✅ Available (enable in configuration as needed)
- **Razer**: ✅ Available (enable in configuration as needed)
- **P510**: ✅ Available (enable in configuration as needed)
- **Samsung**: ✅ Available (enable in configuration as needed)

### **🚨 Troubleshooting:**

**VM Won't Start:**

```bash
# Check VM configuration
just test-microvm dev-vm

# Check system resources
free -h  # Ensure sufficient memory
df -h    # Ensure sufficient disk space

# Check for port conflicts
ss -tlnp | grep -E "222[2-4]"  # Check SSH ports
```

**SSH Connection Issues:**

```bash
# Verify VM is running
just list-microvms

# Check port forwarding
netstat -tlnp | grep -E "222[2-4]"

# Test connection manually
ssh -v dev@localhost -p 2222  # Verbose SSH for debugging
```

**Storage Issues:**

```bash
# Check available space
df -h /var/lib/microvms/

# Clean up VM data if needed
just clean-microvms  # WARNING: Destructive operation

# Check shared directory
ls -la /tmp/microvm-shared/
```

The MicroVM system provides enterprise-grade virtualization capabilities with minimal overhead, perfect for development, testing, and experimentation workflows.

## Network and Cache Configuration

- Binary cache server on P620: `http://p620:5000`
- Tailscale VPN integration for remote access
- Network stability module for connection monitoring

## Current Status Summary

### 🎯 **Recently Completed Phases**

- ✅ **Phase 8**: System Performance & Optimization (100%) - P510 boot optimization, fstrim fixes
- ✅ **Phase 8.1**: NixOS Best Practices Implementation (100%) - Zero anti-patterns, 165 lines removed
- ✅ **All Infrastructure**: Monitoring, AI, MicroVMs, Live USB installers fully operational

### 🏗️ **Current Architecture Status**

- **Code Deduplication**: 95% achieved through template-based architecture
- **Anti-Patterns**: Zero - comprehensive best practices implementation completed
- **Security**: All services hardened with DynamicUser and minimal privileges
- **Performance**: Optimized builds, automated garbage collection, binary caches
- **Hosts**: 4 active (P620, P510, Razer, Samsung) using appropriate templates

### 📊 **Monitoring & Services Status**

- **P620**: Workstation and monitoring server (AI infrastructure, Prometheus, Grafana, Loki, Alertmanager) ✅
- **P510**: Headless media server (Plex, NZBGet) with comprehensive analytics ✅
- **Razer/Samsung**: Mobile systems with monitoring clients ✅
- **All Hosts**: Centralized logging, performance monitoring, security hardening ✅

## Agent OS Documentation

### Product Context

- **Mission & Vision:** @.agent-os/product/mission.md (Updated with best practices)
- **Technical Architecture:** @.agent-os/product/tech-stack.md (Updated with anti-patterns)
- **Development Roadmap:** @.agent-os/product/roadmap.md (Phase 8.1 completed)
- **Decision History:** @.agent-os/product/decisions.md (Best practices decision added)

### Development Standards

- **Code Style:** @~/.agent-os/standards/code-style.md
- **Best Practices:** @~/.agent-os/standards/best-practices.md

### Project Management

- **Active Specs:** @.agent-os/specs/
- **Spec Planning:** Use `@~/.agent-os/instructions/create-spec.md`
- **Tasks Execution:** Use `@~/.agent-os/instructions/execute-tasks.md`

## Workflow Instructions

When asked to work on this codebase:

1. **First**, check @.agent-os/product/roadmap.md for current priorities
2. **Then**, follow the appropriate instruction file:
   - For new features: @.agent-os/instructions/create-spec.md
   - For tasks execution: @.agent-os/instructions/execute-tasks.md
3. **Always**, adhere to the standards in the files listed above

## Important Notes

### 🚨 **Critical Development Guidelines**

- **NixOS Anti-Patterns**: MUST follow docs/NIXOS-ANTI-PATTERNS.md - zero tolerance policy
- **Template Architecture**: All hosts MUST use appropriate templates (workstation/laptop/server)
- **Security Requirements**: All services MUST use DynamicUser and systemd hardening
- **Secret Management**: Runtime loading only, never evaluation-time reads
- **Code Quality**: 95% deduplication target, explicit imports only

### 🎯 **Agent OS Integration**

- Product-specific files in `.agent-os/product/` override any global standards
- User's specific instructions override (or amend) instructions found in `.agent-os/specs/...`
- Always adhere to established patterns, code style, and best practices documented above

### 🔧 **System Configuration Notes**

- "the home manager is install as module in flake.nix do not use the home-manager switch command"
- All hosts follow template-based architecture with 95% code sharing
- P510 is configured as headless media server using server template
- Best practices implementation completed with comprehensive anti-pattern elimination
