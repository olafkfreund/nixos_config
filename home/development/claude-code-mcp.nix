# Claude Code MCP Configuration
# Automatically generates settings.local.json for MCP servers
# Follows docs/NIXOS-ANTI-PATTERNS.md security patterns
{ config, lib, pkgs, osConfig, ... }:
let
  # Access system-level MCP configuration via osConfig
  mcpCfg = osConfig.features.ai.mcp or { };
  enabled = mcpCfg.enable or false;
  obsidianEnabled = mcpCfg.obsidian.enable or false;
  linkedinEnabled = mcpCfg.linkedin.enable or false;
  atlassianEnabled = mcpCfg.atlassian.enable or false;
  whatsappEnabled = mcpCfg.whatsapp.enable or false;

  # Helper function to create shell script wrappers
  mkWrapper = name: script: pkgs.writeShellScript name script;
in
{
  config = lib.mkIf enabled {
    # Claude Code MCP configuration file
    # Location: ~/.claude/settings.local.json
    home.file.".claude/settings.local.json" = {
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
              description = "Browser automation using Playwright - AI-powered web testing, form filling, and DOM interaction";
            };

            # BrowserMCP for privacy-focused browser automation
            browsermcp = {
              command = "${pkgs.nodejs}/bin/npx";
              args = [ "@browsermcp/mcp@latest" ];
              description = "Browser automation with privacy - AI-powered web automation (requires Chrome extension)";
            };

            # Context7 for up-to-date library documentation
            context7 = {
              type = "stdio";
              command = "${pkgs.nodejs}/bin/npx";
              args = [ "-y" "@upstash/context7-mcp@latest" ];
              description = "Up-to-date library documentation - prevents coding hallucinations with current docs";
            };

            # Sequential Thinking for systematic problem-solving
            sequential-thinking = {
              command = "${pkgs.nodejs}/bin/npx";
              args = [ "-y" "@modelcontextprotocol/server-sequential-thinking" ];
              description = "Dynamic and reflective problem-solving through systematic thinking - helps break down complex problems into steps";
            };

            # NotebookLM MCP for Google NotebookLM interaction
            notebooklm = {
              command = "${pkgs.uv}/bin/uvx";
              args = [ "--from" "notebooklm-mcp-cli" "notebooklm-mcp" ];
              description = "Google NotebookLM interaction - create notebooks, add sources, generate audio/video overviews, query content via AI";
            };

            # Terraform MCP for Infrastructure as Code
            terraform = {
              command = if pkgs ? terraform-mcp-server then "${pkgs.terraform-mcp-server}/bin/terraform-mcp-server" else "${pkgs.writeShellScript "terraform-mcp-placeholder" "echo 'Terraform MCP not available'"}";
              args = [ ];
              description = "Terraform Infrastructure as Code - manage and query terraform configurations";
            };
          }
          # Obsidian MCP - conditional configuration based on implementation
          // (lib.optionalAttrs obsidianEnabled {
            "obsidian-rest" =
              if mcpCfg.obsidian.implementation == "zero-dependency"
              then {
                command = if pkgs ? obsidian-mcp then "${pkgs.obsidian-mcp}/bin/obsidian-mcp" else "${pkgs.writeShellScript "obsidian-mcp-placeholder" "echo 'Obsidian MCP not available'"}";
                args = [ mcpCfg.obsidian.vaultPath ];
                description = "Obsidian vault knowledge base (zero-dependency, read-only)";
              }
              else {
                command = "${mkWrapper "obsidian-mcp-rest-wrapper" ''
                  export OBSIDIAN_API_KEY_FILE=${mcpCfg.obsidian.restApi.apiKeyFile}
                  export OBSIDIAN_HOST=${mcpCfg.obsidian.restApi.host}
                  export OBSIDIAN_PORT=${toString mcpCfg.obsidian.restApi.port}
                  export VERIFY_SSL=${if mcpCfg.obsidian.restApi.verifySsl then "true" else "false"}
                  ${if pkgs ? obsidian-mcp-rest then ''
                    exec ${pkgs.obsidian-mcp-rest}/bin/obsidian-mcp-rest "$@"
                  '' else ''
                    echo "Obsidian MCP REST not available" >&2
                    exit 1
                  ''}
                ''}";
                args = [ ];
                description = "Obsidian vault with full CRUD via REST API plugin - requires Local REST API plugin installed";
              };
          })
          # GitHub MCP server (if GitHub token available)
          // (lib.optionalAttrs (osConfig.age.secrets."api-github-token" or null != null) {
            github = {
              command = "${mkWrapper "github-mcp-wrapper" ''
                export GITHUB_TOKEN_FILE=${osConfig.age.secrets."api-github-token".path}
                exec ${pkgs.github-mcp-server}/bin/github-mcp-server "$@"
              ''}";
              args = [ ];
              description = "GitHub repository integration - PR automation, issue management, repository queries";
            };
          })
          # LinkedIn MCP server (if LinkedIn cookie available)
          // (lib.optionalAttrs linkedinEnabled {
            linkedin = {
              command = "${mkWrapper "linkedin-mcp-wrapper" ''
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
          // (lib.optionalAttrs whatsappEnabled {
            whatsapp = {
              command = "${mkWrapper "whatsapp-mcp-wrapper" ''
                # Ensure WhatsApp bridge service is running
                if ! systemctl is-active --quiet whatsapp-bridge; then
                  echo "ERROR: WhatsApp bridge service is not running" >&2
                  echo "Start service: systemctl start whatsapp-bridge" >&2
                  echo "View QR code for authentication: journalctl -u whatsapp-bridge -f" >&2
                  exit 1
                fi

                # Launch MCP server
                exec ${pkgs.customPkgs.whatsapp-mcp.whatsappMcpServer}/bin/whatsapp-mcp-server "$@"
              ''}";
              args = [ ];
              description = "WhatsApp messaging integration - AI-assisted WhatsApp send/receive, message history queries (requires bridge service + QR auth)";
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
                command = "${mkWrapper "atlassian-mcp-wrapper" (
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
                description = "Atlassian Jira and Confluence integration - issue tracking, project management, and documentation (${mode} mode)";
              };
            }
          ))
          # Grafana MCP server (if enabled in servers configuration)
          // (lib.optionalAttrs (mcpCfg.servers.grafana or false) {
            grafana = {
              command = if pkgs ? mcp-grafana then "${pkgs.mcp-grafana}/bin/mcp-grafana" else "${pkgs.writeShellScript "grafana-mcp-placeholder" "echo 'Grafana MCP not available'"}";
              args = [
                "--url"
                "http://p620:3001" # P620 is the monitoring server
                "--token"
                "\${GRAFANA_API_TOKEN}"
              ];
              description = "Grafana dashboard and metrics integration - query monitoring data from P620";
            };
          });
      };

      # Generate JSON configuration with proper formatting
      onChange = ''
        echo "Claude Code MCP configuration updated at ~/.claude/settings.local.json"
        echo "Restart Claude Code for changes to take effect"
      '';
    };

    # Documentation for Claude Code MCP setup
    home.file.".claude/MCP-README.md".text = ''
      # Claude Code MCP Configuration

      This configuration file is automatically generated by NixOS.
      Do not edit ~/.claude/settings.local.json manually unless you want custom overrides.

      ## Configuration Location

      Source: ${config.home.homeDirectory}/.config/nixos/home/development/claude-code-mcp.nix
      Generated: ~/.claude/settings.local.json

      ## Enabled MCP Servers

      ### Always Enabled

      #### Playwright
      - Browser automation using Playwright accessibility tree
      - NixOS-compatible browser paths configured
      - Supports web testing, form filling, and DOM interaction
      - Example: "Open browser to example.com and take a screenshot"

      #### BrowserMCP
      - Privacy-focused browser automation
      - Requires Chrome extension installation
      - AI-powered web automation

      #### Context7
      - Up-to-date library documentation
      - Prevents coding hallucinations with current documentation

      #### Sequential Thinking
      - Dynamic and reflective problem-solving
      - Breaks down complex problems into systematic steps
      - Example: "Think through the architecture for this feature step by step"

      #### Terraform
      - Infrastructure as Code support
      - Manage and query Terraform configurations

      ### Conditionally Enabled

      ${lib.optionalString obsidianEnabled ''
      #### Obsidian (${mcpCfg.obsidian.implementation})
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

      ${lib.optionalString (osConfig.age.secrets."api-github-token" or null != null) ''
      #### GitHub
      - Repository integration
      - PR automation and issue management
      - Token loaded from: ${osConfig.age.secrets."api-github-token".path}
      ''}

      ${lib.optionalString linkedinEnabled ''
      #### LinkedIn
      - Professional networking and job search
      - Profile scraping and company research
      - Job searches with keyword/location filters
      - Note: Cookie expires ~30 days, requires periodic refresh
      ''}

      ${lib.optionalString whatsappEnabled ''
      #### WhatsApp
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
      #### Atlassian (${mcpCfg.atlassian.mode or "cloud"} mode)
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

      ${lib.optionalString (mcpCfg.servers.grafana or false) ''
      #### Grafana
      - Dashboard and metrics integration
      - Query monitoring data from P620 server
      - Requires GRAFANA_API_TOKEN environment variable
      ''}

      ## Applying Changes

      After modifying the configuration in NixOS:
      1. Rebuild your system: `just deploy` or `just quick-deploy HOST`
      2. Restart Claude Code (or reload configuration)
      3. MCP servers will be available in Claude Code

      ## Troubleshooting

      Check configuration:
      - cat ~/.claude/settings.local.json
      - Verify JSON syntax is valid

      Test MCP servers manually:
      - Run the command directly from terminal
      - Check for any error messages

      Service status (WhatsApp):
      - systemctl status whatsapp-bridge
      - journalctl -u whatsapp-bridge -f

      ## Security Notes

      - API keys and tokens loaded at runtime (not in Nix store)
      - Secrets managed via agenix
      - Shell wrappers generated with proper paths
      - Follows docs/NIXOS-ANTI-PATTERNS.md security patterns

      ## Customization

      To add custom MCP servers:
      1. DO NOT edit settings.local.json directly (will be overwritten)
      2. Instead, edit this Nix module: ${config.home.homeDirectory}/.config/nixos/home/development/claude-code-mcp.nix
      3. Rebuild system to apply changes
    '';
  };
}
