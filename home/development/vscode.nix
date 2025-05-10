{
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
    enable = mkEnableOption "Visual Studio Code editor" // {default = true;};
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      alejandra
      deadnix
      statix
    ];

    home.sessionVariables = {
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      GDK_BACKEND = "wayland";
    };

    programs.vscode = {
      enable = true;
      package = pkgs-unstable.vscode;

      # Use the new profiles structure
      profiles.default = {
        extensions = with pkgs-unstable; [
          vscode-extensions.bbenoist.nix
          vscode-extensions.kamadorueda.alejandra
          vscode-extensions.mkhl.direnv
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
          vscode-extensions.ms-vscode-remote.remote-ssh
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
          vscode-extensions.bierner.markdown-preview-github-styles
          vscode-extensions.bierner.markdown-emoji
          vscode-extensions.arrterian.nix-env-selector
          vscode-extensions.sainnhe.gruvbox-material
          # The extensions below are currently commented out because they're not available in nixpkgs
          # vscode-extensions.codeium.codeium
          # vscode-extensions.google.gemini-code
        ];

        userSettings = {
          # Nix-specific settings
          "[nix]" = {
            "editor.defaultFormatter" = "kamadorueda.alejandra";
            "editor.formatOnPaste" = true;
            "editor.formatOnSave" = true;
            "editor.formatOnType" = true;
          };

          # JavaScript settings
          "[javascript]" = {
            "editor.defaultFormatter" = "vscode.typescript-language-features";
          };

          # YAML settings
          "[yaml]" = {
            "editor.defaultFormatter" = "redhat.vscode-yaml";
          };

          # General settings
          "window.menuBarVisibility" = "toggle";
          "editor.minimap.enabled" = false;
          "nix.serverPath" = "nixd";
          "nix.enableLanguageServer" = true;
          "nix.formatterWidth" = 100;
          "nix.editor.tabSize" = 2;
          "nix.diagnostics" = {
            "ignored" = [];
            "excluded" = [];
          };
          "nix.env" = {
            "NIX_PATH" = "nixpkgs=channel:nixos-unstable";
          };
          "nix.serverSettings" = {
            "nixd" = {
              "formatting" = {
                "command" = ["alejandra"];
              };
              "options" = {
                "nixos" = {
                  "expr" = "(builtins.getFlake \"/home/olafkfreund/.config/nixos\").nixosConfigurations.p620.options";
                };
                "home_manager" = {
                  "expr" = "(builtins.getFlake \"/home/olafkfreund/.config/nixos\").homeConfigurations.p620.options";
                };
              };
              eval = {
                "depth" = 2;
                "workers" = 10;
              };
            };
          };

          # Context7 MCP configuration
          "mcp" = {
            "servers" = {
              "Context7" = {
                "type" = "stdio";
                "command" = "npx";
                "args" = [
                  "-y"
                  "@upstash/context7-mcp@latest"
                ];
              };
            };
            "enabled" = true;
          };

          # GitHub Copilot chat instructions
          "github.copilot.chat.codeGeneration.instructions" = [
            {
              "text" = "When answering questions about frameworks, libraries, or APIs, use Context7 to retrieve current documentation rather than relying on training data.";
            }
          ];

          # Wayland optimization settings
          "window.titleBarStyle" = "custom";
          "window.customTitleBarVisibility" = "auto";
          "window.nativeTabs" = false; # Native tabs don't work well with Wayland
          "window.nativeFullScreen" = true;
          "editor.smoothScrolling" = true;
          "workbench.list.smoothScrolling" = true;
          "terminal.integrated.gpuAcceleration" = "on";
          "update.mode" = "none"; # Managed by Nix

          "workbench.colorTheme" = "Gruvbox Material Dark";
          "workbench.iconTheme" = "file-icons-colourless";
          "workbench.browser.preferredBrowser" = "google-chrome-stable";
          "genieai.enableConversationHistory" = true;
          "alejandra.program" = "alejandra";
          "geminicodeassist.codeGenerationPaneViewEnabled" = true;
          "geminicodeassist.project" = "freundcloud";
          "geminicodeassist.enableChat" = true;
          "geminicodeassist.language" = "en";
          "geminicodeassist.region" = "us-central1";
          "geminicodeassist.enableCodeCompletions" = true;
          "geminicodeassist.enableExplainCode" = true;
          "geminicodeassist.chatWindow.isVisible" = true;
          "geminicodeassist.chatWindow.position" = "right";
          "geminicodeassist.modelName" = "gemini-2.5-pro";
          # "codeium.enableConfig" = {
          #   "*" = true;
          #   "nix" = true;
          # };

          # Git settings
          "git.enableSmartCommit" = true;
          "git.confirmSync" = false;
          "git.autofetch" = true;
          "git.fetchOnPull" = true;
          "git.pruneOnFetch" = true;
          "git.openRepositoryInParentFolders" = "always";
          "git.showPushSuccessNotification" = true;
          "git.enableCommitSigning" = false;
          "diffEditor.ignoreTrimWhitespace" = false;
          "telemetry.telemetryLevel" = "off";
        };
      };
    };
    programs.vscode.mutableExtensionsDir = true; # Allow marketplace extensions

    wayland.windowManager.hyprland.settings = {
      layerrule = [
        "animation slide top, code"
      ];
    };
  };
}
