# Technical Stack

> Last Updated: 2025-01-29
> Version: 1.1.0
> Status: Updated with NixOS Best Practices

## Core Technologies

### Application Framework

- **Framework:** NixOS with Flakes
- **Version:** 25.11 (nixos-unstable)
- **Language:** Nix expression language
- **Code Standards:** Follow NixOS anti-patterns documentation (docs/NIXOS-ANTI-PATTERNS.md)
- **Configuration Pattern:** Template-based architecture with feature flags

### Database

- **Primary:** Not applicable (declarative configuration)
- **Configuration Storage:** Git version control with explicit imports
- **Secrets Storage:** Agenix encrypted files with runtime loading
- **State Management:** Declarative with NixOS generations

## Infrastructure Stack

### Configuration Management

- **Framework:** NixOS Flakes
- **Build Tool:** Nix package manager
- **Version Control:** Git
- **Validation:** Custom validation framework with nix eval
- **Import Strategy:** Explicit imports only (no auto-discovery)
- **Anti-Patterns:** Zero `mkIf condition true` patterns
- **Code Review:** Comprehensive checklist from NIXOS-ANTI-PATTERNS.md

### Package Management

- **Package Manager:** Nix with Flakes
- **Cache Strategy:** Multi-tier caching (cache.nixos.org, custom cachix, local p620 cache)
- **Node Version:** 22 LTS (where applicable)

### Module Architecture

- **Architecture:** 141+ modular components with feature flags
- **Import Strategy:** Static imports with conditional enablement (explicit only)
- **Configuration:** Feature-based dependency resolution
- **Validation:** Runtime feature validation and conflict detection
- **Module Pattern:** Trust NixOS module system, direct boolean assignments
- **Code Deduplication:** 95% shared code through template system
- **Function Policy:** No trivial wrappers, use lib functions directly

### Development Environment

- **Editors:** VS Code, Neovim (LazyVim/LunarVim), Emacs
- **Languages:** Python, Go, Rust, Node.js, Java, Lua
- **Shells:** Zsh with Starship, advanced multiplexers (tmux, Zellij)
- **AI Integration:** Claude Code, multiple LLM providers

## Infrastructure Components

### Host Architecture

- **Multi-Host Management:** 4 active hosts (p620, p510, razer, samsung) - **DEX5550 offline**, HP decommissioned
- **Hardware Profiles:** AMD, Intel, NVIDIA configurations
- **Desktop Environment:** Hyprland (Wayland), with Plasma fallback
- **Live Installers:** Hardware-specific USB installation images

### Virtualization

- **Container Runtime:** Docker, Podman
- **MicroVMs:** Development environments with resource isolation
- **Orchestration:** K3s clusters via MicroVM
- **Storage:** Shared nix store with persistent volumes

### System Management

- **Configuration:** Declarative NixOS with flakes
- **Deployment:** Automated with Just and shell scripts
- **Validation:** Multi-stage testing framework
- **Monitoring:** System logs and systemd journal (native tools)

**Note**: External monitoring infrastructure (Prometheus/Grafana/Loki) has been **removed** for simplified configuration.

## Deployment Infrastructure

### Application Hosting

- **Platform:** Self-hosted on NixOS infrastructure
- **Primary Hosts:** p620 (primary workstation), p510 (media server), razer/samsung (mobile)
- **Network:** Tailscale VPN mesh with DNS management

**Note**: DEX5550 is **offline**. Monitoring infrastructure (Prometheus/Grafana/Loki) has been **removed**.

### Automation

- **Deployment:** Justfile with 100+ commands
- **CI/CD:** Custom shell scripts with parallel testing
- **Validation:** Multi-stage configuration testing
- **Rollback:** NixOS generation management

### Secrets Management

- **Provider:** Agenix
- **Key Management:** Age encryption with per-host keys
- **Access Control:** Host-based secret decryption
- **Rotation:** Manual with automated validation
- **Security Pattern:** Runtime loading only (no evaluation-time reads)
- **File References:** Use passwordFile patterns, never inline secrets

## Development Infrastructure

### AI Providers

- **Primary:** Anthropic Claude
- **Secondary:** OpenAI GPT, Google Gemini
- **Local:** Ollama for offline inference
- **Integration:** Unified client interface

### Development Tools

- **Version Control:** Git with GitHub integration
- **Package Management:** Language-specific managers integrated with Nix
- **Testing:** Custom module testing framework
- **Documentation:** Markdown with automated generation

### Storage & Backup

- **File Systems:** ext4, ZFS (where applicable)
- **Backup Strategy:** Planned automated backups with verification
- **Storage Optimization:** Nix store optimization and cleanup automation

## Network Architecture

### VPN Infrastructure

- **Provider:** Tailscale
- **Configuration:** Mesh network with idiot-proof DNS
- **Security:** ACL-based access control
- **Monitoring:** Network stability and connectivity monitoring

### Service Discovery

- **DNS:** Tailscale Magic DNS with conflict prevention
- **Service Mesh:** Planned evaluation (Docker Swarm vs K3s)
- **Load Balancing:** Host-specific service distribution

## Security Framework

### Access Control

- **Authentication:** SSH key-based with potential MFA
- **Authorization:** User groups and sudo privileges
- **Network Security:** Firewall rules and Tailscale ACLs
- **Audit:** Planned access logging and monitoring

### Hardening

- **System Security:** Kernel parameter hardening implemented
- **Service Isolation:** Systemd security features (DynamicUser, ProtectSystem)
- **File Permissions:** Nix-managed permission enforcement
- **Update Management:** Automated security updates via nix flake update
- **Service Security:** No root services, dedicated users with minimal privileges
- **Firewall:** Minimal port opening, interface-specific rules

## Performance Optimization

### Resource Management

- **Memory:** Host-specific swap optimization
- **CPU:** Frequency scaling and thermal management
- **Storage:** SSD optimization and cleanup automation
- **Network:** Performance tuning and monitoring

### Build Optimization

- **Parallel Builds:** Multi-host parallel configuration building
- **Caching:** Aggressive use of binary caches with correct public keys
- **Evaluation:** Lazy evaluation and conditional imports
- **Generation Management:** Automated cleanup of old generations
- **Garbage Collection:** Automated weekly cleanup (30-day retention)
- **Store Optimization:** Automated nix store optimization
- **Performance:** No Import From Derivation (IFD) patterns

## NixOS Best Practices Implementation

### Code Quality Standards

- **Language Standards:** Follow docs/NIXOS-ANTI-PATTERNS.md strictly
- **URL Quoting:** All URLs quoted (RFC 45 compliance)
- **Explicit Imports:** No `with` overuse, clear variable origins
- **No Magic:** Explicit imports list, no auto-discovery mechanisms
- **Function Policy:** No trivial wrappers, use lib functions directly

### Critical Anti-Patterns Avoided

- **mkIf true Pattern:** Eliminated all `mkIf condition true` usage
- **Import From Derivation:** No evaluation-time builds
- **Recursive Attribute Sets:** Minimal `rec` usage to prevent recursion
- **Magic Auto-Discovery:** Explicit module imports only
- **Root Services:** All services run with dedicated users and hardening

### Security Implementation

- **Secret Handling:** Runtime loading only, never evaluation-time reads
- **Service Isolation:** DynamicUser, ProtectSystem, minimal privileges
- **Firewall Configuration:** Minimal ports, interface-specific rules
- **Update Safety:** Build → test → switch deployment workflow

### Performance Optimizations

- **Package Management:** Declarative only, no nix-env usage
- **System vs User:** Proper package separation and organization
- **Binary Caches:** Multi-tier caching with verified public keys
- **Store Management:** Automated garbage collection and optimization

### Development Workflow

- **Testing Pipeline:** Build → test → deploy with validation
- **Code Review:** Comprehensive checklist from anti-patterns documentation
- **Modular Structure:** 141+ modules with explicit imports
- **Template System:** 95% code deduplication through shared templates

### Community Alignment

- **NixOS Patterns:** Follow nixpkgs community standards
- **Transparency:** Clear documentation of implementation decisions
- **Maintainability:** Focus on explicit, debuggable configurations
- **Performance Focus:** Evaluation efficiency and build optimization
