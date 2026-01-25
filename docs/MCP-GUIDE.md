# MCP Servers Guide

Last Updated: 2026-01-25
Status: Active

## Overview

The infrastructure includes comprehensive MCP (Model Context Protocol) server support, enabling AI agents to interact with external tools and data sources through a standardized protocol.

MCP is an open protocol released by Anthropic that standardizes how AI applications connect to external tools and data sources.

## Architecture

Three-core architecture:

1. **MCP Hosts**: AI applications (Claude Code, VS Code, etc.)
2. **MCP Clients**: Protocol handlers within applications
3. **MCP Servers**: Services that provide specific capabilities

## Core MCP Servers

### playwright-mcp

Browser automation using Playwright.

**Features:**
- AI can navigate and interact with web pages
- Automated testing and web scraping
- DOM manipulation and screenshot capabilities
- Form filling and web automation
- Accessibility tree analysis

**NixOS Configuration:**
- Uses `playwright-driver.browsers` package
- Environment variables: `PLAYWRIGHT_BROWSERS_PATH` and `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS`
- Configured in both Claude Code and Claude Desktop

### mcp-nixos

NixOS-specific integration for package management and system operations.

**Repository**: https://github.com/utensils/mcp-nixos

**Features:**
- Package search and installation
- System configuration queries
- NixOS option documentation access
- Flake operations

**Usage**: Ask Claude naturally about NixOS operations.

## Service Integrations

### Atlassian (Jira and Confluence)

Enables AI-assisted interaction with Jira and Confluence through natural language commands.

**Supported:**
- Cloud and self-hosted Atlassian instances
- Jira issue management
- Confluence page operations

**Setup Requirements:**
- Atlassian account credentials
- API tokens for authentication
- Workspace configuration

**Common Tasks:**
- Create/update Jira issues
- Search and query tickets
- Read/edit Confluence pages
- Project analysis

### LinkedIn Professional Networking

Access LinkedIn data for professional networking tasks.

**Features:**
- Profile analysis and extraction
- Work history and skills data
- Connection management
- Job search integration

**Setup Requirements:**
- LinkedIn account credentials
- OAuth authentication
- API access tokens

### WhatsApp Messaging

AI-assisted WhatsApp integration for messaging automation.

**Deployment Status**: P620, Razer, Samsung

**Features:**
- Send/receive messages
- Query message history
- Search conversations
- Automated workflows

**Setup Requirements:**
- WhatsApp account
- QR code authentication
- Mobile device pairing

### Obsidian Knowledge Base

Direct interaction with Obsidian vaults through REST API.

**Deployment Status**: P620, Razer

**Features:**
- Full CRUD operations on notes
- Search and query capabilities
- Tag and metadata management
- Graph navigation

**Setup Requirements:**
- Obsidian Local REST API plugin installed
- Vault configuration
- API endpoint accessible

**Configuration:**
- Default port: 27124
- REST API enabled in Obsidian
- Authentication configured

## Configuration Files

### Claude Code Configuration

Location: `home/development/claude-code-mcp-config.json`

Contains MCP server definitions and connection settings for Claude Code.

### Claude Desktop Configuration

Location: User-specific Claude Desktop settings

Separate configuration for Claude Desktop application integration.

## Quick Reference

### NixOS-Specific Setup

The infrastructure provides NixOS-compatible configurations for all MCP servers:

- Proper browser packages for Playwright
- Environment variable management
- Service integration through Home Manager
- Automatic configuration deployment

### Common Commands

Ask Claude naturally:
- "Search for NixOS packages related to X"
- "Create a Jira ticket for Y"
- "Send a WhatsApp message to Z"
- "Find Obsidian notes about A"
- "Analyze LinkedIn profile for B"

### Troubleshooting

**Connection Issues:**
- Verify MCP server is running
- Check authentication credentials
- Confirm network accessibility
- Review configuration files

**Authentication Failures:**
- Regenerate API tokens
- Update credentials in configuration
- Verify OAuth permissions
- Check token expiration

**Service Not Available:**
- Confirm MCP server installed
- Check service status
- Review logs for errors
- Verify dependencies installed

## Available Hosts

MCP servers are configured on:
- **P620**: Full MCP suite (primary workstation)
- **Razer**: Full MCP suite (laptop)
- **Samsung**: WhatsApp, core servers (laptop)
- **P510**: Core servers only (media server)

## Additional Resources

- MCP Protocol Specification: https://modelcontextprotocol.io
- Anthropic MCP Documentation: https://docs.anthropic.com/mcp
- Claude Desktop: https://claude.ai/desktop
- Claude Code: https://claude.ai/code
