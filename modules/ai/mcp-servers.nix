# MCP (Model Context Protocol) Servers Module
# Provides AI agents with standardized tool access
# Compliant with NIXOS-ANTI-PATTERNS.md
{ config, lib, pkgs, ... }:
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
  };

  config = lib.mkIf cfg.enable {
    # Always include core MCP servers when enabled
    environment.systemPackages = with pkgs;
      # Core MCP servers (essential for AI-assisted development)
      [
        playwright-mcp # Browser automation
        mcp-nixos # NixOS package/option queries
        github-mcp-server # GitHub integration
        chatmcp # AI chat client
      ]

      # Optional MCP servers based on configuration
      ++ lib.optionals (cfg.servers.browsermcp or cfg.enableAll) [ customPkgs.browser-mcp ]
      ++ lib.optionals (cfg.servers.grafana or cfg.enableAll) [ mcp-grafana ]
      ++ lib.optionals (cfg.servers.kubernetes or cfg.enableAll) [ mcp-k8s-go ]
      ++ lib.optionals (cfg.servers.terraform or cfg.enableAll) [ terraform-mcp-server ]
      ++ lib.optionals (cfg.servers.gitea or cfg.enableAll) [ gitea-mcp-server ]
      ++ lib.optionals (cfg.servers.proxy or cfg.enableAll) [ mcp-proxy ]
      ++ lib.optionals ((cfg.obsidian.enable or cfg.enableAll) && cfg.obsidian.implementation == "zero-dependency") [ customPkgs.obsidian-mcp ]
      ++ lib.optionals ((cfg.obsidian.enable or cfg.enableAll) && cfg.obsidian.implementation == "rest-api") [ customPkgs.obsidian-mcp-rest ];

    # MCP servers documentation and usage information
    environment.etc."mcp-servers-info.txt".text = ''
      MCP (Model Context Protocol) Servers Installed
      ================================================

      Core Servers (Always Enabled):
      - playwright-mcp: Browser automation for AI agents
      - mcp-nixos: NixOS package and configuration queries
      - github-mcp-server: GitHub repository integration
      - chatmcp: AI chat client with MCP support

      Optional Servers (Configured):
      ${lib.optionalString (cfg.servers.browsermcp or cfg.enableAll) "- browser-mcp: Browser automation with privacy (requires Chrome extension)"}
      ${lib.optionalString (cfg.obsidian.enable or cfg.enableAll) "- obsidian-mcp: Obsidian vault knowledge base integration"}
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

    # Agenix secret for Obsidian REST API mode
    age.secrets."obsidian-api-key" = lib.mkIf (cfg.obsidian.enable && cfg.obsidian.implementation == "rest-api") {
      file = ../../secrets/obsidian-api-key.age;
      mode = "0400";
      owner = username;
      group = "users";
    };
  };
}
