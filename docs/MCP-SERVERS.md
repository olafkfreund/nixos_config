# MCP (Model Context Protocol) Servers Integration

> Last Updated: 2025-12-02
> Status: Fully Deployed

## Overview

The infrastructure now includes comprehensive MCP (Model Context Protocol) server support, enabling AI agents to interact with external tools and data sources through a standardized protocol.

**MCP is "USB-C for AI"** - a revolutionary standard that enables AI agents to seamlessly interact with tools, databases, APIs, and services without custom integration code.

## What is MCP?

The Model Context Protocol (MCP) is an open protocol released by Anthropic in November 2024 that standardizes how AI applications connect to external tools and data sources. It uses a three-core architecture:

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

**Usage**:
```bash
# Launched automatically by claude-code
# Configure in .claude/settings.local.json:
"playwright": {
  "command": "playwright-mcp",
  "args": ["--browser", "chromium"]
}
```

**Example Use Cases**:
- Automated web testing
- Data extraction from websites
- Filling out forms programmatically
- Taking accessibility-tree snapshots

#### 2. **mcp-nixos**
**Purpose**: NixOS package and configuration queries
**Benefits**:
- Prevents AI hallucinations about NixOS packages (130K+ packages)
- Provides accurate configuration option information (22K+ options)
- Queries official NixOS documentation
- Home Manager integration

**Usage**:
```bash
# Available tools:
# - nixos_search(): Search packages and options
# - nixos_info(): Get detailed package/option information
```

**Example Queries**:
- "What packages are available for monitoring?"
- "How do I configure systemd services?"
- "Show me all options for networking.firewall"

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

- **Official MCP Specification**: https://modelcontextprotocol.io/
- **MCP Server Registry**: https://github.com/modelcontextprotocol/servers
- **Awesome MCP Servers**: https://github.com/punkpeye/awesome-mcp-servers
- **Anthropic MCP Documentation**: https://docs.anthropic.com/mcp

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
