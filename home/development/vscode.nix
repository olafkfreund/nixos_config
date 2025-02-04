{
  inputs,
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
with lib; let
  cfg = config.editor.vscode;
in {
  options.editor.vscode = {
    enable = mkEnableOption {
      default = true;
      description = "vscode";
    };
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [alejandra deadnix statix];

    programs.vscode.enable = true;
    programs.vscode.package = pkgs-unstable.vscode;

    programs.vscode.extensions = with pkgs-unstable; [
      vscode-extensions.bbenoist.nix
      vscode-extensions.kamadorueda.alejandra
      vscode-extensions.tailscale.vscode-tailscale
      vscode-extensions.jnoortheen.nix-ide
      vscode-extensions.golang.go
      vscode-extensions.skellock.just
      vscode-extensions.redhat.vscode-yaml
      vscode-extensions.redhat.vscode-xml
      vscode-extensions.redhat.ansible
      vscode-extensions.pkief.material-product-icons
      vscode-extensions.pkief.material-icon-theme
      vscode-extensions.ms-vscode-remote.remote-containers
      vscode-extensions.ms-kubernetes-tools.vscode-kubernetes-tools
      vscode-extensions.ms-azuretools.vscode-docker
      vscode-extensions.mads-hartmann.bash-ide-vscode
      vscode-extensions.jdinhlife.gruvbox
      vscode-extensions.hediet.vscode-drawio
      vscode-extensions.hashicorp.terraform
      vscode-extensions.github.vscode-pull-request-github
      vscode-extensions.github.vscode-github-actions
      vscode-extensions.github.copilot-chat
      vscode-extensions.github.copilot
      vscode-extensions.genieai.chatgpt-vscode
      vscode-extensions.formulahendry.auto-close-tag
      vscode-extensions.file-icons.file-icons
      vscode-extensions.donjayamanne.githistory
      vscode-extensions.continue.continue
      vscode-extensions.bierner.markdown-preview-github-styles
      vscode-extensions.bierner.markdown-emoji
      # vscode-extensions.asvetliakov.vscode-neovim
      vscode-extensions.arrterian.nix-env-selector
      vscode-extensions.sainnhe.gruvbox-material
    ];

    programs.vscode.userSettings."[nix]" = {
      "editor.defaultFormatter" = "kamadorueda.alejandra";
      "editor.formatOnPaste" = true;
      "editor.formatOnSave" = true;
      "editor.formatOnType" = true;
    };
    programs.vscode.userSettings = {
      "window.menuBarVisibility" = "toggle";
      # "workbench.sideBar.location" = "right";
      "nix.serverPath" = "nixd";
      # "gopls" = {
      #   "ui.semanticTokens" = true;
      # };
      "nix.enableLanguageServer" = true;
      "nix.serverSettings" = {
        "nixd" = {
          "formatting" = {
            "command" = ["alejandra"];
          };
          "options" = {
            "nixos" = {
              "expr" = "(builtins.getFlake \"/home/olafkfreund/.config/nixos\").nixosConfigurations.razer.options";
            };
            "home_manager" = {
              "expr" = "(builtins.getFlake \"/home/olafkfreund/.config/nixos\").homeConfigurations.razer.options";
            };
          };
        };
      };
      "workbench.colorTheme" = "Gruvbox Dark Medium";
      "workbench.iconTheme" = "gruvbox-icon-theme";
      "workbench.externalBrowser" = "google-chrome-stable";
      "genieai.enableConversationHistory" = true;
      "editor.minimap.enabled" = false;
      "[javascript]" = {
        "editor.defaultFormatter" = "vscode.typescript-language-features";
      };
      "alejandra.program" = "alejandra";
      # "redhat.telemetry.enabled" = false;
      "[yaml]" = {
        "editor.defaultFormatter" = "redhat.vscode-yaml";
      };
      # "terminal.integrated.gpuAcceleration" = "off";
      "geminicodeassist.codeGenerationPaneViewEnabled" = true;
      "geminicodeassist.project" = "freundcloud";
      "extensions.experimental.affinity" = {
        "asvetliakov.vscode-neovim" = 1;
      };
      # "codeium.enableConfig" = {
      #   "*" = true;
      #   "nix" = true;
      # };
    };
  };
}
