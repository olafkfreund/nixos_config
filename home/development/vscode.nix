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
      # Network stability enhancements
      DISABLE_REQUEST_THROTTLING = "1";
      ELECTRON_FORCE_WINDOW_MENU_BAR = "1";
      # Increase connection pools and timeouts
      CHROME_NET_TCP_SOCKET_CONNECT_TIMEOUT_MS = "60000";
      CHROME_NET_TCP_SOCKET_CONNECT_ATTEMPT_DELAY_MS = "2000";
    };

    programs.vscode = {
      enable = true;
      package = pkgs-unstable.vscode;

      # Use the new profiles structure
      profiles.default = {
        extensions = with pkgs; [
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
          vscode-extensions.davidanson.vscode-markdownlint
          vscode-extensions.eamodio.gitlens
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
            "excluded" = [
              ".direnv/**"
              "result/**"
              ".git/**"
              "node_modules/**"
            ];
          };
          "nix.env" = {
            "NIX_PATH" = "nixpkgs=channel:nixos-unstable";
          };

          "nix.serverSettings" = {
            "nixd" = {
              "formatting" = {
                "command" = ["alejandra"];
                "timeout_ms" = 5000;
              };
              "options" = {
                "enable" = true;
                "target" = ["all"];
                "offline" = true;
                "nixos" = {
                  "expr" = "(builtins.getFlake (\"git+file://\" + toString /home/olafkfreund/.config/nixos)).nixosConfigurations.p620.options";
                };
                "home_manager" = {
                  "expr" = "(builtins.getFlake (\"git+file://\" + toString /home/olafkfreund/.config/nixos)).homeConfigurations.\"olafkfreund@p620\".options";
                };
              };
              "diagnostics" = {
                "enable" = true;
                "ignored" = [];
                "excluded" = [
                  "\\.direnv"
                  "result"
                  "\\.git"
                  "node_modules"
                ];
              };
              "eval" = {
                "depth" = 2;
                "workers" = 3;
                "trace" = {
                  "server" = "off";
                  "evaluation" = "off";
                };
              };
              "completion" = {
                "enable" = true;
                "priority" = 10;
                "insertSingleCandidateImmediately" = true;
              };
              "path" = {
                "include" = ["**/*.nix"];
                "exclude" = [
                  ".direnv/**"
                  "result/**"
                  ".git/**"
                  "node_modules/**"
                ];
              };
              "lsp" = {
                "progressBar" = true;
                "snippets" = true;
                "logLevel" = "info";
                "maxIssues" = 100;
                "failureHandling" = {
                  "retry" = {
                    "max" = 3;
                    "delayMs" = 1000;
                  };
                  "fallbackToOffline" = true;
                };
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
              "nixos" = {
                "type" = "stdio";
                "command" = "nix";
                "args" = [
                  "shell"
                  "nixpkgs#uv"
                  "--command"
                  "uvx"
                  "mcp-nixos@0.3.1"
                ];
              };
              "@rawveg/ollama-mcp" = {
                "command" = "npx";
                "args" = [
                  "-y"
                  "@rawveg/ollama-mcp"
                ];
              };
              "terraform-registry" = {
                "command" = "npx";
                "args" = [
                  "-y"
                  "terraform-mcp-server"
                ];
              };
              "gcp" = {
                "command" = "sh";
                "args" = [
                  "-c"
                  "npx -y gcp-mcp"
                ];
              };
            };
          };

          # GitHub Copilot chat instructions
          "github.copilot.chat.codeGeneration.instructions" = [
            {
              "text" = "When answering questions about frameworks, libraries, or APIs, use Context7 to retrieve current documentation rather than relying on training data.";
            }
          ];

          # GitHub Copilot custom instructions configuration
          "github.copilot.chat.customInstructions" = {
            "instructions" = ''
              # NixOS Development Guidelines for GitHub Copilot

              - Use declarative configuration with NixOS modules
              - Follow Nixpkgs contribution guidelines
              - Maintain pure and reproducible builds
              - Use flakes for dependency management
              - Prefer functional programming patterns
              - Use 2 spaces for indentation
              - Use camelCase for variable and function names
              - Group related options together
              - Document options with description field
              - Include example values in documentation
              - Keep configurations pure and reproducible
              - Use systemd service units when appropriate
              - Follow least privilege principle
              - Implement proper error handling
              - Document breaking changes
              - Handle upgrades gracefully'';
            "context" = ''
              I am working on a NixOS configuration using Home Manager and Flakes.
              Please provide code that follows NixOS best practices and conventions.
              Consider performance, security, and maintainability in all suggestions.'';
          };

          # Wayland optimization settings
          "window.titleBarStyle" = "custom";
          "window.customTitleBarVisibility" = "auto";
          "window.nativeTabs" = false; # Native tabs don't work well with Wayland
          "window.nativeFullScreen" = true;
          "editor.smoothScrolling" = true;
          "workbench.list.smoothScrolling" = true;
          "terminal.integrated.gpuAcceleration" = "on";
          "update.mode" = "none"; # Managed by Nix
          "chat.mcp.enabled" = true;
          "chat.agent.enabled" = true;
          "chat.mcp.discovery.enabled" = true;
          "chat.tools.autoApprove" = true;
          "chat.agent.maxRequests" = 15;
          "github.copilot.chat.codesearch.enabled" = true;
          "github.copilot.chat.scopeSelection" = true;
          "github.copilot.chat.agent.thinkingTool" = true;
          "githubPullRequests.notifications" = "pullRequests";
          "workbench.colorTheme" = "Gruvbox Material Dark";
          "workbench.iconTheme" = "file-icons-colourless";
          "workbench.browser.preferredBrowser" = "google-chrome-stable";
          "genieai.enableConversationHistory" = true;
          "alejandra.program" = "alejandra";
          "geminicodeassist.codeGenerationPaneViewEnabled" = true;
          "geminicodeassist.project" = "gen-lang-client-0799345902";
          "geminicodeassist.enableChat" = true;
          "geminicodeassist.language" = "en";
          "geminicodeassist.region" = "us-central1";
          "geminicodeassist.enableCodeCompletions" = true;
          "geminicodeassist.enableExplainCode" = true;
          "geminicodeassist.chatWindow.isVisible" = true;
          "geminicodeassist.chatWindow.position" = "right";
          "geminicodeassist.modelName" = "gemini-2.5-pro";
          "workbench.externalBrowser" = "google-chrome-stable";
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

    # Set up XDG file associations for VSCode
    xdg.mimeApps = {
      enable = true;
      associations.added = {
        "text/plain" = ["code.desktop"];
        "text/markdown" = ["code.desktop"];
        "application/json" = ["code.desktop"];
        "application/x-yaml" = ["code.desktop"];
        "text/x-python" = ["code.desktop"];
        "text/x-csrc" = ["code.desktop"];
        "text/x-c++src" = ["code.desktop"];
        "text/x-chdr" = ["code.desktop"];
        "text/x-c++hdr" = ["code.desktop"];
        "text/x-shellscript" = ["code.desktop"];
        "text/html" = ["code.desktop"];
        "text/css" = ["code.desktop"];
        "text/javascript" = ["code.desktop"];
      };
    };

    # Custom VSCode desktop entry with Wayland optimizations
    xdg.desktopEntries.code = {
      name = "Visual Studio Code";
      exec = "code --ozone-platform=wayland --enable-features=UseOzonePlatform,WaylandWindowDecorations %F";
      categories = ["Development" "IDE"];
      comment = "Code Editing. Optimized for Wayland.";
      icon = "code";
      mimeType = [
        "text/plain"
        "text/markdown"
        "application/json"
        "application/x-yaml"
        "text/x-python"
        "text/x-csrc"
        "text/x-c++src"
        "text/x-chdr"
        "text/x-c++hdr"
        "text/x-shellscript"
        "text/html"
        "text/css"
        "text/javascript"
      ];
      type = "Application";
    };

    wayland.windowManager.hyprland.settings = {
      layerrule = [
        "animation slide top, code"
      ];
    };
  };
}
