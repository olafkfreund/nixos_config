# Host Type Templates
# Provides standard import lists and configurations for different host types
# Eliminates duplicate import statements across host configurations
{ lib, ... }: {

  # Base imports used by all hosts
  base = {
    imports = [
      ../modules/core.nix
      ../modules/nixos/core/monitoring.nix
      ../modules/nixos/core/performance.nix
      ../modules/nixos/development/cloud.nix
    ];
  };

  # Workstation configuration (P620, P510 - powerful desktop systems)
  workstation = {
    imports = [
      ../hosts/templates/workstation.nix
    ];

    # Workstation defaults
    config = {
      aiDefaults = {
        enable = lib.mkDefault true;
        profile = "workstation";
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
      ../hosts/templates/laptop.nix
    ];

    # Laptop-specific defaults
    config = {
      aiDefaults = {
        enable = lib.mkDefault true;
        profile = "laptop"; # Disables Ollama for battery life
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

  # Server configuration (DEX5550 - headless monitoring server)
  server = {
    imports = [
      ../hosts/templates/server.nix
    ];

    # Server-specific defaults
    config = {
      aiDefaults = {
        enable = lib.mkDefault true;
        profile = "server"; # Disables Ollama to save resources
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

      # Disable GUI components
      services.xserver.enable = lib.mkDefault false;
      programs.hyprland.enable = lib.mkDefault false;
    };
  };

  # Hybrid configuration (HP - server/workstation hybrid)
  hybrid = {
    imports = [
      ../hosts/templates/workstation.nix # Use workstation template as base
    ];

    # Hybrid-specific defaults (can function as both workstation and server)
    config = {
      aiDefaults = {
        enable = lib.mkDefault true;
        profile = "workstation";
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
