# NixOS Infrastructure Documentation

Last Updated: 2026-01-25

## Overview

This directory contains comprehensive documentation for the NixOS infrastructure configuration. Documentation is organized by category for easy navigation.

## Core Documentation

Essential documentation for NixOS development and best practices.

**PATTERNS.md**
- NixOS best practices and patterns
- Module system usage
- Package writing conventions
- Security patterns
- Performance optimization
- Read this before writing any Nix code

**NIXOS-ANTI-PATTERNS.md**
- Critical anti-patterns to avoid
- Common mistakes and their fixes
- Code review checklist
- Community standards alignment
- Read this to avoid common pitfalls

**MCP-GUIDE.md**
- Model Context Protocol server integration
- Available MCP servers and features
- Setup and configuration
- Service integrations (Atlassian, LinkedIn, WhatsApp, Obsidian)
- Troubleshooting guide

## Guides

Procedural guides for system setup, deployment, and workflows.

**guides/HOST_SETUP.md**
- Host configuration procedures
- Initial setup steps
- Hardware-specific considerations

**guides/deployment-guide.md**
- Deployment procedures
- Build and test workflows
- Production deployment strategy

**guides/UPDATE-WORKFLOW.md**
- System update procedures
- Package update management
- Testing and validation

**guides/GITHUB-WORKFLOW.md**
- Issue-driven development process
- Branch management
- Pull request procedures
- Code review standards

**guides/CACHE-STRATEGY.md**
- Binary cache configuration
- Cache optimization
- Multi-tier caching setup

**guides/CACHIX-ANALYSIS.md**
- Cachix integration analysis
- Performance considerations
- Setup procedures

**guides/PACKAGE-SYSTEM-USAGE.md**
- Three-tier package architecture
- Package categorization
- System vs user packages
- Conditional package loading

**guides/GEMINI_CLI_FEATURE.md**
- Gemini CLI integration
- Features and capabilities
- Configuration guide

## Applications

Application-specific setup and configuration guides.

**applications/CITRIX-WORKSPACE-SETUP.md**
- Citrix Workspace installation
- Configuration procedures
- Troubleshooting

**applications/WAYDROID-SETUP.md**
- Waydroid Android container setup
- Configuration and usage
- Known issues

**applications/flaresolverr-deployment.md**
- FlareSolverr proxy deployment
- Configuration and integration
- Usage guide

**applications/GITLAB-RUNNER-SETUP.md**
- GitLab Runner configuration
- NixOS integration
- Job execution setup

**applications/VSCODE_EXTENSIONS.md**
- VS Code extension management
- NixOS configuration
- Recommended extensions

**applications/screensharing_cosmic.md**
- Screen sharing in COSMIC desktop
- Wayland configuration
- Troubleshooting guide

**applications/P620-BIOS-NUMA-Configuration.md**
- P620 BIOS settings
- NUMA configuration
- Performance tuning

## Tooling

Development tooling and Claude Code documentation.

**tooling/CLAUDE-CODE-OPTIMIZATION.md**
- Claude Code performance optimization
- Configuration tuning
- Best practices

**tooling/claude-code-update-2.0.54.md**
- Claude Code 2.0.54 update notes
- New features
- Migration guide

**tooling/Claude-Powerline.md**
- Powerline shell integration
- Theme configuration
- Claude Code integration

**tooling/Github-spec-kit.md**
- GitHub specification toolkit
- Template usage
- Workflow automation

## NixOS Command System

Command system documentation and reference guides.

**Nixos/README.md**
- Command system overview
- Usage instructions

**Nixos/COMMANDS-INDEX.md**
- Complete command index
- Command categories
- Quick reference

**Nixos/Command-System-Overview.md**
- Architecture overview
- Command implementation
- Extension guide

**Nixos/Quick-Reference.md**
- Common commands
- Quick lookup guide
- Usage examples

**Nixos/Update-Checker-Guide.md**
- Update checking system
- Automation procedures
- Configuration guide

## Documentation Standards

All documentation follows these standards:

**Format:**
- Markdown format (.md)
- No emojis or decorative icons
- Clear section headers
- Code blocks for examples
- Professional technical writing

**Organization:**
- Categorized by purpose
- Logical folder structure
- Consistent naming conventions
- Cross-referenced where appropriate

**Maintenance:**
- Last Updated date at top of each file
- Status indicator (Active, Deprecated, etc.)
- Regular reviews for accuracy
- Obsolete docs removed promptly

## Contributing

When adding new documentation:

1. Choose appropriate category folder
2. Follow naming conventions (UPPERCASE-WITH-DASHES.md)
3. Include Last Updated date
4. No emojis or icons
5. Update this README index
6. Cross-reference related documentation

## Quick Navigation

**New to NixOS?**
Start with PATTERNS.md and NIXOS-ANTI-PATTERNS.md

**Setting up a host?**
See guides/HOST_SETUP.md and guides/deployment-guide.md

**Working with AI tools?**
See MCP-GUIDE.md and tooling/ folder

**Deploying applications?**
See applications/ folder for specific guides

**Need command reference?**
See Nixos/COMMANDS-INDEX.md

## Support

For infrastructure questions or documentation issues:
- Check relevant documentation first
- Review PATTERNS.md for best practices
- Consult NIXOS-ANTI-PATTERNS.md for common issues
- Reference GitHub workflow for contribution process
