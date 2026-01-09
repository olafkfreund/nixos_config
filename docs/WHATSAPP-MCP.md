# WhatsApp MCP Integration

> **AI-Assisted WhatsApp Messaging for Claude Code & Claude Desktop**
> Version: 1.0.0
> Status: Deployed (P620, Razer, Samsung)

## Overview

WhatsApp MCP enables AI assistants (Claude Code, Claude Desktop) to interact with WhatsApp through natural language
commands. Send/receive messages, query message history, search conversations, and automate WhatsApp workflows directly
from your AI environment.

**Key Features:**

- 📱 **Send/Receive Messages**: Natural language WhatsApp interaction
- 🔍 **Message History**: Query and search conversations
- 👥 **Group Chat Support**: Send to groups and manage group messages
- 📎 **Media Files**: Send images, documents, and other files
- 🎤 **Voice Messages**: Optional FFmpeg support for voice message conversion
- 🔒 **Secure**: QR code authentication, encrypted storage

## Architecture

WhatsApp MCP uses a two-component architecture:

### 1. Go Bridge (`whatsapp-bridge`)

- **Purpose**: Persistent connection to WhatsApp Web API
- **Technology**: Go application using whatsmeow library
- **Storage**: SQLite database for session/message history
- **Service**: Systemd service with security hardening
- **Location**: `/var/lib/whatsapp-mcp/whatsapp.db`

### 2. Python MCP Server (`whatsapp-mcp-server`)

- **Purpose**: Model Context Protocol implementation for AI integration
- **Technology**: Python 3.11+ with MCP SDK
- **Dependencies**: httpx, mcp[cli], requests
- **Integration**: Communicates with Go bridge via HTTP API

## Installation

### Prerequisites

WhatsApp MCP is **already deployed** on the following hosts:

- ✅ **P620** (workstation) - Voice messages enabled
- ✅ **Razer** (laptop) - Voice messages enabled
- ✅ **Samsung** (laptop) - Voice messages enabled

Configuration files:

- **System**: `modules/ai/mcp-servers.nix`
- **Service**: `modules/services/whatsapp-bridge.nix`
- **Package**: `pkgs/whatsapp-mcp/default.nix`
- **Claude Desktop**: `home/development/claude-desktop/mcp-config.nix`
- **Claude Code**: `home/development/claude-code-mcp-config.json`

### Enable on Additional Hosts

To enable WhatsApp MCP on another host:

```nix
# In hosts/HOSTNAME/configuration.nix
features.ai.mcp = {
  enable = true;
  whatsapp = {
    enable = true;
    enableVoiceMessages = true;  # Enable FFmpeg for voice message conversion (.ogg Opus)
  };
};
```

Then rebuild:

```bash
just quick-deploy HOSTNAME
```

## Setup & Authentication

### Initial QR Code Authentication

WhatsApp MCP requires QR code authentication on first use (similar to WhatsApp Web).

#### Step 1: Start the WhatsApp Bridge Service

```bash
# Check if service is running
systemctl status whatsapp-bridge

# Start service if not running
sudo systemctl start whatsapp-bridge

# Enable service to start on boot
sudo systemctl enable whatsapp-bridge
```

#### Step 2: View QR Code

```bash
# Watch logs for QR code
journalctl -u whatsapp-bridge -f

# The QR code will be displayed in ASCII art in the logs
# Example output:
# [INFO] Please scan the QR code with WhatsApp mobile app
# █████████████████████████████████
# ██ ▄▄▄▄▄ █▀ █▀▀██ ... ▄▄▄▄▄ ██
# ██ █   █ █▀▀ ▄▄▀█ ... █   █ ██
# ...
```

#### Step 3: Scan with WhatsApp Mobile App

1. Open WhatsApp on your mobile phone
2. Go to **Settings** → **Linked Devices**
3. Tap **"Link a Device"**
4. Scan the QR code from the terminal/logs
5. Wait for "Connected" message in logs

#### Step 4: Verify Connection

```bash
# Check service status (should show "active (running)")
systemctl status whatsapp-bridge

# Verify database was created
ls -lah /var/lib/whatsapp-mcp/whatsapp.db
```

### Session Management

**Session Duration:** ~20 days

After approximately 20 days, the WhatsApp session expires and re-authentication is required.

**Re-authentication Process:**

1. Service will fail automatically when session expires
2. Notification service will alert about expired authentication
3. Follow QR code authentication steps above to re-authenticate

**Check Authentication Status:**

```bash
# View recent logs
journalctl -u whatsapp-bridge --since "1 hour ago"

# Check for authentication errors
journalctl -u whatsapp-bridge | grep -i "auth\|disconnect\|error"
```

## Usage Examples

### Claude Code Integration

WhatsApp MCP is automatically available in Claude Code when the bridge service is running.

**Example Commands:**

```bash
# Send a message to a contact
"Send a message to John saying I'll be running 10 minutes late"

# Send to a group
"Send 'Meeting in 5 minutes' to the team group"

# Search message history
"Find messages from Sarah containing 'meeting' from the last week"

# Get recent messages
"Show me the last 10 messages from Alice"

# Send a document
"Send the project document.pdf to Bob"

# Send an image
"Send image.png to the family group with caption 'Look at this!'"
```

**Natural Language Processing:**

Claude Code understands natural language and will:

- Identify contact names from your WhatsApp contacts
- Parse message content and context
- Handle media attachments automatically
- Infer message urgency and priority

### Claude Desktop Integration

WhatsApp MCP appears as a server in Claude Desktop:

1. Open Claude Desktop
2. MCP server "whatsapp" is automatically configured
3. Use natural language commands as with Claude Code
4. Server validates bridge is running before executing commands

**Configuration Location:**

- Auto-generated: `~/.config/Claude/claude_desktop_config.json`
- Source: `home/development/claude-desktop/mcp-config.nix`

## Configuration

### Service Configuration

**Systemd Service:**

```bash
# Service file location
/etc/systemd/system/whatsapp-bridge.service

# View service configuration
systemctl cat whatsapp-bridge

# Service logs
journalctl -u whatsapp-bridge -f
```

**Security Hardening:**

- `DynamicUser=true` - Dedicated ephemeral user
- `StateDirectory=whatsapp-mcp` - Persistent data directory
- `ProtectSystem=strict` - Read-only system filesystem
- `ProtectHome=true` - User home directories protected
- `NoNewPrivileges=true` - No privilege escalation
- `PrivateTmp=true` - Private `/tmp` directory

### Data Storage

**Database Location:** `/var/lib/whatsapp-mcp/whatsapp.db`

**Contents:**

- WhatsApp session credentials (encrypted)
- Message history (configurable retention)
- Contact information
- Group chat metadata

**Backup Recommendations:**

```bash
# Backup database (while service is stopped)
sudo systemctl stop whatsapp-bridge
sudo cp /var/lib/whatsapp-mcp/whatsapp.db /backup/location/
sudo systemctl start whatsapp-bridge

# Automated backup (add to cron)
0 2 * * * systemctl stop whatsapp-bridge && cp /var/lib/whatsapp-mcp/whatsapp.db /backup/whatsapp-$(date +\%Y\%m\%d).db && systemctl start whatsapp-bridge
```

### Voice Messages (Enabled)

FFmpeg support is **enabled by default** on all deployed hosts (P620, Razer, Samsung):

```nix
# Current configuration (all hosts)
features.ai.mcp.whatsapp = {
  enable = true;
  enableVoiceMessages = true;  # FFmpeg for .ogg Opus conversion
};
```

Voice message capabilities:

- ✅ Voice messages automatically converted to `.ogg` Opus format
- ✅ Full compatibility with WhatsApp Web API
- ✅ Send and receive voice messages via MCP
- ✅ FFmpeg package automatically installed when enabled

To disable (if needed):

```nix
enableVoiceMessages = false;  # Remove FFmpeg dependency
```

## Troubleshooting

### Service Not Running

**Problem:** Bridge service fails to start

**Solution:**

```bash
# Check service status
systemctl status whatsapp-bridge

# View detailed logs
journalctl -u whatsapp-bridge -n 50 --no-pager

# Common issues:
# - Port already in use
# - Database permission errors
# - Missing dependencies

# Restart service
sudo systemctl restart whatsapp-bridge
```

### Authentication Failed

**Problem:** QR code scan fails or session expires

**Solution:**

```bash
# 1. Stop service
sudo systemctl stop whatsapp-bridge

# 2. Clear session data (if needed)
sudo rm /var/lib/whatsapp-mcp/whatsapp.db

# 3. Restart service
sudo systemctl start whatsapp-bridge

# 4. Watch for new QR code
journalctl -u whatsapp-bridge -f

# 5. Scan QR code with WhatsApp mobile app
```

### MCP Server Not Available

**Problem:** Claude Code/Desktop can't find WhatsApp MCP

**Solution:**

```bash
# Verify bridge service is running
systemctl is-active whatsapp-bridge

# Check Claude Desktop config
cat ~/.config/Claude/claude_desktop_config.json | jq '.mcpServers.whatsapp'

# Check Claude Code config
cat ~/.config/claude-code/claude-code-mcp-config.json | jq '.mcpServers.whatsapp'

# Restart Claude application after service start
```

### Message Send Failures

**Problem:** Messages fail to send via MCP

**Diagnostics:**

```bash
# Check bridge logs for errors
journalctl -u whatsapp-bridge | grep -i "error\|fail"

# Verify WhatsApp connection status
# (Look for "Connected" vs "Disconnected" in logs)

# Check database integrity
sudo sqlite3 /var/lib/whatsapp-mcp/whatsapp.db "PRAGMA integrity_check;"

# Test bridge API directly (if available)
curl http://localhost:PORT/health  # Replace PORT with actual port
```

### Database Corruption

**Problem:** Database errors or corruption

**Solution:**

```bash
# 1. Stop service
sudo systemctl stop whatsapp-bridge

# 2. Backup corrupted database
sudo cp /var/lib/whatsapp-mcp/whatsapp.db /backup/corrupted.db

# 3. Attempt repair
sudo sqlite3 /var/lib/whatsapp-mcp/whatsapp.db "VACUUM;"
sudo sqlite3 /var/lib/whatsapp-mcp/whatsapp.db "REINDEX;"

# 4. If repair fails, restore from backup or delete and re-authenticate
sudo rm /var/lib/whatsapp-mcp/whatsapp.db

# 5. Restart service
sudo systemctl start whatsapp-bridge

# 6. Re-authenticate with QR code
```

## Security Considerations

### Session Security

**Encrypted Storage:**

- WhatsApp session credentials stored encrypted in SQLite
- Database permissions: `0700` (owner read/write/execute only)
- Systemd service runs as dedicated user (DynamicUser)

**Network Security:**

- Bridge communicates with WhatsApp servers over TLS
- Local MCP server uses HTTP (localhost only)
- No external port exposure required

**Access Control:**

- Service runs with minimal privileges
- StateDirectory managed by systemd
- File system protections via systemd security directives

### Authentication Security

**QR Code Security:**

- QR code displayed only in systemd logs
- Logs accessible only to root and systemd-journal group
- QR code expires after single scan
- Session tied to specific device

**Session Expiry:**

- Automatic session expiry after ~20 days
- Manual logout: Unlink device in WhatsApp mobile app
- Session invalidation on password change

### Data Privacy

**Message History:**

- Messages stored locally in SQLite database
- No cloud synchronization (local only)
- Message retention configurable
- Database backups user-controlled

**Compliance:**

- GDPR: User controls all data, can delete database anytime
- Data residency: All data stored on local host
- No third-party access: Direct WhatsApp connection only

## Integration with Existing MCP Infrastructure

WhatsApp MCP is part of the comprehensive MCP ecosystem:

### Other MCP Servers (P620, Razer, Samsung)

- **Obsidian** (rest-api): Knowledge base integration
- **Atlassian** (cloud): Jira and Confluence integration
- **GitHub** (stdio): Repository integration
- **Context7** (stdio): Up-to-date library documentation
- **Sequential Thinking**: Systematic problem-solving
- **Playwright**: Browser automation
- **BrowserMCP**: Privacy-focused browser automation
- **Terraform**: Infrastructure as Code support

### Unified MCP Configuration

All MCP servers managed centrally:

- **System Module**: `modules/ai/mcp-servers.nix`
- **Claude Desktop**: Auto-generated from Nix configuration
- **Claude Code**: JSON configuration with validation wrappers

### Feature Flags

Enable/disable MCP servers per host:

```nix
features.ai.mcp = {
  enable = true;
  whatsapp.enable = true;         # WhatsApp
  obsidian.enable = true;         # Obsidian
  atlassian.enable = true;        # Jira/Confluence
  servers.browsermcp = true;      # Browser automation
};
```

## Maintenance

### Regular Maintenance Tasks

**Weekly:**

- Check service health: `systemctl status whatsapp-bridge`
- Review logs for errors: `journalctl -u whatsapp-bridge --since "7 days ago" | grep -i error`

**Monthly:**

- Backup database: `cp /var/lib/whatsapp-mcp/whatsapp.db /backup/`
- Clean old message history (if needed)
- Verify authentication status

**As Needed (~20 days):**

- Re-authenticate via QR code scan

### Upgrade Process

WhatsApp MCP is managed by NixOS and upgraded via system updates:

```bash
# Update flake inputs
just update-flake

# Test upgrade on specific host
just test-host p620

# Deploy upgrade
just quick-deploy p620
just quick-deploy razer
just quick-deploy samsung

# Verify service after upgrade
systemctl status whatsapp-bridge
journalctl -u whatsapp-bridge --since "5 minutes ago"
```

**Note:** Session persists across upgrades (database retained in StateDirectory).

## Development & Debugging

### Manual Testing

**Test Go Bridge:**

```bash
# Run bridge manually (for debugging)
sudo -u DynamicUser-whatsapp-bridge /nix/store/.../bin/whatsapp-bridge

# Check database
sudo sqlite3 /var/lib/whatsapp-mcp/whatsapp.db ".tables"
sudo sqlite3 /var/lib/whatsapp-mcp/whatsapp.db "SELECT * FROM sessions;"
```

**Test Python MCP Server:**

```bash
# Run MCP server manually
whatsapp-mcp-server

# Check MCP protocol communication
# (Requires understanding of MCP protocol)
```

### Log Analysis

**View All Logs:**

```bash
# Follow live logs
journalctl -u whatsapp-bridge -f

# Show last 100 lines
journalctl -u whatsapp-bridge -n 100

# Show logs since boot
journalctl -u whatsapp-bridge -b

# Show logs for specific time range
journalctl -u whatsapp-bridge --since "2025-01-09 10:00" --until "2025-01-09 11:00"
```

**Filter Logs:**

```bash
# Authentication logs
journalctl -u whatsapp-bridge | grep -i "qr\|auth\|connect"

# Error logs
journalctl -u whatsapp-bridge | grep -i "error\|fail\|panic"

# Message activity
journalctl -u whatsapp-bridge | grep -i "message\|send\|receive"
```

### Package Hashes

When building the WhatsApp MCP package, you may need to update hashes:

**Location:** `pkgs/whatsapp-mcp/default.nix`

**Update Process:**

```bash
# 1. Try to build package (will fail with correct hash)
nix build .#packages.x86_64-linux.customPkgs.whatsapp-mcp

# 2. Copy hash from error message
# Example error:
# error: hash mismatch in fixed-output derivation
# specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
# got:       sha256-REALHASH1234567890ABCDEF...=

# 3. Update hash in default.nix
# - Update src.hash with GitHub source hash
# - Update vendorHash with Go vendor hash

# 4. Rebuild
nix build .#packages.x86_64-linux.customPkgs.whatsapp-mcp
```

## Resources

**Official Documentation:**

- GitHub: <https://github.com/lharries/whatsapp-mcp>
- whatsmeow library: <https://github.com/tulir/whatsmeow>
- Model Context Protocol: <https://modelcontextprotocol.io>

**NixOS Configuration:**

- Package: `pkgs/whatsapp-mcp/default.nix`
- Service: `modules/services/whatsapp-bridge.nix`
- MCP Module: `modules/ai/mcp-servers.nix`
- GitHub Issue: #137 (implementation tracking)

**Support:**

- NixOS Discourse: <https://discourse.nixos.org>
- WhatsApp MCP Issues: <https://github.com/lharries/whatsapp-mcp/issues>

## Changelog

### Version 1.0.0 (2025-01-09)

**Initial Implementation:**

- ✅ Go bridge package with security hardening
- ✅ Python MCP server package
- ✅ Systemd service with DynamicUser
- ✅ Claude Desktop integration (auto-configured)
- ✅ Claude Code integration (JSON config)
- ✅ Deployed on P620, Razer, Samsung
- ✅ Comprehensive documentation

**Features:**

- QR code authentication workflow
- Message send/receive via natural language
- Message history queries
- Group chat support
- Media file support
- Optional voice message support (FFmpeg)

**Security:**

- Systemd security hardening (DynamicUser, ProtectSystem, etc.)
- Encrypted SQLite database
- Local-only storage (no cloud sync)
- Session expiry and re-authentication

**Known Limitations:**

- Package hashes need updating during first build
- Session requires re-authentication every ~20 days
- Voice messages require FFmpeg (optional feature)

---

## WhatsApp MCP Integration - AI-Assisted WhatsApp Messaging

For questions or issues, refer to the Troubleshooting section or check the GitHub issue tracker.
