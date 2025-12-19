# LinkedIn MCP Server Documentation

> **LinkedIn Professional Networking Integration for Claude Desktop and Claude Code**

## Overview

The LinkedIn MCP (Model Context Protocol) server enables Claude to directly access
LinkedIn data for professional networking tasks including:

- **Profile Analysis**: Extract detailed profile information, work history, and skills
- **Company Research**: Retrieve comprehensive company information
- **Job Search**: Find jobs with keyword and location filters
- **Job Recommendations**: Get personalized job suggestions based on profile
- **Job Details**: Fetch specific job posting information

**Repository**: [stickerdaniel/linkedin-mcp-server](https://github.com/stickerdaniel/linkedin-mcp-server)

## Architecture

### Implementation Method

The LinkedIn MCP server is deployed using **native uvx** (pragmatic approach):

- **Package Manager**: `uvx` (uv's command execution tool)
- **Distribution**: Official `linkedin-mcp-server` from GitHub
- **Dependencies**: Automatically managed by uv (102 Python packages)
- **Authentication**: Uses LinkedIn `li_at` cookie for session management
- **Performance**: First run ~15-20s (downloads deps), subsequent runs instant (cached)

### Why uvx Instead of Full Nix Packaging?

This is a **deliberate pragmatic decision** with documented trade-offs:

**Reasons for uvx:**

1. **Complex Dependencies**: Requires 20+ Python packages, many not in nixpkgs
2. **Maintenance Burden**: Full Nix packaging would require maintaining all upstream deps
3. **Rapid Evolution**: MCP ecosystem is new and fast-moving
4. **Proper Caching**: uv caches in `~/.cache/uv` (persistent across reboots)
5. **Deterministic**: `uv.lock` pins exact versions (reproducible builds)
6. **Isolated**: Creates virtual environments (no system pollution)

**Trade-offs Accepted:**

- Network dependency on first run (~15-20 seconds)
- Runtime dependency download (impure but cached)
- Not fully offline (requires internet for initial setup)

This pattern is similar to other nixpkgs packages (VSCode extensions, npm/cargo caches) where full packaging is impractical.

### NixOS Integration

- **Package**: `pkgs/linkedin-mcp/default.nix` - Native wrapper script using uvx
- **Module**: `modules/ai/mcp-servers.nix` - Feature flag and configuration management
- **Claude Desktop**: `home/development/claude-desktop/mcp-config.nix` - Claude Desktop integration
- **Secrets**: Agenix-encrypted cookie stored in `/run/agenix/api-linkedin-cookie`
- **Runtime**: Pure NixOS with uv package manager for Python dependencies

## LinkedIn Cookie Management

### Understanding li_at Cookie

The `li_at` cookie is LinkedIn's authentication cookie:

- **Lifetime**: Approximately 30 days (may vary)
- **Session Limit**: Only one active session per cookie
- **Security**: Treat as a password - never commit to version control
- **Rotation**: Requires periodic refresh when expired

### Cookie Extraction Methods

#### Method 1: Chrome DevTools (Manual)

1. **Login to LinkedIn**:
   - Open Chrome/Chromium browser
   - Navigate to [https://www.linkedin.com](https://www.linkedin.com)
   - Login with your LinkedIn credentials

2. **Open DevTools**:
   - Press `F12` or right-click → "Inspect"
   - Navigate to **Application** tab
   - In left sidebar: **Storage → Cookies → <https://www.linkedin.com>**

3. **Extract Cookie**:
   - Find the cookie named `li_at`
   - Copy the **Value** column (long alphanumeric string)
   - This is your LinkedIn authentication cookie

#### Method 2: Docker Automated Extraction

```bash
# Run LinkedIn MCP server in interactive mode to extract cookie
docker run -it --rm stickerdaniel/linkedin-mcp-server:latest --get-cookie

# Follow the prompts to login via browser
# Cookie will be displayed in terminal
```

### Initial Cookie Setup

After extracting your LinkedIn cookie, create the encrypted secret:

```bash
# Navigate to NixOS configuration directory
cd ~/.config/nixos

# Create new secret for LinkedIn cookie
./scripts/manage-secrets.sh create api-linkedin-cookie

# When prompted, paste your li_at cookie value
# Example: AQEDATXpGbwC1z4mAAABjxN-zW0AAAGPP4tRbU0...
```

The script will:

1. Encrypt the cookie using age encryption
2. Create `secrets/api-linkedin-cookie.age` file
3. Configure access permissions for P620 and Razer hosts

### Cookie Refresh Process

When the LinkedIn cookie expires (~30 days), follow this workflow:

#### Step 1: Extract New Cookie

Use either Method 1 (Chrome DevTools) or Method 2 (Docker) from above to get a fresh `li_at` cookie value.

#### Step 2: Update Encrypted Secret

```bash
# Edit existing secret
./scripts/manage-secrets.sh edit api-linkedin-cookie

# Paste new cookie value when editor opens
# Save and exit editor
```

#### Step 3: Deploy Updated Configuration

```bash
# Deploy to P620
just quick-deploy p620

# Deploy to Razer
just quick-deploy razer

# Or deploy to both in parallel
just deploy-all-parallel
```

#### Step 4: Restart Claude Desktop

After deploying the new cookie:

1. Close Claude Desktop completely
2. Reopen Claude Desktop
3. LinkedIn MCP server will use the new cookie

### Cookie Expiration Symptoms

You'll know the cookie has expired when:

- LinkedIn MCP commands in Claude return authentication errors
- Error messages mention "expired" or "invalid session"
- LinkedIn profile/job queries fail consistently

## Available Tools in Claude

Once configured, Claude has access to these LinkedIn tools:

### `get_person_profile`

Extract detailed profile information:

```text
Get LinkedIn profile for John Smith
Show me the work history for Jane Doe
```

**Returns**: Name, headline, location, work experience, education, skills

### `get_company_profile`

Retrieve company information:

```text
Tell me about Microsoft on LinkedIn
Get company profile for Google
```

**Returns**: Company name, description, industry, size, location, specialties

### `get_job_details`

Fetch specific job posting data:

```text
Get details for job ID 123456789
Show me information about this job posting: linkedin.com/jobs/view/123456789
```

**Returns**: Job title, company, location, description, requirements, applicant count

### `search_jobs`

Find jobs with filters:

```text
Search for "software engineer" jobs in San Francisco
Find remote "data scientist" positions
```

**Parameters**:

- `keywords`: Job search terms
- `location`: Geographic location (optional)
- `remote`: Filter for remote jobs (optional)

**Returns**: List of matching jobs with title, company, location, summary

### `get_recommended_jobs`

Get personalized job recommendations:

```text
Show me recommended jobs based on my LinkedIn profile
What jobs would you recommend for me?
```

**Returns**: Personalized job recommendations based on profile analysis

### `close_session`

Properly terminate browser session:

```text
Close LinkedIn session
End LinkedIn MCP connection
```

**Purpose**: Cleanup browser resources (automatically handled by MCP)

## Configuration Details

### Hosts with LinkedIn MCP Enabled

- **P620** (AMD workstation): Primary development system
- **Razer** (Intel/NVIDIA laptop): Mobile development

Both hosts have LinkedIn MCP configured in their `configuration.nix` files.

### Security Implementation

Following `docs/NIXOS-ANTI-PATTERNS.md` security patterns:

**✅ CORRECT - Runtime Secret Loading**:

```nix
# In modules/ai/mcp-servers.nix
age.secrets."api-linkedin-cookie" = lib.mkIf cfg.linkedin.enable {
  file = ../../secrets/api-linkedin-cookie.age;
  mode = "0400";  # Read-only for owner
  owner = username;
  group = "users";
};

# In home/development/claude-desktop/mcp-config.nix
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
};
```

**❌ WRONG - Evaluation Time (DON'T DO THIS)**:

```nix
# NEVER read secrets during evaluation!
env.LINKEDIN_COOKIE = builtins.readFile "/run/agenix/api-linkedin-cookie";
```

### Docker Requirements

The LinkedIn MCP server requires Docker to be enabled on the host:

```nix
# Typically already configured in host configuration.nix
virtualisation.docker.enable = true;
```

P620 and Razer both have Docker enabled for development purposes.

## Troubleshooting

### Issue: "LINKEDIN_COOKIE_FILE environment variable not set"

**Cause**: Environment variable not passed to wrapper script

**Solution**:

```bash
# Check if secret exists
ls -la /run/agenix/api-linkedin-cookie

# If missing, create the secret
./scripts/manage-secrets.sh create api-linkedin-cookie

# Rebuild system
just quick-deploy p620
```

### Issue: "Cookie file not found" or "Cookie file not readable"

**Cause**: Agenix secret not properly decrypted or permissions incorrect

**Solution**:

```bash
# Check agenix service status
systemctl status agenix

# Verify secret ownership
sudo ls -la /run/agenix/

# Rebuild and restart agenix
just quick-deploy p620
sudo systemctl restart agenix
```

### Issue: LinkedIn authentication errors in Claude

**Cause**: Cookie expired or invalid

**Solution**:

1. Extract fresh cookie (see Cookie Extraction Methods above)
2. Update secret: `./scripts/manage-secrets.sh edit api-linkedin-cookie`
3. Deploy: `just quick-deploy p620`
4. Restart Claude Desktop

### Issue: "Docker container failed to start"

**Cause**: Docker service not running or image not pulled

**Solution**:

```bash
# Check Docker service
systemctl status docker

# Start Docker if stopped
sudo systemctl start docker

# Pull LinkedIn MCP image manually
docker pull stickerdaniel/linkedin-mcp-server:latest

# Test LinkedIn MCP directly
export LINKEDIN_COOKIE_FILE=/run/agenix/api-linkedin-cookie
linkedin-mcp
```

### Issue: Claude Desktop doesn't recognize LinkedIn MCP

**Cause**: Claude Desktop configuration not updated or not restarted

**Solution**:

1. Verify configuration: `cat ~/.config/Claude/claude_desktop_config.json`
2. Check for LinkedIn entry in `mcpServers` section
3. Completely close Claude Desktop (not just minimize)
4. Reopen Claude Desktop
5. Check Claude's developer tools (View → Developer → Developer Tools) for MCP logs

## Terms of Service Considerations

**Important**: LinkedIn's Terms of Service may prohibit automated scraping or data extraction.
This tool is intended for **personal use only** to assist with legitimate professional networking activities.

**Recommendations**:

- Review [LinkedIn's User Agreement](https://www.linkedin.com/legal/user-agreement)
- Use responsibly and within rate limits
- Only access your own profile data and public information
- Do not use for bulk data collection or commercial purposes
- Respect LinkedIn's robots.txt and API policies

## Privacy & Security

### Cookie Security Best Practices

1. **Never share your li_at cookie** - Treat it as a password
2. **Use agenix encryption** - Never store cookies in plaintext
3. **Regular rotation** - Refresh cookie every 30 days
4. **Access control** - Cookie only accessible on P620 and Razer
5. **Audit access** - Monitor LinkedIn account for unusual activity

### Data Handling

- LinkedIn data accessed via MCP is processed locally on your machine
- No data is sent to third parties (except LinkedIn's servers)
- Docker container runs in isolated, read-only environment
- All capabilities dropped for security hardening

## Maintenance Schedule

### Monthly Tasks (Every ~30 Days)

1. **Check cookie expiration**: Test LinkedIn MCP in Claude
2. **Rotate cookie if needed**: Extract and update secret
3. **Deploy updates**: Rebuild NixOS configuration
4. **Verify functionality**: Test LinkedIn queries in Claude

### As Needed

- **Update Docker image**: Pull latest LinkedIn MCP server image
- **Review LinkedIn ToS**: Stay informed about policy changes
- **Monitor logs**: Check for authentication or rate limit issues

## Reference Links

- **GitHub Repository**: <https://github.com/stickerdaniel/linkedin-mcp-server>
- **Model Context Protocol**: <https://modelcontextprotocol.io/>
- **MCP-NixOS Documentation**: <https://mcp-nixos.io>
- **LinkedIn Developer Resources**: <https://developer.linkedin.com/>
- **Agenix Documentation**: <https://github.com/ryantm/agenix>

## Support

For issues related to:

- **LinkedIn MCP server**: Open issue on [stickerdaniel/linkedin-mcp-server](https://github.com/stickerdaniel/linkedin-mcp-server)
- **NixOS configuration**: Check `docs/PATTERNS.md` and `docs/NIXOS-ANTI-PATTERNS.md`
- **Cookie extraction**: Follow methods above or consult LinkedIn MCP server documentation
- **Claude Desktop integration**: Verify configuration in `~/.config/Claude/claude_desktop_config.json`

---

**Last Updated**: 2025-01-19
**NixOS Version**: 25.11 (nixos-unstable)
**LinkedIn MCP Server**: Docker (stickerdaniel/linkedin-mcp-server:latest)
