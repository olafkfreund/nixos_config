# 🗂️ NixOS Configuration

A sophisticated, modular NixOS configuration system designed for managing multiple hosts with different hardware profiles, comprehensive optimization, and advanced automation. This configuration emphasizes maintainability, modularity, and production-ready quality standards.

## 🏗️ Architecture Overview

This configuration uses a **flake-based** approach with extensive modularization and optimization:

```
nixos-config/
├── flake.nix                 # Main entry point, defines hosts and inputs
├── Justfile                  # Command runner for all operations
├── hosts/                    # Host-specific configurations
│   ├── p620/                # AMD workstation (ROCm GPU)
│   ├── razer/               # Intel/NVIDIA laptop
│   ├── p510/                # Intel Xeon/NVIDIA workstation  
│   ├── samsung/             # Intel laptop
│   └── dex5550/             # Intel SFF with integrated graphics
├── modules/                  # 141+ optimized, reusable NixOS modules
│   ├── ai/                  # AI tools and services
│   ├── desktop/             # Desktop environment components
│   ├── services/            # System services and daemons
│   ├── containers/          # Docker, Podman, Kubernetes
│   ├── development/         # Development tools and languages
│   └── ...                  # Other functional categories
├── home/                     # Home Manager base configurations
├── Users/                    # Per-user configurations with host-specific files
├── lib/                      # Custom library functions and utilities
├── scripts/                  # Management, validation, and utility scripts
├── templates/                # Configuration templates for new hosts/modules
└── docs/                     # Comprehensive documentation
```

### 🏆 Key Features

✅ **Multi-host support** with hardware-specific optimizations  
✅ **141+ optimized modules** with comprehensive validation  
✅ **Feature flag system** for granular control  
✅ **Automated secrets management** with Agenix  
✅ **Quality validation framework** with automated testing  
✅ **Performance optimizations** for different hardware profiles  
✅ **Comprehensive documentation** and templates  
✅ **CI/CD pipeline** with automated testing and validation  
✅ **Dead code elimination** and performance optimization  

## 🚀 Quick Start

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

## 🔧 Using the Justfile

The Justfile provides convenient commands for all operations. It's the primary interface for managing this configuration.

### 📋 Available Commands

```bash
just --list  # Show all available commands
```

### 🏗️ Building and Testing

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

### 🚀 Deployment Commands

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

### 🔍 Quality and Maintenance

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

## 🏠 Host Configuration

Each host has a standardized, optimized structure:

### Host Directory Structure
```
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

## 👥 User Management

### User Configuration Structure
```
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

## 🧩 Module System

### Module Categories

The configuration includes 141+ optimized modules organized by function:

- **`modules/ai/`** - AI tools (Ollama, ChatGPT CLI, Gemini CLI)
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

## 🔧 Feature System

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
    chatgpt = true;     # ChatGPT CLI tools
    gemini-cli = true;  # Google Gemini CLI
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

## 🚀 Enhanced Shell Environment

### Comprehensive Terminal Experience

This configuration provides a modern, high-performance shell environment with seamless integration across all components:

#### ✨ **Enhanced Zsh Configuration** (`home/shell/zsh.nix`)

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

#### ⭐ **Enhanced Starship Prompt** (`home/shell/starship/default.nix`)

**Rich Information Display:**
- Command duration for performance awareness (shows for commands >1s)
- Comprehensive Git status with branch, commits, and file states
- Development context (Nix shells, containers, cloud environments)
- Hardware-aware icons and consistent Gruvbox theming

#### 🖥️ **Enhanced Tmux Configuration** (`home/shell/tmux/default.nix`)

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

#### 📱 **Enhanced Zellij Configuration** (`home/shell/zellij/default.nix`)

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

#### 🔧 **Key Features and Integrations**

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

#### 📖 **Documentation**

Detailed documentation for each component:
- [`home/shell/zsh/README.md`](home/shell/zsh/README.md) - Zsh configuration guide
- [`home/shell/tmux/README.md`](home/shell/tmux/README.md) - Tmux setup and keybindings
- [`home/shell/zellij/README.md`](home/shell/zellij/README.md) - Zellij configuration guide

#### 🎯 **Quick Start**

The enhanced shell environment is automatically available on all configured hosts. Key productivity features:

1. **Start a development session**: `tmux-sessionizer` (Ctrl+F)
2. **Navigate with intelligence**: Use `cd` (zoxide-powered) for smart directory jumping
3. **Enhanced file operations**: `ezals` for beautiful directory listings
4. **AI assistance**: `Alt+E` for command help, `aiexplain command` for explanations
5. **Modern search**: `fzfpreview` for file searching with previews

## 🔐 Secrets Management

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

## 🚦 Testing and Validation

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

## 🔄 Update and Maintenance Procedures

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

## 🛠️ Hardware-Specific Optimizations

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

## 📚 Documentation and Resources

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

## 🚨 Troubleshooting

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

## 🤝 Contributing and Development

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

## 📞 Support and Community

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

## 🎯 Configuration Highlights

This NixOS configuration represents a **production-ready, enterprise-grade** system with:

- **🏆 141+ Optimized Modules** with comprehensive validation
- **🔧 Advanced Feature Management** with granular control
- **🚀 Multi-Host Architecture** supporting diverse hardware
- **🔐 Comprehensive Secrets Management** with role-based access
- **📋 Quality Validation Framework** ensuring code quality
- **🛠️ Extensive Automation** through Justfile commands
- **📚 Complete Documentation** with templates and guides
- **⚡ Performance Optimization** across all system levels

**Perfect for**: Development workstations, multi-user environments, enterprise deployments, and anyone seeking a maintainable, scalable NixOS configuration.

---

*This configuration has undergone comprehensive optimization across 7 phases, eliminating technical debt, enhancing performance, and establishing production-ready quality standards.*