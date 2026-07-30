# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Global Standards

Agent-OS standards and workflow templates (read on demand, not auto-loaded):

- Standards: `~/.agent-os/standards/{tech-stack,code-style,best-practices}.md`
- Workflows: invoke `/plan-product`, `/create-spec`, `/execute-tasks`, `/analyze-product`

---

## Repository Overview

This is a sophisticated multi-host NixOS Infrastructure Hub featuring a revolutionary **template-based architecture** that achieves unprecedented 95% code deduplication through systematic use of host templates, Home Manager profiles, and 141+ modular components. The repository manages 3 active hosts (P620, Razer, P510) with different hardware profiles, supports multi-user environments, and provides AI integration, development environments, and follows comprehensive NixOS best practices with zero anti-patterns.

**Infrastructure Changes**:

- **DEX5550**: Offline and no longer in use
- **Samsung**: Decommissioned and archived
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

### **Comprehensive Documentation**

For complete workflow details, see:

- **[docs/GITHUB-WORKFLOW.md](./docs/GITHUB-WORKFLOW.md)** - Complete GitHub workflow guide

## Key Commands

Run `just --list` for the full recipe list. Two non-obvious ones:

**For lock bumps + deploy in one idiot-proof command, see [docs/UPDATE-DEPLOY.md](./docs/UPDATE-DEPLOY.md).** TL;DR: `nhs [HOST] [SCOPE]` or `just update-commit-deploy [HOST] [SCOPE]` handles `nix flake update -> test-build -> commit + push -> nh switch` atomically, works for local AND remote hosts, and refuses to run if the working tree is dirty.

`just quick-deploy HOST` deploys only if the configuration actually changed.

## Architecture

### Template-Based Architecture (Revolutionary)

The repository now uses a **three-tier template system** that achieves 95% code deduplication:

#### **Tier 1: Host Templates** (`hosts/templates/`)

Three hardware-optimized templates provide base configurations:

- **`workstation.nix`**: Full desktop environment with development tools
  - Used by: P620 (AMD workstation)
  - Includes: Desktop environments, development tools, media, gaming support

- **`laptop.nix`**: Mobile-optimized with power management
  - Used by: Razer (mobile system)
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
- **Razer**: `developer` + `laptop-user` (mobile development)
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

- **Host-specific live USB images** for each system (P620, Razer, P510)
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

### DON'T - Critical NixOS Anti-Patterns to Avoid

Full catalogue with wrong/correct examples: **[docs/NIXOS-ANTI-PATTERNS.md](./docs/NIXOS-ANTI-PATTERNS.md)** (zero-tolerance policy). Covers `mkIf true`, excessive `with`, dangerous `rec`, IFD, evaluation-time secrets, root services, `nix-env`, monolithic config, magic auto-discovery, and missing garbage collection.

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

1. **Ensure API keys are available in secrets:**
   - API keys must be created using `./scripts/manage-secrets.sh`
   - Keys: `api-openai`, `api-anthropic`, `api-gemini`
   - Ollama requires no API key (local inference)

2. **Test and deploy:**

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

## Agent OS Documentation

Project context, read on demand (paths only, deliberately not auto-loaded):

- `.agent-os/product/mission.md`, `tech-stack.md`, `roadmap.md`, `decisions.md`
- Active specs: `.agent-os/specs/`
- Spec planning / task execution: invoke `/create-spec`, `/execute-tasks`

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
