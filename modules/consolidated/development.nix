# Consolidated Development Module
# Replaces 20+ development-related modules
{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.consolidated.development;

  # Smart language detection based on host usage
  languagePackages = {
    essential = with pkgs; [
      git
      git-crypt
      gh
      curl
      wget
      jq
      yq-go # Use Go version consistently
      direnv
    ];

    nix = with pkgs; [
      nil
      nixd
      nixfmt-classic
      nixpkgs-fmt
      statix
      deadnix
      nix-tree
      nix-diff
    ];

    python = with pkgs; [
      python311
      python311Packages.pip
      python311Packages.virtualenv
      python311Packages.poetry
      python311Packages.numpy
      python311Packages.requests
    ];

    javascript = with pkgs; [
      nodejs_22
      npm
      yarn
      nodePackages.typescript
      nodePackages.eslint
      nodePackages.prettier
    ];

    rust = with pkgs; [
      rustc
      cargo
      rustfmt
      clippy
      rust-analyzer
    ];

    go = with pkgs; [
      go
      gopls
      golangci-lint
    ];

    system = with pkgs; [
      gcc
      gnumake
      cmake
      pkg-config
      openssl
      zlib
      systemd
    ];
  };

  # Editor configurations (consolidated)
  editorConfigs = {
    vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        ms-python.python
        rust-lang.rust-analyzer
        bradlc.vscode-tailwindcss
        esbenp.prettier-vscode
      ];
      userSettings = {
        "editor.formatOnSave" = true;
        "editor.tabSize" = 2;
        "files.autoSave" = "onFocusChange";
      };
    };
  };

in
{
  options.consolidated.development = {
    enable = mkEnableOption "consolidated development environment";

    languages = {
      nix = mkEnableOption "Nix development tools" // { default = true; };
      python = mkEnableOption "Python development stack";
      javascript = mkEnableOption "JavaScript/Node.js development";
      rust = mkEnableOption "Rust development tools";
      go = mkEnableOption "Go development tools";
      system = mkEnableOption "System development (C/C++)" // { default = true; };
    };

    editors = {
      vscode = mkEnableOption "Visual Studio Code";
      neovim = mkEnableOption "Neovim with LazyVim";
    };

    containers = {
      docker = mkEnableOption "Docker development";
      podman = mkEnableOption "Podman alternative";
    };

    profile = mkOption {
      type = types.enum [ "minimal" "full" "specialized" ];
      default = "full";
      description = "Development environment profile";
    };
  };

  config = mkIf cfg.enable {
    # Development packages (smart loading)
    environment.systemPackages =
      languagePackages.essential
      ++ optionals cfg.languages.nix languagePackages.nix
      ++ optionals cfg.languages.python languagePackages.python
      ++ optionals cfg.languages.javascript languagePackages.javascript
      ++ optionals cfg.languages.rust languagePackages.rust
      ++ optionals cfg.languages.go languagePackages.go
      ++ optionals cfg.languages.system languagePackages.system;

    # Development programs
    programs = {
      # VS Code configuration
      vscode = mkIf cfg.editors.vscode editorConfigs.vscode;

      # Neovim with LazyVim (consolidated config)
      neovim = mkIf cfg.editors.neovim {
        enable = true;
        defaultEditor = true;
        viAlias = true;
        vimAlias = true;

        configure = {
          customRC = ''
            " LazyVim setup will be handled by Home Manager
            lua require("lazy").setup()
          '';
        };
      };

      # Direnv for project environments
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      # Better shell for development
      zsh.enable = mkDefault true;

      # Git configuration
      git = {
        enable = true;
        lfs.enable = true;
      };
    };

    # Development services
    services = {
      # Docker (if enabled)
      docker = mkIf cfg.containers.docker {
        enable = true;
        enableOnBoot = mkDefault false; # Start on demand
        autoPrune.enable = true;
      };
    };

    # Virtualization for development
    virtualisation = mkIf cfg.containers.docker {
      docker = {
        enable = true;
        enableOnBoot = false;
        daemon.settings = {
          # Performance optimizations
          log-driver = "json-file";
          log-opts = {
            max-size = "10m";
            max-file = "3";
          };
        };
      };
    };


    # Development user groups
    users.groups = {
      docker = mkIf cfg.containers.docker { };
    };

    # Environment variables for development
    environment.variables = {
      EDITOR = mkIf cfg.editors.neovim "nvim";
      VISUAL = mkIf cfg.editors.neovim "nvim";

      # Development-specific paths
      CARGO_HOME = mkIf cfg.languages.rust "/home/\${USER}/.cargo";
      GOPATH = mkIf cfg.languages.go "/home/\${USER}/go";
      NODE_PATH = mkIf cfg.languages.javascript "${pkgs.nodejs_22}/lib/node_modules";
    };

    # Performance optimizations for development
    nix.settings = {
      # Optimize for development builds
      builders-use-substitutes = true;
      keep-outputs = true; # Keep build outputs for development
      keep-derivations = true;
    };
  };
}
