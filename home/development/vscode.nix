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
      package = pkgs.vscode-fhs;

      # Enable mutable extensions and settings
      mutableExtensionsDir = true;

      # Essential extensions that should always be available
      extensions = with pkgs.vscode-extensions; [
        # Core Nix development (critical for our workflow)
        bbenoist.nix
        kamadorueda.alejandra
        mkhl.direnv
        jnoortheen.nix-ide
        arrterian.nix-env-selector

        # Essential development tools
        github.copilot
        github.copilot-chat
        eamodio.gitlens
        rust-lang.rust-analyzer
        ms-python.python
        ms-python.vscode-pylance
        golang.go
      ];

      # Minimal essential settings that should remain consistent
      userSettings = {
        # Essential Nix development settings (critical for our workflow)
        "[nix]" = {
          "editor.defaultFormatter" = "kamadorueda.alejandra";
          "editor.formatOnPaste" = true;
          "editor.formatOnSave" = true;
          "editor.formatOnType" = true;
        };

        # Nix language server configuration (critical)
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
          };
        };

        # Core system integration
        "editor.fontFamily" = mkDefault "'JetBrainsMono Nerd Font', 'Droid Sans Mono', 'monospace'";
        "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font'";
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

        # Critical MCP server configuration
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

        # Essential system settings
        "update.mode" = "none"; # Managed by Nix
        "telemetry.telemetryLevel" = "off";
        "settingsSync.enabled" = false; # Use mutable settings instead
        "alejandra.program" = "alejandra";
        "workbench.externalBrowser" = "google-chrome-stable";

        # Performance optimizations for NixOS
        "files.watcherExclude" = {
          "**/node_modules/**" = true;
          "**/target/**" = true;
          "**/result/**" = true;
          "**/.direnv/**" = true;
          "**/.git/**" = true;
        };
        "files.exclude" = {
          "**/.direnv" = true;
          "**/result" = true;
        };
      };
    };

    # Initialize VS Code settings file if it doesn't exist (then let VS Code manage it)
    home.activation.vscodeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
      SETTINGS_DIR="$HOME/.config/Code/User"
      SETTINGS_FILE="$SETTINGS_DIR/settings.json"

      # Create VS Code config directory if it doesn't exist
      mkdir -p "$SETTINGS_DIR"

      # Only create settings file if it doesn't exist - VS Code will manage it after that
      if [ ! -f "$SETTINGS_FILE" ]; then
        echo "Creating initial VS Code settings file (VS Code will manage it after this)..."
        cp ${./vscode-settings-template.json} "$SETTINGS_FILE"
        chmod 644 "$SETTINGS_FILE"
        echo "VS Code settings initialized. You can now modify settings through VS Code UI."
      else
        echo "VS Code settings file exists - letting VS Code manage it."
      fi
    '';

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
