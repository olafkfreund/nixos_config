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

    atlassian = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Atlassian MCP server for Jira and Confluence integration";
      };

      mode = lib.mkOption {
        type = lib.types.enum [ "cloud" "self-hosted" ];
        default = "cloud";
        description = ''
          Atlassian deployment mode:
          - cloud: Atlassian Cloud (requires username + API token)
          - self-hosted: Self-hosted instance (requires Personal Access Token)
        '';
      };

      jira = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Jira integration";
        };

        url = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "https://your-domain.atlassian.net";
          description = "Jira instance URL (cloud or self-hosted)";
        };

        username = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "user@example.com";
          description = "Jira username/email (cloud mode only)";
        };

        tokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = lib.literalExpression "config.age.secrets.\"api-jira-token\".path";
          description = ''
            Path to Jira API token file (runtime loading only, cloud mode).
            Generate token at: https://id.atlassian.com/manage-profile/security/api-tokens
            NEVER set token value directly - use file path for runtime loading.
          '';
        };

        patFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = lib.literalExpression "config.age.secrets.\"api-jira-pat\".path";
          description = ''
            Path to Jira Personal Access Token file (runtime loading only, self-hosted mode).
            NEVER set PAT value directly - use file path for runtime loading.
          '';
        };
      };

      confluence = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Confluence integration";
        };

        url = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "https://your-domain.atlassian.net/wiki";
          description = "Confluence instance URL (cloud or self-hosted)";
        };

        username = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "user@example.com";
          description = "Confluence username/email (cloud mode only)";
        };

        tokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = lib.literalExpression "config.age.secrets.\"api-confluence-token\".path";
          description = ''
            Path to Confluence API token file (runtime loading only, cloud mode).
            Generate token at: https://id.atlassian.com/manage-profile/security/api-tokens
            NEVER set token value directly - use file path for runtime loading.
          '';
        };

        patFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = lib.literalExpression "config.age.secrets.\"api-confluence-pat\".path";
          description = ''
            Path to Confluence Personal Access Token file (runtime loading only, self-hosted mode).
            NEVER set PAT value directly - use file path for runtime loading.
          '';
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment = {
      # Always include core MCP servers when enabled
      systemPackages = (with pkgs;
        # Core MCP servers (essential for AI-assisted development)
        [
          playwright-mcp # Browser automation
          playwright-driver.browsers # NixOS-compatible Playwright browsers
          github-mcp-server # GitHub integration
          chatmcp # AI chat client
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
      ++ lib.optionals (cfg.atlassian.enable or cfg.enableAll) [ pkgs.customPkgs.atlassian-mcp ];

      # NixOS-specific Playwright environment variables
      # These are required because Playwright expects browsers in ~/.cache/ms-playwright
      # but NixOS stores them in the Nix store
      sessionVariables = {
        PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
        PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
      };

      # MCP servers documentation and usage information
      etc."mcp-servers-info.txt".text = ''
        MCP (Model Context Protocol) Servers Installed
        ================================================

        Core Servers (Always Enabled):
        - playwright-mcp: Browser automation for AI agents
        - github-mcp-server: GitHub repository integration
        - chatmcp: AI chat client with MCP support
        - mcp-nixos: NixOS packages and configuration options queries

        Optional Servers (Configured):
        ${lib.optionalString (cfg.servers.browsermcp or cfg.enableAll) "- browser-mcp: Browser automation with privacy (requires Chrome extension)"}
        ${lib.optionalString (cfg.obsidian.enable or cfg.enableAll) "- obsidian-mcp: Obsidian vault knowledge base integration"}
        ${lib.optionalString (cfg.linkedin.enable or cfg.enableAll) "- linkedin-mcp: LinkedIn professional networking and job search"}
        ${lib.optionalString (cfg.atlassian.enable or cfg.enableAll) "- atlassian-mcp: Jira and Confluence integration (project management and documentation)"}
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

      # Atlassian cloud mode secrets
      "api-jira-token" = lib.mkIf (cfg.atlassian.enable && cfg.atlassian.jira.enable && cfg.atlassian.mode == "cloud") {
        file = ../../secrets/api-jira-token.age;
        mode = "0400";
        owner = username;
        group = "users";
      };

      "api-confluence-token" = lib.mkIf (cfg.atlassian.enable && cfg.atlassian.confluence.enable && cfg.atlassian.mode == "cloud") {
        file = ../../secrets/api-confluence-token.age;
        mode = "0400";
        owner = username;
        group = "users";
      };

      # Atlassian self-hosted mode secrets
      "api-jira-pat" = lib.mkIf (cfg.atlassian.enable && cfg.atlassian.jira.enable && cfg.atlassian.mode == "self-hosted") {
        file = ../../secrets/api-jira-pat.age;
        mode = "0400";
        owner = username;
        group = "users";
      };

      "api-confluence-pat" = lib.mkIf (cfg.atlassian.enable && cfg.atlassian.confluence.enable && cfg.atlassian.mode == "self-hosted") {
        file = ../../secrets/api-confluence-pat.age;
        mode = "0400";
        owner = username;
        group = "users";
      };
    };
  };
}
