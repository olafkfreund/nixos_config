# Obsidian MCP Server Setup Guide

> Last Updated: 2025-12-02
> Status: Ready for Deployment

## Overview

This guide covers the installation and configuration of the Obsidian MCP (Model Context Protocol) server for your NixOS infrastructure. The Obsidian MCP server enables AI agents (Claude Code, VS Code, etc.) to interact directly with your Obsidian knowledge base.

## What is Obsidian MCP?

**Obsidian MCP** is a lightweight Model Context Protocol server that provides AI assistants with direct access to your Obsidian vault. It enables:

- **Read/Write Operations**: AI can read existing notes and create new ones
- **Search Capabilities**: Full-text search across your vault
- **Link Management**: Navigate and understand note relationships
- **Tag Operations**: Query and organize by tags
- **Frontmatter Access**: Read and modify YAML frontmatter

`★ Insight ─────────────────────────────────────`
**Why @mauricio.wolff/mcp-obsidian?**

- Zero dependencies - no Obsidian plugins required
- 40-60% smaller responses than alternatives
- Works with any vault structure (no setup needed)
- Active maintenance and modern TypeScript implementation
  `─────────────────────────────────────────────────`

## Implementation Choice

We've chosen **@mauricio.wolff/mcp-obsidian** (by bitbonsai) because:

✅ **Zero Dependencies**: No Obsidian plugins required
✅ **Lightweight**: Token-optimized responses (40-60% smaller)
✅ **Universal**: Works with any vault structure
✅ **Secure**: Safe vault access with intelligent handling
✅ **Modern**: Active development, TypeScript-based
✅ **Compatible**: Works with all MCP clients (Claude Code, VS Code, etc.)

### Alternative Implementations (Not Used)

| Server                              | Why Not Used                                            |
| ----------------------------------- | ------------------------------------------------------- |
| **obsidian-mcp-server** (cyanheads) | Requires Local REST API plugin installation in Obsidian |
| **@mseep/obsidian-mcp-server**      | Also requires REST API plugin, more complex setup       |

## Installation

### Automatic Installation (Recommended)

The Obsidian MCP server is already packaged in your NixOS configuration but **disabled by default**. To enable it:

#### **Option 1: Enable in Host Configuration**

```nix
# In hosts/HOSTNAME/configuration.nix
features.ai.mcp = {
  obsidian = {
    enable = true;
    vaultPath = "/home/olafkfreund/Documents/ObsidianVault";  # Your vault path
  };
};
```

#### **Option 2: Use Environment Variable**

```nix
# Enable without hardcoding path
features.ai.mcp.obsidian.enable = true;

# Then set environment variable in your shell profile:
# export OBSIDIAN_VAULT_PATH="/home/olafkfreund/Documents/ObsidianVault"
```

#### **Option 3: Enable All MCP Servers**

```nix
# Enable everything including Obsidian
features.ai.mcp.enableAll = true;
```

### Manual Installation (Alternative)

If you prefer manual installation without NixOS configuration:

```bash
# Install globally
npm install -g @mauricio.wolff/mcp-obsidian

# Or use npx (no installation)
npx @mauricio.wolff/mcp-obsidian@latest /path/to/vault
```

## Configuration

### Claude Code Configuration

The configuration has been added to `home/development/claude-code-mcp-config.json`:

```json
{
  "mcpServers": {
    "obsidian": {
      "command": "npx",
      "args": [
        "@mauricio.wolff/mcp-obsidian@latest",
        "${OBSIDIAN_VAULT_PATH:-~/Documents/ObsidianVault}"
      ],
      "description": "Obsidian vault knowledge base integration"
    }
  }
}
```

**Configuration Steps:**

1. Set your vault path:

   ```bash
   export OBSIDIAN_VAULT_PATH="/home/olafkfreund/Documents/ObsidianVault"
   ```

2. Add to your shell profile (`.zshrc` or `.bashrc`):

   ```bash
   echo 'export OBSIDIAN_VAULT_PATH="/home/olafkfreund/Documents/ObsidianVault"' >> ~/.zshrc
   ```

3. Reload shell or source profile:

   ```bash
   source ~/.zshrc
   ```

### VS Code Configuration

For VS Code integration, the template is in `home/development/vscode-mcp-template.json`:

```json
{
  "servers": {
    "obsidian": {
      "type": "stdio",
      "command": "npx",
      "args": ["@mauricio.wolff/mcp-obsidian@latest", "${OBSIDIAN_VAULT_PATH}"]
    }
  }
}
```

## Deployment

### Step 1: Configure Your Vault Path

Choose where your Obsidian vault is located:

```bash
# Common locations:
~/Documents/ObsidianVault          # Documents folder
~/Obsidian                         # Home directory
~/Notes                            # Custom notes folder
```

### Step 2: Enable in Configuration

Edit your host configuration:

```bash
# Edit host config
vim hosts/p620/configuration.nix

# Add Obsidian MCP configuration:
features.ai.mcp = {
  obsidian = {
    enable = true;
    vaultPath = "/home/olafkfreund/Documents/ObsidianVault";
  };
};
```

### Step 3: Build and Deploy

```bash
# Test configuration
just test-host p620

# Deploy to host
just quick-deploy p620

# Or deploy to all hosts
just deploy-all-parallel
```

### Step 4: Verify Installation

```bash
# Check if command is available
which obsidian-mcp

# Test server manually
obsidian-mcp ~/Documents/ObsidianVault

# Or test with npx
npx @mauricio.wolff/mcp-obsidian@latest ~/Documents/ObsidianVault
```

## Usage Examples

### With Claude Code

Once configured, Claude can access your Obsidian vault:

```bash
# Example queries
claude "List all notes in my Obsidian vault"
claude "Search for notes about NixOS configuration"
claude "Create a new note about today's work"
claude "Find notes tagged with #project"
claude "Show me the frontmatter from note X"
```

### Available Operations

The Obsidian MCP server provides these capabilities:

1. **List Notes**: `list_notes()` - Get all notes in vault
2. **Read Note**: `read_note(path)` - Read specific note content
3. **Write Note**: `write_note(path, content)` - Create/update notes
4. **Search**: `search_notes(query)` - Full-text search
5. **List Tags**: `list_tags()` - Get all tags in vault
6. **Get Links**: `get_backlinks(note)` - Find note relationships
7. **Frontmatter**: `read_frontmatter(note)` - Access YAML metadata

### Example Workflows

#### **1. Knowledge Base Queries**

```
User: "claude, what notes do I have about Kubernetes?"
Claude: [Searches vault, lists relevant notes]

User: "Show me the content of that first note"
Claude: [Reads and displays note content]
```

#### **2. Note Creation**

```
User: "Create a note about today's infrastructure changes"
Claude: [Creates new note with AI-generated content about recent work]
```

#### **3. Research Integration**

```
User: "Search my vault for information about Prometheus setup, then compare with current config"
Claude: [Searches vault, reads relevant notes, compares with current system]
```

#### **4. Tag-Based Organization**

```
User: "List all notes tagged with #infrastructure"
Claude: [Queries tags, lists matching notes]

User: "Create a summary of these notes"
Claude: [Reads notes, creates comprehensive summary]
```

## Troubleshooting

### Server Not Found

```bash
# Check if installed
which obsidian-mcp
npx @mauricio.wolff/mcp-obsidian@latest --help

# Reinstall if needed
npm install -g @mauricio.wolff/mcp-obsidian@latest
```

### Vault Path Issues

```bash
# Verify vault exists
ls -la ~/Documents/ObsidianVault

# Check environment variable
echo $OBSIDIAN_VAULT_PATH

# Test with explicit path
obsidian-mcp /full/path/to/vault
```

### Permission Errors

```bash
# Check vault permissions
ls -la ~/Documents/ObsidianVault

# Ensure read/write access
chmod -R u+rw ~/Documents/ObsidianVault
```

### Claude Code Not Finding Server

```bash
# Check MCP configuration
cat ~/.config/claude-code/mcp-config.json

# Verify environment variable in Claude's context
claude "echo $OBSIDIAN_VAULT_PATH"

# Restart Claude Code
pkill -f claude-code
claude
```

### NPX Connection Issues

```bash
# Update npm
npm install -g npm@latest

# Clear npx cache
rm -rf ~/.npm/_npx

# Test npx directly
npx @mauricio.wolff/mcp-obsidian@latest --version
```

## Security Considerations

### Vault Access

- ✅ **Read-only by default**: Server can't modify notes unless configured
- ✅ **Local access only**: No network exposure
- ✅ **No plugin requirements**: Direct filesystem access
- ✅ **Sandboxed execution**: Runs in Node.js sandbox

### Best Practices

1. **Backup First**: Always backup vault before enabling write access
2. **Test Queries**: Try read-only operations before enabling writes
3. **Review Changes**: Check AI-generated notes before accepting
4. **Use Version Control**: Keep vault in Git for change tracking

### Access Control

```nix
# Restrict to specific users
features.ai.mcp.obsidian = {
  enable = true;
  vaultPath = "/home/olafkfreund/Documents/ObsidianVault";
  # Server runs with user permissions only
};
```

## Advanced Configuration

### Multiple Vaults

```nix
# Configure different vaults per user
features.ai.mcp.obsidian = {
  enable = true;
  vaultPath =
    if config.users.users ? olafkfreund
    then "/home/olafkfreund/Documents/ObsidianVault"
    else "/home/other/Documents/Vault";
};
```

### Per-Project Configuration

For project-specific Claude Code configuration:

```bash
# In project directory
mkdir -p .claude
cat > .claude/mcp-config.json << EOF
{
  "mcpServers": {
    "obsidian": {
      "command": "npx",
      "args": [
        "@mauricio.wolff/mcp-obsidian@latest",
        "$(pwd)/docs/obsidian-vault"
      ]
    }
  }
}
EOF
```

### Custom Wrapper Script

The NixOS package includes a wrapper (`obsidian-mcp`) that:

- Validates vault path existence
- Provides helpful error messages
- Supports OBSIDIAN_VAULT_PATH environment variable
- Uses latest version automatically

```bash
# Usage
obsidian-mcp /path/to/vault

# Or with environment variable
export OBSIDIAN_VAULT_PATH=~/Documents/ObsidianVault
obsidian-mcp
```

## Performance Optimization

### Token Usage

@mauricio.wolff/mcp-obsidian uses **40-60% fewer tokens** than alternatives:

- **Efficient responses**: Only necessary data returned
- **Smart link handling**: Resolves references intelligently
- **Optimized search**: Returns relevant excerpts, not full notes
- **Compressed metadata**: Minimal frontmatter parsing

### Caching

```bash
# NPX caches the package after first use
# Manual cache management (rarely needed):
npm cache clean --force
```

## Future Enhancements

### Planned Features

1. **Semantic Search**: Vector-based similarity search
2. **Graph Analysis**: Advanced link relationship queries
3. **Templates**: AI-powered note templates
4. **Auto-tagging**: Intelligent tag suggestions
5. **Sync Integration**: Real-time vault synchronization

### Community Tools

Consider these complementary tools:

- **Obsidian Omnisearch**: Advanced search plugin
- **Templater**: Dynamic note templates
- **Dataview**: Query notes like database
- **Git Sync**: Automatic version control

## Resources

### Official Documentation

- **Project Website**: [mcp-obsidian.org](https://mcp-obsidian.org)
- **GitHub Repository**: [github.com/bitbonsai/mcp-obsidian](https://github.com/bitbonsai/mcp-obsidian)
- **NPM Package**: [@mauricio.wolff/mcp-obsidian](https://www.npmjs.com/package/@mauricio.wolff/mcp-obsidian)

### Related Documentation

- [MCP Servers Overview](./MCP-SERVERS.md) - Complete MCP integration guide
- [AI Infrastructure](./AI-INFRASTRUCTURE.md) - Overall AI setup
- [Claude Code Configuration](./CLAUDE-CODE.md) - Claude Code setup

### Community Resources

- **Obsidian Forum**: [forum.obsidian.md](https://forum.obsidian.md)
- **MCP Discussion**: [Obsidian MCP experiences thread](https://forum.obsidian.md/t/obsidian-mcp-servers-experiences-and-recommendations/99936)
- **Medium Guide**: [Using MCP in Obsidian — the right way](https://mayeenulislam.medium.com/using-mcp-in-obsidian-the-right-way-646cf56ec7a7)

## Quick Reference

### Configuration Locations

```
NixOS Config:          modules/ai/mcp-servers.nix
Custom Package:        pkgs/obsidian-mcp/default.nix
Claude Code Config:    home/development/claude-code-mcp-config.json
VS Code Template:      home/development/vscode-mcp-template.json
Documentation:         docs/OBSIDIAN-MCP-SETUP.md
```

### Commands

```bash
# Enable in config
vim hosts/p620/configuration.nix

# Deploy
just quick-deploy p620

# Test server
obsidian-mcp ~/Documents/ObsidianVault

# Check status
which obsidian-mcp
echo $OBSIDIAN_VAULT_PATH

# Manual run
npx @mauricio.wolff/mcp-obsidian@latest /path/to/vault
```

### Environment Variables

```bash
# Required
export OBSIDIAN_VAULT_PATH="/home/olafkfreund/Documents/ObsidianVault"

# Optional
export OBSIDIAN_MCP_DEBUG=true  # Enable debug logging
export OBSIDIAN_MCP_PORT=3000   # Custom port (if needed)
```

---

**Implementation Status**: ✅ Complete and ready for deployment

**Next Steps**:

1. Set OBSIDIAN_VAULT_PATH environment variable
2. Enable in host configuration
3. Deploy and test with Claude Code
4. Explore AI-powered knowledge base interactions
