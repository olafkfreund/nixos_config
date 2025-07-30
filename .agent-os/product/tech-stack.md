# Technical Stack

> Last Updated: 2025-01-29
> Version: 1.0.0

## Core Technologies

### Application Framework
- **Framework:** NixOS with Flakes
- **Version:** 25.11 (nixos-unstable)
- **Language:** Nix expression language

### Database
- **Primary:** Not applicable (declarative configuration)
- **Configuration Storage:** Git version control
- **Secrets Storage:** Agenix encrypted files

## Infrastructure Stack

### Configuration Management
- **Framework:** NixOS Flakes
- **Build Tool:** Nix package manager
- **Version Control:** Git
- **Validation:** Custom validation framework with nix eval

### Package Management
- **Package Manager:** Nix with Flakes
- **Cache Strategy:** Multi-tier caching (cache.nixos.org, custom cachix, local p620 cache)
- **Node Version:** 22 LTS (where applicable)

### Module Architecture
- **Architecture:** 141+ modular components with feature flags
- **Import Strategy:** Static imports with conditional enablement
- **Configuration:** Feature-based dependency resolution
- **Validation:** Runtime feature validation and conflict detection

### Development Environment
- **Editors:** VS Code, Neovim (LazyVim/LunarVim), Emacs
- **Languages:** Python, Go, Rust, Node.js, Java, Lua
- **Shells:** Zsh with Starship, advanced multiplexers (tmux, Zellij)
- **AI Integration:** Claude Code, multiple LLM providers

## Infrastructure Components

### Host Architecture
- **Multi-Host Management:** 6 active hosts (p620, p510, razer, samsung, dex5550, hp)
- **Hardware Profiles:** AMD, Intel, NVIDIA configurations
- **Desktop Environment:** Hyprland (Wayland), with Plasma fallback
- **Live Installers:** Hardware-specific USB installation images

### Virtualization
- **Container Runtime:** Docker, Podman
- **MicroVMs:** Development environments with resource isolation
- **Orchestration:** K3s clusters via MicroVM
- **Storage:** Shared nix store with persistent volumes

### Monitoring & Observability
- **Metrics:** Prometheus + Grafana stack
- **Exporters:** Node, systemd, custom NixOS exporters
- **Dashboards:** Multi-host Grafana dashboards
- **Alerting:** Alertmanager (configured, rules pending)
- **Logging:** Planned Loki + Promtail implementation

## Deployment Infrastructure

### Application Hosting
- **Platform:** Self-hosted on NixOS infrastructure
- **Primary Hosts:** p620 (workstation), p510 (server), dex5550 (monitoring)
- **Network:** Tailscale VPN mesh with DNS management

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
- **System Security:** Planned kernel parameter hardening
- **Service Isolation:** Systemd security features
- **File Permissions:** Nix-managed permission enforcement
- **Update Management:** Automated security updates via nix flake update

## Performance Optimization

### Resource Management
- **Memory:** Host-specific swap optimization
- **CPU:** Frequency scaling and thermal management
- **Storage:** SSD optimization and cleanup automation
- **Network:** Performance tuning and monitoring

### Build Optimization
- **Parallel Builds:** Multi-host parallel configuration building
- **Caching:** Aggressive use of binary caches
- **Evaluation:** Lazy evaluation and conditional imports
- **Generation Management:** Automated cleanup of old generations