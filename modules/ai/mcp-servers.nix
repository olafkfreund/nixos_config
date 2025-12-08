# MCP (Model Context Protocol) Servers Module
# Provides AI agents with standardized tool access
# Compliant with NIXOS-ANTI-PATTERNS.md
{ config, lib, pkgs, ... }:
let
  cfg = config.features.ai.mcp;
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

      vaultPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/home/user/Documents/ObsidianVault";
        description = "Path to Obsidian vault (can also use OBSIDIAN_VAULT_PATH env var)";
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
      ++ lib.optionals (cfg.servers.grafana or cfg.enableAll) [ mcp-grafana ]
      ++ lib.optionals (cfg.servers.kubernetes or cfg.enableAll) [ mcp-k8s-go ]
      ++ lib.optionals (cfg.servers.terraform or cfg.enableAll) [ terraform-mcp-server ]
      ++ lib.optionals (cfg.servers.gitea or cfg.enableAll) [ gitea-mcp-server ]
      ++ lib.optionals (cfg.servers.proxy or cfg.enableAll) [ mcp-proxy ]
      ++ lib.optionals (cfg.obsidian.enable or cfg.enableAll) [ customPkgs.obsidian-mcp ];

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
  };
}
