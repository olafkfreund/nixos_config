{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.development.core;
in {
  options.custom.development.core = {
    enable = lib.mkEnableOption "core development tools";

    versionControl = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable version control tools";
      };
    };

    buildTools = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable build tools";
      };
    };

    textProcessing = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable text processing tools";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs;
      [
        # Version control
      ]
      ++ lib.optionals cfg.versionControl.enable [
        git
        git-lfs
        gitui
        lazygit
        gh # GitHub CLI
        gitlab-runner
      ]
      ++ lib.optionals cfg.buildTools.enable [
        # Build tools
        gnumake
        cmake
        ninja
        meson
        autoconf
        automake
        libtool
        pkg-config
      ]
      ++ lib.optionals cfg.textProcessing.enable [
        # Text processing
        jq
        yq
        ripgrep
        fd
        sd
        bat
        eza
        fzf
      ];

    # Git configuration
    programs.git = lib.mkIf cfg.versionControl.enable {
      enable = true;
      config = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
      };
    };

    # Enable direnv for project environments
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
