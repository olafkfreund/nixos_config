# Enhanced Development Workflow Tools
# Task runners, build systems, testing frameworks, and CI/CD integration
{ pkgs
, lib
, ...
}:
with lib;
let
  # Workflow configuration
  cfg = {
    # Task runners and build systems
    taskRunners = {
      just = true; # Justfile task runner
      make = true; # GNU Make
      ninja = false; # Ninja build system
      bazel = false; # Bazel build system
      earthly = false; # Earthly CI/CD
    };

    # Testing frameworks and tools
    testing = {
      # Multi-language testing
      act = true; # GitHub Actions local testing
      hyperfine = true; # Benchmarking tool
      tokei = true; # Code statistics

      # Language-specific testing
      pytest = true; # Python testing
      jest = false; # JavaScript testing
      cargo_test = true; # Rust testing (via cargo)
      go_test = true; # Go testing (via go)
    };

    # CI/CD and automation
    cicd = {
      github_cli = true; # GitHub CLI
      act = true; # Local GitHub Actions
      pre_commit = true; # Pre-commit hooks
      commitizen = false; # Conventional commits
    };

    # Development databases and services
    services = {
      # Local development databases
      sqlite = true; # SQLite for local development
      redis = false; # Redis for caching
      postgresql = false; # PostgreSQL for complex apps

      # Development servers
      caddy = false; # Modern web server
      nginx = false; # Traditional web server
    };

    # API and networking tools
    networking = {
      httpie = true; # Modern HTTP client
      curl = true; # Traditional HTTP client
      wget = true; # File downloader
      jq = true; # JSON processor
      yq = true; # YAML processor
      dive = true; # Docker image analyzer
    };

    # Documentation and publishing
    documentation = {
      # Documentation generators
      mdbook = false; # Rust-based documentation
      hugo = false; # Static site generator

      # Documentation tools
      pandoc = true; # Document converter
      graphviz = true; # Graph visualization
      plantuml = false; # UML diagrams
    };

    # Performance and monitoring
    monitoring = {
      # System monitoring
      htop = true; # Process monitor
      btop = true; # Modern process monitor
      bandwhich = true; # Network monitor

      # Development monitoring
      flamegraph = false; # Performance profiling
      perf = false; # Linux performance tools
    };
  };

  # Package collections based on configuration
  taskRunnerPackages = with pkgs; flatten [
    (optional cfg.taskRunners.just just)
    (optional cfg.taskRunners.make gnumake)
    (optional cfg.taskRunners.ninja ninja)
    (optional cfg.taskRunners.bazel bazel)
    (optional cfg.taskRunners.earthly earthly)
  ];

  testingPackages = with pkgs; flatten [
    (optional cfg.testing.act act)
    (optional cfg.testing.hyperfine hyperfine)
    (optional cfg.testing.tokei tokei)
    (optional cfg.testing.pytest python313Packages.pytest)
    (optional cfg.testing.jest nodePackages.jest)
    # Note: cargo test and go test are included with their respective language packages
  ];

  cicdPackages = with pkgs; flatten [
    (optional cfg.cicd.github_cli gh)
    (optional cfg.cicd.act act)
    (optional cfg.cicd.pre_commit pre-commit)
    (optional cfg.cicd.commitizen commitizen)
  ];

  servicePackages = with pkgs; flatten [
    (optional cfg.services.sqlite sqlite)
    (optional cfg.services.redis redis)
    (optional cfg.services.postgresql postgresql)
    (optional cfg.services.caddy caddy)
    (optional cfg.services.nginx nginx)
  ];

  networkingPackages = with pkgs; flatten [
    (optional cfg.networking.httpie httpie)
    (optional cfg.networking.curl curl)
    (optional cfg.networking.wget wget)
    (optional cfg.networking.jq jq)
    (optional cfg.networking.yq yq-go)
    (optional cfg.networking.dive dive)
  ];

  documentationPackages = with pkgs; flatten [
    (optional cfg.documentation.mdbook mdbook)
    (optional cfg.documentation.hugo hugo)
    (optional cfg.documentation.pandoc pandoc)
    (optional cfg.documentation.graphviz graphviz)
    (optional cfg.documentation.plantuml plantuml)
  ];

  monitoringPackages = with pkgs; flatten [
    (optional cfg.monitoring.htop htop)
    (optional cfg.monitoring.btop btop)
    (optional cfg.monitoring.bandwhich bandwhich)
    (optional cfg.monitoring.flamegraph flamegraph)
    (optional cfg.monitoring.perf linuxPackages.perf)
  ];

in
{
  # Enhanced development workflow packages
  home.packages = flatten [
    taskRunnerPackages
    testingPackages
    cicdPackages
    servicePackages
    networkingPackages
    documentationPackages
    monitoringPackages
  ];

  # Enhanced shell aliases for workflow tools
  home.shellAliases = mkMerge [
    # Task runners
    (mkIf cfg.taskRunners.just {
      j = "just";
      jl = "just --list";
      jr = "just --show";
    })

    # Testing shortcuts
    (mkIf cfg.testing.pytest {
      pyt = "python -m pytest";
      pytv = "python -m pytest -v";
      pytw = "python -m pytest --watch";
    })

    # CI/CD shortcuts
    (mkIf cfg.cicd.github_cli {
      gh-pr = "gh pr create";
      gh-status = "gh pr status";
      gh-view = "gh pr view";
      gh-merge = "gh pr merge";
    })

    # API and networking shortcuts
    (mkIf cfg.networking.httpie {
      http-get = "http GET";
      http-post = "http POST";
      http-put = "http PUT";
      http-delete = "http DELETE";
    })

    (mkIf cfg.networking.jq {
      pretty-json = "jq '.'";
      json-keys = "jq 'keys'";
    })

    # Documentation shortcuts
    (mkIf cfg.documentation.pandoc {
      md2pdf = "pandoc -o output.pdf";
      md2html = "pandoc -o output.html";
    })

    # Monitoring shortcuts
    (mkIf cfg.monitoring.btop {
      # Use 'btop' directly instead of 'top' to avoid conflict with bash.nix
      btop-mon = "btop";
      proc-mon = "btop";
    })
  ];

  # Enhanced environment variables for workflow
  home.sessionVariables = mkMerge [
    # Task runner configuration
    (mkIf cfg.taskRunners.just {
      JUST_CHOOSER = "fzf";
      JUST_UNSTABLE = "1";
    })

    # Testing configuration
    (mkIf cfg.testing.pytest {
      PYTEST_CURRENT_TEST = "1";
    })

    # CI/CD configuration
    (mkIf cfg.cicd.github_cli {
      GH_PAGER = "less";
      GH_EDITOR = "nvim";
    })
  ];

  # Note: Git configuration removed to avoid conflicts with existing git setup
  # GitHub CLI integration is handled separately when gh is enabled

  # Development workflow scripts and configuration files
  home.file = mkMerge [
    # Pre-commit configuration
    (mkIf cfg.cicd.pre_commit {
      ".pre-commit-config.yaml".text = ''
        # Enhanced pre-commit configuration for development workflow
        repos:
          - repo: https://github.com/pre-commit/pre-commit-hooks
            rev: v4.4.0
            hooks:
              - id: trailing-whitespace
              - id: end-of-file-fixer
              - id: check-yaml
              - id: check-json
              - id: check-toml
              - id: check-xml
              - id: check-merge-conflict
              - id: check-case-conflict
              - id: mixed-line-ending

          # Nix-specific hooks
          - repo: https://github.com/nix-community/nixpkgs-fmt
            rev: v1.3.0
            hooks:
              - id: nixpkgs-fmt

          # Additional language-specific hooks can be enabled here
          # Python
          # - repo: https://github.com/psf/black
          #   rev: 23.1.0
          #   hooks:
          #     - id: black

          # JavaScript/TypeScript
          # - repo: https://github.com/pre-commit/mirrors-prettier
          #   rev: v3.0.0-alpha.4
          #   hooks:
          #     - id: prettier
      '';
    })
    # Development environment setup script
    (mkIf cfg.taskRunners.just {
      ".local/bin/dev-setup" = {
        text = ''
          #!/bin/sh
          # Development environment setup script
          echo "🚀 Setting up development environment..."

          # Initialize pre-commit if available
          ${optionalString cfg.cicd.pre_commit ''
          if [ -f .pre-commit-config.yaml ]; then
            echo "📋 Installing pre-commit hooks..."
            ${pkgs.pre-commit}/bin/pre-commit install
          fi
          ''}

          # Initialize justfile if it doesn't exist
          if [ ! -f justfile ] && [ ! -f Justfile ]; then
            echo "📝 Creating basic justfile..."
            cat > justfile << 'EOF'
          # Development workflow commands

          # Show available commands
          default:
            @just --list

          # Run tests
          test:
            echo "Running tests..."

          # Format code
          format:
            echo "Formatting code..."

          # Build project
          build:
            echo "Building project..."

          # Clean build artifacts
          clean:
            echo "Cleaning build artifacts..."

          # Start development server
          dev:
            echo "Starting development server..."
          EOF
          fi

          echo "✅ Development environment ready!"
        '';
        executable = true;
      };
    })

    # Project statistics script
    (mkIf cfg.testing.tokei {
      ".local/bin/project-stats" = {
        text = ''
          #!/bin/sh
          # Project statistics and analysis
          echo "📊 Project Statistics"
          echo "===================="
          echo

          # Code statistics
          echo "📝 Code Statistics:"
          ${pkgs.tokei}/bin/tokei
          echo

          # Git statistics
          if [ -d .git ]; then
            echo "🔗 Git Statistics:"
            echo "Total commits: $(git rev-list --all --count)"
            echo "Contributors: $(git shortlog -sn | wc -l)"
            echo "Current branch: $(git branch --show-current)"
            echo "Last commit: $(git log -1 --format='%cr')"
            echo
          fi

          # Directory size
          echo "📁 Directory Size:"
          du -sh . 2>/dev/null || echo "Unable to calculate directory size"
          echo

          # Recent activity
          if [ -d .git ]; then
            echo "⏰ Recent Activity (last 10 commits):"
            git log --oneline -10
          fi
        '';
        executable = true;
      };
    })

    # Development workflow helper
    {
      ".local/bin/dev-help" = {
        text = ''
          #!/bin/sh
          # Development workflow help
          echo "🛠️  Development Workflow Tools"
          echo "=============================="
          echo

          echo "📋 Available Tools:"
          ${optionalString cfg.taskRunners.just ''echo "  just          - Task runner (j, jl, jr)"''}
          ${optionalString cfg.cicd.github_cli ''echo "  gh            - GitHub CLI (gh-pr, gh-status)"''}
          ${optionalString cfg.networking.httpie ''echo "  http          - HTTP client (http-get, http-post)"''}
          ${optionalString cfg.testing.hyperfine ''echo "  hyperfine     - Benchmarking tool"''}
          ${optionalString cfg.networking.jq ''echo "  jq            - JSON processor (pretty-json, json-keys)"''}
          ${optionalString cfg.monitoring.btop ''echo "  btop          - Process monitor (top)"''}
          echo

          echo "📝 Quick Commands:"
          echo "  dev-setup     - Initialize development environment"
          ${optionalString cfg.testing.tokei ''echo "  project-stats - Show project statistics"''}
          echo "  dev-help      - Show this help"
          echo

          echo "📚 Documentation:"
          echo "  All tools are configured with sensible defaults and enhanced aliases."
          echo "  Check individual tool help with: <tool> --help"
        '';
        executable = true;
      };
    }
  ];
}
