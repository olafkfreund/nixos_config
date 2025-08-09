# 🔐 Secrets Management Guide

This guide covers the complete secrets management system using Agenix for secure, declarative secret handling across multiple hosts and users.

## 📋 Table of Contents

- [Overview](#overview)
- [Initial Setup](#initial-setup)
- [Adding New Users](#adding-new-users)
- [Managing Secrets](#managing-secrets)
- [Host Management](#host-management)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)

## 🔍 Overview

Our secrets management system provides:

- **Encrypted Storage**: All secrets encrypted with age encryption
- **Multi-Host Support**: Secrets accessible across designated hosts
- **Multi-User Access**: Role-based access to relevant secrets
- **Declarative Configuration**: Infrastructure-as-code approach to secret management
- **Audit Trail**: Complete logging of secret access

### Architecture

```
secrets.nix (key definitions)
├── secrets/
│   ├── user-password-<username>.age
│   ├── service-api-keys.age
│   ├── ssh-host-keys.age
│   └── database-credentials.age
└── modules/security/secrets.nix (NixOS integration)
```

## 🚀 Initial Setup

### 1. Initialize Secrets Management

```bash
# Run the initialization script
./scripts/manage-secrets.sh init

# This creates:
# - secrets/ directory
# - secrets.nix template
# - Updates .gitignore
```

### 2. Generate SSH Keys

```bash
# Extract current system SSH keys
./scripts/get-keys.sh

# Output example:
# User public key (olafkfreund):
#   olafkfreund = "ssh-ed25519 AAAAC3Nz... olafkfreund@nixos";
#
# Host public key (p620):
#   p620 = "ssh-ed25519 AAAAC3Nz... root@p620";
```

### 3. Configure Key Definitions

Edit `secrets.nix` with the actual public keys from step 2:

```nix
# secrets.nix
let
  # User public keys - replace with actual keys from get-keys.sh
  olafkfreund = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGm4Cmh2EQaXmEBtKGJ9IKvQGGzLOhQIGHGJDmTrJKpO olafkfreund@nixos";
  newuser = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHm4Cmh2EQaXmEBtKGJ9IKvQGGzLOhQIGHGJDmTrJKpO newuser@nixos";

  # Host public keys - get from each host with get-keys.sh
  p620 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKBm4nKtCHJGHJGHJGHJGHJGHJGHJGHJGHJGHJGHJGJG root@p620";
  razer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILBm4nKtCHJGHJGHJGHJGHJGHJGHJGHJGHJGHJGHJGJG root@razer";
  p510 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMBm4nKtCHJGHJGHJGHJGHJGHJGHJGHJGHJGHJGHJGJG root@p510";
  dex5550 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINBm4nKtCHJGHJGHJGHJGHJGHJGHJGHJGHJGHJGHJGJG root@dex5550";

  # Role-based groups
  allUsers = [ olafkfreund newuser ];
  adminUsers = [ olafkfreund ];
  standardUsers = [ newuser ];

  allHosts = [ p620 razer p510 dex5550 ];
  workstations = [ p620 razer ];
  servers = [ p510 dex5550 ];
in
{
  # User passwords - accessible by user and their designated hosts
  "secrets/user-password-olafkfreund.age".publicKeys = [ olafkfreund ] ++ allHosts;
  "secrets/user-password-newuser.age".publicKeys = [ newuser ] ++ workstations;

  # Admin secrets - only for admin users
  "secrets/root-password.age".publicKeys = adminUsers ++ allHosts;
  "secrets/admin-api-keys.age".publicKeys = adminUsers ++ allHosts;

  # Service secrets - role-based access
  "secrets/docker-registry-auth.age".publicKeys = allUsers ++ allHosts;
  "secrets/github-token.age".publicKeys = allUsers ++ workstations;
  "secrets/database-password.age".publicKeys = adminUsers ++ servers;

  # Host-specific secrets
  "secrets/wifi-password.age".publicKeys = allUsers ++ [ razer ]; # Only laptop
  "secrets/backup-encryption-key.age".publicKeys = adminUsers ++ servers;
}
```

### 4. Enable in NixOS Configuration

Add to each host's `configuration.nix`:

```nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/security/secrets.nix
    # ... other imports
  ];

  # Enable secrets management
  modules.security.secrets = {
    enable = true;
    hostKeys = ["/etc/ssh/ssh_host_ed25519_key"];
    userKeys = ["/home/${vars.username}/.ssh/id_ed25519"];
  };

  # Users automatically get secret-managed passwords if available
  users.users = lib.genAttrs hostUsers (username: {
    isNormalUser = true;
    hashedPasswordFile = lib.mkIf
      (config.modules.security.secrets.enable &&
       builtins.hasAttr "user-password-${username}" config.age.secrets)
      config.age.secrets."user-password-${username}".path;
  });
}
```

### 5. Apply Configuration

```bash
# Rebuild the system to enable secrets management
sudo nixos-rebuild switch --flake .#<hostname>

# The agenix tool is now available system-wide
```

## 👥 Adding New Users

### 1. Generate SSH Keys for New User

```bash
# As the new user, generate SSH keys
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# Extract the public key
cat ~/.ssh/id_ed25519.pub
```

### 2. Update Host User Lists

Add the user to relevant host configurations:

```nix
# hosts/p620/variables.nix
{
  hostUsers = [
    "olafkfreund"
    "newuser"        # Add new user
    "developer"      # Another new user
  ];
  # ... rest of configuration
}
```

### 3. Update Secrets Configuration

Add the new user's public key to `secrets.nix`:

```nix
let
  # Add new user public key
  newuser = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHm4Cmh2EQaXmEBtKGJ9IKvQGGzLOhQIGHGJDmTrJKpO newuser@nixos";

  # Update user groups
  allUsers = [ olafkfreund newuser ];
  standardUsers = [ newuser ];
in
{
  # Add secrets for new user
  "secrets/user-password-newuser.age".publicKeys = [ newuser ] ++ workstations;

  # Update existing secrets if user needs access
  "secrets/docker-registry-auth.age".publicKeys = allUsers ++ allHosts;
}
```

### 4. Create User Secrets

```bash
# Create password for new user
./scripts/manage-secrets.sh create user-password-newuser

# Create any role-specific secrets
./scripts/manage-secrets.sh create api-key-newuser-github
```

### 5. Rekey Existing Secrets

```bash
# Update all secrets with new key access
./scripts/manage-secrets.sh rekey
```

### 6. Apply Changes

```bash
# Rebuild configuration to create user
sudo nixos-rebuild switch --flake .#<hostname>
```

## 🔑 Managing Secrets

### Creating Secrets

```bash
# Create a new secret
./scripts/manage-secrets.sh create secret-name

# Examples:
./scripts/manage-secrets.sh create user-password-developer
./scripts/manage-secrets.sh create api-key-openai
./scripts/manage-secrets.sh create database-backup-key
```

### Editing Secrets

```bash
# Edit existing secret
./scripts/manage-secrets.sh edit secret-name

# Examples:
./scripts/manage-secrets.sh edit user-password-olafkfreund
./scripts/manage-secrets.sh edit github-token
```

### Viewing Secret Status

```bash
# List all available secrets
./scripts/manage-secrets.sh list

# Check system status
./scripts/manage-secrets.sh status
```

### Secret Access Patterns

#### User Passwords

```nix
"secrets/user-password-${username}.age".publicKeys = [ userKey ] ++ relevantHosts;
```

#### Service Credentials

```nix
"secrets/service-${servicename}.age".publicKeys = serviceUsers ++ serviceHosts;
```

#### Admin Secrets

```nix
"secrets/admin-${secretname}.age".publicKeys = adminUsers ++ allHosts;
```

#### Host-Specific Secrets

```nix
"secrets/host-${hostname}-${secretname}.age".publicKeys = adminUsers ++ [ hostKey ];
```

## 🖥️ Host Management

### Adding New Hosts

1. **Generate Host SSH Keys**:

   ```bash
   # On the new host
   sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""

   # Extract public key
   sudo cat /etc/ssh/ssh_host_ed25519_key.pub
   ```

2. **Update secrets.nix**:

   ```nix
   let
     # Add new host key
     newhost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINewHostKey root@newhost";

     # Update host groups
     allHosts = [ p620 razer p510 dex5550 newhost ];
   ```

3. **Create Host Configuration**:

   ```nix
   # hosts/newhost/configuration.nix
   {
     modules.security.secrets = {
       enable = true;
       hostKeys = ["/etc/ssh/ssh_host_ed25519_key"];
       userKeys = ["/home/${vars.username}/.ssh/id_ed25519"];
     };
   }
   ```

4. **Rekey All Secrets**:

   ```bash
   ./scripts/manage-secrets.sh rekey
   ```

### Removing Hosts

1. **Update secrets.nix** (remove host from groups)
2. **Rekey secrets**: `./scripts/manage-secrets.sh rekey`
3. **Remove host configuration files**

## 🔧 Troubleshooting

### Common Issues

#### "No identity matched any of the recipients"

**Cause**: SSH keys in `secrets.nix` don't match the keys used to encrypt the secret.

**Solution**:

```bash
# Extract current keys
./scripts/get-keys.sh

# Update secrets.nix with correct keys
nano secrets.nix

# Rekey all secrets
./scripts/manage-secrets.sh rekey
```

#### Secret Not Accessible After Host Rebuild

**Cause**: Secret file permissions or paths incorrect.

**Solution**:

```bash
# Check secret file exists and has correct permissions
ls -la /run/agenix/

# Verify configuration
./scripts/manage-secrets.sh status

# Rebuild if necessary
sudo nixos-rebuild switch --flake .#<hostname>
```

#### Key Mismatch During Rekey

**Cause**: Some secrets encrypted with keys not in current `secrets.nix`.

**Solution**:

```bash
# Use recovery script
./scripts/recover-secrets.sh

# This will help identify problematic secrets and guide recovery
```

### Recovery Procedures

#### Complete Secret Recreation

If you lose access to critical keys:

```bash
# Backup existing secrets
cp -r secrets/ secrets.backup.$(date +%s)

# Recreate critical secrets
./scripts/manage-secrets.sh create user-password-<username>
./scripts/manage-secrets.sh create root-password

# Update other secrets as needed
```

#### Key Rotation

When rotating SSH keys:

```bash
# Generate new keys
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_new -N ""

# Update secrets.nix with new public key
# Keep old key temporarily for transition

# Rekey all secrets
./scripts/manage-secrets.sh rekey

# Remove old key from secrets.nix
# Final rekey
./scripts/manage-secrets.sh rekey
```

## 🛡️ Security Best Practices

### Key Management

1. **Regular Key Rotation**: Rotate SSH keys periodically
2. **Principle of Least Privilege**: Only grant access to necessary secrets
3. **Audit Access**: Regularly review who has access to what secrets
4. **Backup Keys**: Securely backup SSH private keys

### Secret Organization

1. **Descriptive Names**: Use clear, descriptive secret names
2. **Role-Based Access**: Group secrets by user roles and responsibilities
3. **Host Isolation**: Limit secret access to relevant hosts only
4. **Service Separation**: Separate secrets by service/application

### Operational Security

1. **Secure Workstations**: Ensure development machines are secure
2. **Access Logging**: Monitor secret access through systemd logs
3. **Incident Response**: Have procedures for compromised secrets
4. **Documentation**: Keep security procedures documented and current

### Monitoring

```bash
# Monitor secret access
journalctl -u agenix-*

# Check secret file integrity
find /run/agenix -type f -ls

# Verify secret decryption
agenix -d secrets/user-password-olafkfreund.age > /dev/null && echo "OK"
```

## 📚 Reference

### Management Scripts

- `./scripts/manage-secrets.sh` - Main secret management interface
- `./scripts/get-keys.sh` - Extract SSH public keys
- `./scripts/recover-secrets.sh` - Handle secret recovery scenarios
- `./scripts/setup-secrets.sh` - Complete initial setup

### Configuration Files

- `secrets.nix` - Key definitions and secret access control
- `modules/security/secrets.nix` - NixOS integration module
- `.gitignore` - Excludes secret files from version control

### Useful Commands

```bash
# Quick status check
./scripts/manage-secrets.sh status

# List available secrets
./scripts/manage-secrets.sh list

# Test secret decryption
agenix -d secrets/<secret-name>.age > /dev/null

# Verify agenix installation
which agenix || echo "agenix not in PATH"

# Check secret file permissions
ls -la /run/agenix/
```

This secrets management system provides robust, declarative secret handling while maintaining the reproducible and auditable nature of NixOS configurations.
