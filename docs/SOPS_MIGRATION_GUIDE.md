# Agenix to SOPS-nix Migration Guide

## Overview

This guide documents the migration from `agenix` to `sops-nix` for secrets management in our NixOS infrastructure. SOPS provides better tooling, more flexibility, and simpler secrets management.

## Why SOPS-nix?

### Advantages over Agenix

1. **Better UX**: Direct editing with `sops secrets.yaml` instead of `agenix -e`
2. **Multiple formats**: Supports YAML, JSON, ENV, INI, and binary files
3. **Partial encryption**: Can encrypt only values, keeping keys readable
4. **Multi-key support**: Better support for multiple encryption keys
5. **Audit trail**: Built-in audit logging capabilities
6. **Better tooling**: More mature ecosystem and CLI tools

## Migration Steps

### Step 1: Install SOPS Tools

```bash
# Add to your shell or system packages
nix-shell -p sops age
```

### Step 2: Generate Age Keys (if needed)

```bash
# Generate new age key for encryption
age-keygen -o ~/.config/sops/age/keys.txt

# Or use existing SSH keys
mkdir -p ~/.config/sops/age
ssh-to-age < ~/.ssh/id_ed25519.pub > ~/.config/sops/age/keys.txt
```

### Step 3: Create SOPS Configuration

Create `.sops.yaml` in your repository root:

```yaml
# .sops.yaml
keys:
  # User keys
  - &admin age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p

  # Host keys (from SSH host keys)
  - &p620 age1yubikey1qwqw7l3lqxrp7d2xh39rwx0x5q4xjqfkpzdxwyqal4x9s5pw2x6z9q
  - &razer age1yubikey1q2z8xpqxrp7d2xh39rwx0x5q4xjqfkpzdxwyqal4x9s5pw2x6z9q
  - &p510 age1yubikey1q3w7l3lqxrp7d2xh39rwx0x5q4xjqfkpzdxwyqal4x9s5pw2x6z9q
  - &dex5550 age1yubikey1q4qw7l3lqxrp7d2xh39rwx0x5q4xjqfkpzdxwyqal4x9s5pw2x6z9q
  - &samsung age1yubikey1q5qw7l3lqxrp7d2xh39rwx0x5q4xjqfkpzdxwyqal4x9s5pw2x6z9q

creation_rules:
  # Default rule for all secrets
  - path_regex: secrets/[^/]+\.(yaml|json|env|ini)$
    key_groups:
      - age:
          - *admin
          - *p620
          - *razer
          - *p510
          - *dex5550
          - *samsung

  # Host-specific secrets
  - path_regex: secrets/hosts/p620/[^/]+\.(yaml|json|env|ini)$
    key_groups:
      - age:
          - *admin
          - *p620

  - path_regex: secrets/hosts/razer/[^/]+\.(yaml|json|env|ini)$
    key_groups:
      - age:
          - *admin
          - *razer
```

### Step 4: Create New Secrets Structure

```bash
# Create secrets directory structure
mkdir -p secrets/{common,hosts/{p620,razer,p510,dex5550,samsung}}

# Create common secrets file
cat > secrets/common/secrets.yaml << 'EOF'
# User passwords
user_passwords:
  olafkfreund: "your-hashed-password-here"

# API Keys
api_keys:
  openai: "sk-..."
  anthropic: "sk-ant-..."
  gemini: "..."
  github_token: "ghp_..."

# Network
network:
  wifi_password: "..."
  tailscale_auth_key: "tskey-..."
EOF

# Encrypt the secrets file
sops -e -i secrets/common/secrets.yaml
```

### Step 5: Update Flake

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Remove agenix
    # agenix.url = "github:ryantm/agenix";

    # Add sops-nix
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, sops-nix, ... }@inputs: {
    nixosConfigurations = {
      p620 = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/p620/configuration.nix
          sops-nix.nixosModules.sops
        ];
      };
      # ... other hosts
    };
  };
}
```

### Step 6: Create SOPS Module

```nix
# modules/security/sops.nix
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.security.sops;
in {
  options.security.sops = {
    enable = mkEnableOption "SOPS secrets management";

    hostSecrets = mkOption {
      type = types.bool;
      default = true;
      description = "Enable host-specific secrets";
    };
  };

  config = mkIf cfg.enable {
    # SOPS configuration
    sops = {
      # Age key file location
      age.keyFile = "/var/lib/sops-nix/key.txt";
      age.generateKey = true;

      # SSH host key for decryption
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

      # Default sops file
      defaultSopsFile = ../../secrets/common/secrets.yaml;
      defaultSopsFormat = "yaml";

      # Validation
      validateSopsFiles = true;

      # Secret definitions
      secrets = {
        # User passwords
        "user_passwords/olafkfreund" = {
          neededForUsers = true;
        };

        # API Keys
        "api_keys/openai" = {
          mode = "0400";
          owner = config.users.users.olafkfreund.name;
        };

        "api_keys/anthropic" = {
          mode = "0400";
          owner = config.users.users.olafkfreund.name;
        };

        "api_keys/gemini" = {
          mode = "0400";
          owner = config.users.users.olafkfreund.name;
        };

        "api_keys/github_token" = {
          mode = "0400";
          owner = config.users.users.olafkfreund.name;
        };

        # Network secrets
        "network/wifi_password" = {};
        "network/tailscale_auth_key" = {};
      };

      # Host-specific secrets (if exists)
      secrets = mkIf (cfg.hostSecrets &&
        builtins.pathExists ../../secrets/hosts/${config.networking.hostName}/secrets.yaml) {
        sopsFile = ../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
      };
    };

    # Ensure sops is available
    environment.systemPackages = with pkgs; [
      sops
      age
      ssh-to-age
    ];
  };
}
```

### Step 7: Update Service Configurations

Replace agenix secret references with sops:

```nix
# Before (agenix)
services.myservice = {
  passwordFile = config.age.secrets.mypassword.path;
};

# After (sops-nix)
services.myservice = {
  passwordFile = config.sops.secrets."api_keys/mypassword".path;
};
```

### Step 8: Migration Script

Create a migration script to convert existing secrets:

```bash
#!/usr/bin/env bash
# scripts/migrate-to-sops.sh

set -euo pipefail

echo "=== Agenix to SOPS Migration Script ==="

# Check prerequisites
command -v sops >/dev/null 2>&1 || { echo "sops is required but not installed."; exit 1; }
command -v age >/dev/null 2>&1 || { echo "age is required but not installed."; exit 1; }

# Create directories
mkdir -p secrets/{common,hosts/{p620,razer,p510,dex5550,samsung}}

# Function to decrypt agenix secret
decrypt_agenix() {
  local secret_file=$1
  agenix -d "$secret_file" 2>/dev/null || echo ""
}

# Migrate user passwords
echo "Migrating user passwords..."
cat > secrets/common/users.yaml << EOF
user_passwords:
  olafkfreund: "$(decrypt_agenix secrets/user-password-olafkfreund.age)"
EOF

# Migrate API keys
echo "Migrating API keys..."
cat > secrets/common/api-keys.yaml << EOF
api_keys:
  openai: "$(decrypt_agenix secrets/api-openai.age)"
  anthropic: "$(decrypt_agenix secrets/api-anthropic.age)"
  gemini: "$(decrypt_agenix secrets/api-gemini.age)"
  github_token: "$(decrypt_agenix secrets/api-github-token.age)"
EOF

# Migrate network secrets
echo "Migrating network secrets..."
cat > secrets/common/network.yaml << EOF
network:
  wifi_password: "$(decrypt_agenix secrets/wifi-password.age)"
  tailscale_auth_key: "$(decrypt_agenix secrets/tailscale-auth-key.age)"
EOF

# Encrypt with SOPS
echo "Encrypting with SOPS..."
sops -e -i secrets/common/users.yaml
sops -e -i secrets/common/api-keys.yaml
sops -e -i secrets/common/network.yaml

echo "Migration complete!"
echo ""
echo "Next steps:"
echo "1. Review encrypted files in secrets/"
echo "2. Update your configuration to use sops module"
echo "3. Test on one host before deploying to all"
echo "4. Remove old agenix secrets after verification"
```

## Usage Examples

### Creating New Secrets

```bash
# Create or edit secrets file
sops secrets/common/api-keys.yaml

# Create host-specific secret
sops secrets/hosts/p620/custom.yaml
```

### Accessing Secrets in Configuration

```nix
{ config, ... }: {
  # Use secret in service
  services.myapp = {
    apiKeyFile = config.sops.secrets."api_keys/openai".path;
  };

  # Use in systemd service
  systemd.services.my-service = {
    serviceConfig = {
      EnvironmentFile = config.sops.secrets."service_env".path;
    };
  };

  # Template usage
  services.grafana.provision.datasources.settings.datasources = [{
    access = "proxy";
    basicAuth = true;
    basicAuthPassword = "$__file{${config.sops.secrets."monitoring/grafana_password".path}}";
  }];
}
```

### Managing Keys

```bash
# Add new user/host to existing secret
sops updatekeys secrets/common/api-keys.yaml

# Rotate keys
sops rotate -i secrets/common/api-keys.yaml

# Show keys info
sops -k secrets/common/api-keys.yaml
```

## Troubleshooting

### Common Issues

1. **Secret not decrypting**: Check that host key is in `.sops.yaml`
2. **Permission denied**: Ensure correct ownership in secret definition
3. **File not found**: Verify `sopsFile` path is correct
4. **Key not available**: Check `age.keyFile` or `age.sshKeyPaths`

### Debug Commands

```bash
# Check SOPS can decrypt
sops -d secrets/common/api-keys.yaml

# Verify age key
age-keygen -y ~/.config/sops/age/keys.txt

# Check systemd service for sops
systemctl status sops-nix
journalctl -u sops-nix -f

# Manual test decryption
nix-shell -p sops --run "sops -d secrets/common/api-keys.yaml"
```

## Rollback Plan

If migration fails, you can rollback to agenix:

1. Keep agenix secrets directory backup
2. Revert flake.nix changes
3. Revert module changes
4. Run `nixos-rebuild switch`

## Benefits After Migration

1. **Simpler editing**: Direct `sops` command instead of `agenix -e`
2. **Better organization**: Structured YAML/JSON instead of individual files
3. **Partial encryption**: Can see structure while values are encrypted
4. **Git-friendly**: Better diff visualization
5. **Multi-format**: Support for env files, JSON, INI formats
6. **Better integration**: Native systemd support

## References

- [sops-nix Documentation](https://github.com/Mic92/sops-nix)
- [SOPS Documentation](https://github.com/mozilla/sops)
- [Age Encryption](https://github.com/FiloSottile/age)
