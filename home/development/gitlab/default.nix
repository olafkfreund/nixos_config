{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.development.gitlab;
in
{
  options.development.gitlab = {
    enable = mkEnableOption "GitLab development tools and integration";

    packages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional GitLab-related packages to install";
    };

    runner = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable GitLab Runner for local CI/CD testing";
      };

      config = mkOption {
        type = types.attrs;
        default = { };
        description = "GitLab Runner configuration";
        example = literalExpression ''
          {
            concurrent = 4;
            check_interval = 0;
            session_timeout = 1800;
          }
        '';
      };
    };

    fluxcd = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable FluxCD operator tools for GitOps workflows";
      };
    };

    ciLocal = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable GitLab CI local testing tools";
      };
    };
  };

  config = mkIf cfg.enable {
    # Core GitLab development packages
    home = {
      packages = with pkgs; [
        # GitLab CLI and tools
        glab # GitLab CLI tool for repository management

        # GitLab Runner for local CI/CD testing
        (mkIf cfg.runner.enable gitlab-runner)

        # FluxCD operator tools for GitOps
        (mkIf cfg.fluxcd.enable fluxcd)
        (mkIf cfg.fluxcd.enable fluxcd-operator-mcp)
        (mkIf cfg.fluxcd.enable fluxcd-operator)

        # GitLab CI local testing
        (mkIf cfg.ciLocal.enable gitlab-ci-local)

        # Additional related tools
        git # Core git functionality
        jq # JSON processing for API responses
        curl # HTTP client for GitLab API
        yq-go # YAML processing for CI/CD files

      ] ++ cfg.packages;

      # GitLab Runner configuration (if enabled)
      file = mkIf cfg.runner.enable {
        ".gitlab-runner/config.toml" = {
          text = ''
            concurrent = ${toString (cfg.runner.config.concurrent or 4)}
            check_interval = ${toString (cfg.runner.config.check_interval or 0)}
            session_timeout = ${toString (cfg.runner.config.session_timeout or 1800)}

            [session_server]
              session_timeout = ${toString (cfg.runner.config.session_timeout or 1800)}
          '';
        };
      };

      # Development environment variables
      sessionVariables = mkIf cfg.enable ({
        # GitLab CLI configuration
        GITLAB_HOST = "gitlab.com";

        # FluxCD configuration
        FLUX_SYSTEM_NAMESPACE = mkIf cfg.fluxcd.enable "flux-system";
      } // (mkIf cfg.runner.enable {
        # GitLab Runner configuration
        GITLAB_RUNNER_CONFIG_FILE = "$HOME/.gitlab-runner/config.toml";
      }));
    };

    # GitLab CLI configuration
    programs = {
      git.settings = mkIf cfg.enable {
        # GitLab-specific git configuration
        gitlab = {
          host = "gitlab.com";
        };
      };

      # Shell aliases and functions for GitLab workflows
      zsh = {
        shellAliases = mkIf cfg.enable {
          # GitLab CLI shortcuts
          "gl" = "glab";
          "glr" = "glab repo";
          "glc" = "glab repo clone";
          "glv" = "glab repo view";
          "gli" = "glab issue";
          "glm" = "glab mr";
          "glp" = "glab pipeline";

          # GitLab CI local testing
          "ci-local" = mkIf cfg.ciLocal.enable "gitlab-ci-local";
          "ci-test" = mkIf cfg.ciLocal.enable "gitlab-ci-local --preview";

          # FluxCD shortcuts
          "flux" = mkIf cfg.fluxcd.enable "flux";
          "fluxctl" = mkIf cfg.fluxcd.enable "flux";
        };

        # Additional shell configuration for GitLab workflows
        initContent = mkIf cfg.enable ''
          # GitLab workflow functions
          gitlab-clone() {
            if [[ $# -eq 0 ]]; then
              echo "Usage: gitlab-clone <project-path>"
              echo "Example: gitlab-clone mygroup/myproject"
              return 1
            fi
            glab repo clone "$1"
          }

          gitlab-mr-create() {
            local title="$1"
            local description="$2"
            if [[ -z "$title" ]]; then
              echo "Usage: gitlab-mr-create <title> [description]"
              return 1
            fi
            glab mr create --title "$title" --description "$description"
          }

          ${optionalString cfg.ciLocal.enable ''
            # GitLab CI local testing functions
            ci-validate() {
              if [[ -f ".gitlab-ci.yml" ]]; then
                echo "Validating GitLab CI configuration..."
                gitlab-ci-local --preview
              else
                echo "No .gitlab-ci.yml found in current directory"
                return 1
              fi
            }

            ci-run() {
              local job="$1"
              if [[ -z "$job" ]]; then
                echo "Available jobs:"
                gitlab-ci-local --list
                return 1
              fi
              echo "Running GitLab CI job: $job"
              gitlab-ci-local "$job"
            }
          ''}

          ${optionalString cfg.fluxcd.enable ''
            # FluxCD helper functions
            flux-status() {
              echo "FluxCD system status:"
              flux get all --all-namespaces
            }

            flux-reconcile() {
              local resource="$1"
              if [[ -z "$resource" ]]; then
                echo "Usage: flux-reconcile <resource>"
                echo "Example: flux-reconcile source git/myrepo"
                return 1
              fi
              flux reconcile "$resource"
            }
          ''}
        '';
      };
    };
  };
}
