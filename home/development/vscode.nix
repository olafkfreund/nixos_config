{
  config,
  lib,
  pkgs,
  # pkgs-unstable,
  ...
}:
with lib; let
  cfg = config.editor.vscode;

  # Custom extensions not available in nixpkgs
  # Note: Uncomment and add proper sha256 hashes when needed
  customExtensions = [
    # Example: Uncomment and get hash using scripts/get-extension-hashes.sh
    # (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    #   mktplcRef = {
    #     name = "geminicodeassist";
    #     publisher = "google";
    #     version = "2.36.0";
    #     sha256 = "sha256-REPLACE_WITH_ACTUAL_HASH";
    #   };
    #   meta = {
    #     description = "Google Gemini Code Assist for VS Code";
    #     license = lib.licenses.unfree;
    #   };
    # })
  ];
in {
  options.editor.vscode = {
    enable = mkEnableOption "Visual Studio Code editor" // {default = true;};
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      alejandra
      deadnix
      statix
      icu # Required for .NET globalization support (MCP servers)
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
      package = pkgs.vscode;

      # Use the new profiles structure
      profiles.default = {
        extensions = with pkgs;
          [
            vscode-extensions.bbenoist.nix
            vscode-extensions.kamadorueda.alejandra
            vscode-extensions.mkhl.direnv
            vscode-extensions.tailscale.vscode-tailscale
            vscode-extensions.jnoortheen.nix-ide
            vscode-extensions.golang.go
            vscode-extensions.skellock.just
            vscode-extensions.redhat.vscode-yaml
            vscode-extensions.redhat.vscode-xml
            # vscode-extensions.redhat.ansible
            vscode-extensions.pkief.material-product-icons
            vscode-extensions.pkief.material-icon-theme
            vscode-extensions.ms-vscode-remote.remote-containers
            vscode-extensions.ms-vscode-remote.remote-ssh
            vscode-extensions.ms-kubernetes-tools.vscode-kubernetes-tools
            # vscode-extensions.ms-azuretools.vscode-docker
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

            # Python support
            vscode-extensions.ms-python.python
            vscode-extensions.ms-python.debugpy
            vscode-extensions.ms-python.vscode-pylance

            # Additional useful extensions
            vscode-extensions.esbenp.prettier-vscode # Prettier formatter
            vscode-extensions.bradlc.vscode-tailwindcss # Tailwind CSS
            vscode-extensions.rust-lang.rust-analyzer # Rust support
            vscode-extensions.ms-vscode.cpptools # C++ support
            vscode-extensions.ms-dotnettools.csharp # C# support
            vscode-extensions.ms-vscode.live-server # Live server
            vscode-extensions.usernamehw.errorlens # Error lens for better error visibility
            vscode-extensions.streetsidesoftware.code-spell-checker # Spell checker
            # vscode-extensions.ms-vscode.vscode-json # JSON support - not available
            vscode-extensions.yzhang.markdown-all-in-one # Better markdown support
            vscode-extensions.christian-kohler.path-intellisense # Path autocomplete
            vscode-extensions.oderwat.indent-rainbow # Indent visualization
            vscode-extensions.gruntfuggly.todo-tree # TODO highlighting
            vscode-extensions.vscode-icons-team.vscode-icons # Better icons
            vscode-extensions.ms-vscode.hexeditor # Hex editor
            # vscode-extensions.ms-ceintl.vscode-language-pack-en # English language pack - not available

            # Docker support (if available in nixpkgs)
            # vscode-extensions.ms-azuretools.vscode-docker

            # Add any missing extensions here by finding their nixpkgs equivalent
            # Or use vscode-utils.buildVscodeMarketplaceExtension for unavailable ones
          ]
          ++ customExtensions;

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
            "editor.insertSpaces" = true;
            "editor.tabSize" = 2;
            "editor.autoIndent" = "advanced";
          };

          # Markdown settings
          "[markdown]" = {
            "editor.defaultFormatter" = "yzhang.markdown-all-in-one";
            "editor.wordWrap" = "on";
            "editor.quickSuggestions" = {
              "comments" = "off";
              "strings" = "off";
              "other" = "off";
            };
          };

          # JSON settings
          "[json]" = {
            "editor.defaultFormatter" = "ms-vscode.vscode-json";
            "editor.tabSize" = 2;
          };

          # Python settings
          "[python]" = {
            "editor.defaultFormatter" = "ms-python.black-formatter";
            "editor.formatOnSave" = true;
            "editor.codeActionsOnSave" = {
              "source.organizeImports" = "explicit";
            };
          };

          # Go settings
          "[go]" = {
            "editor.formatOnSave" = true;
            "editor.codeActionsOnSave" = {
              "source.organizeImports" = "explicit";
            };
          };

          # Rust settings
          "[rust]" = {
            "editor.defaultFormatter" = "rust-lang.rust-analyzer";
            "editor.formatOnSave" = true;
          };

          # General settings
          "window.menuBarVisibility" = "toggle";
          "editor.minimap.enabled" = false;
          "editor.bracketPairColorization.enabled" = true;
          "editor.guides.bracketPairs" = "active";
          "editor.linkedEditing" = true;
          "editor.cursorBlinking" = "smooth";
          "editor.cursorSmoothCaretAnimation" = "on";
          "editor.fontLigatures" = true;
          "editor.fontSize" = mkDefault 14;
          "editor.fontFamily" = mkDefault "'JetBrainsMono Nerd Font', 'Droid Sans Mono', 'monospace'";
          "editor.lineHeight" = 1.6;
          "editor.letterSpacing" = 0.5;
          "editor.tabSize" = 2;
          "editor.insertSpaces" = true;
          "editor.trimAutoWhitespace" = true;
          "editor.detectIndentation" = true;
          "editor.wordWrap" = "bounded";
          "editor.wordWrapColumn" = 100;
          "editor.rulers" = [80 100];
          "editor.formatOnSave" = true;
          "editor.formatOnPaste" = true;
          "editor.codeActionsOnSave" = {
            "source.organizeImports" = "explicit";
            "source.fixAll" = "explicit";
          };
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
                  "expr" = "(builtins.getFlake (\"git+file://\" + toString /home/${config.home.username}/.config/nixos)).nixosConfigurations.p620.options";
                };
                "home_manager" = {
                  "expr" = "(builtins.getFlake (\"git+file://\" + toString /home/${config.home.username}/.config/nixos)).homeConfigurations.\"${config.home.username}@p620\".options";
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
              "github" = {
                "type" = "stdio";
                "command" = "npx";
                "args" = [
                  "-y"
                  "@modelcontextprotocol/server-github"
                ];
                "env" = {
                  "GITHUB_PERSONAL_ACCESS_TOKEN" = "\${GITHUB_TOKEN}";
                };
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
              # Enhanced Development Environment Guidelines for GitHub Copilot

              ## NixOS & Language Development
              - Use declarative configuration with NixOS modules
              - Follow Nixpkgs contribution guidelines and unified language support
              - Maintain pure and reproducible builds with centralized tooling
              - Use flakes for dependency management with language-specific configurations
              - Prefer functional programming patterns across all languages
              - Use 2 spaces for indentation in Nix, follow language conventions otherwise
              - Use camelCase for variable and function names in Nix
              - Group related options together with feature flags
              - Document options with description field and examples
              - Keep configurations pure and reproducible with shared LSP configs
              
              ## Language Support Integration
              - Use centralized language server configurations from languages.nix
              - Follow established formatter preferences (alejandra for Nix, black for Python, etc.)
              - Integrate with unified development tooling and environment variables
              - Leverage shared aliases and shortcuts for language-specific workflows
              - Maintain consistency across editors for language features
              
              ## Development Workflow
              - Use systemd service units when appropriate
              - Follow least privilege principle
              - Implement proper error handling with language-appropriate patterns
              - Document breaking changes and migration paths
              - Handle upgrades gracefully with version management
              - Integrate with Git workflow and development utilities'';
            "context" = ''
              I am working on an enhanced NixOS development environment using Home Manager and Flakes.
              The configuration includes unified language support, centralized LSP configurations, and
              integrated development tooling across multiple editors (VS Code, Neovim, Emacs, Zed).
              Please provide code that follows NixOS best practices, leverages the enhanced development
              infrastructure, and maintains consistency across the development stack.
              Consider performance, security, maintainability, and cross-editor compatibility.'';
          };

          # Wayland optimization settings
          "window.titleBarStyle" = "custom";
          "window.customTitleBarVisibility" = "auto";
          "window.nativeTabs" = false; # Native tabs don't work well with Wayland
          "window.nativeFullScreen" = true;
          "editor.renderWhitespace" = "all";
          "editor.smoothScrolling" = true;
          "workbench.list.smoothScrolling" = true;
          # Terminal settings
          "terminal.integrated.gpuAcceleration" = "on";
          "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font'";
          "terminal.integrated.fontSize" = mkDefault 13;
          "terminal.integrated.lineHeight" = 1.2;
          "terminal.integrated.cursorBlinking" = true;
          "terminal.integrated.cursorStyle" = "line";
          "terminal.integrated.scrollback" = 10000;
          "terminal.integrated.shell.linux" = "${pkgs.zsh}/bin/zsh";
          "terminal.integrated.defaultProfile.linux" = "zsh";
          "terminal.integrated.profiles.linux" = {
            "zsh" = {
              "path" = "${pkgs.zsh}/bin/zsh";
              "args" = ["-l"];
            };
            "bash" = {
              "path" = "${pkgs.bash}/bin/bash";
              "args" = ["-l"];
            };
          };
          "update.mode" = "none"; # Managed by Nix
          
          # Performance optimizations
          "files.watcherExclude" = {
            "**/node_modules/**" = true;
            "**/target/**" = true;
            "**/result/**" = true;
            "**/.direnv/**" = true;
            "**/.git/**" = true;
            "**/dist/**" = true;
            "**/build/**" = true;
          };
          "search.exclude" = {
            "**/node_modules" = true;
            "**/target" = true;
            "**/result" = true;
            "**/.direnv" = true;
            "**/dist" = true;
            "**/build" = true;
          };
          "files.exclude" = {
            "**/.direnv" = true;
            "**/result" = true;
          };
          "typescript.tsc.autoDetect" = "off";
          "npm.autoDetect" = "off";
          "gulp.autoDetect" = "off";
          "jake.autoDetect" = "off";
          "grunt.autoDetect" = "off";
          "chat.mcp.enabled" = true;
          "chat.agent.enabled" = true;
          "chat.mcp.discovery.enabled" = true;
          "chat.tools.autoApprove" = true;
          "chat.agent.maxRequests" = 15;
          "github.copilot.chat.codesearch.enabled" = true;
          "github.copilot.chat.scopeSelection" = true;
          "github.copilot.chat.agent.thinkingTool" = true;
          "githubPullRequests.notifications" = "pullRequests";
          # Workbench settings
          "workbench.colorTheme" = mkDefault "Gruvbox Material Dark";
          "workbench.iconTheme" = "file-icons-colourless";
          "workbench.browser.preferredBrowser" = "google-chrome-stable";
          "workbench.startupEditor" = "welcomePageInEmptyWorkbench";
          "workbench.editor.tabCloseButton" = "right";
          "workbench.editor.tabSizing" = "shrink";
          "workbench.editor.limit.enabled" = true;
          "workbench.editor.limit.value" = 10;
          "workbench.editor.limit.perEditorGroup" = true;
          "workbench.activityBar.location" = "top";
          "workbench.tree.indent" = 20;
          "workbench.tree.renderIndentGuides" = "always";
          "workbench.sideBar.location" = "left";
          "workbench.panel.defaultLocation" = "bottom";
          "workbench.editor.enablePreview" = false;
          "workbench.editor.enablePreviewFromQuickOpen" = false;
          "genieai.enableConversationHistory" = true;
          "alejandra.program" = "alejandra";
          "geminicodeassist.codeGenerationPaneViewEnabled" = true;
          "geminicodeassist.project" = "gen-lang-client-0059434248";
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
          
          # Disable settings sync to prevent conflicts with declarative configuration
          "settingsSync.keybindingsPerPlatform" = false;
          "settingsSync.enabled" = false;
        };
      };
    };
    # programs.vscode.mutableExtensionsDir = true; # Disabled to prevent settings conflicts

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
