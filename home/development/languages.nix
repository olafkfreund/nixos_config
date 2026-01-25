# Enhanced Language Support and Tooling
# Unified language server, formatter, and development tool configuration
{ pkgs
, lib
, ...
}:
with lib; let
  # Language support configuration
  cfg = {
    # Core programming languages
    languages = {
      nix = {
        enable = true;
        lsp = "nixd";
        formatters = [ "alejandra" "deadnix" "statix" ];
        tools = [ "nix-tree" "nix-diff" "nix-prefetch-git" ];
      };

      python = {
        enable = true;
        lsp = "pylsp";
        formatters = [ "black" "isort" ];
        tools = [ "poetry" "pipenv" "pytest" "mypy" "flake8" ];
        versions = [ "python3" "python312" "python313" ];
      };

      javascript = {
        enable = true;
        lsp = "typescript-language-server";
        formatters = [ "prettier" "eslint" ];
        tools = [ "nodejs" "npm" "yarn" "pnpm" ];
        variants = [ "typescript" "react" "vue" "svelte" ];
      };

      go = {
        enable = true;
        lsp = "gopls";
        formatters = [ "gofmt" "goimports" ];
        tools = [ "go" "delve" "gore" "gotests" ];
      };

      rust = {
        enable = true;
        lsp = "rust-analyzer";
        formatters = [ "rustfmt" ];
        tools = [ "cargo" "rustc" "clippy" "miri" ];
      };

      cpp = {
        enable = false;
        lsp = "clangd";
        formatters = [ "clang-format" ];
        tools = [ "gcc" "cmake" "gdb" ];
      };

      java = {
        enable = false;
        lsp = "jdtls";
        formatters = [ "google-java-format" ];
        tools = [ "jdk" "maven" "gradle" ];
      };

      csharp = {
        enable = false;
        lsp = "omnisharp";
        formatters = [ "csharpier" ];
        tools = [ "dotnet" ];
      };
    };

    # Development utilities
    utilities = {
      vcs = {
        git = true;
        lazygit = true;
        gh = true;
        git-crypt = true;
      };

      containers = {
        docker = true;
        podman = false;
        kubectl = true;
        helm = false;
      };

      databases = {
        sqlite = true;
        postgresql = false;
        redis = false;
      };

      cloud = {
        terraform = true;
        aws = false;
        gcp = false;
      };

      monitoring = {
        htop = true;
        btop = true;
        bandwhich = true;
        ncdu = true;
      };
    };

    # AI development tools
    ai = {
      copilot = true;
      codeium = true;
      ollama = false;
    };
  };

  # Helper functions
  enabledLanguages = filterAttrs (_name: lang: lang.enable) cfg.languages;
  enabledUtilities = filterAttrs (_name: util: any (x: x) (attrValues util)) cfg.utilities;

  # Package collections
  languagePackages = flatten (mapAttrsToList
    (
      name: lang:
        optionals lang.enable (
          # LSP servers
          (optional (lang.lsp == "nixd") pkgs.nixd)
          ++ (optional (lang.lsp == "pylsp") pkgs.python313Packages.python-lsp-server)
          ++ (optional (lang.lsp == "typescript-language-server") pkgs.nodePackages.typescript-language-server)
          ++ (optional (lang.lsp == "gopls") pkgs.gopls)
          ++ (optional (lang.lsp == "rust-analyzer") pkgs.rust-analyzer)
          ++ (optional (lang.lsp == "clangd") pkgs.clang-tools)
          ++
          # Formatters
          (optional (elem "alejandra" lang.formatters) pkgs.alejandra)
          ++ (optional (elem "deadnix" lang.formatters) pkgs.deadnix)
          ++ (optional (elem "statix" lang.formatters) pkgs.statix)
          ++ (optional (elem "black" lang.formatters) pkgs.python313Packages.black)
          ++ (optional (elem "isort" lang.formatters) pkgs.python313Packages.isort)
          ++ (optional (elem "prettier" lang.formatters) pkgs.nodePackages.prettier)
          ++ (optional (elem "eslint" lang.formatters) pkgs.nodePackages.eslint)
          ++ (optional (elem "gofmt" lang.formatters) pkgs.go)
          ++ (optional (elem "rustfmt" lang.formatters) pkgs.rustfmt)
          ++
          # Language-specific tools
          (optionals (name == "nix") (with pkgs; [ nix-tree nix-diff nix-prefetch-git ]))
          ++ (optionals (name == "python") (with pkgs; [
            python313Packages.poetry-core
            python313Packages.pytest
            python313Packages.mypy
            python313Packages.flake8
          ]))
          ++ (optionals (name == "javascript") (with pkgs; [ nodejs_24 yarn ]))
          ++ (optionals (name == "go") (with pkgs; [ go delve gore gotests ]))
          ++ (optionals (name == "rust") (with pkgs; [ cargo rustc clippy ]))
        )
    )
    enabledLanguages);

  utilityPackages = flatten (mapAttrsToList
    (
      category: utils:
        optionals (any (x: x) (attrValues utils)) (
          # VCS tools
          (optionals (category == "vcs") (
            with pkgs;
            (optional utils.git git)
            ++ (optional utils.lazygit lazygit)
            ++ (optional utils.gh gh)
            ++ (optional utils.git-crypt git-crypt)
          ))
          ++
          # Container tools
          (optionals (category == "containers") (
            with pkgs;
            (optional utils.docker docker)
            ++ (optional utils.podman podman)
            ++ (optional utils.kubectl kubectl)
            ++ (optional utils.helm helm)
          ))
          ++
          # Database tools
          (optionals (category == "databases") (
            with pkgs;
            (optional utils.sqlite sqlite)
            ++ (optional utils.postgresql postgresql)
            ++ (optional utils.redis redis)
          ))
          ++
          # Cloud tools
          (optionals (category == "cloud") (
            with pkgs;
            (optional utils.terraform terraform)
            ++ (optional utils.aws awscli2)
            ++ (optional utils.gcp google-cloud-sdk)
          ))
          ++
          # Monitoring tools
          (optionals (category == "monitoring") (
            with pkgs;
            (optional utils.htop htop)
            ++ (optional utils.btop btop)
            ++ (optional utils.bandwhich bandwhich)
            ++ (optional utils.ncdu ncdu)
          ))
        )
    )
    enabledUtilities);

  aiPackages = with pkgs; (optional cfg.ai.ollama ollama);
in
{
  # Git configuration enhancement
  programs.git = mkIf cfg.utilities.vcs.git {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      core.editor = "nvim";
      merge.tool = "vimdiff";
      diff.tool = "vimdiff";
    };
  };

  # Direnv for project environment management
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # Combined home configuration
  home = {
    # Language support packages
    packages = languagePackages ++ utilityPackages ++ aiPackages;

    # Development shell aliases
    shellAliases = mkMerge [
      # Nix development
      (mkIf cfg.languages.nix.enable {
        nix-build-test = "nix-build --dry-run";
        nix-shell-pure = "nix-shell --pure";
        nix-fmt = "alejandra";
        nix-check = "statix check && deadnix check";
      })

      # Python development
      (mkIf cfg.languages.python.enable {
        py = "python3";
        pip-upgrade = "pip install --upgrade pip";
        pytest-watch = "ptw";
        py-format = "black . && isort .";
      })

      # JavaScript/TypeScript development
      (mkIf cfg.languages.javascript.enable {
        npm-ls = "npm list --depth=0";
        npm-outdated = "npm outdated";
        yarn-upgrade = "yarn upgrade-interactive";
        js-format = "prettier --write .";
      })

      # Go development
      (mkIf cfg.languages.go.enable {
        go-mod-tidy = "go mod tidy";
        go-test-verbose = "go test -v";
        go-build-all = "go build ./...";
        go-format = "gofmt -w .";
      })

      # Rust development
      (mkIf cfg.languages.rust.enable {
        cargo-check-all = "cargo check --all-targets";
        cargo-test-all = "cargo test --all";
        cargo-clippy-all = "cargo clippy --all-targets";
        rust-format = "cargo fmt";
      })

      # Git shortcuts
      (mkIf cfg.utilities.vcs.git {
        gs = "git status";
        ga = "git add";
        gc = "git commit";
        gp = "git push";
        gl = "git log --oneline";
        gd = "git diff";
        # Note: lg function defined in shell config for advanced lazygit integration
      })

      # Container shortcuts
      (mkIf cfg.utilities.containers.docker {
        d = "docker";
        dc = "docker-compose";
        k = "kubectl";
      })
    ];

    # Environment variables for development
    sessionVariables = mkMerge [
      # General development
      {
        EDITOR = "nvim";
        BROWSER = "firefox";
        TERM = "foot";
      }

      # Language-specific
      (mkIf cfg.languages.go.enable {
        GOPATH = "$HOME/go";
        GOBIN = "$HOME/go/bin";
      })

      (mkIf cfg.languages.rust.enable {
        CARGO_HOME = "$HOME/.cargo";
      })

      (mkIf cfg.languages.python.enable {
        PYTHONDONTWRITEBYTECODE = "1";
        PYTHONUNBUFFERED = "1";
      })
    ];

    # Language server configurations export for editors
    file.".config/development/lsp-config.json".text = builtins.toJSON {
      languages =
        mapAttrs
          (_name: lang: {
            inherit (lang) lsp;
            inherit (lang) formatters;
            enabled = lang.enable;
          })
          cfg.languages;

      paths = {
        nixd = "${pkgs.nixd}/bin/nixd";
        pylsp = "${pkgs.python313Packages.python-lsp-server}/bin/pylsp";
        typescript-language-server = "${pkgs.nodePackages.typescript-language-server}/bin/typescript-language-server";
        gopls = "${pkgs.gopls}/bin/gopls";
        rust-analyzer = "${pkgs.rust-analyzer}/bin/rust-analyzer";
        clangd = "${pkgs.clang-tools}/bin/clangd";
      };
    };
  };
}
