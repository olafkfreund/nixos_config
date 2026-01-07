# Atlassian MCP Server Integration

> **Complete Guide to Jira and Confluence AI Integration**
> Last Updated: 2026-01-07
> Status: Production Ready

## Overview

The Atlassian MCP (Model Context Protocol) server enables AI-assisted interaction with **Jira** and **Confluence** through natural language commands. This integration supports both **cloud** and **self-hosted** Atlassian instances, providing comprehensive project management and documentation capabilities.

### What You Can Do

**Jira Capabilities:**

- 🔍 **Natural Language Search**: "Find all critical bugs assigned to me"
- 📝 **Issue Management**: Create, update, and transition issues
- 🎯 **JQL Queries**: Advanced filtering with Jira Query Language
- 🔄 **Workflow Automation**: Automate issue transitions and updates
- 📊 **Project Insights**: Query project status and metrics

**Confluence Capabilities:**

- 📚 **Documentation Search**: "Find API documentation in the tech space"
- ✏️ **Content Creation**: Create and update pages
- 💬 **Comment Management**: Add and manage page comments
- 🔎 **CQL Queries**: Advanced Confluence Query Language searches
- 📖 **Knowledge Discovery**: Navigate and explore content

### Repository

**MCP Atlassian Server**: <https://github.com/sooperset/mcp-atlassian>

---

## Quick Start (Cloud Mode)

### Prerequisites

1. **Atlassian Cloud Account** with Jira and/or Confluence access
2. **API Token** from <https://id.atlassian.com/manage-profile/security/api-tokens>
3. **NixOS System** with MCP servers enabled

### 5-Minute Setup

```nix
# 1. Add to your host configuration (e.g., hosts/p620/configuration.nix)
features.ai.mcp = {
  enable = true;

  atlassian = {
    enable = true;
    mode = "cloud";  # or "self-hosted"

    jira = {
      enable = true;
      url = "https://your-domain.atlassian.net";
      username = "your-email@example.com";
      tokenFile = config.age.secrets."api-jira-token".path;
    };

    confluence = {
      enable = true;
      url = "https://your-domain.atlassian.net/wiki";
      username = "your-email@example.com";
      tokenFile = config.age.secrets."api-confluence-token".path;
    };
  };
};
```

```bash
# 2. Create and encrypt your API token
echo "your-api-token-here" > /tmp/jira-token.txt
agenix -e secrets/api-jira-token.age
# Paste token, save, exit
rm /tmp/jira-token.txt

# 3. Deploy configuration
just quick-deploy p620

# 4. Start using in Claude
# "Find all issues assigned to me in the PROJ project"
```

---

## Detailed Configuration

### Cloud Mode Setup

**Use Case**: Atlassian Cloud (yourDomain.atlassian.net)

#### Step 1: Generate API Token

1. Visit: <https://id.atlassian.com/manage-profile/security/api-tokens>
2. Click "Create API token"
3. Name it: "NixOS MCP Server" (or similar)
4. Copy the generated token

**Important**: You can use the **same token** for both Jira and Confluence, or create separate tokens for each.

#### Step 2: Configure Host

Add to your host configuration (`hosts/p620/configuration.nix` or similar):

```nix
{ config, ... }:
{
  # Enable MCP servers
  features.ai.mcp = {
    enable = true;

    atlassian = {
      enable = true;
      mode = "cloud";

      # Jira configuration
      jira = {
        enable = true;
        url = "https://your-domain.atlassian.net";
        username = "your-email@example.com";
        tokenFile = config.age.secrets."api-jira-token".path;
      };

      # Confluence configuration
      confluence = {
        enable = true;
        url = "https://your-domain.atlassian.net/wiki";
        username = "your-email@example.com";
        # Can use same token as Jira or different token
        tokenFile = config.age.secrets."api-confluence-token".path;
      };
    };
  };
}
```

#### Step 3: Encrypt Secrets

```bash
# Encrypt Jira token
echo "your-jira-api-token" > /tmp/jira-token.txt
agenix -e secrets/api-jira-token.age
# Paste token, save and exit
rm /tmp/jira-token.txt

# If using separate Confluence token
echo "your-confluence-api-token" > /tmp/confluence-token.txt
agenix -e secrets/api-confluence-token.age
# Paste token, save and exit
rm /tmp/confluence-token.txt
```

#### Step 4: Deploy

```bash
# Test configuration
just validate

# Deploy to host
just quick-deploy p620
```

---

### Self-Hosted Mode Setup

**Use Case**: Self-hosted Jira Server (v8.14+) or Confluence Server (v6.0+)

#### Step 1: Generate Personal Access Tokens (PAT)

**For Jira**:

1. Log in to your Jira instance
2. Go to: Profile → Personal Access Tokens
3. Create token with appropriate permissions
4. Copy the generated PAT

**For Confluence**:

1. Log in to your Confluence instance
2. Go to: Profile → Personal Access Tokens
3. Create token with appropriate permissions
4. Copy the generated PAT

#### Step 2: Configure Host

```nix
{ config, ... }:
{
  features.ai.mcp = {
    enable = true;

    atlassian = {
      enable = true;
      mode = "self-hosted";

      # Jira configuration (self-hosted)
      jira = {
        enable = true;
        url = "https://jira.your-company.com";
        patFile = config.age.secrets."api-jira-pat".path;
      };

      # Confluence configuration (self-hosted)
      confluence = {
        enable = true;
        url = "https://confluence.your-company.com";
        patFile = config.age.secrets."api-confluence-pat".path;
      };
    };
  };
}
```

#### Step 3: Encrypt PATs

```bash
# Encrypt Jira PAT
echo "your-jira-pat-here" > /tmp/jira-pat.txt
agenix -e secrets/api-jira-pat.age
# Paste PAT, save and exit
rm /tmp/jira-pat.txt

# Encrypt Confluence PAT
echo "your-confluence-pat-here" > /tmp/confluence-pat.txt
agenix -e secrets/api-confluence-pat.age
# Paste PAT, save and exit
rm /tmp/confluence-pat.txt
```

#### Step 4: Deploy

```bash
just validate
just quick-deploy p620
```

---

## Configuration Options

### Jira-Only Setup

If you only want Jira integration:

```nix
features.ai.mcp.atlassian = {
  enable = true;
  mode = "cloud";

  jira = {
    enable = true;
    url = "https://your-domain.atlassian.net";
    username = "your-email@example.com";
    tokenFile = config.age.secrets."api-jira-token".path;
  };

  # Confluence disabled
  confluence.enable = false;
};
```

### Confluence-Only Setup

If you only want Confluence integration:

```nix
features.ai.mcp.atlassian = {
  enable = true;
  mode = "cloud";

  # Jira disabled
  jira.enable = false;

  confluence = {
    enable = true;
    url = "https://your-domain.atlassian.net/wiki";
    username = "your-email@example.com";
    tokenFile = config.age.secrets."api-confluence-token".path;
  };
};
```

---

## Usage Examples

### Jira Interactions

**Search for Issues:**

```
"Find all issues assigned to me"
"Show critical bugs in the BACKEND project"
"List issues in sprint 'Sprint 42' that are in progress"
"Find all unresolved issues with label 'security'"
```

**Create Issues:**

```
"Create a bug ticket: Login fails with OAuth"
"Create a story in PROJECT-123: Add dark mode support"
"Create a task to update documentation in DOCS project"
```

**Update Issues:**

```
"Update issue PROJ-456 status to In Progress"
"Add comment to PROJ-789: This is fixed in PR #123"
"Assign issue PROJ-111 to john.doe@example.com"
"Change priority of PROJ-222 to High"
```

**Advanced JQL Queries:**

```
"Search Jira: project = PROJ AND status != Done ORDER BY priority DESC"
"Find issues: assignee = currentUser() AND duedate < now()"
"Show: sprint in openSprints() AND type = Bug"
```

### Confluence Interactions

**Search Documentation:**

```
"Find pages about API authentication in the Tech space"
"Search Confluence for pages containing 'deployment process'"
"Show recent pages in the PROJ space"
```

**Create and Update Content:**

```
"Create a Confluence page titled 'New Feature Design' in the DESIGN space"
"Update page 12345 with the new architecture diagram"
"Add a comment to page 'API Documentation': Needs updating for v2.0"
```

**Advanced CQL Queries:**

```
"Search Confluence: type = page AND space = TECH ORDER BY lastmodified DESC"
"Find: label = 'api' AND creator = currentUser()"
```

---

## Environment Variables (Advanced)

The following environment variables are automatically configured based on your NixOS settings:

**Cloud Mode:**

```bash
ATLASSIAN_MODE=cloud
JIRA_URL=https://your-domain.atlassian.net
JIRA_USERNAME=your-email@example.com
JIRA_TOKEN_FILE=/run/agenix/api-jira-token
CONFLUENCE_URL=https://your-domain.atlassian.net/wiki
CONFLUENCE_USERNAME=your-email@example.com
CONFLUENCE_TOKEN_FILE=/run/agenix/api-confluence-token
```

**Self-Hosted Mode:**

```bash
ATLASSIAN_MODE=self-hosted
JIRA_URL=https://jira.your-company.com
JIRA_PAT_FILE=/run/agenix/api-jira-pat
CONFLUENCE_URL=https://confluence.your-company.com
CONFLUENCE_PAT_FILE=/run/agenix/api-confluence-pat
```

---

## Troubleshooting

### Issue: "JIRA_TOKEN_FILE environment variable not set"

**Solution**: Ensure your host configuration includes:

```nix
features.ai.mcp.atlassian.jira.tokenFile = config.age.secrets."api-jira-token".path;
```

And the secret is encrypted:

```bash
agenix -e secrets/api-jira-token.age
```

### Issue: "Token file not found"

**Solution**: Rebuild your system to decrypt secrets:

```bash
just quick-deploy p620
```

The secret will be available at `/run/agenix/api-jira-token` after deployment.

### Issue: "API authentication failed"

**Possible Causes**:

1. **Expired Token**: Cloud API tokens don't expire, but PATs for self-hosted might
2. **Wrong Credentials**: Verify username matches the token owner
3. **Insufficient Permissions**: Ensure token has proper project/space access

**Solution**:

```bash
# Regenerate token and re-encrypt
agenix -e secrets/api-jira-token.age
just quick-deploy p620
```

### Issue: "Module not found: uvx"

**Solution**: Ensure your NixOS configuration includes:

```nix
environment.systemPackages = with pkgs; [
  python3Packages.uvx
];
```

This is automatically included when `features.ai.mcp.atlassian.enable = true`.

### Test MCP Server Manually

```bash
# Set environment variables
export ATLASSIAN_MODE=cloud
export JIRA_URL=https://your-domain.atlassian.net
export JIRA_USERNAME=your-email@example.com
export JIRA_TOKEN_FILE=/run/agenix/api-jira-token

# Run MCP server
atlassian-mcp
```

Expected output: Server should start without errors.

---

## Security Notes

### ✅ Security Best Practices Implemented

1. **Runtime Secret Loading**: Tokens loaded at runtime, never in Nix store
2. **File Permissions**: Secrets mode 0400 (read-only by owner)
3. **Encryption**: All secrets encrypted with agenix
4. **Access Control**: Secrets only accessible on configured workstations

### ⚠️ Important Security Warnings

**NEVER**:

- Commit plain-text tokens to git
- Use `builtins.readFile` for secrets (evaluation-time reading)
- Set tokens directly in configuration.nix
- Share encrypted `.age` files without understanding access control

**ALWAYS**:

- Use `tokenFile` or `patFile` options (runtime loading)
- Encrypt secrets with agenix before committing
- Rotate tokens periodically
- Use minimum required permissions for tokens

### Token Rotation

```bash
# 1. Generate new token from Atlassian
# 2. Update encrypted secret
agenix -e secrets/api-jira-token.age

# 3. Redeploy
just quick-deploy p620

# 4. Old token can be revoked from Atlassian
```

---

## Requirements

- **Jira**: v8.14 or higher (self-hosted), or Atlassian Cloud
- **Confluence**: v6.0 or higher (self-hosted), or Atlassian Cloud
- **Python**: 3.12+ (automatically provided by NixOS)
- **Network**: Access to Atlassian instance (cloud or self-hosted)

---

## References

- **MCP Atlassian Repository**: <https://github.com/sooperset/mcp-atlassian>
- **Model Context Protocol**: <https://modelcontextprotocol.io/>
- **Atlassian API Tokens**: <https://id.atlassian.com/manage-profile/security/api-tokens>
- **Jira REST API**: <https://developer.atlassian.com/cloud/jira/platform/rest/v3/>
- **Confluence REST API**: <https://developer.atlassian.com/cloud/confluence/rest/v1/>

---

## Next Steps

1. ✅ Configure Atlassian MCP (see Quick Start above)
2. 📚 Read [MCP-SERVERS.md](./MCP-SERVERS.md) for complete MCP overview
3. 🔧 Explore [PATTERNS.md](./PATTERNS.md) for NixOS best practices
4. 🚀 Start using Jira and Confluence through AI natural language

**Happy coding with AI-assisted project management!** 🎉
