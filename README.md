# NixOS Infrastructure Hub

> **Fast, Easy, Reliable** - Template-Based Architecture with Claude Code Integration

## 🚀 Quick Start

```bash
# Clone and enter directory
git clone <your-repo-url>
cd nixos-infrastructure

# Validate configuration
just validate-quick

# Deploy to current host
just deploy

# Get help
just help-extended
/nix-help  # Claude Code help
```

## 📊 Architecture Overview

This repository implements a sophisticated **template-based NixOS configuration management system** achieving **95% code deduplication** through a three-tier architecture. The system manages **4 active hosts** (P620, P510, Razer, Samsung) with different hardware profiles, supports multi-user environments, and provides comprehensive automation through Justfile commands and Claude Code integration.

### Key Statistics

| Metric                   | Value                              |
| ------------------------ | ---------------------------------- |
| **Code Deduplication**   | 95% shared code                    |
| **Active Hosts**         | 4 (workstation, server, 2 laptops) |
| **Modules**              | 141+ modular components            |
| **Justfile Commands**    | 140+ automation commands           |
| **Claude Code Skills**   | 16 specialized skills              |
| **Claude Code Commands** | 20+ workflow commands              |
| **Claude Code Agents**   | 6 specialized agents               |
| **Anti-Patterns**        | Zero (100% compliance)             |

### Core Architecture Components

- **🖥️ Host Templates**: 3 hardware-optimized templates (workstation, laptop, server)
- **👤 Home Manager Profiles**: 4 role-based user profiles with composition capabilities
- **🧩 Modular Foundation**: 141+ reusable modules for fine-grained functionality control
- **🎨 Asset Management**: Centralized asset organization with clean directory structure
- **🤖 Claude Code Integration**: 16 skills, 20+ commands, 4 agents for AI-assisted development
- **⚡ Justfile Automation**: 140+ commands for building, testing, deploying, and managing

### Infrastructure Status

- **✅ Active Hosts**: P620 (workstation), P510 (media server), Razer (laptop), Samsung (laptop)
- **❌ Offline**: DEX5550 (decommissioned)
- **📊 Monitoring**: Simplified (using native systemd tools instead of Prometheus/Grafana stack)

## 🏗️ Directory Structure

```
├── flake.nix                          # Main flake configuration
├── justfile                          # 140+ automation commands
├── lib/                               # Utility functions and builders
├── modules/                           # 141+ modular components
│   ├── features/                      # Feature-based modules with flags
│   ├── services/                      # Service-specific configurations
│   └── default.nix                    # Module imports and organization
├── hosts/                             # Host-specific configurations
│   ├── templates/                     # Host type templates (NEW)
│   │   ├── workstation.nix            # Full desktop workstation template
│   │   ├── laptop.nix                 # Mobile laptop template
│   │   └── server.nix                 # Headless server template
│   ├── p620/                          # AMD workstation (uses workstation template)
│   ├── p510/                          # Intel Xeon server (uses server template, media server)
│   ├── razer/                         # Intel/NVIDIA laptop (uses laptop template)
│   ├── samsung/                       # Intel laptop (uses laptop template)
│   └── common/                        # Shared host configurations
├── home/                              # Home Manager configurations and profiles
│   └── profiles/                      # Role-based profiles
│       ├── server-admin/              # Headless server administration profile
│       ├── developer/                 # Development tools and environments profile
│       ├── desktop-user/              # Full desktop environment profile
│       └── laptop-user/               # Mobile-optimized profile
├── Users/                             # Per-user configurations with profile compositions
├── assets/                            # Centralized asset management
│   ├── wallpapers/                    # Desktop wallpapers
│   ├── themes/                        # Color schemes and themes
│   ├── icons/                         # Icon sets
│   └── certificates/                  # SSL certificates and keys
├── secrets/                           # Agenix encrypted secrets
├── scripts/                           # Management and automation scripts
├── .claude/                           # Claude Code integration (NEW)
│   ├── CLAUDE.md                      # Claude Code project configuration
│   ├── commands/                      # 20+ slash commands for workflows
│   ├── skills/                        # 16 specialized knowledge skills
│   └── agents/                        # 4 specialized automation agents
└── docs/                              # Documentation
    ├── PATTERNS.md                    # NixOS best practices
    └── NIXOS-ANTI-PATTERNS.md         # Anti-patterns to avoid
```

## 🎯 Template System

### Host Templates

**Workstation Template** (`hosts/templates/workstation.nix`)

- **Target**: Full desktop development workstation
- **Used by**: P620 (AMD workstation)
- **Features**: Desktop environments, development tools, media apps, gaming support
- **Profile Composition**: developer + desktop-user

**Laptop Template** (`hosts/templates/laptop.nix`)

- **Target**: Mobile development with power management
- **Used by**: Razer (Intel/NVIDIA), Samsung (Intel)
- **Features**: Power management, mobile hardware support, battery optimization
- **Profile Composition**: developer + laptop-user

**Server Template** (`hosts/templates/server.nix`)

- **Target**: Headless server operation
- **Used by**: P510 (media server)
- **Features**: Server services, headless operation, security hardening
- **Profile Composition**: server-admin + developer

### Home Manager Profiles

| Profile          | Description                                  | Use Cases                              |
| ---------------- | -------------------------------------------- | -------------------------------------- |
| **server-admin** | Minimal CLI-focused server administration    | Headless servers, minimal environments |
| **developer**    | Full development toolchain and editors       | Software development, coding           |
| **desktop-user** | Complete desktop environment with multimedia | Full desktop experience                |
| **laptop-user**  | Mobile-optimized with battery consciousness  | Mobile development, on-the-go          |

### Profile Compositions

- **P620 (Workstation)**: developer + desktop-user = Full development workstation
- **Razer (Laptop)**: developer + laptop-user = Mobile development system
- **Samsung (Laptop)**: developer + laptop-user = Mobile development system
- **P510 (Server)**: server-admin + developer = Development-capable media server

## 🤖 Claude Code Integration

Claude Code provides AI-assisted development with specialized skills, commands, and agents for NixOS development.

### Quick Access

```bash
# Get comprehensive help
/nix-help

# Create new module (2 minutes)
/nix-module

# Smart deployment (2.5 minutes)
/nix-deploy

# Auto-fix anti-patterns (1 minute)
/nix-fix

# Security audit (1 minute)
/nix-security

# Code review (1 minute)
/nix-review
```

### Slash Commands (20+)

**Core Commands**:

- `/nix-help` - Complete command reference and documentation
- `/nix-info` - Show system and configuration information
- `/nix-module` - Create new NixOS module with best practices
- `/nix-deploy` - Smart deployment with validation
- `/nix-test` - Run comprehensive tests
- `/nix-validate` - Validate configuration quality

**Development Commands**:

- `/nix-fix` - Auto-fix anti-patterns and issues
- `/nix-review` - Code review against best practices
- `/nix-optimize` - Performance analysis and optimization
- `/nix-clean` - Cleanup and maintenance
- `/nix-secrets` - Secrets management workflows

**Workflow Commands**:

- `/nix-workflow-feature` - Complete feature development (5-10min)
- `/nix-workflow-bugfix` - Bug fix workflow (2-5min)
- `/nix-workflow-security` - Security audit workflow (3-5min)

**Infrastructure Commands**:

- `/nix-microvm` - MicroVM management
- `/nix-live` - Live USB creation
- `/nix-network` - Network diagnostics
- `/nix-precommit` - Pre-commit hook management

**GitHub Integration**:

- `/nix-new-task` - Create GitHub issue with research (2min)
- `/nix-check-tasks` - Review open tasks (30s)

### Skills (16 Specialized)

Skills provide automatic knowledge injection when relevant technologies are mentioned.

**NixOS Tools**:

- **agenix** - Secret management with age encryption
- **home-manager** - User environment management
- **devenv** - Development environment setup
- **nixcore** - Core NixOS concepts and patterns

**Package Integration**:

- **cargo2nix** - Rust package integration
- **node2nix** - Node.js package integration
- **uv2nix** - Python UV package integration

**Desktop Environments**:

- **gnome** - GNOME desktop configuration
- **cosmic-de** - System76 COSMIC desktop
- **hyprland** - Hyprland Wayland compositor
- **niri** - Niri scrollable tiling compositor
- **stylix** - System-wide theming

**Infrastructure**:

- **tailscale** - VPN mesh networking
- **github** - GitHub integration and workflows
- **media** - \*arr stack (Radarr, Sonarr, Lidarr, Prowlarr) (NEW)
- **mangowc** - MangoHud gaming overlay
- **dankms** - DKMS kernel module management

### Agents (6 Specialized)

Agents automatically activate based on your request context:

- **deployment-coordinator** - Intelligent multi-host deployment orchestration (NEW)
- **issue-checker** - GitHub issue analysis and task tracking
- **local-logs** - System log parsing and analysis
- **nix-check** - Configuration validation and testing
- **security-patrol** - Proactive security monitoring and hardening (NEW)
- **update** - Package update management and review

### Built-in Agents

Claude Code also provides built-in agents:

- **nixos-pro** - NixOS development and optimization
- **code-reviewer** - Code review against best practices
- **debugger** - Error analysis and debugging
- **security-auditor** - Security vulnerability detection

## ⚡ Justfile Commands (140+)

The Justfile provides 140+ automation commands organized by category.

### Quick Commands

```bash
just                    # Show all available commands
just help-extended      # Show extended help with examples
just default           # Display categorized commands
```

### Building & Testing (25 commands)

**Basic Testing**:

```bash
just check-syntax                  # Check Nix syntax (5s)
just validate-quick                # Quick validation (30s)
just validate                      # Comprehensive validation (2min)
just validate-quality              # Quality checks with documentation
just test-host p620                # Test specific host (60s)
just test-all                      # Test all hosts sequentially
just test-all-parallel             # Test all hosts in parallel (FASTER)
```

**Advanced Testing**:

```bash
just test-modules                  # Test all modules
just test-module MODULE            # Test specific module
just test-packages                 # Test package builds
just test-home                     # Test Home Manager configs
just test-home-user USER HOST      # Test specific user config
just test-microvm vm               # Test MicroVM configuration
just test-rollback                 # Test rollback capability
just test-secrets                  # Test secret decryption
```

**CI/CD Pipeline**:

```bash
just ci                            # Full CI/CD pipeline
just ci-quick                      # Quick CI tests
just ci-hosts "p620 razer"         # Test specific hosts
just ci-custom JOBS=4 TIMEOUT=600  # Custom CI settings
```

### Deployment (30 commands)

**Basic Deployment**:

```bash
just deploy                        # Deploy to local system
just p620                          # Deploy to P620 workstation
just p510                          # Deploy to P510 server
just razer                         # Deploy to Razer laptop
just samsung                       # Deploy to Samsung laptop
```

**Smart Deployment**:

```bash
just quick-deploy p620             # Only deploy if changed (30s)
just quick-all                     # Test + deploy all if tests pass
just deploy-smart p620             # Smart deployment with validation
just deploy-cached p620            # Use binary cache optimization
just deploy-fast p620              # Fast deployment (minimal builds)
just emergency-deploy p620         # Skip tests (USE WITH CAUTION)
```

**Bulk Deployment**:

```bash
just deploy-all                    # Deploy to all hosts sequentially
just deploy-all-parallel           # Deploy to all hosts in parallel (FASTEST)
just deploy-interactive            # Interactive host selector
```

**Advanced Deployment**:

```bash
just deploy-local-build p620       # Build locally, deploy remotely
just pre-deploy p620               # Pre-deployment checks
just diff p620                     # Show configuration diff
just dry-run p620                  # See what would change
```

### MicroVM Management (15 commands)

**VM Operations**:

```bash
just start-microvm dev-vm          # Start development VM
just stop-microvm dev-vm           # Stop VM
just restart-microvm dev-vm        # Restart VM
just ssh-microvm dev-vm            # SSH into VM
just rebuild-microvm dev-vm        # Rebuild and restart
```

**VM Management**:

```bash
just list-microvms                 # Show all VM status
just stop-all-microvms             # Stop all VMs
just clean-microvms                # Clean VM artifacts
just test-all-microvms             # Test all VM configs
just microvm-help                  # Show MicroVM help
```

**Available VMs**:

- `dev-vm` - Complete development stack (SSH port 2222)
- `test-vm` - Minimal testing environment (SSH port 2223)
- `playground-vm` - Advanced DevOps tools (SSH port 2224)

### Live USB Creation (8 commands)

```bash
just build-live p620               # Build P620 installer
just build-all-live                # Build all installers
just show-devices                  # Find USB devices
just flash-live p620 /dev/sdX      # Flash to USB (DANGEROUS)
just test-live-config p620         # Test live config
just test-hw-config p620           # Test hardware parser
just clean-live                    # Clean build artifacts
just live-help                     # Show live USB help
```

### Secrets Management (8 commands)

```bash
just secrets                       # Interactive secrets manager
just secrets-status                # Check all secrets
just secrets-status-host p620      # Check host-specific secrets
just test-secrets                  # Test secret decryption
just test-all-secrets              # Test all secrets
just fix-agenix-remote p620        # Fix remote agenix issues
```

### Maintenance & Cleanup (12 commands)

**Garbage Collection**:

```bash
just cleanup                       # Clean old generations (keep 7)
just cleanup 30                    # Keep 30 days of generations
just gc                            # Standard garbage collection
just gc-aggressive                 # Remove all old generations
just full-cleanup                  # Complete cleanup with metrics
```

**Optimization**:

```bash
just optimize                      # Optimize nix store
just clean-all                     # Clean everything (DESTRUCTIVE)
just clean-dead-code               # Remove dead code (CAREFUL)
just pre-commit-clean              # Clean pre-commit cache
```

### Performance Testing (10 commands)

```bash
just perf-test                     # Comprehensive performance tests
just perf-build-times              # Test build times
just perf-eval                     # Test evaluation performance
just perf-memory                   # Test memory usage
just perf-parallel                 # Test parallel efficiency
just perf-cache                    # Test cache performance
just bench-host p620               # Benchmark specific host
```

### Analysis & Debugging (15 commands)

**Configuration Analysis**:

```bash
just analyze p620                  # Analyze config size
just analyze-config                # Find dead code and duplicates
just check-deprecated              # Find deprecated options
just efficiency-report             # Show efficiency metrics
just summary                       # Configuration summary
```

**Status & Monitoring**:

```bash
just status                        # System health status
just status-all                    # All hosts status
just network-check                 # Check network stability
just network-monitor               # Monitor network
just ping-hosts                    # Test all hosts reachable
```

**Debugging**:

```bash
just debug-module p620 MODULE      # Debug module evaluation
just trace-option p620 OPTION      # Trace option evaluation
just show-build p620               # Show what would be built
just show-diff p620                # Show build diff
just show-drv PACKAGE              # Show package derivation
```

### Updates & Maintenance (10 commands)

```bash
just update                        # Update local system
just update-flake                  # Update flake inputs
just update-input nixpkgs          # Update specific input
just update-workflow p620          # Complete update workflow
just preview-updates p620          # Preview package changes
just check-updates                 # Check available updates
just new-packages                  # Find newly added packages
```

### Development Tools (12 commands)

**Code Quality**:

```bash
just format                        # Format all Nix files
just format-all                    # Format with pre-commit
just format-path PATH              # Format specific path
just lint-all                      # Lint all files
just security-scan                 # Security scan
```

**Pre-commit Hooks**:

```bash
just pre-commit-install            # Install hooks
just pre-commit-run                # Run all hooks
just pre-commit-staged             # Run on staged files
just pre-commit-hook HOOK          # Run specific hook
just pre-commit-update             # Update hook versions
```

**Development Environment**:

```bash
just dev-shell                     # Enter dev shell
just repl                          # Open Nix REPL
```

### Utilities (10 commands)

```bash
just backup                        # Create configuration backup
just restore BACKUP_PATH           # Restore from backup
just history                       # View generation history
just info                          # Show flake info
just metadata                      # Show flake metadata
just docs                          # Export documentation
just create-host HOST TYPE         # Create new host config
just watch                         # Watch and auto-test
```

## 🎨 Feature System

The configuration uses feature flags for granular control over system functionality.

### Example Configuration

```nix
features = {
  # Development tools
  development = {
    enable = true;
    languages = {
      python = true;
      nodejs = true;
      go = true;
      rust = true;
    };
    docker = true;
    kubernetes = false;
  };

  # Desktop environment
  desktop = {
    enable = true;
    environment = "hyprland";  # or "plasma", "gnome"
    gaming = true;
    multimedia = true;
  };

  # Virtualization
  virtualization = {
    enable = true;
    docker = true;
    libvirt = true;
    microvm = true;
  };

  # AI integration
  ai = {
    enable = true;
    ollama = true;
    providers = {
      enable = true;
      defaultProvider = "anthropic";
      enableFallback = true;
      openai.enable = true;
      anthropic.enable = true;
      gemini.enable = true;
    };
  };

  # Media server (P510)
  media = {
    enable = true;
    radarr = true;    # Movies
    sonarr = true;    # TV series
    lidarr = true;    # Music
    prowlarr = true;  # Indexer manager
    plex = true;      # Media server
    nzbget = true;    # Usenet downloader
    transmission = true;  # Torrent client
  };
};
```

## 🔐 Secrets Management

### Agenix Integration

```bash
# Interactive management
just secrets

# Common operations
./scripts/manage-secrets.sh create SECRET_NAME
./scripts/manage-secrets.sh edit SECRET_NAME
./scripts/manage-secrets.sh rekey
./scripts/manage-secrets.sh status
```

### Secret Organization

- **User passwords**: `user-password-USERNAME.age`
- **API keys**: `api-SERVICE-NAME.age`
- **Certificates**: `cert-DOMAIN-NAME.age`
- **Database credentials**: `db-SERVICE-NAME.age`

### Security Best Practices

```nix
# ❌ WRONG - Evaluation time (secrets in Nix store)
services.myapp.password = builtins.readFile "/secrets/password";

# ✅ CORRECT - Runtime loading (secure)
services.myapp.passwordFile = config.age.secrets.password.path;
```

## 📚 Documentation

### Essential Reading

**Before writing any code**, always consult:

1. **[docs/PATTERNS.md](./docs/PATTERNS.md)** - Comprehensive best practices
   - Module system patterns
   - Package writing patterns
   - Security patterns
   - Performance patterns

2. **[docs/NIXOS-ANTI-PATTERNS.md](./docs/NIXOS-ANTI-PATTERNS.md)** - Critical anti-patterns to avoid
   - The `mkIf true` anti-pattern
   - Security anti-patterns
   - Performance anti-patterns
   - Module system anti-patterns

### Claude Code Documentation

- **[.claude/CLAUDE.md](./.claude/CLAUDE.md)** - Claude Code project guide
- **[.claude/commands/](./.claude/commands/)** - Slash command documentation
- **[.claude/skills/](./.claude/skills/)** - Skill reference guides
- **[.claude/agents/](./.claude/agents/)** - Agent capabilities

## 🚀 Quick Workflows

### Feature Development

```bash
# Using Claude Code (RECOMMENDED)
/nix-workflow-feature

# Manual workflow
/nix-new-task              # Create GitHub issue
/nix-module                # Create module structure
just test-module MODULE    # Test module
/nix-review                # Review code
just quick-deploy HOST     # Deploy if changed
```

### Bug Fix

```bash
# Using Claude Code (RECOMMENDED)
/nix-workflow-bugfix

# Manual workflow
/nix-check-tasks           # Check open issues
just test-host HOST        # Reproduce issue
/nix-fix                   # Auto-fix if possible
/nix-review                # Review fixes
just quick-deploy HOST     # Deploy fix
```

### Security Audit

```bash
# Using Claude Code (RECOMMENDED)
/nix-workflow-security

# Manual workflow
/nix-security              # Run security audit
just security-scan         # System-wide scan
/nix-fix                   # Fix issues
just test-all              # Validate fixes
```

### Daily Development

```bash
# Morning routine
/nix-check-tasks           # Check open tasks
just status                # Check system health
just check-updates         # Check for updates

# Development cycle
/nix-module                # Create modules
just test-host HOST        # Test changes
/nix-review                # Review code
just quick-deploy HOST     # Deploy changes

# End of day
/nix-fix                   # Fix any issues
just full-cleanup          # Clean up
```

## 🏗️ Architecture Benefits

### Quantified Results

| Metric                  | Before     | After      | Improvement |
| ----------------------- | ---------- | ---------- | ----------- |
| Code Deduplication      | 30% shared | 95% shared | +317%       |
| Host Configuration Size | 500 lines  | 50 lines   | -90%        |
| User Configuration Size | 300 lines  | 100 lines  | -67%        |
| Total Lines of Code     | 4,000      | 1,200      | -70%        |
| Anti-Patterns           | 15+        | 0          | -100%       |
| Deployment Time         | 5 min      | 30 sec     | -90%        |

### Maintenance Benefits

- ✅ **Single point updates** through template changes
- ✅ **Consistent behavior** across similar host types
- ✅ **Easy testing** through template validation
- ✅ **Simple additions** with minimal unique configuration
- ✅ **Systematic conflict resolution** patterns
- ✅ **AI-assisted development** with Claude Code
- ✅ **140+ automation commands** via Justfile

### Scalability Benefits

- ✅ **Easy host additions** through templates
- ✅ **Simple user role creation** through profiles
- ✅ **Mix-and-match compositions** for custom use cases
- ✅ **Scales to dozens of hosts** and user types
- ✅ **Zero technical debt** with anti-pattern elimination
- ✅ **Automated workflows** for common operations

## 🛠️ Advanced Features

### Media Server Stack (P510)

Complete \*arr stack for media automation:

```nix
features.media = {
  enable = true;
  radarr = true;      # Movie collection manager
  sonarr = true;      # TV series manager
  lidarr = true;      # Music manager
  prowlarr = true;    # Indexer manager
  plex = true;        # Media server
  nzbget = true;      # Usenet downloads
  transmission = true; # Torrent downloads
};
```

**Access**:

- Radarr: `http://p510:7878`
- Sonarr: `http://p510:8989`
- Lidarr: `http://p510:8686`
- Prowlarr: `http://p510:9696`
- Plex: `http://p510:32400/web`

See `.claude/skills/media.md` for complete documentation.

### AI Provider System

Multi-provider AI integration with automatic fallback:

```bash
# Main AI interface
ai-cli "your question"
ai-cli -p anthropic "specific question"
ai-cli -p ollama "local question"

# Provider management
ai-cli --status
ai-cli --list-providers
ai-switch anthropic
```

**Supported Providers**:

- Anthropic Claude (default)
- OpenAI GPT
- Google Gemini
- Ollama (local inference)

### MicroVM Development Environments

Lightweight virtualization for development:

```bash
# Start VMs
just start-microvm dev-vm        # Development stack
just start-microvm test-vm       # Testing environment
just start-microvm playground-vm # DevOps sandbox

# SSH access
just ssh-microvm dev-vm
# Or: ssh dev@localhost -p 2222
```

### Live USB Installers

Hardware-specific installation media:

```bash
# Build installer
just build-live p620

# Flash to USB
just show-devices
just flash-live p620 /dev/sdX

# Boot and install
sudo install-p620
```

## 🔧 Troubleshooting

### Build Failures

```bash
just check-syntax           # Syntax validation
just test-host p620         # Test specific host
nix flake check --show-trace # Detailed errors
```

### Deployment Issues

```bash
just diff p620              # Show config changes
just dry-run p620           # Preview changes
just emergency-deploy p620  # Skip tests (careful!)
```

### Performance Problems

```bash
just perf-test              # Run benchmarks
just analyze p620           # Analyze configuration
just efficiency-report      # Show metrics
```

### Secrets Issues

```bash
just secrets-status         # Check all secrets
just test-secrets           # Test decryption
just secrets                # Interactive manager
```

### Claude Code Issues

```bash
/nix-help                   # Get help
/nix-info                   # Show system info
/nix-validate               # Validate setup
```

## 📖 Learning Resources

### Getting Started

1. **Read**: [docs/PATTERNS.md](./docs/PATTERNS.md) - Best practices
2. **Review**: [docs/NIXOS-ANTI-PATTERNS.md](./docs/NIXOS-ANTI-PATTERNS.md) - What to avoid
3. **Explore**: [.claude/CLAUDE.md](./.claude/CLAUDE.md) - Claude Code guide
4. **Try**: `/nix-help` - Interactive help

### Workflow Guides

1. **Feature Development**: `/nix-workflow-feature` - Complete guided process
2. **Bug Fixes**: `/nix-workflow-bugfix` - Systematic debugging
3. **Security**: `/nix-workflow-security` - Security audit workflow

### Skills Documentation

Explore `.claude/skills/` for in-depth guides on:

- agenix (secrets), home-manager (users), devenv (development)
- cargo2nix (Rust), node2nix (Node.js), uv2nix (Python)
- gnome, hyprland, niri, cosmic-de (desktop environments)
- tailscale (VPN), github (workflows), **media (\*arr stack)**

## 🤝 Contributing

### Development Standards

1. **Read documentation first** (PATTERNS.md and NIXOS-ANTI-PATTERNS.md)
2. **Use Claude Code** for guided workflows (`/nix-workflow-*`)
3. **Test thoroughly** (`just test-all`)
4. **Review code** (`/nix-review`)
5. **Fix anti-patterns** (`/nix-fix`)
6. **Create GitHub issues** (`/nix-new-task`)
7. **Track progress** (`/nix-check-tasks`)

### Quality Requirements

- ✅ All syntax must validate (`just check-syntax`)
- ✅ Quality checks must pass (`just validate-quality`)
- ✅ Build tests must succeed (`just test-all`)
- ✅ No anti-patterns (`/nix-fix` and manual review)
- ✅ Security hardening applied (`/nix-security`)
- ✅ Documentation complete for new features

## 📊 Project Status

### Current Phase

**Phase 8.1**: NixOS Best Practices Implementation - **COMPLETED** ✅

### Recent Accomplishments

- ✅ Zero anti-patterns across entire codebase
- ✅ 95% code deduplication through templates
- ✅ 165 lines removed through proper abstractions
- ✅ Complete Claude Code integration (16 skills, 20+ commands, 4 agents)
- ✅ 140+ Justfile automation commands
- ✅ Media management skill for \*arr stack
- ✅ Security hardening with DynamicUser and systemd features
- ✅ Comprehensive documentation (PATTERNS.md, ANTI-PATTERNS.md)

### Active Development

See [.agent-os/product/roadmap.md](./.agent-os/product/roadmap.md) for detailed roadmap.

## 📞 Support

### Getting Help

- **Claude Code**: `/nix-help` - Interactive help system
- **Justfile**: `just help-extended` - Extended command help
- **Documentation**: See `docs/` directory
- **Skills**: See `.claude/skills/` for technology guides

### Quick References

```bash
# Command lists
just --list                 # All Justfile commands
/nix-help                   # All Claude Code commands
/nix-help skills           # Available skills
/nix-help agents           # Available agents

# Status and info
just status                 # System status
/nix-info                   # Configuration info
just efficiency-report      # Metrics
```

## 📝 License

See repository for license information.

---

**Built with**: NixOS, Flakes, Home Manager, Agenix, Claude Code
**Architecture**: Template-based, modular, zero anti-patterns
**Automation**: 140+ Justfile commands, 20+ Claude Code workflows
**Integration**: 16 skills, 4 agents, comprehensive AI assistance

> **Fast, Easy, Reliable** - The modern way to manage NixOS infrastructure
