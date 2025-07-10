# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a sophisticated multi-host NixOS configuration using flakes with extensive modularization, secrets management, and automation. The repository manages 4 active hosts with different hardware profiles and supports multi-user environments.

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
just quick-deploy dex5550 # Deploy DEX5550 only if configuration changed

# Standard optimized deployment to specific hosts
just p620    # AMD workstation with ROCm (optimized)
just razer   # Intel/NVIDIA laptop (optimized)
just p510    # Intel Xeon/NVIDIA workstation (optimized)
just dex5550 # Intel SFF with integrated graphics (optimized)

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
just quick-deploy dex5550

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
- `flake.nix` - Main entry point defining hosts and configurations
- `hosts/` - Host-specific configurations (p620, razer, p510, dex5550)
- `modules/` - Reusable NixOS modules organized by category
- `home/` - Home Manager base configurations
- `Users/` - Per-user configurations with host-specific home files
- `secrets/` - Encrypted secrets using Agenix
- `scripts/` - Management and utility scripts

### Host Configuration Pattern
Each host has:
- `configuration.nix` - Main NixOS configuration
- `variables.nix` - Host-specific variables (users, features, hardware)
- `hardware-configuration.nix` - Generated hardware configuration

### Module System
Modules use a consistent pattern with feature flags:
```nix
features = {
  development = {
    enable = true;
    python = true;
    go = true;
  };
  virtualization = {
    enable = true;
    docker = true;
  };
}
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

## Important Conventions

1. **Always verify packages exist** before using them in configurations
2. **Use feature flags** for conditional module loading
3. **Test changes** with `just test-host HOST` before deploying
4. **Format code** with `just format` before committing
5. **Validate** with `just validate` for comprehensive checks
6. **Secrets** must be created through the management script, never hardcoded
7. **MODULAR ARCHITECTURE**: All new services MUST be created in their own configuration files within `modules/` directory, NOT added directly to host `configuration.nix` files

## Hardware-Specific Considerations

- **P620**: AMD GPU requires ROCm support, uses `amdgpu` driver
- **Razer**: Hybrid Intel/NVIDIA graphics needs Optimus configuration
- **P510**: Intel Xeon with NVIDIA requires CUDA support
- **DEX5550**: Intel integrated graphics, optimized for efficiency

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

### NEVER add services directly to configuration.nix
- ❌ **Wrong**: Adding `services.myservice = { ... }` directly in `hosts/*/configuration.nix`
- ✅ **Correct**: Create `modules/services/myservice.nix` and enable via feature flags
- This maintains modularity, reusability, and clean architecture

**Example - Adding a new service:**
```bash
# 1. Create module file
echo '{ config, lib, pkgs, ... }: ...' > modules/services/myservice.nix

# 2. Add to modules/default.nix imports
# 3. Enable in host via features.myservice.enable = true;
# 4. NOT: services.myservice = { ... } in configuration.nix
```

**Benefits of modular architecture:**
- 🔄 **Reusable** across multiple hosts
- 🧪 **Testable** in isolation
- 🧹 **Clean** host configurations
- 🔧 **Maintainable** and organized codebase

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

### Enabling Monitoring on Additional Hosts
To add monitoring to other hosts (razer, p510, dex5550):

1. **Enable monitoring in client mode:**
```nix
# In hosts/HOSTNAME/configuration.nix
features = {
  monitoring = {
    enable = true;
    mode = "client";  # Send metrics to P620 server
    serverHost = "p620";
    
    features = {
      nodeExporter = true;
      nixosMetrics = true;
    };
  };
};
```

2. **Deploy configuration:**
```bash
just test-host HOSTNAME
just HOSTNAME  # Deploy to specific host
```

3. **Verify monitoring:**
   - Check Prometheus targets: http://p620:9090/targets
   - View host dashboard in Grafana: http://p620:3001

## Network and Cache Configuration

- Binary cache server on P620: `http://p620:5000`
- Tailscale VPN integration for remote access
- Network stability module for connection monitoring

## Monitoring and Observability

### Monitoring Stack (Phase 7 - FULLY DEPLOYED)
A comprehensive monitoring infrastructure deployed on DEX5550 as the monitoring server:

**Services:**
- **Prometheus** (port 9090): Metrics collection and storage
- **Grafana** (port 3001): Visualization and dashboards  
- **Alertmanager** (port 9093): Alert management and routing
- **Node Exporters** (port 9100): System metrics collection

**Custom Exporters:**
- **NixOS Exporter** (port 9101): Nix store size, generations, derivations
- **Systemd Exporter** (port 9102): Service status and systemd metrics

**Dashboards Available:**
- NixOS System Overview: Global system metrics
- Host-specific dashboards: p620 (AMD), razer (NVIDIA), p510 (NVIDIA), dex5550 (Intel)
- Hardware-specific panels for GPU metrics

**Management Commands:**
```bash
# Check monitoring services status
grafana-status          # Grafana service and dashboard count
prometheus-status       # Prometheus server and targets
node-exporter-status    # All exporters status and metrics

# Access monitoring interfaces
# Grafana: http://dex5550.home.freundcloud.com:3001 (admin/nixos-admin)
# Prometheus: http://dex5550.home.freundcloud.com:9090
# Alertmanager: http://dex5550.home.freundcloud.com:9093
```

**Configuration:**
- Server mode on DEX5550 (monitoring server)
- Client mode deployed on P620, P510, and Razer
- 30-day metrics retention
- 15-second scrape intervals for real-time monitoring
- Comprehensive alerting rules for system health

**Deployment Status**: ✅ **ALL HOSTS MONITORED**
- P620: ✅ Node exporter, systemd exporter, AI metrics
- DEX5550: ✅ Prometheus, Grafana, Alertmanager
- P510: ✅ Node exporter, systemd exporter, storage metrics
- Razer: ✅ Node exporter, systemd exporter, mobile metrics

## Complete AI Infrastructure Deployment (Phase 9.3 - Production Ready)

### Enterprise-Grade AI Infrastructure
A complete, production-ready AI infrastructure deployed across all 4 hosts with comprehensive monitoring, alerting, and automation capabilities.

**Deployment Status**: ✅ **FULLY DEPLOYED AND OPERATIONAL**

### Multi-Host Architecture
- **P620** (Primary AI Host): AI providers, alerting, load testing, local inference
- **DEX5550** (Monitoring Server): Prometheus, Grafana, centralized monitoring
- **P510** (High Performance Client): Storage analysis, automated remediation
- **Razer** (Mobile Client): Basic monitoring and system analysis

### Deployment Validation Results
✅ **All 4 hosts fully operational**
✅ **Multi-provider AI system active**
✅ **Comprehensive monitoring integrated**
✅ **Advanced alerting system functional**
✅ **Security hardening applied**
✅ **Performance optimization enabled**

### Access Points
- **Grafana**: http://dex5550.home.freundcloud.com:3001
- **Prometheus**: http://dex5550.home.freundcloud.com:9090
- **Alertmanager**: http://dex5550.home.freundcloud.com:9093

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

## Network and Cache Configuration

- Binary cache server on P620: `http://p620:5000`
- Tailscale VPN integration for remote access
- Network stability module for connection monitoring