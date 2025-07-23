# Gmail OAuth2 Setup Guide

This guide walks through setting up OAuth2 authentication for Gmail accounts in NeoMutt.

## Prerequisites

- Google Cloud Console access
- Both Gmail accounts: olaf@freundcloud.com and olaf.loken@gmail.com
- Access to the NixOS configuration

## Step 1: Google Cloud Console Setup

### 1.1 Create/Select Project
1. Visit [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Note the project ID for reference

### 1.2 Enable Gmail API
1. Go to **APIs & Services** → **Library**
2. Search for "Gmail API"
3. Click **Enable**

### 1.3 Create OAuth2 Credentials
1. Go to **APIs & Services** → **Credentials**
2. Click **+ CREATE CREDENTIALS** → **OAuth client ID**
3. Choose **Desktop application** as application type
4. Name it "NeoMutt Gmail Integration"
5. Download the JSON file with credentials

### 1.4 Configure OAuth Consent Screen
1. Go to **APIs & Services** → **OAuth consent screen**
2. Choose **External** user type
3. Fill in required fields:
   - App name: "NeoMutt Gmail"
   - User support email: your email
   - Developer contact: your email
4. Add scopes: `https://mail.google.com/`
5. Add test users: both Gmail accounts

## Step 2: Generate OAuth2 Tokens

### 2.1 Install oauth2ms Tool
The tool is automatically installed when email OAuth2 is enabled.

### 2.2 Extract Client Credentials
From the downloaded JSON file, extract:
- `client_id`: Long string ending in `.apps.googleusercontent.com`
- `client_secret`: Random string

### 2.3 Generate Refresh Tokens

For each Gmail account, run:

```bash
# For primary account (olaf@freundcloud.com)
oauth2ms --debug \
  --client-id="YOUR_CLIENT_ID" \
  --client-secret="YOUR_CLIENT_SECRET" \
  --scope="https://mail.google.com/" \
  --email="olaf@freundcloud.com"

# For secondary account (olaf.loken@gmail.com)  
oauth2ms --debug \
  --client-id="YOUR_CLIENT_ID" \
  --client-secret="YOUR_CLIENT_SECRET" \
  --scope="https://mail.google.com/" \
  --email="olaf.loken@gmail.com"
```

### 2.4 Save Refresh Tokens
The command will:
1. Open browser for Google authentication
2. You'll authorize the application
3. Return refresh token - **SAVE THIS SECURELY**

## Step 3: Store Secrets with Agenix

### 3.1 Store Client Secret
```bash
./scripts/manage-secrets.sh create gmail-oauth2-client-secret
# Paste the client_secret from JSON file
```

### 3.2 Store Refresh Tokens
```bash
# Primary account refresh token
./scripts/manage-secrets.sh create gmail-oauth2-refresh-token-primary
# Paste refresh token for olaf@freundcloud.com

# Secondary account refresh token  
./scripts/manage-secrets.sh create gmail-oauth2-refresh-token-secondary
# Paste refresh token for olaf.loken@gmail.com
```

## Step 4: Update Configuration

### 4.1 Set Client ID
Edit `/home/olafkfreund/.config/nixos/modules/email/auth/default.nix`:

```nix
features.email.auth.oauth2.clientCredentials = mkIf (cfg.method == "oauth2") {
  clientId = "YOUR_ACTUAL_CLIENT_ID_HERE";  # Replace with real client ID
  clientSecretFile = "/run/agenix/gmail-oauth2-client-secret";
};
```

### 4.2 Enable OAuth2 in Host Configuration
The OAuth2 method is already enabled by default in the email configuration.

## Step 5: Deploy and Test

### 5.1 Test Configuration
```bash
just test-host p620
```

### 5.2 Deploy Configuration
```bash
just quick-deploy p620
```

### 5.3 Verify OAuth2 Setup
```bash
# Check if OAuth2 setup script is available
ls -la /etc/neomutt/oauth2-setup.sh

# Run setup verification
sudo /etc/neomutt/oauth2-setup.sh

# Check if secrets are accessible
sudo ls -la /run/agenix/gmail-oauth2-*
```

### 5.4 Test Token Refresh
```bash
# Test OAuth2 token refresh service
sudo systemctl start neomutt-oauth2-refresh
sudo systemctl status neomutt-oauth2-refresh

# Check if access tokens are generated
ls -la /tmp/neomutt-oauth2-access-token-*
```

## Troubleshooting

### Common Issues

**Error: "invalid_client"**
- Verify client_id and client_secret are correct
- Check that Desktop application type was selected

**Error: "access_denied"**  
- Ensure Gmail accounts are added as test users in OAuth consent screen
- Check that Gmail API is enabled

**Error: "invalid_scope"**
- Verify scope is exactly: `https://mail.google.com/`

**Refresh token expires**
- Google may expire refresh tokens if unused for 6 months
- Re-run oauth2ms to generate new refresh token

### Debug Commands

```bash
# Check OAuth2 service logs
journalctl -u neomutt-oauth2-refresh -f

# Manual token refresh test
sudo /etc/neomutt/oauth2-refresh.sh "olaf@freundcloud.com" \
  "/run/agenix/gmail-oauth2-refresh-token-primary" \
  "/tmp/test-access-token"

# Verify token works with Gmail API
curl -H "Authorization: Bearer $(cat /tmp/test-access-token)" \
  "https://gmail.googleapis.com/gmail/v1/users/me/profile"
```

## Security Notes

- Refresh tokens are stored encrypted with agenix
- Access tokens are temporary (1 hour expiry) and stored in /tmp
- OAuth2 tokens auto-refresh every 30 minutes
- Client secret is encrypted and never stored in plaintext

## Next Steps

After OAuth2 is working:
1. Configure mbsync for email synchronization  
2. Set up NeoMutt account configurations
3. Test email sending/receiving
4. Configure AI email processing