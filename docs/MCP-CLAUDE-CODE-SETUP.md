# Claude Code MCP Integration Setup

Complete guide for using MCP (Model Context Protocol) servers with Claude Code.

## What's Configured

All MCP servers are now installed and configured on your system:

### Core MCP Servers (Always Available)

1. **obsidian-mcp** - Obsidian vault knowledge base
2. **mcp-nixos** - NixOS package/option queries
3. **github-mcp-server** - GitHub integration
4. **chatmcp** - AI chat client
5. **terraform-mcp-server** - Infrastructure as Code
6. **mcp-grafana** - Monitoring dashboard integration
7. **context7** - Up-to-date library documentation

## Environment Variables

The following environment variable is automatically set in your zsh configuration:

```bash
export OBSIDIAN_VAULT_PATH="$HOME/Documents/Caliti"
```

This will be available in all new shell sessions after deployment.

## Claude Code Configuration

### Configuration File Location

The MCP configuration is stored at:
```
/home/olafkfreund/.config/nixos/home/development/claude-code-mcp-config.json
```

### Activating MCP in Claude Code

To enable MCP servers in Claude Code, copy the configuration to Claude Code's settings:

```bash
# Create Claude Code config directory if it doesn't exist
mkdir -p ~/.claude

# Copy MCP configuration
cp /home/olafkfreund/.config/nixos/home/development/claude-code-mcp-config.json ~/.claude/mcp-config.json
```

Or manually add to `~/.claude/settings.local.json`:

```json
{
  "mcpServers": {
    // Copy contents from claude-code-mcp-config.json
  }
}
```

## Required Environment Variables

Some MCP servers require authentication tokens:

### GitHub MCP Server

Set your GitHub token (if not already set):

```bash
# Add to ~/.zshrc or set in NixOS configuration
export GITHUB_TOKEN="your-github-token-here"
```

Create a token at: https://github.com/settings/tokens

Required scopes: `repo`, `read:org`, `read:user`

### Grafana MCP Server (Optional)

Set your Grafana API token:

```bash
export GRAFANA_API_TOKEN="your-grafana-token-here"
```

Create a token in Grafana at: http://dex5550:3001/org/apikeys

## Testing MCP Servers

Test each server individually:

### Obsidian MCP
```bash
# Should use the environment variable automatically
obsidian-mcp $OBSIDIAN_VAULT_PATH
```

### NixOS MCP
```bash
mcp-nixos
# Try: "search for package firefox"
```

### GitHub MCP
```bash
github-mcp-server
# Try: "list my repositories"
```

### Terraform MCP
```bash
terraform-mcp-server
# Try: "show terraform state"
```

### Grafana MCP
```bash
mcp-grafana --url http://dex5550:3001 --token $GRAFANA_API_TOKEN
# Try: "show dashboards"
```

## Using MCP in Claude Code

Once configured, Claude Code can interact with all these servers. Example prompts:

### Obsidian Queries
- "Search my Obsidian vault for notes about NixOS"
- "Create a new note in my vault about MCP setup"
- "What notes do I have about monitoring?"

### NixOS Queries
- "What NixOS options are available for Docker?"
- "Find packages related to AI development"
- "Show me the configuration options for systemd services"

### GitHub Integration
- "List open issues in my nixos_config repository"
- "Create a new issue for updating Claude Code"
- "Show recent pull requests"

### Grafana Monitoring
- "What's the current CPU usage on P620?"
- "Show me the Prometheus targets status"
- "What alerts are currently firing?"

### Terraform
- "List terraform resources in this directory"
- "Show the current terraform state"
- "Plan terraform changes"

## Troubleshooting

### MCP Server Not Found

Ensure the server is installed:
```bash
which obsidian-mcp mcp-nixos github-mcp-server
```

If missing, rebuild your NixOS configuration:
```bash
sudo nixos-rebuild switch --flake .#p620
```

### Environment Variable Not Set

Check if the variable exists:
```bash
echo $OBSIDIAN_VAULT_PATH
```

If empty, restart your shell or source zshrc:
```bash
exec zsh
# or
source ~/.zshrc
```

### Claude Code Not Seeing Servers

1. Check MCP config file exists: `cat ~/.claude/mcp-config.json`
2. Restart Claude Code completely
3. Check Claude Code logs for MCP errors

### Authentication Errors

Verify tokens are set:
```bash
echo $GITHUB_TOKEN
echo $GRAFANA_API_TOKEN
```

## Benefits of MCP Integration

With MCP enabled, Claude Code can:

1. **Access Your Knowledge Base** - Query and update Obsidian notes
2. **Understand NixOS** - Accurate package and option information
3. **Automate GitHub** - Create issues, PRs, and manage repositories
4. **Monitor Systems** - Query Grafana dashboards and metrics
5. **Manage Infrastructure** - Interact with Terraform configurations
6. **Stay Current** - Use Context7 for up-to-date library documentation

This creates a powerful AI-assisted development environment with access to your actual tools and data!

## Documentation

- **MCP Protocol**: https://modelcontextprotocol.io/
- **Server List**: `nix search nixpkgs mcp`
- **System Info**: `cat /etc/mcp-servers-info.txt`
- **MCP Servers Guide**: `cat docs/MCP-SERVERS.md`
- **Obsidian Setup**: `cat docs/OBSIDIAN-MCP-SETUP.md`
