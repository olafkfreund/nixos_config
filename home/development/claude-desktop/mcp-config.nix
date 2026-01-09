# Claude Desktop MCP Configuration
# Automatically generates claude_desktop_config.json for MCP servers
# Follows docs/NIXOS-ANTI-PATTERNS.md security patterns
{ config, lib, pkgs, osConfig, ... }:
let
  # Access system-level MCP configuration via osConfig
  mcpCfg = osConfig.features.ai.mcp or { };
  enabled = mcpCfg.enable or false;
  obsidianEnabled = mcpCfg.obsidian.enable or false;
  linkedinEnabled = mcpCfg.linkedin.enable or false;
  atlassianEnabled = mcpCfg.atlassian.enable or false;
in
{
  config = lib.mkIf enabled {
    # Claude Desktop MCP configuration file
    # Location: ~/.config/Claude/claude_desktop_config.json
    xdg.configFile."Claude/claude_desktop_config.json" = {
      text = builtins.toJSON {
        mcpServers =
          # Always enabled MCP servers
          {
            # Playwright MCP for browser automation
            playwright = {
              command = "${pkgs.nodejs}/bin/npx";
              args = [ "-y" "@playwright/mcp@latest" ];
              env = {
                PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
                PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
              };
              description = "Browser automation using Playwright";
            };

            # NixOS MCP server
            # Temporarily disabled - fastmcp version conflict with mcp 1.25.0
            # nixos = {
            #   command = "mcp-nixos";
            #   args = [ ];
            #   description = "NixOS package and option queries";
            # };

            # Context7 for up-to-date library documentation
            context7 = {
              type = "stdio";
              command = "${pkgs.nodejs}/bin/npx";
              args = [ "-y" "@upstash/context7-mcp@latest" ];
              description = "Up-to-date library documentation";
            };

            # Sequential Thinking for systematic problem-solving
            sequential-thinking = {
              command = "${pkgs.nodejs}/bin/npx";
              args = [ "-y" "@modelcontextprotocol/server-sequential-thinking" ];
              description = "Dynamic and reflective problem-solving through systematic thinking";
            };
          }
          # Obsidian MCP - conditional configuration based on implementation
          // (lib.optionalAttrs obsidianEnabled {
            obsidian =
              if mcpCfg.obsidian.implementation == "zero-dependency"
              then {
                command = "obsidian-mcp";
                args = [ mcpCfg.obsidian.vaultPath ];
                description = "Obsidian vault knowledge base (zero-dependency, read-only)";
              }
              else {
                command = "obsidian-mcp-rest";
                args = [ ];
                env = {
                  OBSIDIAN_API_KEY_FILE = mcpCfg.obsidian.restApi.apiKeyFile;
                  OBSIDIAN_HOST = mcpCfg.obsidian.restApi.host;
                  OBSIDIAN_PORT = toString mcpCfg.obsidian.restApi.port;
                  VERIFY_SSL = if mcpCfg.obsidian.restApi.verifySsl then "true" else "false";
                };
                description = "Obsidian vault with full CRUD via REST API plugin";
              };
          })
          # GitHub MCP server (if GitHub token available)
          // (lib.optionalAttrs (osConfig.age.secrets."api-github-token" or null != null) {
            github = {
              command = "${pkgs.writeShellScript "github-mcp-wrapper" ''
                export GITHUB_PERSONAL_ACCESS_TOKEN=$(cat ${osConfig.age.secrets."api-github-token".path})
                exec ${pkgs.github-mcp-server}/bin/github-mcp-server "$@"
              ''}";
              args = [ "stdio" ];
              description = "GitHub repository integration";
            };
          })
          # LinkedIn MCP server (if LinkedIn cookie available)
          // (lib.optionalAttrs linkedinEnabled {
            linkedin = {
              command = "${pkgs.writeShellScript "linkedin-mcp-wrapper" ''
                export LINKEDIN_COOKIE_FILE=${osConfig.age.secrets."api-linkedin-cookie".path}
                exec ${pkgs.docker}/bin/docker run --rm -i \
                  --read-only \
                  --security-opt=no-new-privileges \
                  --cap-drop=ALL \
                  -e LINKEDIN_COOKIE="$(cat $LINKEDIN_COOKIE_FILE)" \
                  stickerdaniel/linkedin-mcp-server:latest "$@"
              ''}";
              args = [ ];
              description = "LinkedIn professional networking and job search";
            };
          })
          # WhatsApp MCP server
          // (lib.optionalAttrs (mcpCfg.whatsapp.enable or false) {
            whatsapp = {
              command = "${pkgs.writeShellScript "whatsapp-mcp-wrapper" ''
                # Ensure WhatsApp bridge service is running
                if ! systemctl is-active --quiet whatsapp-bridge; then
                  echo "ERROR: WhatsApp bridge service is not running"
                  echo "Start service: systemctl start whatsapp-bridge"
                  echo "View QR code for authentication: journalctl -u whatsapp-bridge -f"
                  exit 1
                fi

                # Launch MCP server
                exec ${pkgs.customPkgs.whatsapp-mcp.whatsappMcpServer}/bin/whatsapp-mcp-server "$@"
              ''}";
              args = [ ];
              description = "WhatsApp messaging integration (requires bridge service)";
            };
          })
          # Atlassian MCP server (Jira and Confluence)
          // (lib.optionalAttrs atlassianEnabled (
            let
              mode = mcpCfg.atlassian.mode or "cloud";
              jiraEnabled = mcpCfg.atlassian.jira.enable or false;
              confluenceEnabled = mcpCfg.atlassian.confluence.enable or false;
            in
            {
              atlassian = {
                command = "${pkgs.writeShellScript "atlassian-mcp-wrapper" (
                  if mode == "cloud" then ''
                    ${lib.optionalString jiraEnabled ''
                      export JIRA_URL="${mcpCfg.atlassian.jira.url}"
                      export JIRA_USERNAME="${mcpCfg.atlassian.jira.username}"
                      export JIRA_TOKEN_FILE="${mcpCfg.atlassian.jira.tokenFile}"
                    ''}
                    ${lib.optionalString confluenceEnabled ''
                      export CONFLUENCE_URL="${mcpCfg.atlassian.confluence.url}"
                      export CONFLUENCE_USERNAME="${mcpCfg.atlassian.confluence.username}"
                      export CONFLUENCE_TOKEN_FILE="${mcpCfg.atlassian.confluence.tokenFile}"
                    ''}
                    export ATLASSIAN_MODE="cloud"
                    exec ${pkgs.customPkgs.atlassian-mcp}/bin/atlassian-mcp "$@"
                  '' else ''
                    ${lib.optionalString jiraEnabled ''
                      export JIRA_URL="${mcpCfg.atlassian.jira.url}"
                      export JIRA_PAT_FILE="${mcpCfg.atlassian.jira.patFile}"
                    ''}
                    ${lib.optionalString confluenceEnabled ''
                      export CONFLUENCE_URL="${mcpCfg.atlassian.confluence.url}"
                      export CONFLUENCE_PAT_FILE="${mcpCfg.atlassian.confluence.patFile}"
                    ''}
                    export ATLASSIAN_MODE="self-hosted"
                    exec ${pkgs.customPkgs.atlassian-mcp}/bin/atlassian-mcp "$@"
                  ''
                )}";
                args = [ ];
                description = "Atlassian Jira and Confluence integration (${mode} mode)";
              };
            }
          ));
      };

      # Generate JSON configuration with proper formatting
      onChange = ''
        echo "Claude Desktop MCP configuration updated"
        echo "Restart Claude Desktop for changes to take effect"
      '';
    };

    # Documentation for Claude Desktop MCP setup
    home.file.".config/Claude/MCP-README.md".text = ''
      # Claude Desktop MCP Configuration

      This configuration file is automatically generated by NixOS.
      Do not edit ~/.config/Claude/claude_desktop_config.json manually.

      ## Configuration Location

      Source: /home/${config.home.username}/.config/nixos/home/development/claude-desktop/mcp-config.nix
      Generated: ~/.config/Claude/claude_desktop_config.json

      ## Enabled MCP Servers

      ### Playwright
      - Browser automation using Playwright accessibility tree
      - NixOS-compatible browser paths configured
      - Supports web testing, form filling, and DOM interaction
      - Example: "Open browser to example.com and take a screenshot"

      ${lib.optionalString obsidianEnabled ''
      ### Obsidian (${mcpCfg.obsidian.implementation})
      ${if mcpCfg.obsidian.implementation == "rest-api" then ''
      - Mode: REST API (full CRUD operations)
      - Plugin Required: Obsidian Local REST API
      - Host: ${mcpCfg.obsidian.restApi.host}
      - Port: ${toString mcpCfg.obsidian.restApi.port}
      - SSL Verification: ${if mcpCfg.obsidian.restApi.verifySsl then "Enabled" else "Disabled"}
      '' else ''
      - Mode: Zero-dependency (read-only)
      - Vault Path: ${mcpCfg.obsidian.vaultPath}
      - No plugin required
      ''}
      ''}

      ### NixOS
      - Package and option queries
      - Prevents AI hallucinations about NixOS

      ${lib.optionalString (osConfig.age.secrets."api-github-token" or null != null) ''
      ### GitHub
      - Repository integration
      - PR automation and issue management
      ''}

      ${lib.optionalString linkedinEnabled ''
      ### LinkedIn
      - Professional networking and job search
      - Profile scraping and company research
      - Job searches with keyword/location filters
      - Personalized job recommendations
      - Note: Cookie expires ~30 days, requires periodic refresh
      ''}

      ${lib.optionalString (mcpCfg.whatsapp.enable or false) ''
      ### WhatsApp
      - AI-assisted WhatsApp messaging
      - Send/receive messages via natural language
      - Query message history and conversations
      - Group chat support
      - Media file support${lib.optionalString mcpCfg.whatsapp.enableVoiceMessages " (voice messages enabled)"}
      - Requires: whatsapp-bridge service running
      - Authentication: QR code scan (expires ~20 days)
      - View QR: journalctl -u whatsapp-bridge -f
      - Examples:
        - "Send a message to John saying I'll be late"
        - "Find messages from Sarah containing 'meeting'"
        - "Send document.pdf to the team group"
      ''}

      ${lib.optionalString atlassianEnabled ''
      ### Atlassian (${mcpCfg.atlassian.mode or "cloud"} mode)
      ${lib.optionalString (mcpCfg.atlassian.jira.enable or false) ''
      - **Jira Integration**:
        - URL: ${mcpCfg.atlassian.jira.url or "Not configured"}
        - JQL search with natural language
        - Issue creation, updates, and transitions
        - Project management automation
      ''}
      ${lib.optionalString (mcpCfg.atlassian.confluence.enable or false) ''
      - **Confluence Integration**:
        - URL: ${mcpCfg.atlassian.confluence.url or "Not configured"}
        - CQL search for documentation
        - Page creation, updates, and comments
        - Content discovery and management
      ''}
      - Examples:
        - "Find all issues assigned to me in project PROJ"
        - "Create a bug ticket for the login issue"
        - "Search Confluence for API documentation"
        - "Update issue PROJ-123 status to In Progress"
      ''}

      ### Context7
      - Up-to-date library documentation
      - Prevents coding hallucinations

      ### Sequential Thinking
      - Dynamic and reflective problem-solving
      - Breaks down complex problems into systematic steps
      - Helps with thorough analysis and planning
      - Example: "Think through the architecture for this feature step by step"

      ## Applying Changes

      After modifying the configuration in NixOS:
      1. Rebuild your system: `just deploy` or `just p620`
      2. Restart Claude Desktop application
      3. MCP servers will be available in Claude

      ## Troubleshooting

      Check logs:
      - Claude Desktop: Check application console (View → Developer → Developer Tools)
      - MCP servers: Run manually to test (e.g., `obsidian-mcp-rest`)

      Verify configuration:
      - cat ~/.config/Claude/claude_desktop_config.json
      - Check for syntax errors in JSON

      ## Security Notes

      - API keys loaded at runtime (not in Nix store)
      - Secrets managed via agenix
      - Follow docs/NIXOS-ANTI-PATTERNS.md security patterns
    '';
  };
}
