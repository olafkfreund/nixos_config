{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.development;
in {
  options.custom.development = {
    enable = lib.mkEnableOption "development environment";

    languages = lib.mkOption {
      type = lib.types.listOf (lib.types.enum [
        "nix"
        "rust"
        "python"
        "javascript"
        "typescript"
        "go"
        "c"
        "cpp"
        "java"
        "kotlin"
        "swift"
        "ruby"
        "php"
        "lua"
        "haskell"
      ]);
      default = ["nix"];
      description = "Programming languages to support";
    };

    editors = lib.mkOption {
      type = lib.types.listOf (lib.types.enum ["nixvim" "vscode" "jetbrains"]);
      default = ["nixvim"];
      description = "Editors to install";
    };

    tools = lib.mkOption {
      type = lib.types.listOf (lib.types.enum [
        "git"
        "docker"
        "podman"
        "kubernetes"
        "terraform"
        "ansible"
        "vagrant"
        "nodejs"
        "yarn"
        "npm"
        "cargo"
        "rustup"
      ]);
      default = ["git"];
      description = "Development tools to install";
    };

    databases = lib.mkOption {
      type = lib.types.listOf (lib.types.enum [
        "postgresql"
        "mysql"
        "redis"
        "mongodb"
        "sqlite"
      ]);
      default = [];
      description = "Database systems to install";
    };

    containers = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable container support";
      };

      runtime = lib.mkOption {
        type = lib.types.enum ["docker" "podman"];
        default = "docker";
        description = "Container runtime to use";
      };
    };
  };

  imports = [
    ../modules/development/core.nix
    ../modules/development/languages.nix
    ../modules/development/editors.nix
    ../modules/development/containers.nix
    ../modules/development/databases.nix
  ];

  config = lib.mkIf cfg.enable {
    # Enable desktop environment for GUI tools
    custom.desktop.enable = lib.mkDefault true;

    # Core development packages
    environment.systemPackages = with pkgs;
      [
        # Version control
        git
        git-lfs

        # Build tools
        gnumake
        cmake

        # Text processing
        jq
        yq
        ripgrep
        fd

        # Network tools
        curl
        wget
        httpie

        # Compression
        gzip
        xz
        bzip2
      ]
      ++ lib.optionals (builtins.elem "git" cfg.tools) [
        gitui
        lazygit
        gh
      ]
      ++ lib.optionals (builtins.elem "nodejs" cfg.tools) [
        nodejs
        npm
        yarn
      ]
      ++ lib.optionals (builtins.elem "cargo" cfg.tools) [
        cargo
        rustc
        rustfmt
        clippy
      ];

    # Programming language support
    custom.development.languages = {
      nix.enable = builtins.elem "nix" cfg.languages;
      rust.enable = builtins.elem "rust" cfg.languages;
      python.enable = builtins.elem "python" cfg.languages;
      javascript.enable = builtins.elem "javascript" cfg.languages;
      go.enable = builtins.elem "go" cfg.languages;
    };

    # Editor configuration
    custom.development.editors = {
      nixvim.enable = builtins.elem "nixvim" cfg.editors;
      vscode.enable = builtins.elem "vscode" cfg.editors;
    };

    # Container support
    custom.development.containers = lib.mkIf cfg.containers.enable {
      enable = true;
      runtime = cfg.containers.runtime;
    };

    # Enable virtualization for development VMs
    virtualisation = {
      libvirtd = {
        enable = true;
        qemu = {
          package = pkgs.qemu_kvm;
          ovmf = {
            enable = true;
            packages = [pkgs.OVMFFull.fd];
          };
        };
      };
    };

    # Add user to required groups
    users.users =
      lib.mapAttrs (_: user: {
        extraGroups =
          user.extraGroups
          ++ [
            "docker"
            "libvirtd"
            "kvm"
          ];
      })
      config.users.users;
  };
}
