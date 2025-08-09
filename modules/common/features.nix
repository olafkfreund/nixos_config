{ lib, ... }:
with lib; {
  options.features = {
    development = {
      enable = mkEnableOption "Enable development tools";

      # Granular enablement options
      python = mkEnableOption "Python development";
      go = mkEnableOption "Go development";
      nodejs = mkEnableOption "Node.js development";
      java = mkEnableOption "Java development";
      lua = mkEnableOption "Lua development";
      nix = mkEnableOption "Nix development";
      shell = mkEnableOption "Shell development";
      ansible = mkEnableOption "Ansible development";
      cargo = mkEnableOption "Cargo/Rust development";
      github = mkEnableOption "GitHub development";
      devshell = mkEnableOption "DevShell development";
      precommit = mkEnableOption "Pre-commit hooks and linting";
    };

    virtualization = {
      enable = mkEnableOption "Enable virtualization";
      docker = mkEnableOption "Enable Docker";
      podman = mkEnableOption "Enable Podman";
      incus = mkEnableOption "Enable Incus containers";
      spice = mkEnableOption "Enable SPICE";
      libvirt = mkEnableOption "Enable libvirt";
      sunshine = mkEnableOption "Enable Sunshine for streaming";
    };

    cloud = {
      enable = mkEnableOption "Enable cloud tools";
      aws = mkEnableOption "Enable AWS tools";
      azure = mkEnableOption "Enable Azure tools";
      google = mkEnableOption "Enable Google Cloud tools";
      k8s = mkEnableOption "Enable Kubernetes tools";
      terraform = mkEnableOption "Enable Terraform tools";
    };

    security = {
      enable = mkEnableOption "Enable security tools";
      onepassword = mkEnableOption "Enable 1Password";
      gnupg = mkEnableOption "Enable GnuPG";
    };

    networking = {
      enable = mkEnableOption "Enable networking";
    };

    ai = {
      enable = mkEnableOption "Enable AI tools";
      ollama = mkEnableOption "Enable Ollama AI";
      gemini-cli = mkEnableOption "Enable Google Gemini CLI";

      # Enhanced AI provider support
      providers = {
        enable = mkEnableOption "Enable unified AI provider support";

        defaultProvider = mkOption {
          type = types.enum [ "openai" "anthropic" "gemini" "ollama" ];
          default = "openai";
          description = "Default AI provider to use";
        };

        enableFallback = mkOption {
          type = types.bool;
          default = true;
          description = "Enable automatic fallback between providers";
        };

        costOptimization = mkOption {
          type = types.bool;
          default = false;
          description = "Enable cost-based provider selection";
        };

        openai = {
          enable = mkEnableOption "OpenAI provider";
          priority = mkOption {
            type = types.int;
            default = 1;
            description = "Provider priority (1 = highest)";
          };
        };

        anthropic = {
          enable = mkEnableOption "Anthropic/Claude provider";
          priority = mkOption {
            type = types.int;
            default = 2;
            description = "Provider priority (1 = highest)";
          };
        };

        gemini = {
          enable = mkEnableOption "Google Gemini provider";
          priority = mkOption {
            type = types.int;
            default = 3;
            description = "Provider priority (1 = highest)";
          };
        };

        ollama = {
          enable = mkEnableOption "Ollama local provider";
          priority = mkOption {
            type = types.int;
            default = 4;
            description = "Provider priority (1 = highest)";
          };
        };
      };
    };

    programs = {
      lazygit = mkEnableOption "Enable LazyGit";
      thunderbird = mkEnableOption "Enable Thunderbird";
      obsidian = mkEnableOption "Enable Obsidian";
      office = mkEnableOption "Enable Office tools";
      webcam = mkEnableOption "Enable Webcam tools";
      print = mkEnableOption "Enable Printing";
    };

    media = {
      droidcam = mkEnableOption "Enable DroidCam";
    };

    monitoring = {
      enable = mkEnableOption "Enable monitoring and observability";

      mode = mkOption {
        type = types.enum [ "server" "client" "standalone" ];
        default = "client";
        description = "Monitoring mode (server/client/standalone)";
      };

      serverHost = mkOption {
        type = types.str;
        default = "p620";
        description = "Monitoring server hostname";
      };

      features = {
        prometheus = mkEnableOption "Enable Prometheus metrics collection";
        grafana = mkEnableOption "Enable Grafana dashboards";
        nodeExporter = mkEnableOption "Enable node exporter";
        nixosMetrics = mkEnableOption "Enable NixOS-specific metrics";
        alerting = mkEnableOption "Enable alerting";
      };
    };
  };
}
