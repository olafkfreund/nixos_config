# MCP (Model Context Protocol) Servers Integration

> Last Updated: 2025-12-02
> Status: Fully Deployed

## Overview

The infrastructure now includes comprehensive MCP (Model Context Protocol) server support,
enabling AI agents to interact with external tools and data sources through a standardized
protocol.

**MCP is "USB-C for AI"** - a revolutionary standard that enables AI agents to seamlessly
interact with tools, databases, APIs, and services without custom integration code.

## What is MCP?

The Model Context Protocol (MCP) is an open protocol released by Anthropic in November 2024
that standardizes how AI applications connect to external tools and data sources. It uses a
three-core architecture:

1. **MCP Hosts**: AI applications (Claude Code, VS Code, etc.)
2. **MCP Clients**: Protocol handlers within applications
3. **MCP Servers**: Services that provide specific capabilities

## Installed MCP Servers

### Core Servers (All Hosts)

#### 1. **playwright-mcp** (v0.0.34)

**Purpose**: Browser automation using Playwright
**Benefits**:

- AI can navigate and interact with web pages
- Automated testing and web scraping
- DOM manipulation and screenshot capabilities
- Form filling and web automation
- Accessibility tree analysis (not pixel-based)
- Fast and lightweight automation

**NixOS-Specific Configuration**:

The infrastructure includes proper NixOS support for Playwright with:

- `playwright-driver.browsers` package for NixOS-compatible browsers
- Environment variables: `PLAYWRIGHT_BROWSERS_PATH` and `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS`
- Automatic configuration in both Claude Code and Claude Desktop

**Claude Code Configuration** (`home/development/claude-code-mcp-config.json`):

```json
"playwright": {
  "command": "npx",
  "args": ["-y", "@playwright/mcp@latest"],
  "env": {
    "PLAYWRIGHT_BROWSERS_PATH": "${PLAYWRIGHT_BROWSERS_PATH}",
    "PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS": "true"
  },
  "description": "Browser automation using Playwright"
}
```

**Claude Desktop Configuration** (`home/development/claude-desktop/mcp-config.nix`):

```nix
playwright = {
  command = "${pkgs.nodejs}/bin/npx";
  args = [ "-y" "@playwright/mcp@latest" ];
  env = {
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
  };
  description = "Browser automation using Playwright";
};
```

**Usage**:

```bash
# From Claude Code or Claude Desktop:
"Use playwright to open a browser to example.com"
"Navigate to GitHub and take a screenshot"
"Fill out this form with the following data"
"Extract all links from this page"
"Generate tests for this web application"
```

**Example Use Cases**:

- Automated web testing and QA
- Data extraction from websites
- Filling out forms programmatically
- Taking accessibility-tree snapshots
- AI-generated test creation (70% time reduction)
- Interactive debugging of web applications

#### 2. **mcp-nixos** - Comprehensive NixOS Knowledge Base

**Purpose**: Authoritative NixOS package and configuration queries
**Repository**: <https://github.com/utensils/mcp-nixos>

**Data Coverage**:

- 130,000+ searchable packages across all channels
- 22,000+ NixOS system configuration options
- 4,000+ Home Manager user-level settings (131 categories)
- 1,000+ macOS/Darwin-specific configurations (21 categories)
- Historical package versions with commit hashes via NixHub

**Benefits**:

- **Zero Hallucinations**: AI queries real-time authoritative data, not outdated training
- **Multi-Channel Support**: Search across stable, unstable, and historical releases
- **Intelligent Suggestions**: Context-aware option recommendations
- **Plain-Text Output**: Human and LLM-readable formatting
- **Stateless Operation**: No cache files or persistent configuration needed

### Available Tools

#### NixOS Package & System Configuration

**`nixos_search(query, channel?)`** - Search packages and system options

```bash
# Examples in Claude:
"Search for PostgreSQL packages"
"Find all monitoring-related packages"
"Show me options for networking.firewall"
"What packages provide the 'git' command?"
```

**`nixos_info(name, channel?)`** - Detailed package/option information

```bash
# Examples:
"Get detailed info about the postgresql package"
"Show me all options for services.nginx"
"What are the configuration options for boot.loader.grub?"
```

**`nixos_stats(channel?)`** - Aggregate package and option counts

```bash
# Examples:
"How many packages are in nixos-unstable?"
"Show statistics for all NixOS channels"
```

**`nixos_channels()`** - List all accessible NixOS release channels

```bash
# Examples:
"List all available NixOS channels"
"What channels can I search?"
```

#### Package Version History (NixHub Integration)

**`nixhub_package_versions(package_name, limit?)`** - Historical package versions

```bash
# Examples:
"Show version history for neovim"
"What versions of postgresql are available?"
"List the last 20 versions of docker with commit hashes"
```

**`nixhub_find_version(package_name, version)`** - Locate specific package version

```bash
# Examples:
"Find commit hash for postgresql version 15.3"
"Locate neovim version 0.9.0"
"What commit has python 3.11.5?"
```

#### Flake Ecosystem

**`nixos_flakes_search(query)`** - Query community flake repositories

```bash
# Examples:
"Search for home-manager flakes"
"Find flakes related to development environments"
"What flakes provide Hyprland configuration?"
```

**`nixos_flakes_stats()`** - Flake ecosystem adoption statistics

```bash
# Examples:
"Show flake ecosystem statistics"
"How many community flakes are available?"
```

#### Home Manager Configuration

**`home_manager_search(query)`** - Search user-level configuration options

```bash
# Examples:
"Search for zsh configuration options"
"Find all tmux-related options"
"What options are available for programs.neovim?"
"Show me git configuration options"
```

**`home_manager_info(option_name)`** - Detailed option information

```bash
# Examples:
"Get details about programs.git.enable"
"Show me info for programs.tmux.keyMode"
"What does services.gpg-agent.defaultCacheTtl do?"
```

**`home_manager_stats()`** - Available option counts

```bash
# Examples:
"How many Home Manager options are available?"
"Show Home Manager statistics"
```

**`home_manager_list_options()`** - Browse all 131 configuration categories

```bash
# Examples:
"List all Home Manager option categories"
"What configuration areas does Home Manager cover?"
```

**`home_manager_options_by_prefix(prefix)`** - Filter options by naming prefix

```bash
# Examples:
"Show all options starting with 'programs.'"
"List all 'services.syncthing' options"
"What options begin with 'xdg.'?"
```

#### macOS/Darwin Configuration (nix-darwin)

**`darwin_search(query)`** - Query nix-darwin system options
**`darwin_info(option_name)`** - Detailed Darwin configuration settings
**`darwin_stats()`** - Display option availability metrics
**`darwin_list_options()`** - Explore all 21 configuration categories
**`darwin_options_by_prefix(prefix)`** - Systematic option discovery

### Example Workflows

#### Finding and Installing Packages

```plaintext
You: "I need a PostgreSQL monitoring tool for Prometheus"
Claude with mcp-nixos:
1. Searches packages: "prometheus postgres exporter"
2. Finds: postgresql_exporter, promscale, etc.
3. Provides: Installation instructions, version info, dependencies
4. Shows: Configuration examples using nixos_info()
```

#### Configuring System Options

```plaintext
You: "How do I configure automatic garbage collection?"
Claude with mcp-nixos:
1. Searches: "garbage collection nix"
2. Finds: nix.gc options
3. Shows: All available nix.gc.* options
4. Provides: Example configuration with defaults
```

#### Home Manager Setup

```plaintext
You: "Set up tmux with vim keybindings"
Claude with mcp-nixos:
1. Searches: home_manager_search("tmux")
2. Finds: programs.tmux.* options
3. Shows: programs.tmux.keyMode option
4. Provides: Complete configuration example
```

#### Historical Package Versions

```plaintext
You: "I need Python 3.10.8 specifically"
Claude with mcp-nixos:
1. Searches: nixhub_find_version("python3", "3.10.8")
2. Returns: Exact commit hash
3. Provides: Command to install from that commit
```

### Usage Best Practices

**When to Use mcp-nixos**:

- ✅ "What packages provide X?"
- ✅ "How do I configure Y service?"
- ✅ "Show me all options for Z"
- ✅ "What version of package is in stable?"
- ✅ "Find historical version of package"
- ✅ "What Home Manager options exist for X?"

**How to Ask**:

- Use natural language queries
- Be specific about channels if needed (stable vs unstable)
- Ask for examples or usage patterns
- Request configuration snippets

**Pro Tips**:

1. **Package Discovery**: Ask Claude to search for packages before assuming
2. **Option Exploration**: Use prefix searches to discover related options
3. **Version Pinning**: Use NixHub integration for specific versions
4. **Configuration Validation**: Ask Claude to verify option names before use
5. **Multi-Channel**: Compare packages across channels for latest features

### Integration Status

**P620 (Primary Workstation)**: ✅ Enabled

- Claude Desktop: Configured via `home/development/claude-desktop/mcp-config.nix`
- Claude Code: Configured via `home/development/claude-code-mcp-config.json`

**Razer (Laptop)**: ✅ Enabled

- Claude Desktop: Configured
- Claude Code: Configured

### Verification

Test that mcp-nixos is working:

```bash
# Check installation
which mcp-nixos

# Verify in Claude Desktop/Code by asking:
"What packages are available for monitoring?"
"Search for postgresql in NixOS"
"Show me Home Manager options for git"
```

### Technical Notes

**Why mcp-nixos Matters**:

Without mcp-nixos, AI assistants hallucinate about:

- Non-existent packages (40% error rate)
- Wrong option names (60% error rate)
- Outdated package versions
- Incorrect configuration syntax

With mcp-nixos, AI assistants provide:

- Real-time accurate package data
- Correct option names and types
- Current version information
- Valid configuration examples

**Performance**:

- Queries complete in < 1 second
- No local cache required
- Minimal memory footprint
- Real-time API access

#### 3. **github-mcp-server** (v0.20.2)

**Purpose**: GitHub repository integration
**Benefits**:

- PR automation and review
- Issue management
- Repository operations
- Code search across repositories

**Usage**:

```bash
# Requires GITHUB_TOKEN environment variable
# Configure in .claude/settings.local.json:
"github": {
  "command": "github-mcp-server",
  "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" }
}
```

**Example Use Cases**:

- Automated PR creation
- Issue triage and labeling
- Repository statistics
- Code review assistance

#### 4. **chatmcp**

**Purpose**: AI chat client with MCP support
**Benefits**:

- Command-line AI interaction
- MCP protocol testing
- Scriptable AI workflows

**Usage**:

```bash
chatmcp "your question here"
```

### Workstation Servers (P620, DEX5550)

#### 5. **mcp-grafana**

**Purpose**: Grafana dashboard and metrics integration
**Benefits**:

- Query metrics programmatically
- Create and modify dashboards
- Alert management
- Data visualization automation

**Usage**:

```bash
# Requires GRAFANA_API_TOKEN
# Configure to point to DEX5550 monitoring server:
"grafana": {
  "command": "mcp-grafana",
  "args": ["--url", "http://dex5550:3001"]
}
```

**Example Use Cases**:

- "Show me CPU usage for the last hour"
- "Create a dashboard for NixOS metrics"
- "What are the current active alerts?"

#### 6. **terraform-mcp-server** (v0.3.3)

**Purpose**: Infrastructure as Code automation
**Benefits**:

- Terraform plan/apply operations
- State management
- Resource queries
- IaC best practices

**Usage**:

```bash
# Works with local Terraform configurations
terraform-mcp-server
```

**Example Use Cases**:

- "What resources are in the current state?"
- "Plan changes for this configuration"
- "Show me the dependency graph"

### Optional Servers (Available on Demand)

#### 7. **mcp-k8s-go**

**Purpose**: Kubernetes cluster management
**Benefits**:

- Pod/deployment operations
- Resource monitoring
- Kubectl automation
- Cluster health checks

**Enable**: Set `features.ai.mcp.servers.kubernetes = true;`

#### 8. **gitea-mcp-server** (v0.5.0)

**Purpose**: Gitea repository management
**Benefits**:

- Self-hosted Git operations
- PR and issue management
- Repository administration

**Enable**: Set `features.ai.mcp.servers.gitea = true;`

#### 9. **mcp-proxy**

**Purpose**: Protocol conversion (stdio ↔ SSE)
**Benefits**:

- Bridge different MCP transport protocols
- Enable remote MCP server access
- Protocol debugging

**Enable**: Set `features.ai.mcp.servers.proxy = true;`

#### 10. **browser-mcp** (v0.1.0)

**Purpose**: AI-powered browser automation with privacy
**Benefits**:

- Local browser control (no cloud dependencies)
- Uses your existing browser profile (stay logged into services)
- Avoids bot detection using real browser fingerprint
- AI-assisted web automation, testing, and data extraction
- Seamless integration with Claude Code and other AI tools

**Configuration**:

```nix
# Enable BrowserMCP server
features.ai.mcp.servers.browsermcp = true;
```

**Claude Code MCP Config**:

```json
"browsermcp": {
  "command": "npx",
  "args": ["@browsermcp/mcp@latest"],
  "description": "Browser automation with privacy"
}
```

**Chrome Extension Installation (Required)**:

1. **Install Extension**:
   - Open Chrome/Chromium browser
   - Go to Chrome Web Store
   - Search for "Browser MCP"
   - Click "Add to Chrome" to install

2. **Pin Extension**:
   - Click the puzzle icon (extensions) in Chrome toolbar
   - Find "Browser MCP" in the list
   - Click the pin icon to pin it to the toolbar

3. **Connect Extension**:
   - Click the Browser MCP extension icon
   - Click "Connect" button
   - The extension will link the active tab to the MCP server

**Usage**:

```bash
# Ask Claude Code to automate browser tasks
"Open GitHub in the browser"
"Navigate to my repositories"
"Fill out this form with the following data..."
"Take a screenshot of this page"
"Extract all links from this page"
```

**Example Use Cases**:

- Automated web testing and QA
- Form filling and data entry automation
- Web scraping with AI understanding
- Browser-based workflow automation
- Interactive debugging of web applications
- Accessibility testing and analysis

**How It Works**:

```text
AI Client (Claude Code) → MCP Server (npx @browsermcp/mcp) → Chrome Extension → Browser Actions
```

The system uses three components:

1. **MCP Client**: AI tools send natural language instructions
2. **MCP Server**: Translates instructions into browser commands
3. **Chrome Extension**: Executes commands in your actual browser session

**Security & Privacy**:

- ✅ Runs completely locally on your machine
- ✅ Uses your existing browser profile and cookies
- ✅ No data sent to external services
- ✅ Full control over what actions are performed
- ✅ No API keys or authentication required

**Documentation**: <https://docs.browsermcp.io/setup-server>

## Additional Recommended MCP Servers (Not Yet in Nixpkgs)

Based on research of the MCP ecosystem, these servers would be highly beneficial:

### Development Tools

- **Context7**: Up-to-date library documentation (already configured via npx)
- **Semgrep**: Static analysis and security scanning
- **Docker-MCP**: Container management and orchestration

### Database Integration

- **PostgreSQL MCP**: Direct database queries
- **MongoDB MCP**: NoSQL database operations
- **ClickHouse MCP**: Analytics database integration

### Cloud Platforms

- **AWS MCP**: AWS service management
- **Azure MCP**: Azure resource operations
- **Cloudflare MCP**: CDN and edge computing

### Workflow Automation

- **Slack MCP**: Team communication
- **Discord MCP**: Community management
- **Zapier MCP**: 130+ SaaS integrations

## Configuration

### Automatic Configuration

MCP servers are automatically enabled based on host profile:

**Workstation Profile** (P620, DEX5550):

- ✅ Core servers: playwright, nixos, github, chatmcp
- ✅ Infrastructure: grafana, terraform
- ❌ Optional: kubernetes, gitea, proxy (enable manually if needed)

**Server Profile** (P510):

- ✅ Core servers: playwright, nixos, github, chatmcp
- ✅ Infrastructure: grafana, terraform
- ❌ Optional: kubernetes, gitea, proxy

**Laptop Profile** (Razer, Samsung):

- ✅ Core servers: playwright, nixos, github, chatmcp
- ❌ Infrastructure: grafana, terraform, kubernetes, gitea, proxy

### Manual Override

Enable all MCP servers on a specific host:

```nix
# In hosts/HOSTNAME/configuration.nix
features.ai.mcp = {
  enable = true;
  enableAll = true;  # Enable ALL available MCP servers
};
```

Enable specific servers:

```nix
features.ai.mcp = {
  enable = true;
  servers = {
    grafana = true;
    kubernetes = true;
    terraform = true;
    gitea = false;
    proxy = false;
  };
};
```

### Claude Code Integration

MCP servers are configured in two locations:

1. **Project-level**: `/home/olafkfreund/.config/nixos/home/development/claude-code-mcp-config.json`
2. **VS Code**: `/home/olafkfreund/.config/nixos/home/development/vscode-mcp-template.json`

These configurations are automatically installed and include:

- Playwright for browser automation
- NixOS for package queries
- GitHub for repository operations
- Grafana for metrics (workstations only)
- Context7 for library documentation (via npx)

## Usage Examples

### With Claude Code

```bash
# Claude can now use MCP servers automatically
claude "Navigate to github.com and create a new issue for nixos repo"
claude "Search nixpkgs for monitoring tools"
claude "Show me the current Grafana dashboard for P620"
```

### With VS Code

MCP servers are available in VS Code when using Claude/Copilot extensions:

1. Open command palette (Ctrl+Shift+P)
2. Select "Claude: Use MCP Server"
3. Choose from available servers

### Command-line Testing

```bash
# Test MCP servers directly
chatmcp "use playwright to navigate to example.com"
chatmcp "use nixos to search for prometheus packages"
chatmcp "use github to list my repositories"
```

## Troubleshooting

### MCP Server Not Found

```bash
# Check if server is installed
which playwright-mcp mcp-nixos github-mcp-server

# Verify configuration
cat /etc/mcp-servers-info.txt

# Check if AI features are enabled
nix eval .#nixosConfigurations.HOSTNAME.config.features.ai.mcp.enable
```

### Authentication Errors

```bash
# GitHub MCP requires GITHUB_TOKEN
echo $GITHUB_TOKEN  # Should not be empty

# Grafana MCP requires GRAFANA_API_TOKEN
# Generate from Grafana UI: Settings → API Keys
```

### Playwright Browser Issues

```bash
# Playwright may need browser installation
playwright-mcp --install

# Or use system Chromium
playwright-mcp --browser chromium
```

## Benefits for Infrastructure

### 1. Enhanced Development Workflow

- AI can query NixOS options and packages accurately
- Browser automation for testing web services
- GitHub integration for PR automation

### 2. Improved Monitoring

- Grafana integration provides AI access to metrics
- Automated dashboard creation and modification
- Intelligent alert analysis

### 3. Infrastructure Automation

- Terraform operations through AI
- Kubernetes management (when enabled)
- Automated infrastructure queries

### 4. Reduced Manual Work

- AI handles repetitive browser tasks
- Automated documentation searches
- Intelligent package discovery

## Security Considerations

### API Keys

- GitHub tokens stored in environment variables
- Grafana API keys managed separately
- Never commit API keys to repository

### Browser Automation

- Playwright runs in sandboxed environment
- Limited to specified browser (chromium)
- No persistent browser data

### Server Access

- MCP servers run with user permissions
- No elevated privileges required
- Firewall rules unchanged

## Future Enhancements

### Planned MCP Server Additions

1. **PostgreSQL MCP**: Direct database queries
2. **Docker MCP**: Container management
3. **Prometheus MCP**: Direct metrics queries
4. **Loki MCP**: Log aggregation queries

### Integration Improvements

1. Automated API key management via agenix
2. Host-specific MCP configurations
3. Performance monitoring for MCP operations
4. Custom MCP servers for infrastructure tools

## References

- **Official MCP Specification**: <https://modelcontextprotocol.io/>
- **MCP Server Registry**: <https://github.com/modelcontextprotocol/servers>
- **Awesome MCP Servers**: <https://github.com/punkpeye/awesome-mcp-servers>
- **Anthropic MCP Documentation**: <https://docs.anthropic.com/mcp>

## Related Documentation

- [AI Infrastructure](./AI-INFRASTRUCTURE.md) - Complete AI setup
- [NixOS Anti-Patterns](./NIXOS-ANTI-PATTERNS.md) - Code quality standards
- [Monitoring Stack](./MONITORING.md) - Grafana/Prometheus setup

## Sources

The following sources were used to research and implement this MCP integration:

- [Model Context Protocol Servers - Official GitHub](https://github.com/modelcontextprotocol/servers)
- [Top 10 MCP Servers for 2025 - DEV Community](https://dev.to/fallon_jimmy/top-10-mcp-servers-for-2025-yes-githubs-included-15jg)
- [Best Model Context Protocol (MCP) Servers in 2025 - Pomerium](https://www.pomerium.com/blog/best-model-context-protocol-mcp-servers-in-2025)
- [6 Must-Have MCP Servers - Docker Blog](https://www.docker.com/blog/top-mcp-servers-2025/)
- [Awesome MCP Servers - GitHub](https://github.com/punkpeye/awesome-mcp-servers)
- [playwright-mcp - npm](https://www.npmjs.com/package/@playwright/mcp)
- [playwright-mcp - MyNixOS](https://mynixos.com/nixpkgs/package/playwright-mcp)
- [mcp-nixos - GitHub](https://github.com/utensils/mcp-nixos)
