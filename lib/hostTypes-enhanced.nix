# Enhanced Host Type Templates with Package Management
# Provides standard import lists and package configurations for different host types
# Integrates with the new three-tier package management system
# Compliant with NIXOS-ANTI-PATTERNS.md
{ lib, ... }: {

  # Base imports used by all hosts
  base = {
    imports = [
      ../modules/core.nix
      ../modules/monitoring.nix
      ../modules/performance.nix
      ../modules/cloud.nix
      # Add new package system
      ../modules/nixos/packages/default.nix
    ];
  };

  # Server configuration (DEX5550, P510 as server - headless systems)
  server = {
    imports = [
      ../modules/core.nix
      ../modules/monitoring.nix
      ../modules/performance.nix
      ../modules/cloud.nix
      ../modules/development.nix # Minimal dev tools for administration
      ../modules/email.nix
      ../modules/programs.nix # Needed for media and other program features
      ../modules/common/ai-defaults.nix
      # New package system with server-specific defaults
      ../modules/nixos/packages/default.nix
      ../modules/nixos/packages/host-specific/server-packages.nix
      # No desktop modules for servers
    ];

    # Server-specific package and feature defaults
    config = {
      aiDefaults = {
        enable = lib.mkDefault true;
        profile = "server"; # Disables Ollama to save resources
      };

      # Package configuration (following anti-patterns - direct assignment)
      packages = {
        # Core packages always enabled (Tier 1)

        # Category packages (Tier 2) - NO GUI packages!
        development = {
          enable = lib.mkDefault true;
          languages = {
            python = lib.mkDefault true; # Server administration
            nodejs = lib.mkDefault false; # Not needed on servers
            rust = lib.mkDefault false; # Not needed on servers
            go = lib.mkDefault false; # Not needed on servers
            nix = lib.mkDefault true; # NixOS administration
          };
          editors = {
            neovim = lib.mkDefault true; # Headless editor
            vscode = lib.mkDefault false; # GUI not available
          };
        };

        desktop.enable = lib.mkDefault false; # CRITICAL: No GUI packages

        media = {
          enable = lib.mkDefault true;
          server = lib.mkDefault true; # Media server tools
          processing = lib.mkDefault true; # Media processing
          gui = lib.mkDefault false; # NO GUI media apps
        };

        virtualization = {
          enable = lib.mkDefault true;
          docker = lib.mkDefault true; # Servers often need containers
          kubernetes = lib.mkDefault false; # Only if needed
          vm = lib.mkDefault false; # GUI VMs not available
        };

        admin = {
          enable = lib.mkDefault true;
          monitoring = lib.mkDefault true; # Server monitoring essential
          network = lib.mkDefault true; # Network analysis tools
          security = lib.mkDefault true; # Security tools (headless only)
        };
      };

      features = {
        development = {
          enable = lib.mkDefault true;
          # Minimal development features for server administration
          languages = {
            python = lib.mkDefault true;
            go = lib.mkDefault false;
            rust = lib.mkDefault false;
          };
        };
        desktop.enable = lib.mkDefault false;
        virtualization = {
          enable = lib.mkDefault true;
          docker = lib.mkDefault true; # Servers often need containers
        };
        monitoring = {
          enable = lib.mkDefault true;
          mode = lib.mkDefault "server"; # Act as monitoring server
        };
      };

      # Server-specific optimizations
      services = {
        openssh = {
          enable = lib.mkDefault true;
          settings.PermitRootLogin = lib.mkDefault "no";
        };
      };

      # Disable GUI components (following anti-patterns - direct assignment)
      services.xserver.enable = false;
      programs.hyprland.enable = false;
    };
  };

  # Workstation configuration (P620 - powerful desktop systems)
  workstation = {
    imports = [
      ../modules/core.nix
      ../modules/development.nix
      ../modules/desktop.nix
      ../modules/virtualization.nix
      ../modules/monitoring.nix
      ../modules/performance.nix
      ../modules/email.nix
      ../modules/cloud.nix
      ../modules/programs.nix
      ../modules/common/ai-defaults.nix
      # New package system with workstation-specific defaults
      ../modules/nixos/packages/default.nix
      ../modules/nixos/packages/host-specific/workstation-packages.nix
    ];

    # Workstation-specific package and feature defaults
    config = {
      aiDefaults = {
        enable = lib.mkDefault true;
        profile = "workstation";
      };

      # Package configuration (full feature set)
      packages = {
        # Category packages (Tier 2) - Full stack including GUI
        development = {
          enable = lib.mkDefault true;
          languages = {
            python = lib.mkDefault true;
            nodejs = lib.mkDefault true;
            rust = lib.mkDefault true;
            go = lib.mkDefault true;
            lua = lib.mkDefault true;
            nix = lib.mkDefault true;
          };
          editors = {
            neovim = lib.mkDefault true;
            vscode = lib.mkDefault true; # GUI available
          };
          tools = {
            container = lib.mkDefault true;
            database = lib.mkDefault true;
            network = lib.mkDefault true;
          };
        };

        desktop = {
          enable = lib.mkDefault true; # Full desktop environment
          wayland = lib.mkDefault true;
          browsers = {
            firefox = lib.mkDefault true;
            chrome = lib.mkDefault false;
          };
          media = {
            vlc = lib.mkDefault true;
            spotify = lib.mkDefault true;
            obs = lib.mkDefault true;
            gimp = lib.mkDefault true;
          };
          productivity = {
            obsidian = lib.mkDefault true;
            libreoffice = lib.mkDefault false; # Disabled: large build causing issues
            thunderbird = lib.mkDefault true;
            vscode = lib.mkDefault true;
          };
          communication = {
            slack = lib.mkDefault true;
            zoom = lib.mkDefault false;
          };
        };

        media = {
          enable = lib.mkDefault true;
          server = lib.mkDefault false; # Not a media server
          processing = lib.mkDefault true; # Media processing
          gui = lib.mkDefault true; # GUI media applications
        };

        virtualization = {
          enable = lib.mkDefault true;
          docker = lib.mkDefault true;
          kubernetes = lib.mkDefault true;
          vm = lib.mkDefault true; # GUI VM management
        };

        admin = {
          enable = lib.mkDefault true;
          monitoring = lib.mkDefault true;
          network = lib.mkDefault true;
          security = lib.mkDefault true;
        };
      };

      features = {
        development.enable = lib.mkDefault true;
        desktop.enable = lib.mkDefault true;
        virtualization.enable = lib.mkDefault true;
      };
    };
  };

  # Laptop configuration (Razer, Samsung - portable systems with power management)
  laptop = {
    imports = [
      ../modules/core.nix
      ../modules/development.nix
      ../modules/desktop.nix
      ../modules/virtualization.nix
      ../modules/monitoring.nix
      ../modules/performance.nix
      ../modules/email.nix
      ../modules/cloud.nix
      ../modules/programs.nix
      ../modules/common/ai-defaults.nix
      # New package system with laptop-specific defaults
      ../modules/nixos/packages/default.nix
      ../modules/nixos/packages/host-specific/laptop-packages.nix
    ];

    # Laptop-specific package and feature defaults
    config = {
      aiDefaults = {
        enable = lib.mkDefault true;
        profile = "laptop"; # Disables Ollama for battery life
      };

      # Package configuration (optimized for mobility and battery life)
      packages = {
        # Category packages (Tier 2) - Optimized for mobile use
        development = {
          enable = lib.mkDefault true;
          languages = {
            python = lib.mkDefault true;
            nodejs = lib.mkDefault true;
            rust = lib.mkDefault false; # Heavy compilation
            go = lib.mkDefault true; # Light compilation
            nix = lib.mkDefault true;
          };
          editors = {
            neovim = lib.mkDefault true;
            vscode = lib.mkDefault true;
          };
        };

        desktop = {
          enable = lib.mkDefault true;
          wayland = lib.mkDefault true;
          browsers = {
            firefox = lib.mkDefault true;
            chrome = lib.mkDefault false; # More resource-intensive
          };
          media = {
            vlc = lib.mkDefault true;
            spotify = lib.mkDefault true;
            obs = lib.mkDefault false; # Resource-intensive
            gimp = lib.mkDefault false; # Resource-intensive
          };
          productivity = {
            obsidian = lib.mkDefault true;
            libreoffice = lib.mkDefault false; # Disabled: large build causing issues
            thunderbird = lib.mkDefault true;
          };
        };

        virtualization = {
          enable = lib.mkDefault true;
          docker = lib.mkDefault false; # Prefer Podman for battery
          kubernetes = lib.mkDefault false; # Too resource-intensive
          vm = lib.mkDefault true;
        };

        admin = {
          enable = lib.mkDefault true;
          monitoring = lib.mkDefault true;
          network = lib.mkDefault true; # Important for mobile
          security = lib.mkDefault true;
        };
      };

      features = {
        development.enable = lib.mkDefault true;
        desktop.enable = lib.mkDefault true;
        virtualization = {
          enable = lib.mkDefault true;
          docker = lib.mkDefault false; # Prefer Podman for battery life
        };
        powerManagement.enable = lib.mkDefault true;
      };

      # Laptop-specific power optimizations
      services.thermald.enable = lib.mkDefault true;
      powerManagement = {
        enable = lib.mkDefault true;
        cpuFreqGovernor = lib.mkDefault "powersave";
      };
    };
  };

  # Hybrid configuration (HP - server/workstation hybrid)
  hybrid = {
    imports = [
      ../modules/core.nix
      ../modules/development.nix
      ../modules/desktop.nix
      ../modules/virtualization.nix
      ../modules/monitoring.nix
      ../modules/performance.nix
      ../modules/email.nix
      ../modules/cloud.nix
      ../modules/programs.nix
      ../modules/common/ai-defaults.nix
      # New package system (can be configured as server or workstation)
      ../modules/nixos/packages/default.nix
    ];

    # Hybrid-specific defaults (can function as both workstation and server)
    config = {
      aiDefaults = {
        enable = lib.mkDefault true;
        profile = "workstation";
      };

      # Package configuration (flexible - can be overridden per host)
      packages = {
        development.enable = lib.mkDefault true;
        desktop.enable = lib.mkDefault true; # Can be disabled for server mode
        virtualization.enable = lib.mkDefault true;
        admin.enable = lib.mkDefault true;
      };

      features = {
        development.enable = lib.mkDefault true;
        desktop.enable = lib.mkDefault true; # Can be disabled for server mode
        virtualization.enable = lib.mkDefault true;
        monitoring = {
          enable = lib.mkDefault true;
          mode = lib.mkDefault "client"; # Usually acts as client
        };
      };

      # Hybrid optimizations
      services.openssh.enable = lib.mkDefault true;
    };
  };
}
