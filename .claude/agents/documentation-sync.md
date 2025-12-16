# Documentation Sync Agent

> **Automated Documentation Generation and Synchronization**
> Priority: P3 | Impact: Low-Medium | Effort: Low

## Overview

The Documentation Sync agent automatically generates and maintains up-to-date documentation for NixOS modules, configurations, and infrastructure. It ensures documentation stays synchronized with code changes and provides comprehensive references for all components.

## Agent Purpose

**Primary Mission**: Maintain comprehensive, accurate, and up-to-date documentation through automated generation, synchronization, and validation.

**Trigger Conditions**:

- User mentions documentation, docs, or README
- Commands like `/nix-docs` or `just generate-docs`
- After module changes
- Before releases
- Weekly documentation audits (if configured)

## Core Capabilities

### 1. Module Documentation Generation

**What it does**: Generates comprehensive documentation for NixOS modules

**Documentation includes**:

```yaml
Module Documentation:

For: modules/services/prometheus.nix

Generated Documentation:
  # modules/services/prometheus/README.md

  ## Prometheus Module

  Enterprise-grade monitoring and alerting system.

  ### Options

  #### services.prometheus.enable
  **Type**: boolean
  **Default**: false
  **Description**: Enable Prometheus monitoring service

  #### services.prometheus.port
  **Type**: integer (1-65535)
  **Default**: 9090
  **Description**: Port for Prometheus web interface

  #### services.prometheus.retention
  **Type**: string
  **Default**: "30d"
  **Description**: Data retention period
  **Example**: "90d", "1y"

  ### Usage

  ```nix
  # Basic configuration
  services.prometheus = {
    enable = true;
    port = 9090;
    retention = "90d";
  };
  ```

  ### Examples

  #### Minimal Setup
  ```nix
  services.prometheus.enable = true;
  ```

  #### Full Configuration
  ```nix
  services.prometheus = {
    enable = true;
    port = 9090;
    retention = "1y";
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{
          targets = [ "localhost:9100" ];
        }];
      }
    ];
  };
  ```

  ### Related Modules

  - modules/monitoring/grafana.nix - Visualization
  - modules/monitoring/alertmanager.nix - Alerting
  - modules/monitoring/node-exporter.nix - Metrics

  ### Troubleshooting

  **Issue**: Service fails to start
  **Solution**: Check port availability with `ss -tlnp | grep 9090`

  **Issue**: No metrics displayed
  **Solution**: Verify scrape targets configuration

  ### Security

  - Runs with DynamicUser (non-root)
  - Systemd security hardening enabled
  - Firewall integration available
```

### 2. Configuration Reference Generation

**What it does**: Creates reference documentation for host configurations

**Configuration docs**:

```yaml
Host Configuration Documentation:

For: hosts/p620/configuration.nix

Generated Documentation:
  # hosts/p620/README.md

  ## P620 - AMD Workstation

  Primary development workstation and monitoring server.

  ### Hardware

  - **CPU**: AMD Ryzen (12 cores)
  - **RAM**: 32GB DDR4
  - **GPU**: AMD Radeon (ROCm support)
  - **Storage**: 250GB SSD (NVMe)

  ### Role

  - Primary development environment
  - Monitoring server (Prometheus, Grafana)
  - AI inference host (Ollama with ROCm)

  ### Enabled Features

  - features.development.enable = true
  - features.desktop.enable = true
  - features.monitoring.enable = true (server mode)
  - features.ai-providers.enable = true
  - features.virtualization.enable = true

  ### Services

  **Monitoring**:
  - Prometheus (port 9090)
  - Grafana (port 3001)
  - Alertmanager (port 9093)

  **AI**:
  - Ollama (ROCm acceleration)
  - Multiple LLM providers configured

  **Development**:
  - Docker and containerization
  - Multiple language toolchains
  - VS Code, Neovim

  ### Network Configuration

  - Hostname: p620.home.freundcloud.com
  - Tailscale VPN enabled
  - Firewall: SSH (22) only external
  - Internal services: VPN-only access

  ### Deployment

  ```bash
  # Deploy to P620
  just p620

  # Or use smart deployment
  just quick-deploy p620
  ```

  ### Monitoring

  - Grafana: http://p620:3001
  - Prometheus: http://p620:9090

  ### Maintenance

  - Boot time target: <2 minutes
  - Monitoring: Self-monitored
  - Backups: Manual (planned automation)
```

### 3. API Documentation Generation

**What it does**: Documents custom functions and libraries

**API docs**:

```yaml
API Documentation:

For: lib/systemd-hardening.nix

Generated Documentation:
  # lib/README.md

  ## Library Functions

  ### mkHardenedService

  Creates a systemd service with security hardening.

  **Type**:
  ```nix
  mkHardenedService :: String -> AttrSet -> AttrSet
  ```

  **Arguments**:
  - `name`: Service name (string)
  - `config`: Service configuration (attrset)

  **Returns**: Hardened systemd service configuration

  **Example**:
  ```nix
  myService = mkHardenedService "myservice" {
    description = "My custom service";
    serviceConfig.ExecStart = "${pkgs.myapp}/bin/myapp";
  };
  ```

  **Security Features Applied**:
  - DynamicUser = true
  - ProtectSystem = "strict"
  - ProtectHome = true
  - NoNewPrivileges = true
  - PrivateTmp = true

  **Usage Notes**:
  - Automatically applies security best practices
  - Override individual settings as needed
  - Suitable for most services
```

### 4. Changelog Generation

**What it does**: Generates changelogs from git commits

**Changelog format**:

```yaml
Changelog Generation:

From: Git commit history

Generated Changelog:
  # CHANGELOG.md

  ## [Unreleased]

  ### Added
  - feat(agent): security-patrol for security monitoring (#234)
  - feat(agent): deployment-coordinator for orchestration (#235)
  - feat(skills): media skill for *arr stack (#233)

  ### Changed
  - refactor(modules): eliminate mkIf true anti-patterns (#231)
  - perf(p510): optimize boot time from 51min to <2min (#228)

  ### Fixed
  - fix(razer): resolve Stylix GNOME theme conflicts (#230)
  - fix(p510): fstrim service timeout configuration (#229)

  ### Security
  - security: add systemd hardening to all services (#232)

  ## [2.0.0] - 2025-01-15

  ### Added
  - Template-based architecture (95% code dedup)
  - Home Manager profile composition
  - Live USB installer system
  - MicroVM development environments

  ### Changed
  - Complete NixOS best practices implementation
  - Zero anti-patterns achieved
  - Documentation restructure

  **Full Changelog**: https://github.com/.../compare/v1.0.0...v2.0.0
```

### 5. Architecture Diagrams

**What it does**: Generates architecture documentation

**Diagram generation**:

```yaml
Architecture Documentation:

Generated Mermaid Diagrams:

  # docs/ARCHITECTURE.md

  ## System Architecture

  ### Host Relationships
  ```mermaid
  graph TB
    P620[P620 Workstation<br/>Monitoring Server]
    P510[P510 Server<br/>Media Server]
    Razer[Razer Laptop<br/>Mobile Dev]
    Samsung[Samsung Laptop<br/>Mobile]

    P620 -->|Monitors| P510
    P620 -->|Monitors| Razer
    P620 -->|Monitors| Samsung

    P510 -->|Metrics| P620
    Razer -->|Metrics| P620
    Samsung -->|Metrics| P620
  ```

  ### Module Dependencies
  ```mermaid
  graph LR
    Desktop[Desktop Module]
    Hyprland[Hyprland]
    Wayland[Wayland Support]
    Stylix[Stylix Theme]

    Desktop --> Hyprland
    Hyprland --> Wayland
    Desktop --> Stylix
  ```

  ### Data Flow
  ```mermaid
  sequenceDiagram
    participant App
    participant NodeExp as Node Exporter
    participant Prom as Prometheus
    participant Graf as Grafana

    App->>NodeExp: Expose metrics
    Prom->>NodeExp: Scrape (15s interval)
    Graf->>Prom: Query metrics
    Graf-->>User: Display dashboard
  ```
```

### 6. Documentation Synchronization

**What it does**: Keeps documentation in sync with code

**Sync detection**:

```yaml
Documentation Sync Analysis:

Outdated Documentation:

1. modules/services/prometheus.nix:
   Code changed: 2025-01-14
   Docs updated: 2025-01-10 ⚠️
   Status: OUT OF SYNC (4 days)

   Changes not documented:
     - New option: alertmanager.url
     - Updated default: retention = "90d"

   Action: Regenerate module documentation

2. hosts/p620/configuration.nix:
   Code changed: 2025-01-15
   Docs updated: 2025-01-15 ✅
   Status: IN SYNC

3. CHANGELOG.md:
   Last update: 2025-01-10
   New commits: 15 ⚠️
   Status: MISSING ENTRIES

   Action: Generate changelog for recent commits
```

### 7. Example Collection

**What it does**: Collects and documents usage examples

**Example documentation**:

```yaml
Examples Collection:

From: Live configurations

Generated Examples:
  # docs/EXAMPLES.md

  ## Configuration Examples

  ### Monitoring Setup

  #### Single Host Monitoring
  ```nix
  # hosts/p620/configuration.nix
  features.monitoring = {
    enable = true;
    mode = "server";
  };
  ```

  #### Multi-Host Monitoring
  ```nix
  # Monitoring server (p620)
  features.monitoring = {
    enable = true;
    mode = "server";
  };

  # Clients (razer, p510, samsung)
  features.monitoring = {
    enable = true;
    mode = "client";
    serverHost = "p620";
  };
  ```

  ### Development Environment

  #### Full Stack Development
  ```nix
  features.development = {
    enable = true;
    languages = {
      python = true;
      go = true;
      rust = true;
      javascript = true;
    };
  };
  ```

  #### Language-Specific
  ```nix
  features.development.languages.python = true;
  environment.systemPackages = with pkgs; [
    python311
    python311Packages.pip
    python311Packages.virtualenv
  ];
  ```
```

### 8. Quick Reference Cards

**What it does**: Generates concise reference cards

**Quick reference**:

```yaml
Quick Reference Generation:

  # docs/QUICK-REFERENCE.md

  ## NixOS Infrastructure Quick Reference

  ### Host Overview
  | Host    | Role              | IP              | Services              |
  |---------|-------------------|-----------------|-----------------------|
  | P620    | Workstation       | 192.168.1.100   | Prometheus, Grafana   |
  | P510    | Media Server      | 192.168.1.127   | Plex, *arr stack      |
  | Razer   | Mobile Dev        | DHCP            | Development tools     |
  | Samsung | Mobile            | DHCP            | Basic tools           |

  ### Common Commands
  ```bash
  # Deployment
  just p620              # Deploy to P620
  just quick-deploy HOST # Smart deploy

  # Testing
  just validate          # Full validation
  just test-host HOST    # Test specific host

  # Monitoring
  just grafana-status    # Check Grafana
  just prometheus-status # Check Prometheus
  ```

  ### Port Reference
  | Service     | Port | Host | Access         |
  |-------------|------|------|----------------|
  | SSH         | 22   | All  | External       |
  | Prometheus  | 9090 | P620 | VPN only       |
  | Grafana     | 3001 | P620 | VPN only       |
  | Node Exp    | 9100 | All  | Internal       |

  ### Emergency Procedures
  ```bash
  # Rollback
  sudo nixos-rebuild switch --rollback

  # Emergency deploy
  just emergency-deploy HOST

  # Check logs
  journalctl -u SERVICE -f
  ```
```

## Workflow

### Automated Documentation Generation

```bash
# Triggered by: /nix-docs or just generate-docs

1. **Analysis Phase**
   - Scan all modules
   - Extract options and types
   - Parse git commits
   - Identify changes

2. **Generation Phase**
   - Generate module docs
   - Create host documentation
   - Update API references
   - Build changelog
   - Create architecture diagrams

3. **Validation Phase**
   - Check doc completeness
   - Verify examples work
   - Validate links
   - Test code snippets

4. **Synchronization**
   - Update outdated docs
   - Add missing sections
   - Fix broken links
   - Commit changes
```

### Example Documentation Report

```markdown
# Documentation Generation Report
Generated: 2025-01-15 21:00:00

## Summary

Files Generated: 25
Files Updated: 12
Outdated Docs Fixed: 8
Coverage: 95%

## Generated Documentation

### Module Documentation (15 files)
- modules/services/prometheus/README.md ✅
- modules/services/grafana/README.md ✅
- modules/monitoring/node-exporter/README.md ✅
- ... (12 more)

### Host Documentation (4 files)
- hosts/p620/README.md ✅
- hosts/p510/README.md ✅
- hosts/razer/README.md ✅
- hosts/samsung/README.md ✅

### Reference Documentation (6 files)
- lib/README.md ✅
- docs/ARCHITECTURE.md ✅
- docs/EXAMPLES.md ✅
- docs/QUICK-REFERENCE.md ✅
- CHANGELOG.md ✅
- docs/API.md ✅

## Documentation Coverage

**Module Documentation**:
- Total modules: 141
- Documented: 134 (95%)
- Missing docs: 7 (5%)

**Code Examples**:
- Total examples: 45
- Tested: 45 (100%)
- Working: 45 (100%)

**Architecture Diagrams**:
- Host relationships: ✅
- Module dependencies: ✅
- Data flows: ✅
- Network topology: ✅

## Sync Status

**Up-to-Date**: 130 files ✅
**Outdated**: 0 files ✅
**Broken Links**: 0 ✅

## Next Steps

1. ✅ Review generated documentation
2. ⏭️ Commit documentation updates
3. ⏭️ Deploy documentation site (optional)
4. ⏭️ Set up automated sync

---

**Last Generation**: 2025-01-15 21:00:00
**Next Scheduled**: 2025-01-22 21:00:00 (weekly)
```

## Integration with Existing Tools

### With `/nix-docs` Command

```bash
# /nix-docs triggers documentation generation

/nix-docs                # Generate all documentation
/nix-docs --sync        # Sync outdated docs
/nix-docs --module M    # Document specific module
/nix-docs --changelog   # Update changelog only
```

### With CI/CD Pipeline

```yaml
# .github/workflows/docs.yml
name: Documentation
on:
  push:
    branches: [main]

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Generate Docs
        run: just generate-docs

      - name: Commit Updates
        run: |
          git add docs/
          git commit -m "docs: automated update"
          git push
```

### With Module Refactor

```bash
# Update docs after refactoring
Module Refactor → /nix-docs --sync
```

## Configuration

### Enable Documentation Sync

```nix
# modules/claude-code/documentation-sync.nix
{ config, lib, ... }:
{
  options.claude.documentation-sync = {
    enable = lib.mkEnableOption "Documentation synchronization";

    auto-generate = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Auto-generate docs on module changes";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      description = "Documentation generation schedule";
    };

    coverage-threshold = lib.mkOption {
      type = lib.types.int;
      default = 90;
      description = "Minimum documentation coverage percentage";
    };
  };
}
```

## Best Practices

### 1. Generate After Changes

```bash
# After module changes
/nix-docs --sync

# Before commits
just generate-docs
```

### 2. Validate Examples

```bash
# Test code examples
just test-docs

# Check links
just check-doc-links
```

### 3. Keep Changelog Current

```bash
# Update changelog weekly
/nix-docs --changelog
```

## Troubleshooting

### Outdated Documentation

**Issue**: Documentation doesn't reflect code

**Solution**:
```bash
# Force regeneration
/nix-docs --force --sync

# Check sync status
just doc-status
```

### Broken Links

**Issue**: Documentation contains broken links

**Solution**:
```bash
# Find broken links
just check-doc-links

# Auto-fix common issues
/nix-docs --fix-links
```

## Future Enhancements

1. **Interactive Documentation**: Live code examples
2. **Search Integration**: Full-text search
3. **Version Documentation**: Per-version docs
4. **Auto-Translation**: Multi-language support

## Agent Metadata

```yaml
name: documentation-sync
version: 1.0.0
priority: P3
impact: low-medium
effort: low
dependencies:
  - module-refactor agent
  - git repository
triggers:
  - keyword: documentation, docs, readme
  - command: /nix-docs
  - event: module changes
  - schedule: weekly
outputs:
  - docs/
  - README.md files
  - CHANGELOG.md
  - architecture diagrams
```
