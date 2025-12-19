# mcp-nixos Quick Reference Guide

> **Fast access to mcp-nixos capabilities for Claude Desktop and Claude Code**
> Repository: <https://github.com/utensils/mcp-nixos>

## 🚀 Quick Start

mcp-nixos is **already installed and enabled** on both P620 and Razer!

Just ask Claude naturally:

- "What packages are available for monitoring?"
- "How do I configure systemd services?"
- "Show me Home Manager options for git"

## 📦 NixOS Packages

### Search Packages

```plaintext
"Search for PostgreSQL packages"
"Find all monitoring-related packages"
"What packages provide the 'git' command?"
```

### Package Details

```plaintext
"Get detailed info about the postgresql package"
"Show me version info for neovim"
"What dependencies does docker have?"
```

### Package Statistics

```plaintext
"How many packages are in nixos-unstable?"
"Show statistics for all NixOS channels"
```

### Version History (NixHub)

```plaintext
"Show version history for neovim"
"Find commit hash for postgresql version 15.3"
"What versions of python are available?"
```

## ⚙️ NixOS System Configuration

### Search Options

```plaintext
"Show me options for networking.firewall"
"Find all systemd service options"
"What configuration options exist for boot.loader?"
```

### Option Details

```plaintext
"What are the configuration options for boot.loader.grub?"
"Show me all options for services.nginx"
"Get details about nix.gc.automatic"
```

### List Channels

```plaintext
"List all available NixOS channels"
"What channels can I search?"
```

## 🏠 Home Manager Configuration

### Search Options

```plaintext
"Search for zsh configuration options"
"Find all tmux-related options"
"What options are available for programs.neovim?"
"Show me git configuration options"
```

### Option Details

```plaintext
"Get details about programs.git.enable"
"Show me info for programs.tmux.keyMode"
"What does services.gpg-agent.defaultCacheTtl do?"
```

### Browse Categories

```plaintext
"List all Home Manager option categories"
"Show all options starting with 'programs.'"
"What configuration areas does Home Manager cover?"
```

### Statistics

```plaintext
"How many Home Manager options are available?"
"Show Home Manager statistics"
```

## 🔍 Flake Ecosystem

### Search Flakes

```plaintext
"Search for home-manager flakes"
"Find flakes related to development environments"
"What flakes provide Hyprland configuration?"
```

### Flake Statistics

```plaintext
"Show flake ecosystem statistics"
"How many community flakes are available?"
```

## 💡 Common Use Cases

### Installing a Package

```plaintext
You: "I need a PostgreSQL monitoring tool"
Claude: Searches packages → Finds postgresql_exporter → Provides installation and config
```

### Configuring a Service

```plaintext
You: "How do I enable automatic garbage collection?"
Claude: Searches options → Shows nix.gc.* options → Provides example configuration
```

### Setting Up Home Manager

```plaintext
You: "Set up tmux with vim keybindings"
Claude: Searches HM options → Shows programs.tmux.keyMode → Provides complete config
```

### Finding Specific Version

```plaintext
You: "I need Python 3.10.8 specifically"
Claude: Uses nixhub_find_version → Returns commit hash → Provides installation command
```

## ✅ Verification

Test mcp-nixos is working:

```bash
# Check installation
which mcp-nixos

# In Claude, ask:
"What packages are available for monitoring?"
"Search for postgresql in NixOS"
"Show me Home Manager options for git"
```

## 🎯 Best Practices

### DO ✅

- Use natural language queries
- Ask for examples and usage patterns
- Request configuration snippets
- Specify channels if needed (stable vs unstable)
- Use for package discovery before installing
- Verify option names before using in config

### DON'T ❌

- Don't guess package names - ask Claude to search
- Don't assume option names - use mcp-nixos to verify
- Don't use outdated versions - check current availability
- Don't skip examples - ask for configuration patterns

## 📊 Data Coverage

- **130,000+** searchable packages across all channels
- **22,000+** NixOS system configuration options
- **4,000+** Home Manager user-level settings (131 categories)
- **1,000+** macOS/Darwin configurations (21 categories)
- **Historical versions** with commit hashes via NixHub

## 🔧 Technical Details

**Why It Matters**:

- Without: 40% package hallucinations, 60% wrong option names
- With: Real-time accurate data, correct syntax, valid examples

**Performance**:

- Queries complete in < 1 second
- No local cache required
- Minimal memory footprint
- Real-time API access

## 📍 Current Status

**P620**: ✅ Enabled (Claude Desktop + Claude Code)
**Razer**: ✅ Enabled (Claude Desktop + Claude Code)

## 🔗 Full Documentation

See `docs/MCP-SERVERS.md` for complete details and advanced features.
