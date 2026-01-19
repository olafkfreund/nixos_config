# NixOS Secrets Management

Comprehensive secrets management using Agenix for encrypted configuration secrets.

**Replaces Justfile recipes**: `secrets`, `secrets-status`, `test-secrets`, `test-all-secrets`, `secrets-status-host`, `fix-agenix-remote`

## Quick Usage

**Interactive management**:

```
/nix-secrets
Manage secrets
```

**Check status**:

```
/nix-secrets
Status
```

**Create new secret**:

```
/nix-secrets
Create api-openai
```

**Edit existing secret**:

```
/nix-secrets
Edit api-openai
```

## Features

### Secret Management Operations

**Manage** (interactive):

- ✅ Guided secret management interface
- ✅ Choose from all available operations
- ✅ Safe and user-friendly prompts
- ✅ Runs manage-secrets.sh script

**Status** (5 seconds):

- ✅ Check secrets.nix configuration exists
- ✅ Count encrypted secret files
- ✅ Show current secret definitions
- ✅ Verify agenix availability
- ✅ Check runtime secret access

**Create** (~30 seconds):

- ✅ Create new encrypted secret file
- ✅ Opens $EDITOR for secret content
- ✅ Encrypts with configured keys
- ✅ Validates secret name format
- ✅ Prevents duplicate secrets

**Edit** (~30 seconds):

- ✅ Edit existing encrypted secret
- ✅ Decrypts, opens editor, re-encrypts
- ✅ Maintains encryption keys
- ✅ Validates secret exists

**List** (instant):

- ✅ Shows all secret files
- ✅ Displays secret paths
- ✅ Sorted alphabetically
- ✅ Includes secret count

**Rekey** (~1 minute):

- ✅ Re-encrypt all secrets with new keys
- ✅ Updates encryption for key changes
- ✅ Validates all secrets successfully rekeyed
- ✅ Shows progress for each secret

**Initialize** (~30 seconds):

- ✅ Set up secrets management infrastructure
- ✅ Creates secrets/ directory
- ✅ Creates secrets.nix template
- ✅ Updates .gitignore
- ✅ Provides next steps guidance

### Testing & Validation

**Test Secrets** (~10 seconds):

- ✅ Verify secrets decrypt correctly
- ✅ Check runtime secret access (/run/agenix/)
- ✅ Validate agenix service status
- ✅ Test specific secret file
- ✅ Test all secrets comprehensively

**Test on Remote Host** (~5 seconds):

- ✅ Check secrets on remote systems
- ✅ Verify agenix service running
- ✅ Validate /run/agenix/ directory
- ✅ SSH to host and check status

### Remote Operations

**Fix Remote Agenix** (~10 seconds):

- ✅ Repair agenix issues on remote hosts
- ✅ Stop and restart agenix service
- ✅ Clean up stale runtime directories
- ✅ Verify service health after fix
- ✅ Shows detailed status output

## Secrets Management Workflow

### Initial Setup

```bash
# 1. Initialize secrets management
/nix-secrets
Initialize

# 2. Get SSH public keys for configuration
./scripts/get-keys.sh

# 3. Edit secrets.nix with real keys
vim secrets.nix

# 4. Check everything is ready
/nix-secrets
Status
```

### Creating Secrets

```bash
# 1. Create a new secret
/nix-secrets
Create api-openai

# Editor opens, enter your secret value:
# sk-proj-abc123...

# 2. Verify it was created
/nix-secrets
List

# 3. Test the secret decrypts
/nix-secrets
Test api-openai
```

### Editing Secrets

```bash
# 1. Edit existing secret
/nix-secrets
Edit api-openai

# 2. Make changes in editor

# 3. Verify changes work
/nix-secrets
Test api-openai
```

### Managing Keys

```bash
# 1. Update keys in secrets.nix
vim secrets.nix
# Add/remove host or user public keys

# 2. Rekey all secrets with new configuration
/nix-secrets
Rekey

# 3. Verify all secrets still work
/nix-secrets
Test all secrets
```

### Remote Host Management

```bash
# 1. Check secrets on remote host
/nix-secrets
Check p620

# 2. If issues, fix agenix service
/nix-secrets
Fix agenix on p620

# 3. Verify it's working
/nix-secrets
Check p620
```

## Output Format

### Status Output

```
🔑 NixOS Secrets Management Status

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Configuration
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ secrets.nix configuration found
📁 Found 12 secret files

Current secret definitions:
  "secrets/api-anthropic.age"
  "secrets/api-gemini.age"
  "secrets/api-openai.age"
  "secrets/user-password-olafkfreund.age"
  "secrets/github-token.age"
  "secrets/wifi-password.age"
  "secrets/docker-auth.age"
  "secrets/postgres-password.age"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Agenix Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ agenix command available
✅ agenix service running
✅ Runtime secrets accessible at /run/agenix/

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Next Steps
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Create secret: /nix-secrets Create SECRET_NAME
• Edit secret: /nix-secrets Edit SECRET_NAME
• Test secrets: /nix-secrets Test all secrets
```

### Create Secret Output

```
🔐 Creating New Secret: api-openai

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Configuration
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Secret Name:    secrets/api-openai.age
Encryption:     Age with SSH keys
Access:         Users + Hosts configured in secrets.nix

📝 Opening editor for secret content...
[Editor opens]

✅ Secret Created Successfully
File: secrets/api-openai.age

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Next Steps
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Add to configuration:
   age.secrets."api-openai" = {
     file = ../secrets/api-openai.age;
     mode = "0400";
     owner = "myuser";
   };

2. Reference in services:
   apiKeyFile = config.age.secrets."api-openai".path;

3. Test decryption: /nix-secrets Test api-openai
4. Deploy configuration: /nix-deploy
```

### Test Secrets Output

```
🧪 Testing Secrets Decryption

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Testing Individual Secrets
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ api-anthropic.age - Decrypts successfully
✅ api-gemini.age - Decrypts successfully
✅ api-openai.age - Decrypts successfully
✅ user-password-olafkfreund.age - Decrypts successfully
✅ github-token.age - Decrypts successfully
✅ wifi-password.age - Decrypts successfully
✅ docker-auth.age - Decrypts successfully
✅ postgres-password.age - Decrypts successfully

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Runtime Access Verification
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Checking /run/agenix/ directory:
✅ api-anthropic → /run/agenix.d/1/api-anthropic
✅ api-gemini → /run/agenix.d/1/api-gemini
✅ api-openai → /run/agenix.d/1/api-openai
✅ user-password-olafkfreund → /run/agenix.d/1/user-password-olafkfreund

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ All Secrets Test Passed
Total: 8/8 secrets verified
Time: 3 seconds
```

### Rekey Output

```
🔄 Rekeying All Secrets

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Secrets to Rekey
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

secrets/api-anthropic.age
secrets/api-gemini.age
secrets/api-openai.age
secrets/user-password-olafkfreund.age
secrets/github-token.age
secrets/wifi-password.age
secrets/docker-auth.age
secrets/postgres-password.age

🔐 Rekeying with current key configuration...

✅ api-anthropic.age rekeyed
✅ api-gemini.age rekeyed
✅ api-openai.age rekeyed
✅ user-password-olafkfreund.age rekeyed
✅ github-token.age rekeyed
✅ wifi-password.age rekeyed
✅ docker-auth.age rekeyed
✅ postgres-password.age rekeyed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Rekey Complete
Total: 8 secrets rekeyed successfully
Time: 45 seconds

All secrets now encrypted with updated key configuration.
```

### Remote Host Check Output

```
🔍 Checking Secrets on Remote Host: p620

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Agenix Directory Check
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/run/agenix/ directory:
lrwxrwxrwx 1 root root 18 Jan 15 10:23 /run/agenix -> /run/agenix.d/1

Active secrets:
-r-------- 1 root root 51 Jan 15 10:23 api-anthropic
-r-------- 1 root root 39 Jan 15 10:23 api-gemini
-r-------- 1 root root 51 Jan 15 10:23 api-openai
-r-------- 1 olafkfreund users 60 Jan 15 10:23 user-password-olafkfreund

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Agenix Service Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

● agenix.service - Agenix secret decryption
     Loaded: loaded
     Active: active (exited) since Mon 2025-01-15 10:23:15 UTC
   Main PID: 1234 (code=exited, status=0/SUCCESS)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Remote Host Secrets Healthy
Host: p620
Secrets: 4 accessible
Service: Running
```

## Implementation Details

### Status Command

```bash
# Check configuration
ls -la secrets.nix
find secrets/ -name "*.age" | wc -l

# Check agenix
command -v agenix
systemctl status agenix

# Check runtime access
ls -la /run/agenix/
```

### Create/Edit Commands

```bash
# Create new secret
./scripts/manage-secrets.sh create SECRET_NAME
# Opens $EDITOR with agenix

# Edit existing secret
./scripts/manage-secrets.sh edit SECRET_NAME
# Decrypts, opens $EDITOR, re-encrypts
```

### Test Commands

```bash
# Test single secret
age -d -i ~/.ssh/id_ed25519 secrets/api-openai.age > /dev/null
echo "Status: $?"

# Test all secrets
for secret in secrets/*.age; do
  age -d -i ~/.ssh/id_ed25519 "$secret" > /dev/null
done

# Test runtime access
ls -la /run/agenix/
cat /run/agenix/api-openai > /dev/null
```

### Remote Commands

```bash
# Check remote host
ssh p620 "sudo ls -la /run/agenix/"
ssh p620 "sudo systemctl status agenix --no-pager"

# Fix agenix on remote
ssh p620 "sudo systemctl stop agenix"
ssh p620 "sudo rm -rf /run/agenix.d"
ssh p620 "sudo systemctl start agenix"
ssh p620 "sudo systemctl status agenix --no-pager"
```

## Secret Configuration Pattern

### secrets.nix Structure

```nix
let
  # User public keys
  olafkfreund = "ssh-ed25519 AAAAC3... olafkfreund@nixos";

  # Host public keys
  p620 = "ssh-ed25519 AAAAC3... root@p620";
  razer = "ssh-ed25519 AAAAC3... root@razer";
  p510 = "ssh-ed25519 AAAAC3... root@p510";
  samsung = "ssh-ed25519 AAAAC3... root@samsung";

  # Key groups
  allUsers = [ olafkfreund ];
  allHosts = [ p620 razer p510 samsung ];
  workstations = [ p620 razer ];
  servers = [ p510 ];
in
{
  # Define which keys can decrypt which secrets
  "secrets/api-openai.age".publicKeys = allUsers ++ workstations;
  "secrets/user-password-olafkfreund.age".publicKeys = allUsers ++ allHosts;
  "secrets/postgres-password.age".publicKeys = allUsers ++ servers;
}
```

### Using Secrets in Configuration

```nix
# In your NixOS configuration
{ config, ... }:
{
  # Declare the secret
  age.secrets."api-openai" = {
    file = ../secrets/api-openai.age;
    mode = "0400";
    owner = "myservice";
    group = "myservice";
  };

  # Reference it at runtime
  services.myservice = {
    enable = true;
    apiKeyFile = config.age.secrets."api-openai".path;
  };
}
```

## Secret Naming Conventions

### Standard Patterns

- **User Passwords**: `user-password-USERNAME.age`
- **API Keys**: `api-PROVIDER.age` (e.g., api-openai.age)
- **Service Credentials**: `SERVICE-TYPE.age` (e.g., postgres-password.age)
- **Tokens**: `SERVICE-token.age` (e.g., github-token.age)
- **Certificates**: `SERVICE-cert.age` or `SERVICE-key.age`

### Examples

```bash
# User credentials
user-password-olafkfreund.age
user-ssh-key-olafkfreund.age

# API keys and tokens
api-anthropic.age
api-openai.age
api-gemini.age
github-token.age
cloudflare-token.age

# Service credentials
postgres-password.age
docker-auth.age
wifi-password.age
vpn-credentials.age

# Certificates
ssl-cert.age
ssl-key.age
ca-bundle.age
```

## Best Practices

### DO ✅

- Use descriptive secret names following conventions
- Store secrets in `secrets/` directory only
- Always test secrets after creation/editing
- Rekey secrets when changing access keys
- Keep secrets.nix in version control (contains public keys only)
- Use age.secrets.SECRET.path for runtime references
- Set appropriate owner/group/mode for secrets
- Test secrets before deploying configuration

### DON'T ❌

- Store plaintext secrets anywhere in the repository
- Commit `.age` files to version control (they're in .gitignore)
- Share private SSH keys used for decryption
- Use evaluation-time secret reading (builtins.readFile)
- Set overly permissive modes (use 0400 or 0440)
- Skip testing after rekeying
- Use secrets directly in Nix expressions
- Forget to update secrets.nix when adding/removing hosts

## Troubleshooting

### Secret Won't Decrypt

```bash
# Check if secret exists
/nix-secrets
List

# Check your SSH key
cat ~/.ssh/id_ed25519.pub

# Verify it's in secrets.nix
cat secrets.nix | grep "$(cat ~/.ssh/id_ed25519.pub)"

# Try manual decryption
age -d -i ~/.ssh/id_ed25519 secrets/api-openai.age
```

### Agenix Service Failing

```bash
# Check service status
systemctl status agenix

# Check logs
journalctl -u agenix -f

# Fix on remote host
/nix-secrets
Fix agenix on p620
```

### Can't Edit Secret

```bash
# Verify secret exists
/nix-secrets
List

# Check file permissions
ls -la secrets/

# Verify your key has access
cat secrets.nix
```

### Rekey Fails

```bash
# Verify all keys are valid
./scripts/get-keys.sh

# Check secrets.nix syntax
nix-instantiate --eval secrets.nix

# Try individual secret
./scripts/manage-secrets.sh edit SECRET_NAME
```

## Integration with Other Commands

### With Deployment

```bash
# Create/update secret
/nix-secrets
Create api-openai

# Add to configuration
# (edit configuration.nix to reference secret)

# Test configuration
/nix-validate

# Deploy with new secret
/nix-deploy
Deploy to p620
```

### With Testing

```bash
# Test secrets before deployment
/nix-secrets
Test all secrets

# Run full validation
/nix-validate
Full validation

# Test specific host
/nix-test p620
```

### With Module Development

```bash
# Create secret for new service
/nix-secrets
Create postgres-password

# Create module using secret
/nix-module
Create database/postgres module

# Test module with secret
/nix-test p620
```

## Related Commands

- `/nix-validate` - Validate configuration including secret references
- `/nix-deploy` - Deploy configuration with secrets
- `/nix-test` - Test builds including secret access
- `/nix-security` - Audit secret management security

---

**Pro Tip**: Always test secrets on all hosts after rekeying:

```bash
# Rekey all secrets
/nix-secrets
Rekey

# Test on each host
/nix-secrets
Check p620

/nix-secrets
Check razer

/nix-secrets
Check p510
```

Keep your secrets secure and properly encrypted! 🔐
