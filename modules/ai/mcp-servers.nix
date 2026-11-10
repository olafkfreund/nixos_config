# MCP (Model Context Protocol) Servers Module
# Provides AI agents with standardized tool access
# Compliant with NIXOS-ANTI-PATTERNS.md
{ config, lib, pkgs, mcp-nixos-pkg, ... }:
let
  cfg = config.features.ai.mcp;

  # Get the main user from host variables
  vars = import ../../hosts/${config.networking.hostName}/variables.nix { };
  inherit (vars) username;
in
{
  options.features.ai.mcp = {
    enable = lib.mkEnableOption "MCP (Model Context Protocol) servers";

    servers = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
      description = "Individual MCP servers to enable";
    };

    enableAll = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable all MCP servers (useful for development hosts)";
    };

    obsidian = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Obsidian MCP server for vault access";
      };

      implementation = lib.mkOption {
        type = lib.types.enum [ "rest-api" "zero-dependency" ];
        default = "zero-dependency";
        description = ''
          MCP implementation type:
          - rest-api: Uses Obsidian Local REST API plugin (requires plugin installation, provides full CRUD)
          - zero-dependency: Uses @mauricio.wolff/mcp-obsidian (no plugin needed, read-only)
        '';
      };

      vaultPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/home/user/Documents/ObsidianVault";
        description = "Path to Obsidian vault (zero-dependency mode only)";
      };

      restApi = {
        apiKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = lib.literalExpression "config.age.secrets.\"obsidian-api-key\".path";
          description = "Path to API key file (runtime loading, REST API mode only)";
        };

        host = lib.mkOption {
          type = lib.types.str;
          default = "localhost";
          description = "Obsidian REST API host";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 27123;
          description = "Obsidian REST API port";
        };

        verifySsl = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Verify SSL certificates for HTTPS connections";
        };
      };
    };

    linkedin = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable LinkedIn MCP server for professional networking and job search";
      };

      cookieFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = lib.literalExpression "config.age.secrets.\"api-linkedin-cookie\".path";
        description = ''
          Path to LinkedIn li_at cookie file (runtime loading only).
          Cookie expires approximately every 30 days and requires refresh.
          NEVER set cookie value directly - use file path for runtime loading.
        '';
      };
    };

    whatsapp = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable WhatsApp MCP server for AI-assisted messaging";
      };

      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/whatsapp-mcp";
        description = ''
          Directory for WhatsApp session database and message history.
          Managed by systemd StateDirectory for proper permissions.
        '';
      };

      enableVoiceMessages = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable FFmpeg for voice message conversion to .ogg Opus format";
      };
    };

    notebooklm = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable the Google NotebookLM MCP server (notebooklm-mcp-cli, 49 tools).

          Off by default and enabled per host, because the package ships with
          Users/olafkfreund/profile.nix — which only p620 and razer import —
          while this module is reached by every host. Enabling it on a host
          without the package would declare a server whose command does not
          exist.

          Requires a one-time interactive `nlm auth` on each host: the
          credential is a live Google session cookie in ~/.notebooklm-mcp-cli/,
          it is not declarable, and it expires every few weeks.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment = {
      # Always include core MCP servers when enabled
      systemPackages = (with pkgs;
        # Core MCP servers (essential for AI-assisted development)
        [
          playwright-driver.browsers-chromium # chromium only: the full bundle ships a webkit that fails auto-patchelf (libmanette)
          github-mcp-server # GitHub integration
        ])
      ++ [
        mcp-nixos-pkg # NixOS package/option queries (v2.1.0 from flake - conflict resolved)
      ]

      # Optional MCP servers based on configuration
      ++ lib.optionals (cfg.servers.browsermcp or cfg.enableAll) [ pkgs.customPkgs.browser-mcp ]
      ++ lib.optionals (cfg.servers.grafana or cfg.enableAll) [ pkgs.mcp-grafana ]
      ++ lib.optionals (cfg.servers.kubernetes or cfg.enableAll) [ pkgs.mcp-k8s-go ]
      ++ lib.optionals (cfg.servers.terraform or cfg.enableAll) [ pkgs.terraform-mcp-server ]
      ++ lib.optionals (cfg.servers.gitea or cfg.enableAll) [ pkgs.gitea-mcp-server ]
      ++ lib.optionals (cfg.servers.proxy or cfg.enableAll) [ pkgs.mcp-proxy ]
      ++ lib.optionals ((cfg.obsidian.enable or cfg.enableAll) && cfg.obsidian.implementation == "zero-dependency") [ pkgs.customPkgs.obsidian-mcp ]
      ++ lib.optionals ((cfg.obsidian.enable or cfg.enableAll) && cfg.obsidian.implementation == "rest-api") [ pkgs.customPkgs.obsidian-mcp-rest ]
      ++ lib.optionals (cfg.linkedin.enable or cfg.enableAll) [ pkgs.customPkgs.linkedin-mcp ]
      ++ lib.optionals (cfg.whatsapp.enable or cfg.enableAll) [ pkgs.customPkgs.whatsapp-mcp ];

      # NixOS-specific Playwright environment variables
      # These are required because Playwright expects browsers in ~/.cache/ms-playwright
      # but NixOS stores them in the Nix store
      sessionVariables = {
        PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers-chromium}";
        PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
      };

      # MCP servers documentation and usage information
      etc."mcp-servers-info.txt".text = ''
        MCP (Model Context Protocol) Servers Installed
        ================================================

        Core Servers (Always Enabled):
        - playwright: Browser automation, run via npx @playwright/mcp
          (browsers come from PLAYWRIGHT_BROWSERS_PATH, chromium only)
        - github-mcp-server: GitHub repository integration
        - mcp-nixos: NixOS packages and configuration options queries

        Optional Servers (Configured):
        ${lib.optionalString (cfg.servers.browsermcp or cfg.enableAll) "- browser-mcp: Browser automation with privacy (requires Chrome extension)"}
        ${lib.optionalString (cfg.obsidian.enable or cfg.enableAll) "- obsidian-mcp: Obsidian vault knowledge base integration"}
        ${lib.optionalString (cfg.linkedin.enable or cfg.enableAll) "- linkedin-mcp: LinkedIn professional networking and job search"}
        ${lib.optionalString (cfg.whatsapp.enable or cfg.enableAll) "- whatsapp-mcp: WhatsApp messaging integration with AI-assisted interaction"}
        ${lib.optionalString (cfg.servers.grafana or cfg.enableAll) "- mcp-grafana: Grafana dashboard and metrics integration"}
        ${lib.optionalString (cfg.servers.kubernetes or cfg.enableAll) "- mcp-k8s-go: Kubernetes cluster management"}
        ${lib.optionalString (cfg.servers.terraform or cfg.enableAll) "- terraform-mcp-server: Infrastructure as Code automation"}
        ${lib.optionalString (cfg.servers.gitea or cfg.enableAll) "- gitea-mcp-server: Gitea repository management"}
        ${lib.optionalString (cfg.servers.proxy or cfg.enableAll) "- mcp-proxy: Protocol proxy (stdio <-> SSE)"}

        Usage:
        Configure these servers in your AI client's MCP configuration.
        For Claude Code, add to .claude/settings.local.json or use claude-code CLI.

        Documentation:
        - MCP Protocol: https://modelcontextprotocol.io/
        - Server List: nix search nixpkgs mcp
        - Configuration: cat /etc/mcp-servers-info.txt
      '';
    };

    # Agenix secrets for MCP servers
    # Group all age.secrets together to avoid repeated key warnings
    age.secrets = {
      # Obsidian REST API mode secret
      "obsidian-api-key" = lib.mkIf (cfg.obsidian.enable && cfg.obsidian.implementation == "rest-api") {
        file = ../../secrets/obsidian-api-key.age;
        mode = "0400";
        owner = username;
        group = "users";
      };

      # LinkedIn cookie (li_at) - expires approximately every 30 days
      "api-linkedin-cookie" = lib.mkIf cfg.linkedin.enable {
        file = ../../secrets/api-linkedin-cookie.age;
        mode = "0400";
        owner = username;
        group = "users";
      };
    };
  };
}
