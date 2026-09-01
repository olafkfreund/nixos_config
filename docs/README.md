# NixOS Infrastructure Documentation

Last Updated: 2026-09-01

## Overview

Documentation index for the NixOS configuration. Files are grouped by
purpose. All docs are plain technical Markdown.

## Core Documentation

`PATTERNS.md`
Comprehensive NixOS patterns and best practices. Module system, package
writing conventions, security patterns, performance considerations.
Read before writing modules or packages.

`NIXOS-ANTI-PATTERNS.md`
Anti-patterns to avoid, review checklist, and community-aligned
practices. Read before opening a PR.

`UPDATE-DEPLOY.md`
Reference for `just update-commit-deploy` and the `nhs` / `nhsb` zsh
shortcuts. Idiot-proof flake-lock bump + commit + push + build + switch
flow, including remote hosts and offline-host pre-builds.

`MCP-GUIDE.md`
Model Context Protocol server integration: enabled servers, setup, and
troubleshooting.

## Architecture

Rendered as the Architecture tab of the site; also readable in-repo.

`architecture/desktop.md`
Nixarchy / Omarchy on Hyprland — the sole Wayland session on all three
hosts. Sessions and greeters, the two Omarchy-written files at the flake
root, why `programs.hyprland` is forced off, Lua dispatchers, screen
sharing, and what was removed. Read before touching anything
Hyprland-adjacent.

`architecture/theming.md`
Stylix. The active Omarchy theme is the source of truth for colours; this
covers the mapping onto base16 and what only follows at the next rebuild.

`architecture/template-system.md`
The single parameterised host template (workstation | laptop).

`architecture/feature-flags.md`, `architecture/hardware-profiles.md`,
`architecture/overlays.md`, `architecture/secrets.md`,
`architecture/home-manager.md`, `architecture/philosophy.md`
The remaining architecture notes.

## Guides

Procedural guides for setup, deployment, and routine workflows.

`guides/HOST_SETUP.md`
Procedure for adding a new host (directory layout, host SSH key,
variables, secrets wiring).

`guides/deployment-guide.md`
Full deployment reference: smart deploy, parallel deploy, fast/cached
modes, build-locally-deploy-remotely, emergency deploy.

`guides/UPDATE-WORKFLOW.md`
Update preview workflow with `nvd` (Nix Version Diff): preview-updates,
new-package discovery, integrated `just update-workflow`.

`guides/GITHUB-WORKFLOW.md`
Issue-driven development workflow: branch naming, conventional commits,
PR process, review standards.

`guides/CACHE-STRATEGY.md`
Substituters in use (cache.nixos.org, nix-community.cachix.org, plus two
flake-level caches) and how to speed up builds without a cache server —
there is none.

`guides/PACKAGE-SYSTEM-USAGE.md`
Package categorisation: system vs user, conditional package loading,
template-driven defaults.

## Applications

Application-specific setup notes.

`applications/CITRIX-WORKSPACE-SETUP.md`
Citrix Workspace install and configuration. Requires manual tarball
download (see `pkgs/citrix-workspace/fetch-citrix.sh`); the package is
provided via overlay.

`applications/WAYDROID-SETUP.md`
Waydroid Android container setup.

`applications/flaresolverr-deployment.md`
FlareSolverr proxy deployment.

`applications/GITLAB-RUNNER-SETUP.md`
GitLab Runner configuration on NixOS.

`applications/VSCODE_EXTENSIONS.md`
Declarative VS Code extension management.

`applications/screensharing_cosmic.md`
Screen sharing under COSMIC desktop with Wayland. Historical — COSMIC is
parked (`desktop.cosmic.enable = false` on every host). For the live path see
`architecture/desktop.md`.

`applications/P620-BIOS-NUMA-Configuration.md`
P620 BIOS and NUMA tuning.

`applications/sunshine.md`
Sunshine desktop streaming on p510 (Moonlight clients): setup, and the four
traps — user-service startup, black screen from a DPMS-off output, CSRF
origins, and the read-only web UI.

## Tooling

Development tooling and Claude Code documentation.

`tooling/CLAUDE-CODE-OPTIMIZATION.md`
Claude Code performance and configuration tuning.

`tooling/claude-code-update-2.0.54.md`
Update notes for Claude Code 2.0.54.

`tooling/Claude-Powerline.md`
Powerline integration for Claude Code.

`tooling/Github-spec-kit.md`
GitHub spec-kit for Spec-Driven Development.

## NixOS Command System

`Nixos/README.md`
Command system overview.

`Nixos/COMMANDS-INDEX.md`
Full command index by category.

`Nixos/Command-System-Overview.md`
Architecture and extension model.

`Nixos/Quick-Reference.md`
Common commands at a glance.

`Nixos/Update-Checker-Guide.md`
Automated update checking and configuration.

## Documentation Standards

Format

- Markdown (`.md`), CommonMark.
- No emojis or decorative icons.
- Code blocks for examples.
- Concise technical prose.

Organisation

- One topic per file.
- Cross-reference using relative paths.
- Filenames: `UPPERCASE-WITH-DASHES.md` for top-level, descriptive
  lowercase for application notes.

Maintenance

- Top-of-file `Last Updated:` date.
- Remove obsolete docs rather than letting them rot.
- Reflect repository state (templates, hosts, modules) accurately.

## Contributing

When adding documentation:

1. Pick the right category folder.
2. Add a `Last Updated:` line at the top.
3. No emojis or icons.
4. Update this index in the same change.
5. Cross-reference related docs.

## Quick Navigation

New to the repo
Start with `PATTERNS.md`, then `NIXOS-ANTI-PATTERNS.md`, then the root
`README.md`. For the desktop, `architecture/desktop.md`.

Site nav
`mkdocs.yml` (Backstage TechDocs) and `mkdocs-full.yml` (the published site)
are hand-synced by design. A nav change must land in **both**.

Deploying changes
`UPDATE-DEPLOY.md` for the routine flow; `guides/deployment-guide.md`
for advanced cases.

Adding a host
`guides/HOST_SETUP.md`.

Reviewing or contributing
`guides/GITHUB-WORKFLOW.md` and `NIXOS-ANTI-PATTERNS.md`.

Command reference
`Nixos/COMMANDS-INDEX.md` and `just --list`.
