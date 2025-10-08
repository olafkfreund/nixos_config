# NixOS Configuration Architecture Hierarchy

> Last Updated: 2025-10-08
> Repository: NixOS Infrastructure Hub

## Table of Contents

1. [Overview](#overview)
2. [Three-Tier Architecture](#three-tier-architecture)
3. [Detailed Import Chain](#detailed-import-chain)
4. [Module Organization](#module-organization)
5. [Configuration Flow](#configuration-flow)

---

## Overview

This repository implements a sophisticated **three-tier template-based architecture** achieving **95% code deduplication** through:

- **Host Templates**: 3 hardware-optimized templates (workstation, laptop, server)
- **Profile Compositions**: 4 role-based Home Manager profiles
- **Module System**: 141+ conditional feature modules

---

## Three-Tier Architecture

### Tier 1: Host Templates (Hardware Layer)

```
┌─────────────────────────────────────────────────────────────┐
│                    Host Templates                           │
│                  lib/hostTypes.nix                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐ │
│  │  Workstation   │  │    Laptop      │  │    Server    │ │
│  │                │  │                │  │              │ │
│  │ • Full Desktop │  │ • Power Mgmt   │  │ • Headless   │ │
│  │ • Development  │  │ • Mobile HW    │  │ • Services   │ │
│  │ • Gaming       │  │ • Battery Opt  │  │ • Monitoring │ │
│  │ • AI Stack     │  │ • Development  │  │ • Minimal    │ │
│  │                │  │                │  │              │ │
│  │ Used by: P620  │  │ Used by: Razer │  │ Used by:     │ │
│  │          P510* │  │          Samsung│  │  DEX5550     │ │
│  └────────────────┘  └────────────────┘  └──────────────┘ │
│                                                             │
│  * P510 is workstation hardware but server role            │
└─────────────────────────────────────────────────────────────┘
```

### Tier 2: Home Manager Profiles (Role Layer)

```
┌─────────────────────────────────────────────────────────────┐
│              Home Manager Role Profiles                     │
│                home/profiles/                               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────┐  ┌───────────┐  ┌────────────┐ ┌─────────┐│
│  │ Developer │  │  Desktop   │  │Laptop User │ │ Server  ││
│  │           │  │   User     │  │            │ │  Admin  ││
│  │ • Git     │  │ • Firefox  │  │ • Battery  │ │ • CLI   ││
│  │ • VSCode  │  │ • Chrome   │  │ • Suspend  │ │ • SSH   ││
│  │ • Neovim  │  │ • Hyprland │  │ • Laptop   │ │ • Tmux  ││
│  │ • Docker  │  │ • Waybar   │  │   Tools    │ │ • Htop  ││
│  │ • Lang    │  │ • Terminal │  │ • Power    │ │ • Basic ││
│  │   Tools   │  │ • Media    │  │   Profile  │ │   Tools ││
│  └───────────┘  └───────────┘  └────────────┘ └─────────┘│
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Tier 3: Profile Compositions (User+Host Layer)

```
┌─────────────────────────────────────────────────────────────┐
│           Profile Compositions Per Host                     │
│              Users/olafkfreund/                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  P620 (Full Workstation)                                    │
│  ├─→ Developer Profile                                      │
│  └─→ Desktop User Profile                                   │
│      = Full development + Complete desktop                  │
│                                                             │
│  Razer (Mobile Development)                                 │
│  ├─→ Developer Profile                                      │
│  └─→ Laptop User Profile                                    │
│      = Full development + Mobile optimizations              │
│                                                             │
│  P510 (Dev Server)                                          │
│  ├─→ Server Admin Profile                                   │
│  └─→ Developer Profile                                      │
│      = Server management + Development tools                │
│                                                             │
│  DEX5550 (Pure Server)                                      │
│  └─→ Server Admin Profile                                   │
│      = Server management only                               │
│                                                             │
│  Samsung (Mobile Workstation)                               │
│  ├─→ Developer Profile                                      │
│  └─→ Laptop User Profile                                    │
│      = Full development + Mobile optimizations              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Detailed Import Chain

### Level 1: Flake Root

```
flake.nix (Root Entry Point)
│
├─ inputs (External Dependencies)
│  ├─ nixpkgs (nixos-unstable)
│  ├─ home-manager
│  ├─ agenix (secrets)
│  ├─ hyprland
│  ├─ nur, stylix, lanzaboote
│  └─ custom inputs (nixai, spicetify, etc.)
│
├─ lib/ (Helper Functions)
│  ├─ hostTypes.nix (Template definitions)
│  └─ flake-helpers.nix (Utility functions)
│
├─ overlays (Package Modifications)
│  ├─ customPkgs overlay
│  ├─ zjstatus overlay
│  └─ CMake compatibility fixes
│
└─ nixosConfigurations (Host Definitions)
   ├─ p620    → makeNixosSystem "p620"
   ├─ p510    → makeNixosSystem "p510"
   ├─ razer   → makeNixosSystem "razer"
   ├─ samsung → makeNixosSystem "samsung"
   └─ dex5550 → makeNixosSystem "dex5550"
```

### Level 2: Host Configuration

```
hosts/{HOST}/configuration.nix
│
├─ Hardware Detection
│  └─ ./nixos/hardware-configuration.nix
│
├─ Host Type Template (from lib/hostTypes.nix)
│  ├─ hostTypes.workstation (P620, P510)
│  ├─ hostTypes.laptop (Razer, Samsung)
│  └─ hostTypes.server (DEX5550)
│
├─ Host-Specific Modules
│  ├─ ./nixos/boot.nix
│  ├─ ./nixos/cpu.nix (Intel/AMD specific)
│  ├─ ./nixos/gpu.nix (NVIDIA/AMD specific)
│  ├─ ./nixos/power.nix (laptop only)
│  └─ ./nixos/network.nix
│
├─ Global Module System (auto-imported via modules/default.nix)
│  │  (See Module Organization section)
│  │
│  └─ Feature Flag Configuration
│     ├─ features.development.enable = true/false
│     ├─ features.desktop.enable = true/false
│     ├─ features.virtualization.enable = true/false
│     ├─ features.monitoring.enable = true/false
│     └─ features.ai.enable = true/false
│
└─ Home Manager Integration
   └─ Users/{USER}/{HOST}_home_profile.nix
```

### Level 3: Module System

```
modules/default.nix (Central Registry)
│
├─ Core System Modules (always loaded)
│  ├─ core.nix (essential system config)
│  ├─ monitoring.nix (system observability)
│  ├─ performance.nix (optimization)
│  └─ server.nix (server-specific)
│
├─ Feature Modules (conditional based on features.*)
│  ├─ development.nix
│  ├─ desktop.nix
│  ├─ virtualization.nix
│  ├─ cloud.nix
│  ├─ programs.nix
│  └─ email.nix
│
├─ Service Modules (70+ individual services)
│  └─ services/default.nix
│     ├─ openssh/
│     ├─ docker/
│     ├─ bluetooth/
│     ├─ sound/
│     └─ ... 66 more services
│
├─ Infrastructure Modules
│  ├─ ai/default.nix (4 AI providers)
│  ├─ containers/default.nix (Docker, Podman)
│  ├─ security/default.nix (hardening)
│  ├─ networking/tailscale.nix (VPN)
│  ├─ secrets/api-keys.nix (agenix)
│  └─ microvms/default.nix (3 MicroVMs)
│
└─ Common Utilities
   ├─ common/default.nix
   └─ common/ai-defaults.nix
```

### Level 4: Home Manager

```
home/default.nix (Home Manager Entry)
│
├─ User Environment Categories
│  ├─ browsers/default.nix
│  │  ├─ Firefox
│  │  ├─ Chrome
│  │  └─ Edge
│  │
│  ├─ desktop/default.nix
│  │  ├─ hyprland/ (Wayland compositor)
│  │  ├─ waybar/ (status bar)
│  │  ├─ terminals/ (Alacritty, Kitty, Ghostty)
│  │  ├─ walker/ (launcher)
│  │  └─ theme/ (GTK, Qt, Stylix)
│  │
│  ├─ shell/default.nix
│  │  ├─ zsh/ (shell config)
│  │  ├─ starship/ (prompt)
│  │  ├─ tmux/ (multiplexer)
│  │  └─ zellij/ (modern multiplexer)
│  │
│  ├─ development/default.nix
│  │  ├─ vscode/
│  │  ├─ neovim/
│  │  ├─ git/
│  │  └─ languages/
│  │
│  ├─ media/
│  │  ├─ music.nix (Spotify, etc.)
│  │  └─ spice_themes.nix
│  │
│  └─ games/
│     └─ steam.nix
│
└─ User-Specific Imports
   └─ Users/{USER}/{HOST}_home_profile.nix
      ├─ ../../home/profiles/{PROFILE}/default.nix
      ├─ ../../hosts/{HOST}/nixos/env.nix
      └─ Additional host-specific configs
```

---

## Module Organization

### Complete Module Map (141+ Modules)

```
modules/
│
├─ Category Modules (19 top-level)
│  ├─ core.nix ........................... Essential system config
│  ├─ monitoring.nix ..................... Prometheus, Grafana, exporters
│  ├─ performance.nix .................... System optimization
│  ├─ server.nix ......................... Server-specific config
│  ├─ development.nix .................... Dev environments, languages
│  ├─ desktop.nix ........................ Desktop environment
│  ├─ virtualization.nix ................. Docker, Podman, VMs
│  ├─ cloud.nix .......................... Cloud provider tools
│  ├─ programs.nix ....................... Application programs
│  ├─ email.nix .......................... Email client setup
│  ├─ services/default.nix ............... 70+ service modules
│  ├─ ai/default.nix ..................... AI provider integration
│  ├─ containers/default.nix ............. Container runtimes
│  ├─ security/default.nix ............... Security hardening
│  ├─ common/default.nix ................. Common utilities
│  ├─ common/ai-defaults.nix ............. AI defaults
│  ├─ networking/tailscale.nix ........... VPN networking
│  ├─ secrets/api-keys.nix ............... Agenix secrets
│  └─ microvms/default.nix ............... MicroVM configs
│
├─ Service Modules (70+)
│  └─ services/
│     ├─ openssh/ ....................... SSH server
│     ├─ docker/ ........................ Container runtime
│     ├─ bluetooth/ ..................... Bluetooth support
│     ├─ sound/ ......................... Audio system
│     ├─ ollama/ ........................ Local AI inference
│     ├─ greetd/ ........................ Login manager
│     ├─ power/ ......................... Power management
│     ├─ flatpak/ ....................... Flatpak support
│     ├─ print/ ......................... Printing system
│     ├─ systemd/ ....................... Systemd units
│     ├─ xserver/ ....................... X11 server
│     ├─ libinput/ ...................... Input device config
│     ├─ logind/ ........................ Login handling
│     ├─ gnome/ ......................... GNOME integration
│     ├─ atuin/ ......................... Shell history
│     ├─ sunshine/ ...................... Game streaming
│     ├─ tabby/ ......................... AI code assistant
│     ├─ mtr/ ........................... Network diagnostics
│     ├─ mandb/ ......................... Manual pages
│     ├─ flaresolverr/ .................. Captcha solver
│     ├─ github/ ........................ GitHub CLI tools
│     ├─ dns/ ........................... DNS configuration
│     ├─ cron/ .......................... Scheduled tasks
│     └─ ... 46 more services
│
├─ Desktop Modules (30+)
│  └─ desktop/
│     ├─ wlr/ ........................... Wayland compositor base
│     ├─ gtk/ ........................... GTK theming
│     ├─ plasma/ ........................ KDE Plasma
│     ├─ vnc/ ........................... Remote desktop
│     ├─ remote/ ........................ Remote access
│     └─ cloud-sync/ .................... Cloud synchronization
│
├─ Development Modules (15+)
│  └─ development/
│     └─ (Specific language environments, IDEs, etc.)
│
├─ AI Modules (5)
│  └─ ai/
│     ├─ default.nix .................... AI provider coordination
│     └─ providers/
│        ├─ anthropic.nix ............... Claude integration
│        ├─ openai.nix .................. GPT integration
│        ├─ gemini.nix .................. Gemini integration
│        └─ ollama.nix .................. Local AI models
│
├─ Security Modules (10+)
│  └─ security/
│     ├─ default.nix .................... Security hardening
│     ├─ secrets.nix .................... Agenix integration
│     └─ (Various hardening modules)
│
├─ MicroVM Modules (4)
│  └─ microvms/
│     ├─ default.nix .................... MicroVM coordination
│     ├─ common.nix ..................... Shared VM config
│     ├─ dev-vm.nix ..................... Development VM
│     ├─ test-vm.nix .................... Testing VM
│     └─ playground-vm.nix .............. Experimental VM
│
└─ Infrastructure Modules (50+)
   ├─ fonts/ ............................ Font configurations
   ├─ nix/ .............................. Nix system config
   ├─ nix-index/ ........................ Nix package indexing
   ├─ nixos/ ............................ NixOS-specific modules
   ├─ storage/ .......................... Storage management
   ├─ system/ ........................... System utilities
   ├─ system-scripts/ ................... Custom scripts
   ├─ system-utils/ ..................... Utility functions
   ├─ tools/ ............................ Development tools
   ├─ virt/ ............................. Virtualization support
   ├─ helpers/ .......................... Helper functions
   ├─ overlays/ ......................... Package overlays
   ├─ pkgs/ ............................. Custom packages
   ├─ scripts/ .......................... Management scripts
   ├─ ssh/ .............................. SSH configuration
   ├─ webcam/ ........................... Webcam support
   ├─ scrcpy/ ........................... Android screen mirroring
   ├─ obsidian/ ......................... Obsidian notes
   ├─ office/ ........................... Office applications
   ├─ spell/ ............................ Spell checking
   └─ funny/ ............................ Fun/entertainment apps
```

---

## Configuration Flow

### Build-Time Flow

```
1. nix build .#nixosConfigurations.{HOST}.config.system.build.toplevel
   │
   ├─→ 2. Read flake.nix
   │      └─→ Load inputs (nixpkgs, home-manager, etc.)
   │
   ├─→ 3. Evaluate makeNixosSystem for host
   │      ├─→ Apply overlays
   │      ├─→ Set specialArgs (pkgs-stable, username, etc.)
   │      └─→ Build module list
   │
   ├─→ 4. Load host configuration
   │      ├─→ hosts/{HOST}/configuration.nix
   │      ├─→ Apply host template (workstation/laptop/server)
   │      └─→ Load hardware-configuration.nix
   │
   ├─→ 5. Evaluate modules/default.nix
   │      ├─→ Load all 19 module categories
   │      ├─→ Evaluate feature flags
   │      └─→ Conditionally load 141+ modules
   │
   ├─→ 6. Evaluate home-manager
   │      ├─→ Load Users/{USER}/{HOST}_home_profile.nix
   │      ├─→ Import role profiles (developer, desktop-user, etc.)
   │      └─→ Load home/default.nix categories
   │
   ├─→ 7. Merge all configurations
   │      ├─→ Resolve conflicts (lib.mkForce, lib.mkDefault)
   │      ├─→ Apply assertions and warnings
   │      └─→ Validate configuration
   │
   └─→ 8. Build system closure
          ├─→ Build packages
          ├─→ Generate systemd units
          ├─→ Create configuration files
          └─→ Build boot artifacts
```

### Runtime Flow

```
1. System Boot
   │
   ├─→ 2. Load kernel and initrd
   │
   ├─→ 3. systemd starts
   │      ├─→ Load systemd units
   │      ├─→ Start essential services
   │      └─→ Mount filesystems
   │
   ├─→ 4. Agenix decrypts secrets
   │      └─→ Secrets available at /run/agenix/
   │
   ├─→ 5. Network initialization
   │      ├─→ Tailscale connects
   │      └─→ DNS configured
   │
   ├─→ 6. Service startup (based on feature flags)
   │      ├─→ Development: Docker, Ollama, etc.
   │      ├─→ Desktop: Hyprland, Waybar, etc.
   │      ├─→ Monitoring: Prometheus, Grafana, etc.
   │      └─→ AI: Claude, GPT, Gemini integrations
   │
   ├─→ 7. User session start (if desktop)
   │      ├─→ Greetd/Login manager
   │      ├─→ Start Hyprland/Desktop environment
   │      └─→ Launch user services
   │
   └─→ 8. Home Manager activation
          ├─→ Link dotfiles
          ├─→ Set up user environment
          └─→ Start user services
```

### Deployment Flow

```
1. Code Change
   │
   ├─→ 2. Validation (just validate)
   │      ├─→ Syntax check (nix eval)
   │      ├─→ Module structure test
   │      └─→ Anti-pattern detection
   │
   ├─→ 3. Testing (just test-host {HOST})
   │      ├─→ Build configuration
   │      ├─→ Check for warnings/errors
   │      └─→ Verify no regressions
   │
   ├─→ 4. Parallel Testing (just quick-test)
   │      └─→ Test all hosts simultaneously
   │
   ├─→ 5. Smart Deployment (just quick-deploy {HOST})
   │      ├─→ Check if configuration changed
   │      ├─→ Skip if no changes (efficiency)
   │      └─→ Deploy only if modified
   │
   ├─→ 6. Standard Deployment (just {HOST})
   │      ├─→ Build on host or remotely
   │      ├─→ nixos-rebuild switch
   │      └─→ Activate new generation
   │
   └─→ 7. Parallel Deployment (just deploy-all-parallel)
          └─→ Deploy to all hosts simultaneously
```

---

## Key Architecture Benefits

### 1. Code Deduplication (95%)

```
Traditional Approach:
  p620/configuration.nix:     2000 lines
  razer/configuration.nix:    2000 lines (90% duplicated)
  p510/configuration.nix:     2000 lines (90% duplicated)
  dex5550/configuration.nix:  2000 lines (90% duplicated)
  samsung/configuration.nix:  2000 lines (90% duplicated)
  ─────────────────────────────────────
  Total: 10,000 lines (8,000 duplicated)

Template-Based Approach:
  hosts/templates/workstation.nix:     700 lines
  hosts/templates/laptop.nix:          900 lines
  hosts/templates/server.nix:        1,100 lines
  modules/ (141+ modules):           8,000 lines (shared)
  p620/configuration.nix:              100 lines (overrides only)
  razer/configuration.nix:             100 lines (overrides only)
  p510/configuration.nix:              100 lines (overrides only)
  dex5550/configuration.nix:           100 lines (overrides only)
  samsung/configuration.nix:           100 lines (overrides only)
  ─────────────────────────────────────
  Total: 11,200 lines (500 duplicated = 95% deduplication)
```

### 2. Maintainability

- **Single Source of Truth**: Changes to modules propagate automatically
- **Clear Hierarchy**: Easy to understand import chain
- **Feature Flags**: Conditional loading prevents conflicts
- **Profile Reuse**: Home Manager profiles shared across hosts

### 3. Flexibility

- **Mix and Match**: Profiles can be combined per user/host
- **Override Anywhere**: lib.mkForce for host-specific overrides
- **Template Extension**: Templates can be extended for hybrid hosts
- **Modular Addition**: New features added as modules without touching core

### 4. Testing and Validation

- **Isolated Testing**: Modules can be tested independently
- **Parallel Testing**: Test all hosts simultaneously
- **Smart Deployment**: Deploy only changed configurations
- **Rollback Safety**: NixOS generation management

---

## Comparison: Before vs After Template Architecture

### Before (Traditional Configuration)

```
hosts/p620/configuration.nix (2000 lines)
├─ Duplicated: Desktop environment setup
├─ Duplicated: Development tools configuration
├─ Duplicated: Network setup
├─ Duplicated: Security hardening
├─ Duplicated: User management
├─ Specific: AMD GPU config (50 lines)
└─ Specific: ROCm setup (100 lines)

hosts/razer/configuration.nix (2000 lines)
├─ Duplicated: Desktop environment setup (SAME AS P620)
├─ Duplicated: Development tools configuration (SAME AS P620)
├─ Duplicated: Network setup (SAME AS P620)
├─ Duplicated: Security hardening (SAME AS P620)
├─ Duplicated: User management (SAME AS P620)
├─ Specific: NVIDIA GPU config (50 lines)
├─ Specific: Power management (100 lines)
└─ Specific: Laptop hardware (50 lines)

Problem: 90% code duplication across hosts
```

### After (Template Architecture)

```
hosts/templates/workstation.nix (700 lines)
├─ Desktop environment setup (shared)
├─ Development tools (shared)
├─ Gaming support (shared)
└─ AI infrastructure (shared)

hosts/templates/laptop.nix (900 lines)
├─ Desktop environment setup (shared)
├─ Development tools (shared)
├─ Power management (unique to laptops)
└─ Mobile hardware support (unique to laptops)

hosts/p620/configuration.nix (100 lines)
├─ imports = [ hostTypes.workstation ]
├─ AMD GPU override (50 lines)
└─ ROCm specific config (50 lines)

hosts/razer/configuration.nix (100 lines)
├─ imports = [ hostTypes.laptop ]
├─ NVIDIA GPU override (50 lines)
└─ Razer-specific hardware (50 lines)

Solution: 95% code deduplication achieved
```

---

## Anti-Pattern Elimination

### Before Phase 8.1

```nix
# Anti-Pattern 1: mkIf true everywhere
services.openssh.enable = mkIf cfg.enable true;
programs.git.enable = mkIf config.features.development.enable true;

# Anti-Pattern 2: Unnecessary wrappers
myFunction = lib.mkEnableOption "My Service";  # Trivial wrapper

# Anti-Pattern 3: Magic auto-discovery
imports = builtins.filter (f: f != null) (
  map (f: if pathExists f then f else null)
  (builtins.attrNames (builtins.readDir ./.))
);

# Anti-Pattern 4: Secrets in evaluation
password = builtins.readFile /run/secrets/password;
```

### After Phase 8.1 (Best Practices)

```nix
# Best Practice 1: Direct assignment
services.openssh.enable = cfg.enable;
programs.git.enable = config.features.development.enable;

# Best Practice 2: Use lib functions directly
# No wrapper needed - use mkEnableOption directly in options

# Best Practice 3: Explicit imports
imports = [
  ./core.nix
  ./monitoring.nix
  ./performance.nix
  # ... all modules explicitly listed
];

# Best Practice 4: Runtime secret loading
passwordFile = "/run/agenix/password";
services.myservice.passwordFile = passwordFile;
```

---

**Document Version**: 1.0
**Last Verified**: 2025-10-08
**Maintainer**: Infrastructure Team
**Related**: docs/DEAD_CODE_ANALYSIS.md, docs/NIXOS-ANTI-PATTERNS.md
