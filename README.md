# NixOS Infrastructure Hub - Template-Based Architecture

## Architecture Overview

This repository implements a template-based NixOS configuration management system achieving 95% code deduplication through a three-tier architecture: host templates, Home Manager profiles, and modular components. The system manages 5 active hosts with different hardware profiles and supports multi-user environments.

### Core Architecture Components

- **Host Templates**: 3 hardware-optimized templates (workstation, laptop, server)
- **Home Manager Profiles**: 4 role-based user profiles with composition capabilities
- **Modular Foundation**: 141+ reusable modules for fine-grained functionality control
- **Asset Management**: Centralized asset organization with clean directory structure

## Directory Structure

```
├── flake.nix                          # Main flake configuration
├── lib/                               # Utility functions and builders
├── modules/                           # 141+ modular components
│   ├── features/                      # Feature-based modules with flags
│   ├── services/                      # Service-specific configurations
│   └── default.nix                    # Module imports and organization
├── hosts/                             # Host-specific configurations
│   ├── templates/                     # Host type templates
│   │   ├── workstation.nix            # Full desktop workstation template
│   │   ├── laptop.nix                 # Mobile laptop template
│   │   └── server.nix                 # Headless server template
│   ├── p620/                          # AMD workstation (uses workstation template)
│   ├── p510/                          # Intel Xeon server (uses server template)
│   ├── razer/                         # Intel/NVIDIA laptop (uses laptop template)
│   ├── dex5550/                       # Intel SFF server (uses server template)
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
└── scripts/                           # Management and automation scripts
```

## Template System

### Host Templates

**Workstation Template** (`hosts/templates/workstation.nix`)

- Target: Full desktop development workstation
- Used by: P620 (AMD workstation)
- Features: Complete desktop environments, development tools, media applications, gaming support

**Laptop Template** (`hosts/templates/laptop.nix`)

- Target: Mobile development with power management
- Used by: Razer (Intel/NVIDIA), Samsung (Intel)
- Features: Power management, mobile hardware support, battery optimization

**Server Template** (`hosts/templates/server.nix`)

- Target: Headless server operation
- Used by: P510 (media server), DEX5550 (monitoring server)
- Features: Server services, monitoring, headless operation, security hardening

### Home Manager Profiles

**server-admin**: Minimal CLI-focused server administration
**developer**: Full development toolchain and editors
**desktop-user**: Complete desktop environment with multimedia
**laptop-user**: Mobile-optimized with battery consciousness

### Profile Compositions

- **P620**: developer + desktop-user (full workstation)
- **Razer/Samsung**: developer + laptop-user (mobile development)
- **P510**: server-admin + developer (dev-server composition)
- **DEX5550**: server-admin (pure server)

## Build and Deployment Commands

### Building and Testing

```bash
# Comprehensive validation
just validate

# Quick syntax validation
just validate-quick

# Test specific host
just test-host p620

# Test all hosts
just test-all

# Run full CI pipeline
just ci

# Check syntax across all files
just check-syntax

# Format all Nix files
just format
```

### Host Deployment

```bash
# Deploy to local system (auto-detects hostname)
just deploy

# Deploy to specific hosts
just p620      # AMD workstation with ROCm
just razer     # Intel/NVIDIA laptop with Optimus
just p510      # Intel Xeon/NVIDIA server
just samsung   # Intel laptop with integrated graphics
just dex5550   # Intel SFF with efficiency optimizations

# Update system packages
just update

# Update flake inputs
just update-flake
```

### Advanced Operations

```bash
# Quality validation with detailed reporting
just validate-quality

# Module structure validation
just test-modules

# Performance benchmarking
just perf-test

# Clean up unused store paths
just cleanup
```

## Host Configuration Pattern

Each host follows a standardized structure:

```nix
# hosts/HOSTNAME/configuration.nix
{ config, pkgs, lib, hostUsers, hostTypes, ... }:
let
  vars = import ./variables.nix { };
in {
  # Import appropriate template + host-specific modules
  imports = hostTypes.TEMPLATE_TYPE.imports ++ [
    ./nixos/hardware-configuration.nix
    ./nixos/hardware-specific-config.nix
  ];

  # Template provides 95% of configuration
  # Host only adds unique hardware/network settings
  networking.hostName = vars.hostName;
}
```

## Feature System

The configuration uses feature flags for granular control:

```nix
features = {
  development = {
    enable = true;
    python = true;
    nodejs = true;
    go = true;
    docker = true;
  };

  desktop = {
    enable = true;
    hyprland = true;
    plasma = false;
  };

  virtualization = {
    enable = true;
    docker = true;
    libvirt = true;
  };

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

  monitoring = {
    enable = true;
    mode = "server";
    serverHost = "dex5550";
    features = {
      nodeExporter = true;
      nixosMetrics = true;
      alerting = true;
    };
  };
};
```

## Module Development

### Module Template

```nix
{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.modules.category.name;
in {
  options.modules.category.name = {
    enable = mkEnableOption "module functionality";

    settings = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Configuration settings";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Package list
    ];

    assertions = [
      {
        assertion = cfg.settings != {};
        message = "Module requires configuration settings";
      }
    ];
  };
}
```

### Adding New Module

1. Create module file in appropriate category
2. Follow established pattern with enable options
3. Add to module imports in category default.nix
4. Test with validation suite
5. Document functionality and options

## User Management

### Adding New User

1. Create user directory structure:

   ```bash
   mkdir -p Users/newuser/common
   ```

2. Create base user configuration:

   ```nix
   # Users/newuser/common/default.nix
   { config, lib, pkgs, ... }: {
     home = {
       username = "newuser";
       homeDirectory = "/home/newuser";
       stateVersion = "24.11";
     };
   }
   ```

3. Create host-specific configurations for each host
4. Generate SSH key and add to secrets
5. Create user password secret
6. Add user to host variables
7. Test and deploy

## Secrets Management

### Agenix Integration

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

- User passwords: `user-password-USERNAME.age`
- API keys: `api-SERVICE-NAME.age`
- Certificates: `cert-DOMAIN-NAME.age`
- Database credentials: `db-SERVICE-NAME.age`

## System Services

### AI Provider System

```bash
# Main AI interface
ai-cli "your question"
ai-cli -p anthropic "specific question"
ai-cli -p ollama "local question"

# Provider management
ai-cli --status
ai-cli --list-providers
```

**Supported Providers**: Anthropic Claude, OpenAI, Google Gemini, Ollama (local)

### Monitoring Stack

**Services**:

- Prometheus (port 9090): Metrics collection
- Grafana (port 3001): Visualization dashboards
- Alertmanager (port 9093): Alert management
- Node Exporters (port 9100): System metrics

**Custom Exporters**:

- NixOS Exporter (port 9101): Nix-specific metrics
- Systemd Exporter (port 9102): Service monitoring

### MicroVM Development Environments

```bash
# VM management
just start-microvm dev-vm
just stop-microvm dev-vm
just list-microvms

# SSH access
just ssh-microvm dev-vm
# Or: ssh dev@localhost -p 2222
```

**Available VMs**:

- dev-vm: Complete development stack (port 2222)
- test-vm: Minimal testing environment (port 2223)
- playground-vm: Advanced DevOps tools (port 2224)

## Hardware Support

### AMD Systems (P620)

- ROCm support for GPU computing
- AMD-specific driver optimizations
- Memory and thermal management

### NVIDIA Systems (Razer, P510)

- Hybrid graphics configuration (Optimus)
- CUDA support for development
- Wayland compatibility layers

### Intel Systems (Samsung, DEX5550)

- Power efficiency optimizations
- Wayland-native configurations
- Thermal and frequency scaling

## Validation Framework

### Quality Validation

```bash
# Comprehensive quality checks
just validate-quality

# Build testing
just test-host hostname
just test-all

# Performance validation
just perf-test
```

### Validation Components

- Syntax validation across all Nix files
- Module documentation coverage
- Configuration pattern adherence
- Build success validation
- Performance benchmarking

## Troubleshooting

### Common Issues

**Build Failures**:

```bash
just check-syntax
just test-host hostname
nix flake check --show-trace
```

**Performance Problems**:

```bash
just perf-test
just validate-performance
```

**Secrets Issues**:

```bash
./scripts/manage-secrets.sh status
./scripts/manage-secrets.sh rekey
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

## Development Standards

### Code Requirements

- Follow established module patterns
- Include comprehensive validation with assertions
- Add detailed documentation for complex functionality
- Test changes on multiple hosts before committing

### Quality Standards

- All syntax must validate (`just check-syntax`)
- Quality checks must pass (`just validate-quality`)
- Build tests must succeed (`just test-all`)
- Documentation must be complete for new features

## Architecture Benefits

**Quantified Results**:

| Metric                  | Before     | After      | Improvement |
| ----------------------- | ---------- | ---------- | ----------- |
| Code Deduplication      | 30% shared | 95% shared | +317%       |
| Host Configuration Size | 500 lines  | 50 lines   | -90%        |
| User Configuration Size | 300 lines  | 100 lines  | -67%        |
| Total Lines of Code     | 4,000      | 1,200      | -70%        |

**Maintenance Benefits**:

- Single point updates through template changes
- Consistent behavior across similar host types
- Easy testing through template validation
- Simple additions with minimal unique configuration
- Systematic conflict resolution patterns

**Scalability Benefits**:

- Easy addition of new host types through templates
- Simple creation of new user roles through profiles
- Mix-and-match profile compositions for custom use cases
- Architecture scales to dozens of hosts and user types
