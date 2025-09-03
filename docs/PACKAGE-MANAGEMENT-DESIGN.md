# NixOS Package Management System Design

> **Compliant with**: `docs/NIXOS-ANTI-PATTERNS.md`
> **Status**: Design Phase
> **Goal**: Create flexible, maintainable package categorization system

## 🎯 **Design Principles**

### **Anti-Pattern Compliance**

- ✅ **No `mkIf condition true`** - Use direct assignment (`packages = pkgs.core.packages`)
- ✅ **Explicit imports** - No auto-discovery, clear module lists
- ✅ **Trust module system** - Let NixOS handle disabled services properly
- ✅ **Extract common functionality** - Shared package definitions
- ✅ **Proper separation** - System vs user packages clearly defined
- ✅ **No unnecessary wrappers** - Direct usage of library functions

## 📦 **Three-Tier Package Architecture**

### **Tier 1: Core System Packages**

Essential packages that ALL hosts need regardless of purpose.

```nix
# modules/nixos/packages/core.nix
{ config, lib, pkgs, ... }: {
  config = {
    # Always installed - no conditions needed
    environment.systemPackages = with pkgs; [
      # Essential system tools (headless-compatible)
      curl wget git vim nano
      htop btop iotop
      systemctl journalctl
      ssh openssh
      unzip gzip tar
      coreutils-full

      # Network essentials
      ping traceroute netcat
      dig nslookup

      # System monitoring
      lsof pciutils usbutils
      procps psmisc
    ];
  };
}
```

### **Tier 2: Conditional Feature Packages**

Packages enabled based on host capabilities and feature flags.

```nix
# modules/nixos/packages/conditional.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.features;
in {
  config = {
    environment.systemPackages = with pkgs; [
      # Development packages (NO mkIf condition true!)
    ] ++ lib.optionals cfg.development.enable [
      gcc gnumake cmake ninja
      python3 nodejs go rustc cargo
      docker-compose kubectl
    ] ++ lib.optionals cfg.virtualization.enable [
      docker podman
      qemu libvirt
    ] ++ lib.optionals cfg.desktop.enable [
      # GUI applications
      firefox
      vscode
      discord
    ] ++ lib.optionals cfg.media.enable [
      # Media tools
      ffmpeg mediainfo
      vlc mpv
    ] ++ lib.optionals cfg.ai.enable [
      # AI development tools
      python3Packages.torch
      python3Packages.transformers
    ];
  };
}
```

### **Tier 3: Host-Specific Packages**

Packages unique to individual hosts.

```nix
# hosts/servers/dex5550/packages.nix
{ pkgs, ... }: {
  # Server-specific packages (monitoring server)
  systemPackages = with pkgs; [
    # Monitoring tools specific to this server
    prometheus grafana
    nginx

    # Server administration
    fail2ban
    logrotate
  ];
}

# hosts/workstations/p620/packages.nix
{ pkgs, ... }: {
  # Workstation-specific packages (AI development)
  systemPackages = with pkgs; [
    # AI/ML specific tools
    rocmPackages.llvm.libcxx
    looking-glass-client
    scream

    # Hardware-specific tools
    via wally-cli
    amdgpu-pro
  ];
}
```

## 🏠 **Home Manager Package Categories**

### **Profile-Based Package Management**

Following anti-patterns: **no duplicate package management**, clear separation.

```nix
# home/profiles/server-admin/packages.nix
{ pkgs, ... }: {
  # Minimal CLI packages for server administration
  home.packages = with pkgs; [
    # Terminal multiplexers
    tmux screen

    # File managers
    ranger lf

    # System analysis
    strace ltrace
    bandwhich

    # Text processing
    ripgrep fd fzf
    jq yq
  ];
}

# home/profiles/developer/packages.nix
{ pkgs, ... }: {
  # Development-focused packages
  home.packages = with pkgs; [
    # Editors and IDEs
    neovim
    emacs

    # Version control
    gh lazygit

    # Language servers
    nil nixd rust-analyzer
    gopls pyright

    # Development utilities
    devenv direnv
    pre-commit
  ];
}

# home/profiles/desktop-user/packages.nix
{ pkgs, ... }: {
  # GUI user applications
  home.packages = with pkgs; [
    # Productivity
    obsidian
    thunderbird
    libreoffice

    # Media
    spotify
    obs-studio
    gimp

    # Communication
    slack
    zoom-us
  ];
}
```

## 🛠 **Package Category Modules**

### **Category-Based Organization**

Each category gets its own module with explicit exports.

```nix
# modules/nixos/packages/categories/development.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.packages.development;
in {
  options.packages.development = {
    enable = lib.mkEnableOption "Development packages";

    languages = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = {};
      description = "Language-specific development tools";
    };

    editors = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = {};
      description = "Development editors";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Core development tools (always included)
      git gh lazygit
      curl wget jq
    ] ++ lib.optionals cfg.languages.python [
      python3 python3Packages.pip
      python3Packages.virtualenv
    ] ++ lib.optionals cfg.languages.nodejs [
      nodejs npm yarn
    ] ++ lib.optionals cfg.languages.rust [
      rustc cargo rust-analyzer
    ] ++ lib.optionals cfg.languages.go [
      go gopls
    ] ++ lib.optionals cfg.editors.vscode [
      vscode
    ] ++ lib.optionals cfg.editors.neovim [
      neovim
    ];
  };
}
```

```nix
# modules/nixos/packages/categories/desktop.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.packages.desktop;
in {
  options.packages.desktop = {
    enable = lib.mkEnableOption "Desktop GUI packages";

    browsers = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = {};
    };

    media = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = {};
    };

    productivity = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = {};
    };
  };

  # Only enabled for GUI hosts - NO mkIf condition true!
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Core desktop tools
      xdg-utils
      desktop-file-utils
    ] ++ lib.optionals cfg.browsers.firefox [
      firefox
    ] ++ lib.optionals cfg.browsers.chrome [
      google-chrome
    ] ++ lib.optionals cfg.media.vlc [
      vlc
    ] ++ lib.optionals cfg.media.spotify [
      spotify
    ] ++ lib.optionals cfg.productivity.libreoffice [
      libreoffice
    ] ++ lib.optionals cfg.productivity.obsidian [
      obsidian
    ];
  };
}
```

## 📋 **Service-Integrated Package Management**

### **Automatic Package Dependencies**

Packages automatically included when services are enabled.

```nix
# modules/nixos/packages/service-deps.nix
{ config, lib, pkgs, ... }: {
  config = {
    environment.systemPackages = with pkgs; [
      # Media server dependencies (when media services enabled)
    ] ++ lib.optionals config.services.plex.enable [
      ffmpeg mediainfo
      curl wget
    ] ++ lib.optionals config.services.prometheus.enable [
      prometheus-node-exporter
      curl jq
    ] ++ lib.optionals config.services.nginx.enable [
      nginx
      certbot
    ] ++ lib.optionals config.services.docker.enable [
      docker-compose
      dive # Docker image explorer
    ];
  };
}
```

## 🎛️ **Feature Flag Integration**

### **Host Template Integration**

Packages automatically configured based on host type.

```nix
# lib/host-types.nix (updated)
{ lib, ... }: {
  server = {
    imports = [
      ../modules/nixos/packages/core.nix
      ../modules/nixos/packages/conditional.nix
      ../modules/nixos/packages/service-deps.nix
    ];

    config = {
      # Server package configuration (NO desktop packages)
      packages = {
        development = {
          enable = lib.mkDefault true;
          languages = {
            python = lib.mkDefault true; # Server admin
            nodejs = lib.mkDefault false;
          };
          editors = {
            neovim = lib.mkDefault true;
            vscode = lib.mkDefault false; # GUI not available
          };
        };

        desktop.enable = lib.mkDefault false; # CRITICAL: No GUI
      };
    };
  };

  workstation = {
    imports = [
      ../modules/nixos/packages/core.nix
      ../modules/nixos/packages/conditional.nix
      ../modules/nixos/packages/categories/development.nix
      ../modules/nixos/packages/categories/desktop.nix
      ../modules/nixos/packages/service-deps.nix
    ];

    config = {
      # Workstation package configuration (full stack)
      packages = {
        development = {
          enable = lib.mkDefault true;
          languages = {
            python = lib.mkDefault true;
            nodejs = lib.mkDefault true;
            rust = lib.mkDefault true;
            go = lib.mkDefault true;
          };
          editors = {
            vscode = lib.mkDefault true;
            neovim = lib.mkDefault true;
          };
        };

        desktop = {
          enable = lib.mkDefault true;
          browsers = {
            firefox = lib.mkDefault true;
            chrome = lib.mkDefault false;
          };
          media = {
            vlc = lib.mkDefault true;
            spotify = lib.mkDefault true;
          };
          productivity = {
            obsidian = lib.mkDefault true;
            libreoffice = lib.mkDefault true;
          };
        };
      };
    };
  };
}
```

## 🏗️ **Implementation Structure**

### **Directory Organization**

```bash
modules/nixos/packages/
├── default.nix              # Main package exports
├── core.nix                 # Tier 1: Core system packages
├── conditional.nix          # Tier 2: Feature-based packages
├── service-deps.nix         # Service-integrated packages
├── categories/
│   ├── development.nix      # Development tools
│   ├── desktop.nix          # GUI applications
│   ├── media.nix            # Media packages
│   ├── virtualization.nix  # Container/VM packages
│   └── admin.nix            # System administration
└── host-specific/
    ├── server-packages.nix  # Server-only packages
    ├── workstation-packages.nix
    └── laptop-packages.nix
```

### **Main Package Module**

```nix
# modules/nixos/packages/default.nix
{ ... }: {
  # Explicit imports (following anti-patterns)
  imports = [
    ./core.nix
    ./conditional.nix
    ./service-deps.nix
    ./categories/development.nix
    ./categories/desktop.nix
    ./categories/media.nix
    ./categories/virtualization.nix
    ./categories/admin.nix
  ];
}
```

### **Host Configuration Usage**

```nix
# hosts/servers/p510/configuration.nix
{ config, pkgs, lib, hostTypes, ... }: {
  imports = hostTypes.server.imports ++ [
    ./packages.nix  # Host-specific additions
  ];

  # Packages automatically configured by server template
  # No manual package management needed!

  # Optional host-specific overrides
  packages.development.languages.rust = false; # Not needed on media server
}

# hosts/workstations/p620/configuration.nix
{ config, pkgs, lib, hostTypes, ... }: {
  imports = hostTypes.workstation.imports ++ [
    ./packages.nix  # Host-specific additions
  ];

  # Full package set automatically enabled
  # AI-specific packages in host-specific file
}
```

## ✅ **Compliance Verification**

### **Anti-Pattern Checks**

- ✅ **No `mkIf condition true`** - All conditions use direct assignment or `lib.optionals`
- ✅ **Explicit imports** - Every module import is listed clearly
- ✅ **No auto-discovery** - Manual import lists, no `readDir` logic
- ✅ **Extract common packages** - Shared definitions prevent duplication
- ✅ **Trust module system** - Let NixOS handle package management correctly
- ✅ **Proper separation** - System vs user packages clearly defined
- ✅ **No unnecessary wrappers** - Direct use of `lib.optionals` and `mkIf`

### **Benefits**

- 🎯 **Easy P510 conversion** - Simply use server template, desktop packages automatically disabled
- 🔧 **Maintainable** - Package categories clearly separated and organized
- 🚀 **Performant** - No unnecessary evaluation overhead
- 📦 **Flexible** - Easy to enable/disable package groups per host
- 🛡️ **Compliant** - Follows all established anti-pattern guidelines

---

**Ready for Implementation** ✨
This design provides the foundation for flexible, maintainable package management across all host types while
strictly adhering to NixOS best practices.
