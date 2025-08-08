# NixOS Infrastructure Hub

[![Modern Flake Architecture](https://img.shields.io/badge/Flake-Modern%20Architecture-blue?style=flat-square&logo=nixos)](https://nixos.org)
[![Comprehensive Validation](https://img.shields.io/badge/Quality-10%20Validation%20Checks-green?style=flat-square)](./checks)
[![Development Shells](https://img.shields.io/badge/DevShells-3%20Environments-orange?style=flat-square)](./shells)
[![Production Ready](https://img.shields.io/badge/Status-Production%20Ready-success?style=flat-square)](#current-status)

A sophisticated, enterprise-grade NixOS configuration management system with advanced automation, monitoring, AI integration,
and development environments. Built using **modern flake architecture** with comprehensive validation, quality assurance,
and production-ready standards.

## Modern Flake Architecture ⭐

This configuration features a **modern, enterprise-grade flake architecture** with structured outputs, comprehensive validation,
and advanced developer experience:

```bash
nixos/                                    # NixOS Configuration Repository
├── .agent-os/                           # Agent OS Product Documentation
│   └── product/                         # Product mission, roadmap, decisions
├── flake.nix                           # Main Flake Configuration
├── flake.lock                          # Flake Dependencies Lock
├── README.md                           # Documentation (This File)
├── justfile                            # Task Automation and Commands
│
├── apps/                               # ⭐ NEW: Application Workflow Tools
│   └── default.nix                     # Deploy, test, build-live, dev-utils apps
│
├── checks/                             # ⭐ NEW: Quality Assurance & Validation
│   └── default.nix                     # 10 comprehensive validation checks
│
├── shells/                             # ⭐ NEW: Development Shell Environments
│   ├── dev.nix                        # Primary development environment
│   ├── testing.nix                    # Testing and validation environment
│   └── docs.nix                       # Documentation generation environment
│
├── lib/                                # ⭐ NEW: Helper Libraries & Utilities
│   └── default.nix                     # Shared functions and utilities
│
├── hosts/                              # Host-Specific Configurations
│   ├── p620/                          # AMD Workstation (Primary Development)
│   ├── p510/                          # Intel Xeon Server (Media & Storage)
│   ├── razer/                         # Intel/NVIDIA Laptop (Mobile)
│   ├── dex5550/                       # Intel SFF (Monitoring Server)
│   ├── samsung/                       # Samsung Laptop (Secondary)
│   └── common/                        # Shared host configurations
│
├── modules/                           # Modular NixOS System Components (141+ modules)
│   ├── ai/                           # AI Provider Integration
│   ├── desktop/                      # Desktop Environment Modules
│   ├── development/                  # Development Tools & Languages
│   ├── monitoring/                   # Prometheus/Grafana Stack
│   ├── networking/                   # Network Configuration
│   ├── security/                     # Security & Hardening
│   ├── services/                     # System Services
│   ├── virtualization/               # Container & VM Support
│   └── [additional categories]       # 15+ other module categories
│
├── home/                             # Home Manager Configurations
│   ├── desktop/                      # Desktop Environment Settings
│   ├── development/                  # Development Tools Configuration
│   ├── shell/                        # Shell & Terminal Configuration
│   └── [additional categories]       # Media, network, etc.
│
├── Users/                            # Per-User Configurations
│   ├── olafkfreund/                  # Primary user configurations
│   │   ├── p620_home.nix            # P620-specific home config
│   │   ├── p510_home.nix            # P510-specific home config
│   │   └── [other hosts]            # Other host-specific configs
│   └── [other users]/               # Additional user configurations
│
├── secrets/                          # Encrypted Secrets (Agenix)
│   ├── secrets.nix                   # Secret definitions and access
│   └── *.age                        # Encrypted secret files
│
├── scripts/                          # Automation & Management Scripts
│   ├── install-helpers/             # Live USB installation wizards
│   ├── manage-secrets.sh            # Interactive secrets management
│   └── [utility scripts]           # Additional automation tools
│
├── pkgs/                            # Custom Package Definitions
│   ├── gemini-cli/                  # Custom Gemini CLI package
│   └── [other packages]            # Additional custom packages
│
├── templates/                       # Configuration Templates
│   ├── hosts/                       # Host template configurations
│   └── modules/                     # Module template structures
│
└── [additional directories]         # Icons, themes, documentation, etc.
```

### Key Features

#### 🏗️ **Modern Flake Architecture**

- **Structured outputs** with devShells, checks, apps, and nixosModules
- **3 specialized development environments** (dev, testing, docs)
- **10 comprehensive validation checks** for quality assurance
- **4 application workflow tools** for deployment and management
- **Advanced developer experience** with modern Nix tooling

#### 🖥️ **Infrastructure Management**

- **Multi-host support** with hardware-specific optimizations
- **141+ optimized modules** with comprehensive validation
- **Feature flag system** for granular control
- **Automated secrets management** with Agenix
- **Performance optimizations** for different hardware profiles

#### 🔍 **Quality & Validation**

- **Quality validation framework** with automated testing
- **CI/CD pipeline** with automated testing and validation
- **Dead code elimination** and performance optimization
- **Comprehensive documentation** and templates
- **Enterprise-grade reliability** and production readiness

## Quick Start

### Prerequisites

- NixOS installed with flakes enabled
- Git configured with your credentials
- Basic understanding of Nix/NixOS

### Initial Setup

1. **Clone the repository:**

   ```bash
   git clone https://github.com/olafkfreund/nixos_config.git
   cd nixos_config
   ```

2. **Install just command runner:**

   ```bash
   nix profile install nixpkgs#just
   ```

3. **View available commands:**

   ```bash
   just --list
   ```

4. **Validate the configuration:**

   ```bash
   just validate
   ```

5. **Deploy to your system:**

   ```bash
   just deploy
   ```

6. **Try the AI-enhanced task management:**

   ```bash
   # Beautiful AI dashboard with insights
   ai-dashboard

   # Smart task creation from natural language
   smart-add "Set up development environment, review code, deploy by Friday"

   # Get AI-powered task analysis
   ai-analyze
   ```

## Modern Flake Commands ⚡

The modern flake architecture provides structured access to all development tools and workflows:

### Development Environments

Enter specialized development environments with all necessary tools pre-installed:

```bash
# Primary development environment (nixd, statix, pre-commit, etc.)
nix develop

# Testing and validation environment (VM testing, networking tools)
nix develop .#testing

# Documentation environment (mdbook, graphviz, pandoc)
nix develop .#docs
```

### Quality Assurance & Validation

Run comprehensive quality checks with the validation system:

```bash
# Run all 10 validation checks
nix flake check

# Run specific validation checks
nix build .#checks.x86_64-linux.statix-lint
nix build .#checks.x86_64-linux.host-build-validation
nix build .#checks.x86_64-linux.security-check

# View available checks
nix eval .#checks.x86_64-linux --apply builtins.attrNames
```

### Application Workflow Tools

Use integrated workflow applications for common operations:

```bash
# Deployment workflows
nix run .#deploy -- host p620          # Deploy to specific host
nix run .#deploy -- all               # Deploy to all hosts
nix run .#deploy -- parallel          # Parallel deployment

# Testing workflows
nix run .#test -- host p620           # Test specific host
nix run .#test -- all                 # Test all configurations
nix run .#test -- quick               # Quick validation

# Live USB building
nix run .#build-live -- p620          # Build P620 live USB
nix run .#build-live -- all           # Build all live USBs

# Development utilities
nix run .#dev-utils -- lint           # Run linting
nix run .#dev-utils -- format         # Format code
nix run .#dev-utils -- cleanup        # Cleanup build artifacts
```

### Package Building

Build packages and live images:

```bash
# Build custom packages
nix build .#packages.x86_64-linux.gemini-cli
nix build .#packages.x86_64-linux.claude-code

# Build live ISO images
nix build .#packages.x86_64-linux.live-iso-p620
nix build .#packages.x86_64-linux.live-iso-razer
```

### Module Exports

The flake exports modules for reuse in other configurations:

```nix
# Import specific modules in other flakes
inputs.nixos-infrastructure.nixosModules.monitoring
inputs.nixos-infrastructure.nixosModules.ai-providers
inputs.nixos-infrastructure.nixosModules.development
```

## AI-Enhanced Productivity Tools

Revolutionary productivity system integrating Taskwarrior with Claude AI for intelligent task management:

### Core AI Features

- **Smart Task Creation**: Natural language → structured Taskwarrior tasks with context awareness
- **Intelligent Analysis**: Task prioritization and optimization suggestions based on workload
- **Work Summarization**: Professional daily/weekly reports with productivity pattern analysis
- **Context-Aware Workflows**: Git, time, and location-aware task suggestions

### Ready-to-Use Commands

```bash
# Smart task creation from natural language
smart-task "Review PR, update docs, deploy by Friday"
smt "Quick task description"  # Short alias

# Intelligent task analysis and insights
ai-prioritize               # Smart priority recommendations
ai-metrics                  # Performance analysis and trends
ai-context suggest          # AI suggests optimal work context

# Project breakdown and planning
ai-breakdown "Build user authentication system"  # Creates full project plan
ai-review week             # Weekly review with AI insights
ai-find "tasks related to documentation"  # Semantic task search

# Smart completion with AI feedback
smart-complete 1           # Complete task with AI motivation
smart-done 15             # Alternative completion command
```

### Productivity Workflows

```bash
# Morning routine (automated sequence)
morning    # Context suggestions + priority analysis

# Evening review (automated sequence)
evening    # Daily summary + accomplishments + tomorrow planning

# Development workflow example
cd /path/to/project
smart-task "Fix auth bug, add tests, update docs"  # Context-aware task creation
focus                                               # AI suggests work sequence
ai-prioritize                                      # Intelligent priority analysis
smart-complete 1                                   # Complete with AI feedback
```

### Integration

- **AI Provider System**: Uses unified AI infrastructure (Anthropic/OpenAI/Gemini/Ollama)
- **Taskwarrior Enhancement**: Builds on comprehensive Taskwarrior configuration
- **Shell Integration**: ZSH functions, aliases, and tab completion
- **Time Tracking**: Seamless integration with Timewarrior
- **Monitoring**: Task metrics integration with Prometheus/Grafana stack

The AI productivity system is automatically available on all hosts with productivity features enabled.

## Enhanced Hyprland Configuration

Advanced Hyprland window manager configuration with comprehensive keybindings:

**High-Priority Enhancements:**

- **Window Switching**: `ALT + TAB` and `ALT + SHIFT + TAB` for forward/backward window cycling
- **Workspace Navigation**: `SUPER + TAB` for previous workspace (back-and-forth switching)
- **Application Shortcuts**: `SUPER + E` (file manager), `SUPER + V` (clipboard manager), `SUPER + =` (calculator)
- **System Monitoring**: `SUPER + SHIFT + Escape` for system monitor in floating window
- **Quick Lock**: `SUPER + L` for immediate screen lock

**Advanced Features:**

- **Gaming Mode**: `SUPER + CTRL + G` to disable compositor effects for performance
- **Media Controls**: Hardware keys and `SUPER + P` for play/pause, `SUPER + SHIFT + ,/.` for track navigation
- **Window Opacity**: `SUPER + ALT + -/=/0` for transparency control (80%/90%/100%)
- **Manual Tiling**: `SUPER + ALT + h/j/k/l` for preselected split directions
- **Power Management**: `SUPER + SHIFT + End/Delete/Insert` for suspend/poweroff/reboot

**Development Workflow:**

- **Code Editor**: `SUPER + SHIFT + Return` for VS Code
- **Terminal Options**: `SUPER + SHIFT + T` (large floating), `SUPER + CTRL + T` (tmux session)
- **Network Management**: `SUPER + SHIFT + W` for network configuration TUI

**Configuration Location:**

- Main binds: `/home/olafkfreund/.config/nixos/home/desktop/hyprland/config/binds.nix`
- Documentation: `/home/olafkfreund/.config/nixos/docs/Hyprland_config.md`

## Monitoring & Observability

A comprehensive monitoring infrastructure has been deployed:

**Core Services:**

- **Prometheus** (port 9090): Metrics collection and storage with 30-day retention
- **Grafana** (port 3001): Advanced dashboards and visualization
- **Alertmanager** (port 9093): Intelligent alert management and routing
- **Node Exporters** (port 9100): System-level metrics collection

**Custom Exporters:**

- **NixOS Exporter** (port 9101): Nix store, generations, and system-specific metrics
- **Systemd Exporter** (port 9102): Service status and systemd unit monitoring

**Available Dashboards:**

- NixOS System Overview: Comprehensive system health and performance
- Host-specific dashboards: Tailored monitoring for each system (p620-AMD, razer-NVIDIA, etc.)
- Hardware-specific panels: GPU utilization, thermal monitoring, and performance metrics

**Quick Access:**

```bash
# Check monitoring status
grafana-status          # Service status and dashboard count
prometheus-status       # Server metrics and target health
node-exporter-status    # All exporter services status

# Web interfaces
# Grafana: http://p620:3001 (admin/nixos-admin)
# Prometheus: http://p620:9090
# Alertmanager: http://p620:9093
```

## Unified AI Provider System

A sophisticated multi-provider AI interface with automatic fallback:

**Unified Commands:**

```bash
# Main AI interface
ai-cli "your question"                    # Use default provider (Anthropic)
ai-chat "your question"                   # Convenient alias
ai-cli -p anthropic "specific question"   # Provider-specific queries
ai-cli -p ollama "local question"         # Local AI inference

# Provider management
ai-cli --status                          # Show all provider status
ai-cli --list-providers                  # List available providers
ai-cli -p provider --list-models         # List models per provider

# Advanced features
ai-cli -f "question"                     # Enable automatic fallback
ai-cli -c "question"                     # Cost-optimized provider selection
ai-cli -v "question"                     # Verbose debugging output
```

**Supported Providers:**

1. **Anthropic Claude** (Priority 2, Default)
   - Models: claude-3-5-sonnet, claude-3-5-haiku, claude-3-opus
   - Encrypted API key management via agenix

2. **OpenAI** (Priority 1)
   - Models: gpt-4o, gpt-4o-mini, gpt-3.5-turbo
   - Full API integration with encrypted secrets

3. **Google Gemini** (Priority 3)
   - Models: gemini-1.5-pro, gemini-1.5-flash, gemini-2.0-flash-exp
   - Native integration with Google APIs

4. **Ollama Local** (Priority 4)
   - Models: mistral-small3.1, llama3.2, custom models
   - Local inference with ROCm GPU acceleration on P620

**Shell Integration:**

```bash
# Convenient aliases available system-wide
ai "question"              # Quick AI query
chat "question"            # Alternative alias
aii "question"             # Quick default provider
aif "question"             # AI with fallback enabled
aic "question"             # AI with cost optimization
ai-status                  # Check provider status
```

**Features:**

- **Intelligent Fallback**: Automatically tries alternative providers if one fails
- **Cost Optimization**: Smart provider selection based on usage and cost
- **Encrypted Secrets**: All API keys secured with agenix encryption
- **Priority System**: Configurable provider ordering and selection
- **Timeout Management**: Configurable request timeouts and retry logic
- **Comprehensive Logging**: Debug modes for troubleshooting

## MicroVM Development Environments

A comprehensive MicroVM infrastructure using microvm.nix providing lightweight, isolated development environments:

**Three MicroVM Templates:**

1. **Development VM (dev-vm)**
   - **Resources**: 8GB RAM, 4 CPU cores, SSH port 2222
   - **Features**: Complete development stack (Git, Node.js, Python, Go, Rust, Docker)
   - **Storage**: Persistent project directory and shared host storage
   - **Use Cases**: Isolated development, dependency testing, containerized workflows

2. **Testing VM (test-vm)**
   - **Resources**: 8GB RAM, 4 CPU cores, SSH port 2223
   - **Features**: Minimal testing environment with reset capability
   - **Use Cases**: CI/CD testing, integration testing, clean testing cycles

3. **Playground VM (playground-vm)**
   - **Resources**: 8GB RAM, 4 CPU cores, SSH port 2224
   - **Features**: Advanced DevOps tools (Kubernetes, Helm, Ansible, Wireshark)
   - **Use Cases**: System experimentation, network analysis, learning environments

**Management Commands:**

```bash
# VM Lifecycle
just start-microvm dev-vm        # Start development environment
just stop-microvm dev-vm         # Stop specific VM
just restart-microvm dev-vm      # Restart VM
just list-microvms              # Show all VM status

# Access and SSH
just ssh-microvm dev-vm         # SSH into running VM
# Or manually: ssh dev@localhost -p 2222

# Configuration and Testing
just test-microvm dev-vm        # Test VM configuration
just test-all-microvms         # Test all VM configurations
just rebuild-microvm dev-vm     # Rebuild and restart VM

# Maintenance
just clean-microvms            # Clean up VM data (DESTRUCTIVE)
just microvm-help              # Comprehensive help and examples
```

**Key Features:**

- **NAT Networking**: Simple setup with unique SSH ports per VM
- **Shared Storage**: Efficient /nix/store sharing and persistent volumes
- **Resource Allocation**: 8GB RAM and 4 CPU cores per VM (configurable)
- **QEMU Hypervisor**: Hardware acceleration with minimal overhead
- **Host Integration**: Seamless access to host services and shared directories

**Host Configuration:**

```nix
# Enable MicroVMs on any host
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

- **P620**: Available (enable in configuration as needed)
- **Razer**: Available (enable in configuration as needed)
- **P510**: Available for activation
- **DEX5550**: Available for activation

**Quick Start Workflow:**

```bash
# 1. Start development environment
just start-microvm dev-vm

# 2. SSH into the VM
just ssh-microvm dev-vm

# 3. Work on projects (persistent storage)
cd /home/dev/projects
git clone https://github.com/your/project.git

# 4. Stop when done
just stop-microvm dev-vm
```

The MicroVM system provides enterprise-grade virtualization capabilities with minimal overhead, perfect for development, testing, and experimentation workflows.

### Key Fixes Applied

1. **Grafana Dashboard Structure**: Fixed JSON generation for proper dashboard loading
2. **Prometheus Port Conflicts**: Resolved Docker port 3000 conflict by moving Grafana to 3001
3. **Custom Exporter Compatibility**: Replaced problematic netcat with Python HTTP servers
4. **API Key Path Resolution**: Fixed secret paths to use correct agenix locations (`/run/agenix/api-*`)
5. **Service Dependencies**: Optimized service startup order and dependency management

## Using the Justfile

The Justfile provides convenient commands for all operations. It's the primary interface for managing this configuration.

### Available Commands

```bash
just --list  # Show all available commands
```

### Building and Testing

```bash
# Comprehensive validation (recommended)
just validate

# Quick validation (syntax only)
just validate-quick

# Test specific host without deploying
just test-host p620

# Test all hosts for compatibility
just test-all

# Run full CI pipeline
just ci

# Check Nix syntax across all files
just check-syntax

# Format all Nix files consistently
just format

# Performance testing
just perf-test
```

### Deployment Commands

```bash
# Deploy to local system (auto-detects hostname)
just deploy

# Deploy to specific hosts by name
just p620      # AMD workstation with ROCm
just razer     # Intel/NVIDIA laptop with Optimus
just p510      # Intel Xeon/NVIDIA workstation
just samsung   # Intel laptop with integrated graphics
just dex5550   # Intel SFF with efficiency optimizations

# Update system packages
just update

# Update flake inputs to latest versions
just update-flake

# Update specific flake input
just update-input INPUT_NAME
```

### Quality and Maintenance

```bash
# Run quality validation with detailed reporting
just validate-quality

# Full comprehensive validation (all checks)
just validate-full

# Clean up unused store paths and generations
just cleanup

# Module structure validation
just test-modules

# Performance benchmarking
just perf-test
```

## Host Configuration

Each host has a standardized, optimized structure:

### Host Directory Structure

```bash
hosts/hostname/
├── configuration.nix         # Main NixOS configuration
├── variables.nix             # Host-specific variables and features
├── hardware-configuration.nix # Generated hardware config
├── nixos/                    # NixOS-specific modules
│   ├── boot.nix             # Boot and kernel configuration
│   ├── cpu.nix              # CPU-specific optimizations
│   ├── hardware.nix         # Hardware drivers and config
│   └── ...                  # Other system-level configs
└── themes/                   # Styling and themes
    └── stylix.nix           # Unified styling configuration
```

### Adding a New Host

1. **Create host directory:**

   ```bash
   mkdir hosts/newhostname
   ```

2. **Use configuration templates:**

   ```bash
   cp templates/configuration.nix.template hosts/newhostname/configuration.nix
   cp templates/variables.nix.template hosts/newhostname/variables.nix
   ```

3. **Generate hardware configuration:**

   ```bash
   nixos-generate-config --dir /tmp/nixos-config
   cp /tmp/nixos-config/hardware-configuration.nix hosts/newhostname/
   ```

4. **Configure host variables:**

   ```nix
   # hosts/newhostname/variables.nix
   {
     # Host identification
     hostName = "newhostname";

     # Users on this host
     hostUsers = ["username"];

     # Hardware profile
     hardwareProfile = "desktop"; # or "laptop", "server"

     # Feature flags for granular control
     features = {
       development = {
         enable = true;
         python = true;
         nodejs = true;
         docker = true;
       };
       desktop = {
         enable = true;
         hyprland = true;
         plasma = false;
       };
       gaming.enable = false;
       ai = {
         enable = true;
         ollama = true;
       };
     };
   }
   ```

5. **Add to flake.nix:**

   ```nix
   nixosConfigurations = {
     # ... existing hosts
     newhostname = nixpkgs.lib.nixosSystem (makeNixosSystem "newhostname");
   };
   ```

6. **Test and validate:**

   ```bash
   just test-host newhostname
   just validate
   ```

## User Management

### User Configuration Structure

```bash
Users/username/
├── common/                   # Shared user configuration
├── hostname_home.nix         # Host-specific home configuration
└── features.nix             # User-specific feature overrides
```

### Adding a New User

1. **Create user directory structure:**

   ```bash
   mkdir -p Users/newuser/common
   ```

2. **Create base user configuration:**

   ```nix
   # Users/newuser/common/default.nix
   { config, lib, pkgs, ... }: {
     home = {
       username = "newuser";
       homeDirectory = "/home/newuser";
       stateVersion = "24.11";
     };

     # Import common configurations
     imports = [
       ../../../home/desktop
       ../../../home/development
       ../../../home/shell
     ];

     # User-specific package customizations
     home.packages = with pkgs; [
       # Additional user-specific packages
     ];
   }
   ```

3. **Create host-specific configurations:**

   ```bash
   # For each host the user will use
   cp templates/user_home.nix.template Users/newuser/hostname_home.nix
   ```

4. **Generate SSH key and add to secrets:**

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/newuser_key -N ""

   # Add public key to secrets.nix
   nano secrets.nix
   ```

5. **Create user password secret:**

   ```bash
   ./scripts/manage-secrets.sh create user-password-newuser
   ```

6. **Add user to host variables:**

   ```nix
   # hosts/hostname/variables.nix
   hostUsers = ["existinguser" "newuser"];
   ```

7. **Test and deploy:**

   ```bash
   just test-host hostname
   just deploy
   ```

## Module System

### Module Categories

The configuration includes 141+ optimized modules organized by function:

- **`modules/ai/`** - Unified AI provider system with multi-provider support
- **`modules/monitoring/`** - Comprehensive observability stack (Prometheus, Grafana, Alertmanager)
- **`modules/desktop/`** - Desktop environment components and applications
- **`modules/development/`** - Development tools, languages, and environments
- **`modules/services/`** - System services, daemons, and network services
- **`modules/security/`** - Security tools, hardening, and secrets management
- **`modules/containers/`** - Container runtimes (Docker, Podman, Kubernetes)
- **`modules/cloud/`** - Cloud provider tools (AWS, Azure, GCP, Terraform)
- **`modules/packages/`** - Organized package sets for performance
- **`modules/system/`** - Performance optimizations and system tuning

### Creating a New Module

1. **Use the standardized module template:**

   ```bash
   cp modules/TEMPLATE.nix modules/category/newmodule.nix
   ```

2. **Follow the established pattern:**

   ```nix
   # modules/category/newmodule.nix
   {
     config,
     lib,
     pkgs,
     ...
   }:
   with lib; let
     cfg = config.modules.category.newmodule;
   in {
     options.modules.category.newmodule = {
       enable = mkEnableOption "comprehensive description of module functionality";

       # Organized option groups
       packages = {
         core = mkOption {
           type = types.bool;
           default = true;
           description = ''Enable core functionality packages'';
           example = false;
         };
       };

       # Configuration options with examples
       settings = mkOption {
         type = types.attrsOf types.str;
         default = {};
         description = ''Configuration settings for the module'';
         example = { setting1 = "value1"; };
       };
     };

     config = mkIf cfg.enable {
       # Conditional implementation
       environment.systemPackages = with pkgs;
         optionals cfg.packages.core [
           # Core packages
         ];

       # Always include validation
       assertions = [
         {
           assertion = cfg.packages.core -> (cfg.settings != {});
           message = "Core packages require configuration settings";
         }
       ];

       # Helpful warnings for users
       warnings = [
         (mkIf (!cfg.packages.core) ''
           Module is enabled but core packages are disabled.
           Consider enabling core packages for full functionality.
         '')
       ];
     };
   }
   ```

3. **Add to module imports:**

   ```nix
   # modules/category/default.nix
   {
     imports = [
       ./existing-module.nix
       ./newmodule.nix  # Add your new module
     ];
   }
   ```

4. **Create comprehensive documentation:**

   ```bash
   cp modules/MODULE_README_TEMPLATE.md modules/category/README.md
   # Edit with module-specific information
   ```

5. **Test and validate:**

   ```bash
   just check-syntax
   just test-modules
   just validate-quality
   ```

### Module Best Practices

- **Always use enable options** for conditional functionality
- **Include comprehensive assertions** for configuration validation
- **Provide helpful warnings** for common misconfigurations
- **Add detailed examples** in option descriptions
- **Follow naming conventions** (`modules.category.name`)
- **Document complex modules** with README files
- **Use organized option groups** for related settings
- **Implement proper error handling** with meaningful messages

## Feature System

The configuration uses an advanced feature flag system for granular control:

### Feature Categories and Structure

```nix
features = {
  development = {
    enable = true;      # Master enable for development tools
    python = true;      # Python development environment
    nodejs = true;      # Node.js and npm tools
    go = true;         # Go development tools
    docker = true;     # Container development
    github = true;     # GitHub CLI and tools
  };

  desktop = {
    enable = true;      # Desktop environment
    hyprland = true;    # Hyprland window manager
    plasma = false;     # KDE Plasma (alternative)
    applications = true; # Desktop applications
  };

  virtualization = {
    enable = true;      # Virtualization support
    docker = true;      # Docker containers
    libvirt = true;     # KVM/QEMU virtualization
    incus = false;      # Incus containers
  };

  gaming = {
    enable = false;     # Gaming support
    steam = false;      # Steam client
  };

  ai = {
    enable = true;      # AI tools and services
    ollama = true;      # Local AI models

    # Unified AI provider support
    providers = {
      enable = true;           # Enable unified AI provider system
      defaultProvider = "anthropic";  # Default provider to use
      enableFallback = true;   # Automatic fallback between providers

      # Individual provider support
      openai.enable = true;    # OpenAI ChatGPT/GPT models
      anthropic.enable = true; # Anthropic Claude models
      gemini.enable = true;    # Google Gemini models
      ollama.enable = true;    # Local Ollama models
    };
  };

  monitoring = {
    enable = true;      # Monitoring and observability
    mode = "server";    # server|client|standalone
    serverHost = "p620"; # Monitoring server hostname

    features = {
      nodeExporter = true;   # System metrics collection
      nixosMetrics = true;   # NixOS-specific metrics
      alerting = true;       # Alert management
    };
  };

  security = {
    enable = true;      # Security tools
    onepassword = true; # 1Password integration
    gnupg = true;       # GnuPG encryption
  };
};
```

### Using Features in Configuration

1. **Host-level configuration:**

   ```nix
   # hosts/hostname/variables.nix
   features = {
     development.enable = true;
     desktop.enable = true;
     gaming.enable = false;  # Disable gaming on work machines
   };
   ```

2. **User-level overrides:**

   ```nix
   # Users/username/features.nix
   {
     # Override host defaults for this user
     features.gaming.enable = true;
     features.ai.chatgpt = false;
   }
   ```

3. **Conditional module loading:**

   ```nix
   # Modules automatically respect feature flags
   config = mkIf config.features.development.enable {
     # Development-specific configuration
   };
   ```

## Enhanced Shell Environment

### Comprehensive Terminal Experience

This configuration provides a modern, high-performance shell environment with seamless integration across all components:

#### Enhanced Zsh Configuration (`home/shell/zsh.nix`)

**Modern Performance Features:**

- 50,000 command history with intelligent deduplication
- Smart completion caching for faster startup
- Performance-optimized plugin loading with lazy initialization
- Enhanced syntax highlighting with Gruvbox theme colors

**AI Integration:**

- GitHub Copilot integration (`Alt+\` for suggestions, `Alt+Shift+\` for explanations)
- AIChat integration (`Alt+E` for command enhancement)
- Smart command completion and enhancement

**Developer Productivity:**

- Modern keybindings (Ctrl+Arrow for word navigation, Ctrl+F for session manager)
- Enhanced fzf-tab integration with file previews
- Smart directory navigation with zoxide
- Git-aware prompt and completions

#### Enhanced Starship Prompt (`home/shell/starship/default.nix`)

**Rich Information Display:**

- Command duration for performance awareness (shows for commands >1s)
- Comprehensive Git status with branch, commits, and file states
- Development context (Nix shells, containers, cloud environments)
- Hardware-aware icons and consistent Gruvbox theming

#### Enhanced Tmux Configuration (`home/shell/tmux/default.nix`)

**Modern Performance:**

- Zero escape time and aggressive resizing for responsiveness
- 50,000 line history with enhanced scrollback
- True color support for all modern terminals
- Focus events and clipboard integration

**Vim-Style Navigation:**

- `hjkl` pane navigation with `Alt+hjkl` prefix-free navigation
- `HJKL` pane resizing and `Alt+1-5` quick window access
- Smart pane splitting (`|` vertical, `-` horizontal)
- Intelligent session management with project detection

**Developer Productivity:**

- **Tilish**: i3/sway-like tiling window management
- **tmux-thumbs**: Quick text copying with hint mode
- **extrakto**: Enhanced text extraction from terminal output
- **Enhanced Session Manager**: Smart project detection with fuzzy selection

#### Enhanced Zellij Configuration (`home/shell/zellij/default.nix`)

**Modern Alternative to Tmux:**

- Vim-style keybindings consistent with tmux
- Built-in session management and file browsing
- Smart layouts for development workflows
- Gruvbox theming matching the ecosystem

**Productivity Features:**

- **Development Layout**: 70% editor, 30% terminal, 25% logs
- **File Manager Integration**: Built-in strider file manager
- **Session Management**: Advanced session handling with persistence
- **Smart Keybindings**: Intuitive navigation and window management

#### Key Features and Integrations

**Consistent Theming:**

- Gruvbox Dark theme across all components
- Consistent icons and color schemes
- Modern Nerd Font integration

**Smart Aliases and Commands:**

```bash
# Git enhancements
gc="git commit -v"           # Verbose commits
gl="git log --oneline --graph --decorate"  # Beautiful git log

# Modern tool replacements
ezals="eza --header --git --classify --long --icons"  # Enhanced ls
fzfpreview="fzf --preview 'bat --color=always --line-range :50 {}'"
aiexplain="aichat --role explain"  # AI command explanation

# Multiplexer shortcuts
zj="zellij"                  # Quick zellij access
tmux-sessionizer             # Smart project session management
```

**Integration Points:**

- **Claude Code**: Full integration with enhanced terminal features
- **Modern Tools**: bat, eza, ripgrep, fd, zoxide, atuin
- **Development**: Language servers, formatters, and debugging tools
- **Cloud/DevOps**: AWS, Azure, Terraform, Kubernetes integration

#### Documentation

Detailed documentation for each component:

- [`home/shell/zsh/README.md`](home/shell/zsh/README.md) - Zsh configuration guide
- [`home/shell/tmux/README.md`](home/shell/tmux/README.md) - Tmux setup and keybindings
- [`home/shell/zellij/README.md`](home/shell/zellij/README.md) - Zellij configuration guide

#### Quick Start

The enhanced shell environment is automatically available on all configured hosts. Key productivity features:

1. **Start a development session**: `tmux-sessionizer` (Ctrl+F)
2. **Navigate with intelligence**: Use `cd` (zoxide-powered) for smart directory jumping
3. **Enhanced file operations**: `ezals` for beautiful directory listings
4. **AI assistance**: `Alt+E` for command help, `aiexplain command` for explanations
5. **Modern search**: `fzfpreview` for file searching with previews

## Secrets Management

### Comprehensive Agenix Integration

The configuration uses Agenix for encrypted, declarative secret handling:

```bash
# Interactive secrets management
./scripts/manage-secrets.sh

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

### Access Control

```nix
# secrets.nix
{
  "user-password-username.age".publicKeys = [
    users.username
    systems.hostname1
    systems.hostname2
  ];

  "api-service-name.age".publicKeys = [
    users.admin
    systems.production-host
  ];
}
```

## Testing and Validation

### Comprehensive Validation Framework

The configuration includes multiple validation levels:

1. **Syntax Validation:**

   ```bash
   just check-syntax  # Fast syntax checking
   ```

2. **Build Testing:**

   ```bash
   just test-host hostname     # Test specific host
   just test-all              # Test all hosts
   ```

3. **Quality Validation:**

   ```bash
   just validate-quality      # Comprehensive quality checks
   ```

4. **Full Validation:**

   ```bash
   just validate             # Complete validation suite
   ```

### Quality Validation Features

The quality validation script checks:

- Module documentation coverage
- Option naming patterns and consistency
- Code quality and complexity
- Configuration pattern adherence
- Missing assertions and error handling

## Update and Maintenance Procedures

### Regular Updates

```bash
# Standard update workflow
just update-flake          # Update all inputs
just test-all             # Test on all hosts
just deploy               # Deploy if tests pass
just cleanup              # Clean up old generations
```

### Quality Maintenance

```bash
# Regular quality checks
just validate-quality     # Check code quality
just perf-test           # Performance validation
just validate-full       # Comprehensive validation
```

### Major Updates

1. **Review changelogs** for breaking changes
2. **Update staging environment** first
3. **Run comprehensive validation**:

   ```bash
   just ci  # Full CI pipeline
   ```

4. **Deploy incrementally** host by host
5. **Monitor for issues** and rollback if needed

## Hardware-Specific Optimizations

### Multi-Host Hardware Support

#### AMD GPU Systems (P620)

- **ROCm support** for GPU computing and AI workloads
- **AMD-specific driver optimizations**
- **Memory and thermal management**

#### NVIDIA Systems (Razer, P510)

- **Hybrid graphics** configuration for laptops (Optimus)
- **CUDA support** for workstations and development
- **Wayland compatibility** layers and optimizations

#### Intel Integrated Graphics (Samsung, DEX5550)

- **Power efficiency** optimizations for battery life
- **Wayland-native** configurations for performance
- **Thermal and frequency** scaling optimizations

### Performance Tuning

The configuration includes hardware-specific performance optimizations:

```bash
# Performance validation
just perf-test

# System performance monitoring
just validate-performance
```

## Documentation and Resources

### Primary Documentation

- **[ROADMAP.md](ROADMAP.md)** - Comprehensive development roadmap and planned features
- **[PROGRESS_TRACKER.md](PROGRESS_TRACKER.md)** - Active sprint tracking and progress monitoring
- **[OPTIMIZATION_REPORT.md](OPTIMIZATION_REPORT.md)** - Complete optimization history and results
- **[UPGRADE_GUIDE.md](UPGRADE_GUIDE.md)** - Version upgrade procedures and compatibility
- **Module READMEs** - Comprehensive documentation in each module directory

### Templates and Tools

- **`templates/configuration.nix.template`** - New host configuration template
- **`templates/variables.nix.template`** - Host variables template
- **`modules/TEMPLATE.nix`** - Standardized module template
- **`modules/MODULE_README_TEMPLATE.md`** - Documentation template

### Scripts and Utilities

- **`scripts/manage-secrets.sh`** - Comprehensive secrets management
- **`scripts/validate-quality.sh`** - Quality validation and reporting
- **`scripts/cleanup-dead-code.sh`** - Code cleanup and optimization

## Troubleshooting

### Common Issues and Solutions

1. **Build Failures**

   ```bash
   just check-syntax          # Check for syntax errors
   just test-host hostname     # Test specific host build
   nix flake check --show-trace # Detailed error information
   ```

2. **Quality Issues**

   ```bash
   just validate-quality       # Comprehensive quality report
   # Review generated quality report for specific issues
   ```

3. **Performance Problems**

   ```bash
   just perf-test             # Performance benchmarking
   just validate-performance  # Performance validation
   ```

4. **Secrets Management**

   ```bash
   ./scripts/manage-secrets.sh status  # Check secrets status
   ./scripts/manage-secrets.sh rekey   # Re-encrypt all secrets
   ```

### Debug Commands

```bash
# Detailed build information
nix build .#nixosConfigurations.hostname.config.system.build.toplevel --show-trace

# Module evaluation testing
nix eval .#nixosConfigurations.hostname.config.modules

# Performance profiling
nix build --profile-build .#nixosConfigurations.hostname
```

## Contributing and Development

### Code Standards

- **Follow established patterns** from existing modules
- **Include comprehensive validation** with assertions and warnings
- **Add detailed documentation** for complex functionality
- **Test changes** on multiple hosts before committing

### Quality Requirements

- **All syntax must validate** (`just check-syntax`)
- **Quality checks must pass** (`just validate-quality`)
- **Build tests must succeed** (`just test-all`)
- **Documentation must be complete** for new features

### Development Workflow

1. **Create feature branch** for changes
2. **Follow module templates** for new functionality
3. **Test thoroughly** with validation suite
4. **Update documentation** as needed
5. **Submit with quality validation** results

## Support and Community

### Getting Help

1. **Review comprehensive documentation** in module READMEs
2. **Check quality validation output** for specific guidance
3. **Examine similar configurations** in existing hosts
4. **Test changes incrementally** to isolate issues

### Reporting Issues

- **Use quality validation** to identify problems
- **Provide detailed error messages** and reproduction steps
- **Include system information** and configuration details

---

## Configuration Highlights

This NixOS configuration represents a **production-ready, enterprise-grade** system with:

- **141+ Optimized Modules** with comprehensive validation
- **Advanced Feature Management** with granular control
- **Multi-Host Architecture** supporting diverse hardware
- **Comprehensive Secrets Management** with role-based access
- **Complete Monitoring Stack** with Prometheus, Grafana, and Alertmanager
- **Unified AI Provider System** with multi-provider support and automatic fallback
- **AI-Enhanced Task Management** with intelligent Taskwarrior integration and natural language processing
- **MicroVM Development Environments** with three specialized templates for development workflows
- **Quality Validation Framework** ensuring code quality
- **Extensive Automation** through Justfile commands
- **Complete Documentation** with templates and guides
- **Performance Optimization** across all system levels
- **Comprehensive Observability** with custom NixOS and systemd metrics
- **Intelligent Productivity System** with AI-powered workflows and beautiful terminal interfaces

**Perfect for**: Development workstations, AI/ML environments, multi-user enterprises, monitoring infrastructure, and anyone seeking a maintainable, scalable NixOS configuration with modern DevOps capabilities.

**Latest Capabilities:**

- **AI-Enhanced Task Management**: Revolutionary productivity system with natural language task creation and intelligent analysis
- **Real-time Monitoring**: Full observability stack with custom dashboards for each host
- **AI-Powered Workflows**: Seamless integration with multiple AI providers and local models
- **MicroVM Virtualization**: Lightweight development environments with enterprise features
- **Intelligent Productivity**: Beautiful terminal interfaces with AI-driven insights and automation
- **Automated Fallback**: Intelligent provider switching and cost optimization
- **Hardware-Specific Optimization**: Tailored configurations for AMD ROCm, NVIDIA CUDA, and Intel integrated graphics

---

_This configuration has undergone comprehensive optimization across 12+ phases, including advanced monitoring infrastructure, unified AI provider systems, revolutionary AI-enhanced task management, and MicroVM development environments, eliminating technical debt, enhancing performance, and establishing production-ready quality standards for modern DevOps and productivity environments._
