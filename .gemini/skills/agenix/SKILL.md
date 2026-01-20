---
name: agenix
version: 1.0
description: Agenix Skill
---

# Agenix Skill

## Overview

**agenix** is a lightweight, SSH-based secrets management solution for NixOS that uses age encryption to securely store and deploy sensitive information. It provides a CLI tool for encrypting secrets and a NixOS/Home Manager module for automated decryption and deployment.

### Key Features

- **SSH key integration**: Leverages existing SSH infrastructure for encryption/decryption
- **Nix-native**: Encrypted secrets stored in Nix store, decrypted during activation
- **Minimal dependencies**: No GPG required, small auditable codebase
- **Automatic decryption**: Secrets decrypt during `nixos-rebuild switch` using host keys
- **Multi-platform**: Supports NixOS, Home Manager, and nix-darwin
- **Simple workflow**: Edit secrets with your `$EDITOR`, auto-encrypt on save
- **Version control friendly**: Encrypted secrets can be safely committed to Git

### Why agenix?

**Problem**: Storing secrets (passwords, API keys, certificates) in NixOS configurations is challenging because:

- Plain text secrets in config files are insecure
- Nix store is world-readable - can't use `builtins.readFile` for secrets
- Manual secret deployment is error-prone and doesn't scale
- Need reproducible, declarative secret management

**Solution**: agenix encrypts secrets with SSH/age public keys, stores them in your Nix configuration, and automatically decrypts them on target systems using SSH private keys during activation.

### How It Works

1. **Encrypt**: Use `agenix -e secret.age` to create/edit encrypted secrets locally
2. **Store**: Commit encrypted `.age` files to your Git repository
3. **Declare**: Reference secrets in NixOS config via `age.secrets.<name>.file`
4. **Deploy**: Run `nixos-rebuild switch` - secrets decrypt to `/run/agenix/<name>`
5. **Use**: Services read secrets from runtime paths (never from Nix store)

### Project Information

- **Repository**: <https://github.com/ryantm/agenix>
- **License**: CC0-1.0 (Public Domain)
- **Dependencies**: age, SSH keys
- **Maturity**: Production-ready, widely used in NixOS community

## Installation

### NixOS with Flakes (Recommended)

Add agenix to your `flake.nix`:

```nix
{
  description = "NixOS configuration with agenix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    agenix.url = "github:ryantm/agenix";
    # Optional: Pin to specific version
    # agenix.url = "github:ryantm/agenix/0.15.0";
  };

  outputs = { self, nixpkgs, agenix, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        agenix.nixosModules.default
      ];
    };
  };
}
```

Install the CLI tool in your system:

```nix
# configuration.nix
{ pkgs, agenix, ... }:
{
  environment.systemPackages = [
    agenix.packages.x86_64-linux.default
  ];
}
```

Or run the CLI without installing:

```bash
nix run github:ryantm/agenix -- --help
nix run github:ryantm/agenix -- -e secret.age
```

### NixOS with nix-channel

Add the agenix channel:

```bash
sudo nix-channel --add https://github.com/ryantm/agenix/archive/main.tar.gz agenix
sudo nix-channel --update
```

Import in `configuration.nix`:

```nix
{
  imports = [ <agenix/modules/age.nix> ];

  environment.systemPackages = [
    (import <agenix>).default
  ];
}
```

### NixOS with fetchTarball

For hermetic builds without channels:

```nix
{
  imports = [
    "${builtins.fetchTarball "https://github.com/ryantm/agenix/archive/main.tar.gz"}/modules/age.nix"
  ];

  environment.systemPackages = [
    (import (builtins.fetchTarball "https://github.com/ryantm/agenix/archive/main.tar.gz")).default
  ];
}
```

Pin to specific commit:

```nix
let
  agenixCommit = "298b235f664f925b433614dc33380f0662adfc3f";
  agenixSha256 = "0000000000000000000000000000000000000000000000000000";
in {
  imports = [
    "${builtins.fetchTarball {
      url = "https://github.com/ryantm/agenix/archive/${agenixCommit}.tar.gz";
      sha256 = agenixSha256;
    }}/modules/age.nix"
  ];
}
```

### NixOS with niv

Add agenix as a dependency:

```bash
niv add ryantm/agenix
```

Import in `configuration.nix`:

```nix
{
  imports = [
    "${(import ./nix/sources.nix).agenix}/modules/age.nix"
  ];

  environment.systemPackages = [
    (import (import ./nix/sources.nix).agenix).default
  ];
}
```

### Home Manager

For user-level secrets with Home Manager:

```nix
# home.nix
{ inputs, ... }:
{
  imports = [
    inputs.agenix.homeManagerModules.default
  ];

  age = {
    identityPaths = [ "~/.ssh/id_ed25519" ];
    secrets = {
      personal-token.file = ../secrets/personal-token.age;
    };
  };
}
```

## Quick Start Tutorial

### Step 1: Create Secrets Directory

```bash
mkdir -p secrets
cd secrets
```

### Step 2: Create secrets.nix

Define which public keys can decrypt each secret:

```nix
# secrets/secrets.nix
let
  # User SSH keys
  alice = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0idNvgGiucWgup/mP78zyC23uFjYq0evcWdjGQUaBH alice@laptop";
  bob = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkbfFtJRq+6u/zcZWQRHqNLJoJN0UCT5qqRkUGBQnWo bob@desktop";

  # System SSH host keys
  server1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPJDyIr/FSz1cJdcoW69R+NrWzwGK/+3gJpqD1t8L2zE root@server1";
  server2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKj7H3K8JdQTTULTUi5L9l5JjqQNLq7JCqX5DWQR5sKj root@server2";
in
{
  # API keys accessible by both users and server1
  "api-key.age".publicKeys = [ alice bob server1 ];

  # Database password only for server1
  "db-password.age".publicKeys = [ alice server1 ];

  # SSH private key for deployment
  "deploy-key.age".publicKeys = [ alice server1 server2 ];

  # User-specific secret
  "alice-token.age".publicKeys = [ alice ];
}
```

**Finding Public Keys:**

```bash
# From local SSH keys
cat ~/.ssh/id_ed25519.pub

# From remote host
ssh-keyscan hostname

# From GitHub user
curl https://github.com/username.keys

# From NixOS configuration
ssh root@hostname "cat /etc/ssh/ssh_host_ed25519_key.pub"
```

### Step 3: Create Your First Secret

```bash
# Set EDITOR if not already set
export EDITOR=vim

# Create and encrypt a secret
agenix -e api-key.age
```

This opens your editor. Type the secret content, save, and exit. The file is encrypted with the public keys defined in `secrets.nix`.

### Step 4: Add Secret to NixOS Configuration

```nix
# configuration.nix
{ config, ... }:
{
  age.secrets.api-key = {
    file = ./secrets/api-key.age;
    mode = "440";
    owner = "myservice";
    group = "myservice";
  };

  # Use the secret in a service
  systemd.services.myservice = {
    script = ''
      export API_KEY=$(cat ${config.age.secrets.api-key.path})
      ${pkgs.myapp}/bin/myapp
    '';
    serviceConfig = {
      User = "myservice";
      Group = "myservice";
    };
  };
}
```

### Step 5: Deploy

```bash
nixos-rebuild switch
```

The secret decrypts to `/run/agenix/api-key` with the specified permissions.

### Step 6: Edit Existing Secret

```bash
# Uses your SSH key for decryption
agenix -e api-key.age

# Or specify identity explicitly
agenix -e api-key.age -i ~/.ssh/id_ed25519
```

## Common Use Cases

### User Passwords

```nix
{ config, ... }:
{
  age.secrets.alice-password.file = ./secrets/alice-password.age;

  users.users.alice = {
    isNormalUser = true;
    hashedPasswordFile = config.age.secrets.alice-password.path;
  };
}
```

Create the hashed password:

```bash
mkpasswd -m sha-512 | agenix -e alice-password.age
```

### SSH Private Keys

```nix
{ config, ... }:
{
  age.secrets.deploy-key = {
    file = ./secrets/deploy-key.age;
    mode = "600";
    owner = "deploy";
  };

  users.users.deploy = {
    isNormalUser = true;
    openssh.authorizedKeys.keyFiles = [ ./deploy-key.pub ];
  };

  # Use for SSH connections
  programs.ssh.extraConfig = ''
    Host production
      IdentityFile ${config.age.secrets.deploy-key.path}
  '';
}
```

### Database Credentials

```nix
{ config, pkgs, ... }:
{
  age.secrets.postgres-password = {
    file = ./secrets/postgres-password.age;
    owner = "postgres";
    group = "postgres";
  };

  services.postgresql = {
    enable = true;
    ensureUsers = [{
      name = "myapp";
      # Password set via secret file
    }];
  };

  # Application reads password
  systemd.services.myapp = {
    script = ''
      export DATABASE_URL="postgresql://myapp:$(cat ${config.age.secrets.postgres-password.path})@localhost/myapp"
      ${pkgs.myapp}/bin/myapp
    '';
  };
}
```

### API Keys and Tokens

```nix
{ config, ... }:
{
  age.secrets = {
    github-token.file = ./secrets/github-token.age;
    openai-api-key.file = ./secrets/openai-api-key.age;
    aws-credentials.file = ./secrets/aws-credentials.age;
  };

  # Service with environment file
  systemd.services.backup = {
    script = ''
      export GITHUB_TOKEN=$(cat ${config.age.secrets.github-token.path})
      ${pkgs.backup-script}/bin/backup
    '';
  };
}
```

### TLS Certificates

```nix
{ config, ... }:
{
  age.secrets = {
    "tls-cert.pem" = {
      file = ./secrets/tls-cert.pem.age;
      owner = "nginx";
      group = "nginx";
      mode = "440";
    };
    "tls-key.pem" = {
      file = ./secrets/tls-key.pem.age;
      owner = "nginx";
      group = "nginx";
      mode = "400";
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."example.com" = {
      enableACME = false;
      sslCertificate = config.age.secrets."tls-cert.pem".path;
      sslCertificateKey = config.age.secrets."tls-key.pem".path;
    };
  };
}
```

### Application Configuration Files

```nix
{ config, ... }:
{
  age.secrets.app-config = {
    file = ./secrets/app-config.yaml.age;
    path = "/etc/myapp/config.yaml";
    mode = "440";
    owner = "myapp";
    group = "myapp";
  };

  systemd.services.myapp = {
    script = ''
      ${pkgs.myapp}/bin/myapp --config /etc/myapp/config.yaml
    '';
    serviceConfig = {
      User = "myapp";
      Group = "myapp";
    };
  };
}
```

### Wireguard Private Keys

```nix
{ config, ... }:
{
  age.secrets.wireguard-private = {
    file = ./secrets/wireguard-private.age;
    mode = "400";
  };

  networking.wireguard.interfaces.wg0 = {
    privateKeyFile = config.age.secrets.wireguard-private.path;
    ips = [ "10.0.0.2/24" ];
    peers = [{
      publicKey = "server-public-key";
      endpoint = "vpn.example.com:51820";
      allowedIPs = [ "10.0.0.0/24" ];
    }];
  };
}
```

## Module Configuration Reference

### NixOS Module Options

#### age.secrets.<name>.file

**Type**: `path`
**Required**: Yes

Path to the encrypted `.age` file.

```nix
{
  age.secrets.api-key.file = ./secrets/api-key.age;
}
```

#### age.secrets.<name>.path

**Type**: `string`
**Default**: `/run/agenix/<name>`

Path where the decrypted secret will be available.

```nix
{
  age.secrets.monitrc = {
    file = ./secrets/monitrc.age;
    path = "/etc/monitrc";
  };
}
```

#### age.secrets.<name>.mode

**Type**: `string`
**Default**: `"0400"`

File permissions in chmod format (octal).

```nix
{
  age.secrets.nginx-htpasswd = {
    file = ./secrets/nginx.htpasswd.age;
    mode = "0440";  # Owner and group can read
  };
}
```

Common modes:

- `"0400"`: Owner read-only (most secure)
- `"0440"`: Owner and group read
- `"0600"`: Owner read/write
- `"0640"`: Owner read/write, group read

#### age.secrets.<name>.owner

**Type**: `string`
**Default**: `"root"`

Username of the file owner.

```nix
{
  age.secrets.postgres-password = {
    file = ./secrets/postgres-password.age;
    owner = "postgres";
  };
}
```

#### age.secrets.<name>.group

**Type**: `string`
**Default**: `"root"`

Group name of the file.

```nix
{
  age.secrets.nginx-cert = {
    file = ./secrets/nginx-cert.age;
    owner = "nginx";
    group = "nginx";
  };
}
```

#### age.secrets.<name>.symlink

**Type**: `boolean`
**Default**: `true`

Whether to use a symlink or copy the file.

```nix
{
  age.secrets.elasticsearch-conf = {
    file = ./secrets/elasticsearch.conf.age;
    symlink = false;  # Copy instead of symlink
  };
}
```

**Note**: Symlinks are recommended for security (automatic cleanup). Disable only if an application cannot follow symlinks.

#### age.secrets.<name>.name

**Type**: `string`
**Default**: `<attribute name>`

Custom filename for the decrypted secret.

```nix
{
  age.secrets.monit = {
    name = "monitrc";
    file = ./secrets/monitrc.age;
  };
  # Decrypts to /run/agenix/monitrc instead of /run/agenix/monit
}
```

#### age.identityPaths

**Type**: `list of strings`
**Default**: SSH host keys from `config.services.openssh.hostKeys`

Paths to private keys used for decryption.

```nix
{
  age.identityPaths = [
    "/var/lib/persistent/ssh_host_ed25519_key"
    "/var/lib/persistent/ssh_host_rsa_key"
  ];
}
```

**Important**: Use strings, not Nix paths, to prevent copying private keys to the Nix store.

#### age.secretsDir

**Type**: `string`
**Default**: `/run/agenix`

Directory where secret symlinks are created.

```nix
{
  age.secretsDir = "/run/keys";
}
```

#### age.secretsMountPoint

**Type**: `string`
**Default**: `/run/agenix.d`

Directory for generation-specific secrets (internal use).

```nix
{
  age.secretsMountPoint = "/run/secret-generations";
}
```

#### age.ageBin

**Type**: `string`
**Default**: `"${pkgs.age}/bin/age"`

Path to the age binary.

```nix
{
  # Use rage instead of age
  age.ageBin = "${pkgs.rage}/bin/rage";
}
```

### Home Manager Module Options

Home Manager options are similar to NixOS with these differences:

#### age.identityPaths (Home Manager)

**Type**: `list of strings`
**Required**: Yes (no default)

Must be explicitly configured:

```nix
{
  age.identityPaths = [ "~/.ssh/id_ed25519" ];
}
```

#### age.secretsDir (Home Manager)

**Default**: `$XDG_RUNTIME_DIR/agenix` (Linux) or temporary directory (Darwin)

```nix
{
  age.secretsDir = "$HOME/.secrets";
}
```

## CLI Reference

### Commands

#### Edit Secret

```bash
# Edit secret (creates if doesn't exist)
agenix -e secret.age

# Edit with specific identity
agenix -e secret.age -i ~/.ssh/id_ed25519

# Edit with custom rules file
RULES=./my-secrets.nix agenix -e secret.age
```

#### Rekey Secrets

Re-encrypt all secrets when public keys change:

```bash
# Rekey all secrets
agenix --rekey

# Rekey with specific identity
agenix --rekey -i ~/.ssh/id_ed25519

# Rekey with custom rules
RULES=./my-secrets.nix agenix --rekey
```

#### Decrypt Secret

Output decrypted content to stdout:

```bash
# Decrypt to stdout
agenix -d secret.age

# Decrypt with specific identity
agenix -d secret.age -i ~/.ssh/id_ed25519

# Decrypt to file
agenix -d secret.age > /tmp/secret.txt
```

### Options

- `-e, --edit FILE`: Edit FILE using `$EDITOR`
- `-r, --rekey`: Re-encrypt all secrets with updated recipients
- `-d, --decrypt FILE`: Decrypt FILE to stdout
- `-i, --identity PATH`: Private key path for decryption
- `-v, --verbose`: Enable verbose output
- `-h, --help`: Show help message

### Environment Variables

- **`EDITOR`**: Editor used for `-e` flag (defaults to `cp /dev/stdin` in non-interactive mode)
- **`RULES`**: Path to secrets.nix file (defaults to `./secrets.nix`)

### Examples

```bash
# Create a new secret
export EDITOR=vim
agenix -e database-password.age

# Edit existing secret with nano
EDITOR=nano agenix -e api-key.age

# View secret content
agenix -d api-key.age | less

# Rekey after adding new host
agenix --rekey

# Use custom secrets.nix location
RULES=~/nixos/secrets/rules.nix agenix -e secret.age

# Non-interactive secret creation
echo "my-secret-value" | agenix -e secret.age

# Create secret from file
cat secret.txt | agenix -e secret.age
```

## Advanced Configuration

### Multiple Host Keys

Support both ED25519 and RSA keys:

```nix
# secrets.nix
let
  server1-ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPJDyIr...";
  server1-rsa = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC5...";
in
{
  "secret.age".publicKeys = [
    server1-ed25519
    server1-rsa
  ];
}
```

### Organization-Wide Secrets

```nix
# secrets.nix
let
  # Import keys from separate files
  admins = import ./admin-keys.nix;
  servers = import ./server-keys.nix;

  # Shared secrets
  allKeys = admins ++ servers;
in
{
  "shared-api-key.age".publicKeys = allKeys;
  "admin-password.age".publicKeys = admins;
  "server-cert.age".publicKeys = servers;
}
```

```nix
# admin-keys.nix
[
  "ssh-ed25519 AAAAC3... alice@example.com"
  "ssh-ed25519 AAAAC3... bob@example.com"
  "ssh-ed25519 AAAAC3... charlie@example.com"
]
```

### Per-Environment Secrets

```nix
# secrets.nix
let
  production = import ./keys/production.nix;
  staging = import ./keys/staging.nix;
  development = import ./keys/development.nix;
in
{
  "prod-db-password.age".publicKeys = production;
  "staging-db-password.age".publicKeys = staging;
  "dev-db-password.age".publicKeys = development;

  # Shared across environments
  "shared-api-key.age".publicKeys = production ++ staging ++ development;
}
```

### Armor Mode (ASCII Encoding)

Enable Base64 PEM format for better diff readability:

```nix
# secrets.nix
{
  "armored-secret.age" = {
    publicKeys = [ user1 system1 ];
    armor = true;  # Use ASCII armor format
  };
}
```

Benefits:

- More readable diffs in version control
- Can be pasted in text channels
- Slightly larger file size

### Custom Age Binary

Use `rage` (Rust implementation) instead of `age`:

```nix
{ pkgs, agenix, ... }:
{
  environment.systemPackages = [
    (agenix.packages.x86_64-linux.default.override {
      ageBin = "${pkgs.rage}/bin/rage";
    })
  ];

  age.ageBin = "${pkgs.rage}/bin/rage";
}
```

### Persistent SSH Keys

For systems with impermanence or ephemeral root:

```nix
{ config, ... }:
{
  # Persist SSH host keys
  environment.persistence."/persist" = {
    files = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };

  # Point agenix to persistent keys
  age.identityPaths = [
    "/persist/etc/ssh/ssh_host_ed25519_key"
  ];
}
```

### Secrets in initrd

For unlocking encrypted disks:

```nix
{ config, ... }:
{
  age.secrets.disk-encryption-key = {
    file = ./secrets/disk-key.age;
  };

  boot.initrd.secrets = {
    "/crypto_keyfile.bin" = config.age.secrets.disk-encryption-key.path;
  };

  boot.initrd.luks.devices.cryptroot = {
    device = "/dev/sda2";
    keyFile = "/crypto_keyfile.bin";
  };
}
```

### Integration with sops-nix

Use both agenix and sops-nix in the same system:

```nix
{ config, pkgs, ... }:
{
  imports = [
    inputs.agenix.nixosModules.default
    inputs.sops-nix.nixosModules.sops
  ];

  # agenix for simple secrets
  age.secrets.api-key.file = ./secrets/api-key.age;

  # sops for complex secrets with multiple formats
  sops.secrets."database/password" = {};
}
```

## Security Best Practices

### 1. Use Strong SSH Keys

Generate ED25519 keys (recommended):

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

Or RSA with 4096 bits:

```bash
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
```

### 2. Protect Private Keys

```nix
# ✅ Good: Use strings to avoid store
{
  age.identityPaths = [ "/var/lib/ssh/host_key" ];
}

# ❌ Bad: Nix path copies to store
{
  age.identityPaths = [ /var/lib/ssh/host_key ];
}
```

### 3. Set Restrictive Permissions

```nix
{
  age.secrets.sensitive-data = {
    file = ./secrets/sensitive.age;
    mode = "0400";  # Read-only for owner
    owner = "service-user";
    group = "service-group";
  };
}
```

### 4. Never Read Secrets at Build Time

```nix
# ❌ WRONG: Puts plaintext in world-readable Nix store
{
  services.myapp.apiKey = builtins.readFile config.age.secrets.api-key.path;
}

# ✅ CORRECT: Read at runtime
{
  systemd.services.myapp = {
    script = ''
      export API_KEY=$(cat ${config.age.secrets.api-key.path})
      ${pkgs.myapp}/bin/myapp
    '';
  };
}
```

### 5. Rotate Secrets Regularly

```bash
# Update secret
agenix -e secret.age

# Deploy to all systems
nixops deploy

# Or use CI/CD
git commit -m "Rotate API keys"
git push
```

### 6. Use Separate Keys Per Environment

```nix
# secrets.nix
{
  "prod-db.age".publicKeys = [ prod-admin prod-server ];
  "dev-db.age".publicKeys = [ dev-admin dev-server ];
}
```

### 7. Audit Secret Access

```nix
# Log secret access
{
  systemd.services.audit-secrets = {
    script = ''
      ${pkgs.inotify-tools}/bin/inotifywait -m /run/agenix/ -e access |
        while read path action file; do
          echo "Secret accessed: $file at $(date)" >> /var/log/secret-access.log
        done
    '';
  };
}
```

### 8. Backup Decryption Keys

- Store SSH private keys in a secure password manager
- Keep offline backups of keys
- Document key recovery procedures
- Test key recovery process

### 9. Limit Secret Lifetime

```nix
# Auto-cleanup old secrets
{
  systemd.tmpfiles.rules = [
    "d /run/agenix 0755 root root 30d"
  ];
}
```

### 10. Version Control Encrypted Secrets

```bash
# .gitignore - Don't ignore encrypted secrets
# *.age  # DON'T DO THIS

# DO ignore decrypted secrets
secrets/*.txt
secrets/*.key
!secrets/*.age  # But commit encrypted ones
```

## Common Patterns

### Environment Files

Create environment files for services:

```nix
{ config, pkgs, ... }:
let
  # Generate environment file from secrets
  mkEnvFile = secrets: pkgs.writeScript "load-env" ''
    #!${pkgs.bash}/bin/bash
    ${pkgs.lib.concatMapStringsSep "\n" (s:
      "export ${s.name}=$(cat ${s.path})"
    ) secrets}
  '';
in {
  age.secrets = {
    api-key.file = ./secrets/api-key.age;
    db-password.file = ./secrets/db-password.age;
  };

  systemd.services.myapp = {
    script = ''
      source ${mkEnvFile [
        { name = "API_KEY"; path = config.age.secrets.api-key.path; }
        { name = "DB_PASSWORD"; path = config.age.secrets.db-password.path; }
      ]}
      ${pkgs.myapp}/bin/myapp
    '';
  };
}
```

### Secret Templating

Generate config files with secrets:

```nix
{ config, pkgs, ... }:
{
  age.secrets = {
    db-password.file = ./secrets/db-password.age;
    api-key.file = ./secrets/api-key.age;
  };

  systemd.services.myapp = {
    preStart = ''
      cat > /etc/myapp/config.yaml <<EOF
      database:
        password: $(cat ${config.age.secrets.db-password.path})
      api:
        key: $(cat ${config.age.secrets.api-key.path})
      EOF
      chmod 600 /etc/myapp/config.yaml
    '';
  };
}
```

### Conditional Secrets

Different secrets per host:

```nix
{ config, lib, ... }:
{
  age.secrets = lib.mkMerge [
    # Common secrets for all hosts
    {
      shared-api-key.file = ./secrets/shared-api-key.age;
    }

    # Production-specific secrets
    (lib.mkIf (config.networking.hostName == "prod-server") {
      prod-db-password.file = ./secrets/prod-db.age;
    })

    # Development-specific secrets
    (lib.mkIf (config.networking.hostName == "dev-server") {
      dev-db-password.file = ./secrets/dev-db.age;
    })
  ];
}
```

### Secrets Modules

Create reusable secret modules:

```nix
# modules/secrets.nix
{ config, lib, ... }:
with lib;
{
  options.myorg.secrets = {
    enable = mkEnableOption "organization secrets";

    environment = mkOption {
      type = types.enum [ "production" "staging" "development" ];
      description = "Deployment environment";
    };
  };

  config = mkIf config.myorg.secrets.enable {
    age.secrets = {
      api-key.file = ./secrets/${config.myorg.secrets.environment}/api-key.age;
      db-password.file = ./secrets/${config.myorg.secrets.environment}/db-password.age;
    };
  };
}
```

Usage:

```nix
{
  imports = [ ./modules/secrets.nix ];

  myorg.secrets = {
    enable = true;
    environment = "production";
  };
}
```

## Troubleshooting

### Secret Not Decrypting

**Check identity paths:**

```nix
{
  # Verify paths are correct
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
}
```

**Verify key exists:**

```bash
ls -l /etc/ssh/ssh_host_ed25519_key
```

**Check public key matches:**

```bash
# Get public key from private key
ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key

# Compare with secrets.nix
```

**Test decryption manually:**

```bash
age -d -i /etc/ssh/ssh_host_ed25519_key secret.age
```

### Permission Denied

**Check file permissions:**

```bash
ls -l /run/agenix/
```

**Verify owner/group:**

```nix
{
  age.secrets.mySecret = {
    file = ./secrets/mySecret.age;
    owner = "myuser";  # Make sure user exists
    group = "mygroup";  # Make sure group exists
    mode = "0440";
  };
}
```

**Check service user:**

```nix
{
  systemd.services.myservice = {
    serviceConfig = {
      User = "myuser";  # Must match secret owner
    };
  };
}
```

### Rekeying Fails

**Ensure you have decryption access:**

```bash
# Test with your SSH key
agenix -d secret.age -i ~/.ssh/id_ed25519
```

**Check all secrets can be decrypted:**

```bash
# Rekey with specific identity
agenix --rekey -i ~/.ssh/id_ed25519
```

**Verify secrets.nix syntax:**

```bash
nix-instantiate --eval secrets.nix
```

### Secret Not Found

**Check file path:**

```nix
{
  # Use correct relative path
  age.secrets.api-key.file = ./secrets/api-key.age;  # Relative to config file
  # Or absolute path
  age.secrets.api-key.file = /etc/nixos/secrets/api-key.age;
}
```

**Verify file exists:**

```bash
ls -l secrets/api-key.age
```

### SSH Key Format Issues

**Convert to age-compatible format:**

```bash
# ED25519 keys work directly
ssh-keygen -t ed25519

# RSA keys need conversion
ssh-keygen -t rsa -b 4096
```

**Use ssh-to-age for conversion:**

```bash
nix-shell -p ssh-to-age
ssh-keygen -y -f ~/.ssh/id_rsa | ssh-to-age
```

### Secrets in Nix Store

**Check for accidental store inclusion:**

```bash
# Search for secrets in store
nix-store -q --references /run/current-system | xargs -I {} nix-store -q --tree {} | grep -i secret
```

**Fix: Use runtime reading:**

```nix
# ❌ Wrong
config.password = builtins.readFile config.age.secrets.password.path;

# ✅ Correct
systemd.services.app.script = ''
  export PASSWORD=$(cat ${config.age.secrets.password.path})
'';
```

### Home Manager Secrets Not Working

**Set identityPaths explicitly:**

```nix
{
  age.identityPaths = [ "~/.ssh/id_ed25519" ];
}
```

**Check XDG_RUNTIME_DIR:**

```bash
echo $XDG_RUNTIME_DIR
ls -l $XDG_RUNTIME_DIR/agenix/
```

**Verify home-manager activation:**

```bash
home-manager switch --show-trace
```

## Integration Examples

### NixOps Deployment

```nix
{
  network = {
    description = "Production deployment with secrets";
  };

  webserver = { config, pkgs, ... }: {
    deployment.targetHost = "web.example.com";

    imports = [ inputs.agenix.nixosModules.default ];

    age.secrets = {
      ssl-cert.file = ./secrets/ssl-cert.pem.age;
      ssl-key.file = ./secrets/ssl-key.pem.age;
    };

    services.nginx = {
      enable = true;
      sslCertificate = config.age.secrets.ssl-cert.path;
      sslCertificateKey = config.age.secrets.ssl-key.path;
    };
  };
}
```

### Colmena Deployment

```nix
{
  meta = {
    nixpkgs = import <nixpkgs> {};
    nodeNixpkgs = {
      server = import <nixpkgs> {};
    };
  };

  server = { config, pkgs, ... }: {
    deployment = {
      targetHost = "server.example.com";
      targetUser = "deploy";
    };

    imports = [ inputs.agenix.nixosModules.default ];

    age.secrets.deploy-key = {
      file = ./secrets/deploy-key.age;
      mode = "600";
      owner = "deploy";
    };
  };
}
```

### Deploy-rs Integration

```nix
{
  deploy.nodes.server = {
    hostname = "server.example.com";
    profiles.system = {
      path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.server;
    };
  };

  nixosConfigurations.server = nixpkgs.lib.nixosSystem {
    modules = [
      agenix.nixosModules.default
      {
        age.secrets.deploy-key.file = ./secrets/deploy-key.age;
      }
    ];
  };
}
```

### GitHub Actions CI/CD

```yaml
# .github/workflows/deploy.yml
name: Deploy with Secrets

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - uses: cachix/install-nix-action@v18

      - name: Setup SSH key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.DEPLOY_SSH_KEY }}" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519

      - name: Rekey secrets if needed
        run: |
          nix run github:ryantm/agenix -- --rekey

      - name: Deploy
        run: |
          nixos-rebuild switch --flake .#server --target-host root@server.example.com
```

### Docker Container

```nix
{ config, pkgs, ... }:
{
  age.secrets.app-env = {
    file = ./secrets/app-env.age;
    mode = "644";
  };

  virtualisation.oci-containers.containers.myapp = {
    image = "myapp:latest";
    volumes = [
      "${config.age.secrets.app-env.path}:/app/.env:ro"
    ];
  };
}
```

## Migration Guide

### From Manual Secret Management

Before:

```nix
{
  services.myapp.apiKey = "hardcoded-secret";  # Insecure!
}
```

After:

```nix
{
  age.secrets.api-key.file = ./secrets/api-key.age;

  systemd.services.myapp = {
    script = ''
      export API_KEY=$(cat ${config.age.secrets.api-key.path})
      ${pkgs.myapp}/bin/myapp
    '';
  };
}
```

### From sops-nix

1. Export secrets from sops:

```bash
sops -d secrets.yaml > secrets.txt
```

2. Convert to agenix:

```bash
agenix -e secret.age < secrets.txt
```

3. Update configuration:

```nix
# Before (sops)
{
  sops.secrets.api-key = {};
}

# After (agenix)
{
  age.secrets.api-key.file = ./secrets/api-key.age;
}
```

### From git-crypt

1. Unlock and export:

```bash
git-crypt unlock
cat secrets/api-key > /tmp/api-key
```

2. Encrypt with agenix:

```bash
agenix -e api-key.age < /tmp/api-key
shred -u /tmp/api-key
```

3. Update configuration to use agenix

## Best Practices Summary

### ✅ Do

1. **Version control encrypted secrets** - Commit `.age` files to Git
2. **Use strings for key paths** - Prevent copying private keys to store
3. **Set restrictive permissions** - Use mode `0400` or `0440`
4. **Read secrets at runtime** - Never use `builtins.readFile` on secret paths
5. **Rotate keys regularly** - Update secrets periodically
6. **Backup private keys** - Store recovery keys securely
7. **Use descriptive names** - `db-password.age` not `secret1.age`
8. **Separate secrets per environment** - Different keys for prod/staging/dev
9. **Document key ownership** - Track who can decrypt what
10. **Test rekeying process** - Ensure you can update secrets

### ❌ Don't

1. **Don't use Nix paths for private keys** - Use strings instead
2. **Don't read secrets at build time** - Puts plaintext in Nix store
3. **Don't share private keys** - Each user/system should have unique keys
4. **Don't commit decrypted secrets** - Only commit `.age` files
5. **Don't ignore backup** - Always have key recovery plan
6. **Don't use weak permissions** - Avoid mode `0777` or `0644` for secrets
7. **Don't hardcode secrets** - Always encrypt with agenix
8. **Don't skip rekeying** - Update secrets when keys change
9. **Don't use password-protected SSH keys for automation** - Causes issues with rekeying
10. **Don't assume secrets are authenticated** - Age provides confidentiality, not authentication

## Security Considerations

### Threat Model

**What agenix protects against:**

- ✅ Accidental exposure in version control
- ✅ Unauthorized access to secrets at rest
- ✅ Secrets in build artifacts
- ✅ Accidental logging of secrets

**What agenix does NOT protect against:**

- ❌ Compromised private keys (attacker can decrypt)
- ❌ Root access on target system (can read `/run/agenix/`)
- ❌ Supply chain attacks on age/agenix
- ❌ Side-channel attacks
- ❌ Post-quantum attacks (age is not PQ-safe as of 2024)

### Unauthenticated Encryption

Age provides **confidentiality but not authentication**:

- Attackers with write access to `.age` files can modify encrypted content
- Configuration changes are easier to audit than secret content
- Use file integrity monitoring for production secrets
- Consider additional authentication layers for critical secrets

### Post-Quantum Safety

As of 2024, age is **not post-quantum safe**:

- "Harvest now, decrypt later" attacks are viable
- Don't store long-term secrets in public repositories
- Rotate secrets regularly
- Monitor post-quantum age development

### Recommendations

1. **Rotate secrets regularly** - At least quarterly for critical secrets
2. **Monitor access** - Log and audit secret access patterns
3. **Limit key distribution** - Minimum necessary access principle
4. **Use hardware security modules** - For critical infrastructure keys
5. **Plan for key compromise** - Document incident response procedures
6. **Keep agenix updated** - Security fixes and improvements
7. **Audit regularly** - Review who has access to which secrets
8. **Test recovery** - Ensure you can restore access if keys are lost

## Resources

### Official Documentation

- **GitHub**: <https://github.com/ryantm/agenix>
- **Issues**: <https://github.com/ryantm/agenix/issues>
- **Discussions**: <https://github.com/ryantm/agenix/discussions>

### Related Projects

- **age**: <https://age-encryption.org/>
- **rage**: <https://github.com/str4d/rage> (Rust implementation)
- **sops-nix**: Alternative secrets management
- **git-crypt**: Alternative for Git-based secrets

### Community Resources

- **NixOS Wiki**: Search for "agenix"
- **NixOS Discourse**: Community discussions and help
- **r/NixOS**: Reddit community

### Learning Resources

- **Age specification**: <https://age-encryption.org/v1>
- **SSH key management**: Best practices and guides
- **NixOS secrets management**: Comparison of different approaches

## Quick Reference

### Installation (Flakes)

```nix
{
  inputs.agenix.url = "github:ryantm/agenix";
  outputs = { nixpkgs, agenix, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      modules = [ agenix.nixosModules.default ];
    };
  };
}
```

### Basic Secret

```nix
# secrets.nix
{
  "secret.age".publicKeys = [ user-key host-key ];
}

# configuration.nix
{
  age.secrets.secret.file = ./secrets/secret.age;
}
```

### CLI Commands

```bash
agenix -e secret.age          # Create/edit secret
agenix --rekey                # Re-encrypt all secrets
agenix -d secret.age          # Decrypt to stdout
```

### Common Options

```nix
{
  age.secrets.secret = {
    file = ./secrets/secret.age;  # Required
    path = "/run/agenix/secret";  # Default
    mode = "0400";                # Default
    owner = "root";               # Default
    group = "root";               # Default
  };
}
```

### Finding SSH Keys

```bash
cat ~/.ssh/id_ed25519.pub            # Local user key
ssh-keyscan hostname                 # Remote host key
curl https://github.com/user.keys    # GitHub user keys
```

This comprehensive skill covers everything you need to securely manage secrets in NixOS with agenix!
