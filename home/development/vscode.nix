{ config
, lib
, pkgs
, # pkgs-unstable,
  ...
}:
with lib; let
  cfg = config.editor.vscode;
  # Custom extensions not available in nixpkgs
  # Note: Uncomment and add proper sha256 hashes when needed
in
{
  options.editor.vscode = {
    enable = mkEnableOption "Visual Studio Code editor" // { default = true; };
  };

  config = mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        alejandra
        deadnix
        statix
        hadolint # Dockerfile linter
        hadolint-sarif # Convert hadolint diagnostics to SARIF format
        icu # Required for .NET globalization support (MCP servers)
      ];

      sessionVariables = {
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
        GDK_BACKEND = "wayland";
        # Network stability enhancements
        DISABLE_REQUEST_THROTTLING = "1";
        ELECTRON_FORCE_WINDOW_MENU_BAR = "1";
        # Increase connection pools and timeouts
        CHROME_NET_TCP_SOCKET_CONNECT_TIMEOUT_MS = "60000";
        CHROME_NET_TCP_SOCKET_CONNECT_ATTEMPT_DELAY_MS = "2000";
      };

      # Clean up backup files BEFORE Home Manager checks for conflicts
      activation.vscodeCleanup = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        # Remove any existing backup files that would cause conflicts
        rm -f "$HOME/.config/Code/User/settings.json.backup"
        rm -f "$HOME/.config/Code/User/settings.json.hm-backup"
        rm -f "$HOME/.config/Code/User/mcp.json.backup"
        rm -f "$HOME/.config/Code/User/mcp.json.hm-backup"
        rm -f "$HOME/.claude/settings.json.backup"
        rm -f "$HOME/.claude/settings.json.hm-backup"
      '';

      # Initialize VS Code settings and MCP files as mutable
      # This runs AFTER home-manager creates symlinks (writeBoundary)
      # We remove any symlinks created by programs.vscode.profiles to keep files mutable
      activation.vscodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        SETTINGS_DIR="$HOME/.config/Code/User"
        SETTINGS_FILE="$SETTINGS_DIR/settings.json"
        MCP_FILE="$SETTINGS_DIR/mcp.json"
        SETTINGS_TEMPLATE_FILE="${./vscode-settings-template.json}"
        MCP_TEMPLATE_FILE="${./vscode-mcp-template.json}"

        # Create VS Code config directory if it doesn't exist
        mkdir -p "$SETTINGS_DIR"

        # Remove any existing backup files that cause conflicts
        if [ -f "$SETTINGS_DIR/settings.json.backup" ]; then
          echo "Removing conflicting settings.json.backup file..."
          rm "$SETTINGS_DIR/settings.json.backup"
        fi
        if [ -f "$SETTINGS_DIR/settings.json.hm-backup" ]; then
          echo "Removing conflicting settings.json.hm-backup file..."
          rm "$SETTINGS_DIR/settings.json.hm-backup"
        fi

        # Handle settings.json - convert symlink to mutable file
        if [ -L "$SETTINGS_FILE" ]; then
          echo "Removing Home Manager symlink for VS Code settings..."
          rm "$SETTINGS_FILE"
        fi

        if [ ! -f "$SETTINGS_FILE" ]; then
          echo "Creating initial mutable VS Code settings file..."
          cp "$SETTINGS_TEMPLATE_FILE" "$SETTINGS_FILE"
          chmod 644 "$SETTINGS_FILE"
          echo "✅ VS Code settings.json initialized as mutable file."
        else
          echo "VS Code settings.json file exists and is already mutable - leaving it alone."
        fi

        # Handle mcp.json - convert symlink to mutable file
        if [ -L "$MCP_FILE" ]; then
          echo "Removing Home Manager symlink for MCP configuration..."
          rm "$MCP_FILE"
        fi

        if [ ! -f "$MCP_FILE" ]; then
          echo "Creating initial mutable MCP configuration file..."
          cp "$MCP_TEMPLATE_FILE" "$MCP_FILE"
          chmod 644 "$MCP_FILE"
          echo "✅ VS Code mcp.json initialized as mutable file."
        else
          echo "VS Code mcp.json file exists and is already mutable - leaving it alone."
        fi
      '';
    };

    programs.vscode = {
      enable = true;
      package = pkgs.vscode-fhs;

      # Enable mutable extensions and settings
      mutableExtensionsDir = true;

      # Use the new profiles structure (fixes deprecation warning)
      # NOTE: We intentionally do NOT define any settings here
      # Settings are managed by our activation script to remain mutable
      profiles.default = {
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
          # ms-python.python  # Temporarily disabled due to pygls compatibility issue
          # ms-python.vscode-pylance  # Temporarily disabled due to pygls dependency
          golang.go
        ];

        # IMPORTANT: No settings defined here - activation script handles settings.json
        # This allows settings to remain mutable (editable by VS Code itself)
      };
    };

    # Set up XDG file associations for VSCode
    xdg.mimeApps = {
      enable = true;
      associations.added = {
        "text/plain" = [ "code.desktop" ];
        "text/markdown" = [ "code.desktop" ];
        "application/json" = [ "code.desktop" ];
        "application/x-yaml" = [ "code.desktop" ];
        "text/x-python" = [ "code.desktop" ];
        "text/x-csrc" = [ "code.desktop" ];
        "text/x-c++src" = [ "code.desktop" ];
        "text/x-chdr" = [ "code.desktop" ];
        "text/x-c++hdr" = [ "code.desktop" ];
        "text/x-shellscript" = [ "code.desktop" ];
        "text/html" = [ "code.desktop" ];
        "text/css" = [ "code.desktop" ];
        "text/javascript" = [ "code.desktop" ];
      };
    };

    # Custom VSCode desktop entry with Wayland optimizations
    xdg.desktopEntries.code = {
      name = "Visual Studio Code";
      exec = "code --ozone-platform=wayland --enable-features=UseOzonePlatform,WaylandWindowDecorations %F";
      categories = [ "Development" "IDE" ];
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
  };
}
