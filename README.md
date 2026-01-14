# NixOS Infrastructure Hub

A sophisticated multi-host NixOS configuration management system achieving 95% code deduplication through
template-based architecture. Manages 4 active hosts with 141+ modular components, comprehensive automation,
and zero anti-patterns.

## Learning from This Repository

All changes, features, and implementations are documented through GitHub issues. Browse
[closed issues](https://github.com/olafkfreund/nixos_config/issues?q=is%3Aissue+is%3Aclosed) to see feature
implementations, bug fixes, security audits, performance optimizations, and integration patterns with
step-by-step plans and root cause analysis.

**Recent Notable Issues**:

- Issue #157 - Home Assistant with Tailscale and Cloud integration
- Issue #156 - NixOS best practices implementation (165 lines removed)
- Issue #155 - Template-based architecture achieving 95% deduplication
- Issue #154 - Media server monitoring with Plex/Tautulli exporters
- Issue #153 - MicroVM development environments

**Search by label**: `label:feature`, `label:security`, `label:monitoring`, `label:performance`

Check [open issues](https://github.com/olafkfreund/nixos_config/issues) for current work and future plans.

## Quick Start

```bash
git clone https://github.com/olafkfreund/nixos_config.git
cd nixos_config
just validate-quick              # Quick validation (30s)
just deploy                      # Deploy to current host
just help-extended               # Extended help
```

## Architecture Overview

**Key Statistics**: 95% code deduplication, 4 active hosts, 141+ modules, 140+ automation commands, zero anti-patterns

**Template System** (hosts/templates/):

- workstation.nix - Full desktop development (P620)
- laptop.nix - Mobile with power management (Razer, Samsung)
- server.nix - Headless operation (P510)

**Home Manager Profiles** (home/profiles/):

- server-admin - Minimal CLI server administration
- developer - Full development toolchain
- desktop-user - Complete desktop environment
- laptop-user - Mobile-optimized with battery management

**Profile Compositions**:

- P620: developer + desktop-user
- P510: server-admin + developer
- Razer/Samsung: developer + laptop-user

**Active Infrastructure**:

- P620: AMD workstation (primary development, AI host)
- P510: Intel Xeon server (media server with Plex, headless)
- Razer: Intel/NVIDIA laptop (mobile development)
- Samsung: Intel laptop (mobile)

**Note**: DEX5550 offline, monitoring stack (Prometheus/Grafana/Loki) removed for simplification.

## Directory Structure

```text
├── flake.nix                    # Main flake configuration
├── justfile                     # 140+ automation commands
├── modules/                     # 141+ modular components
├── hosts/
│   ├── templates/               # Host type templates
│   ├── p620/, p510/, razer/, samsung/
│   └── common/
├── home/profiles/               # Role-based profiles
├── Users/                       # Per-user configurations
├── secrets/                     # Agenix encrypted secrets
├── scripts/                     # Management scripts
├── .claude/                     # Claude Code integration
└── docs/                        # Documentation
```

Details: See "Template System" and "Active Infrastructure" sections above.

## Command Reference

| Category     | Command                         | Purpose                                           | Time |
| ------------ | ------------------------------- | ------------------------------------------------- | ---- |
| **Test**     | `just check-syntax`             | Syntax validation                                 | 5s   |
|              | `just validate-quick`           | Quick validation                                  | 30s  |
|              | `just validate`                 | Comprehensive validation                          | 2min |
|              | `just test-host HOST`           | Test specific host                                | 60s  |
|              | `just test-all-parallel`        | Test all hosts in parallel                        | 2min |
| **Deploy**   | `just deploy`                   | Deploy to local system                            | 1min |
|              | `just HOST`                     | Deploy to specific host (p620/p510/razer/samsung) | 1min |
|              | `just quick-deploy HOST`        | Deploy only if changed                            | 30s  |
|              | `just quick-all`                | Test + deploy all if tests pass                   | 3min |
|              | `just deploy-all-parallel`      | Deploy to all simultaneously                      | 2min |
|              | `just emergency-deploy HOST`    | Skip tests (critical fixes only)                  | 30s  |
| **Debug**    | `just status`                   | System health status                              | 5s   |
|              | `just diff HOST`                | Show configuration changes                        | 10s  |
|              | `just analyze HOST`             | Configuration analysis                            | 30s  |
|              | `just debug-module HOST MODULE` | Debug module evaluation                           | 30s  |
| **Maintain** | `just cleanup`                  | Clean old generations                             | 30s  |
|              | `just gc-aggressive`            | Aggressive garbage collection                     | 2min |
|              | `just optimize`                 | Optimize nix store                                | 5min |
|              | `just update-flake`             | Update flake inputs                               | 1min |
|              | `just secrets`                  | Interactive secrets manager                       | -    |
| **Dev**      | `just format`                   | Format all Nix files                              | 10s  |
|              | `just lint-all`                 | Lint all files                                    | 30s  |
|              | `just security-scan`            | Security scan                                     | 1min |

**Full command list**: `just --list` (140+ commands) or `just help-extended`

## Development Workflow

All development follows issue-driven workflow. See docs/GITHUB-WORKFLOW.md for complete details.

```bash
# Create task and branch
/nix-new-task                  # Create GitHub issue with research
gh issue develop N --checkout  # Create feature branch

# Develop and test
just test-host HOST            # Test changes
just validate                  # Full validation

# Submit changes
git commit -m "type: description (#N)"
gh pr create --fill            # Create pull request
```

**Commands**: `/nix-new-task`, `/nix-check-tasks`, `/nix-security`, `/nix-fix`, `/nix-review`

**Workflow types**: Feature development, bug fixes, security audits (see GitHub issues for examples)

## Feature System

Configuration uses feature flags. Examples from active hosts:

- **P620**: development, desktop, virtualization, ai
- **P510**: media (Plex, Radarr, Sonarr), virtualization
- **Razer/Samsung**: development, desktop, laptop power management

```nix
features = {
  development.enable = true;
  desktop.enable = true;
  virtualization.enable = true;
  ai.enable = true;
  media.enable = true;  # Radarr, Sonarr, Plex, etc.
};
```

See host configurations in `hosts/*/configuration.nix` for complete examples.

## Documentation

**Essential** (read before coding):

- docs/PATTERNS.md - NixOS best practices
- docs/NIXOS-ANTI-PATTERNS.md - Critical mistakes to avoid
- docs/GITHUB-WORKFLOW.md - Issue-driven workflow

**Reference**:

- .claude/CLAUDE.md - Claude Code integration guide
- .agent-os/product/roadmap.md - Development roadmap
- GitHub Issues - Implementation examples and learning material

**Commands**: `just help-extended`, `/nix-help`

## Secrets Management

```bash
just secrets                       # Interactive secrets manager
./scripts/manage-secrets.sh create SECRET_NAME
./scripts/manage-secrets.sh edit SECRET_NAME
./scripts/manage-secrets.sh rekey
./scripts/manage-secrets.sh status
```

**Security Pattern**:

```nix
# WRONG - Secrets in Nix store
services.myapp.password = builtins.readFile "/secrets/password";

# CORRECT - Runtime loading
services.myapp.passwordFile = config.age.secrets.password.path;
```

## Advanced Features

**AI Providers**: `ai-cli "question"` - Multi-provider with automatic fallback (Claude, OpenAI, Gemini, Ollama)

**MicroVMs**: `just start-microvm dev-vm` - Isolated development environments (dev-vm, test-vm, playground-vm)

**Live USB**: `just build-live p620` - Hardware-specific installers with automated setup

**Media Server**: `features.media.enable = true` - Complete arr stack (Plex, Radarr, Sonarr, Lidarr, Prowlarr)

See GitHub issues #153, #154, #157 for implementation details and usage examples.

## Troubleshooting

| Issue         | Primary Command       | Alternative                    |
| ------------- | --------------------- | ------------------------------ |
| Build fails   | `just check-syntax`   | `nix flake check --show-trace` |
| Deploy fails  | `just diff HOST`      | `just emergency-deploy HOST`   |
| Secrets error | `just secrets-status` | `just test-secrets`            |
| Performance   | `just perf-test`      | `just analyze HOST`            |
| General debug | `just status`         | `just efficiency-report`       |

See closed GitHub issues for common problems and solutions.

## Why This Architecture

Template-based design achieves 95% code deduplication with zero anti-patterns. Results:

| Metric             | Before      | After       | Improvement |
| ------------------ | ----------- | ----------- | ----------- |
| Code Deduplication | 30% shared  | 95% shared  | +317%       |
| Host Configuration | 500 lines   | 50 lines    | -90%        |
| Total Code         | 4,000 lines | 1,200 lines | -70%        |
| Anti-Patterns      | 15+         | 0           | -100%       |
| Deployment Time    | 5 min       | 30 sec      | -90%        |

**Benefits**: Single-point updates, consistent behavior across host types, easy testing through template
validation, minimal unique configuration per host, zero technical debt, automated workflows.

See GitHub issues #155, #156 for implementation details and benchmarks.

## Contributing

Read docs/PATTERNS.md and docs/NIXOS-ANTI-PATTERNS.md first. Create GitHub issue for all work
(`/nix-new-task`), test thoroughly (`just validate`), review code (`/nix-review`), and follow conventional
commits format. Zero tolerance for anti-patterns.

**Quality Requirements**: Syntax validation passes, build tests succeed, no anti-patterns, security
hardening applied, documentation complete.

See docs/GITHUB-WORKFLOW.md for complete development process.

## Project Status

**Current**: Phase 8.1 Complete - Zero anti-patterns, 95% deduplication, comprehensive automation

**Recent Accomplishments**: Zero anti-patterns across codebase, 95% code deduplication through templates,
165 lines removed through proper abstractions, complete GitHub issue-driven workflow, comprehensive
documentation.

See .agent-os/product/roadmap.md for detailed roadmap and GitHub issues for active development.

## Support and Resources

**Getting Help**:

- GitHub Issues - Learn from closed issues, ask questions in new issues
- Documentation - See docs/ directory for comprehensive guides
- Commands - `just help-extended` for extended command help

**Quick Reference**:

```bash
just --list                    # All 140+ Justfile commands
just status                    # System health status
just efficiency-report         # Metrics and statistics
```

## License

See repository for license information.

---

Built with NixOS, Flakes, Home Manager, Agenix
Architecture: Template-based, modular, zero anti-patterns
Automation: 140+ Justfile commands, issue-driven workflow
Documentation: All changes tracked in GitHub issues
