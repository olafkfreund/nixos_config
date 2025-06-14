# 🗂️ NixOS Configuration

A modular, multi-host NixOS configuration with comprehensive secrets management, multi-user support, and declarative system administration.

## 🏗️ Architecture

### Multi-Host Support

- **P620 Workstation**: AMD-focused with ROCm GPU computing support
- **Razer Laptop**: Intel/NVIDIA hybrid graphics with power management
- **P510 Workstation**: Intel Xeon with NVIDIA CUDA support  
- **DEX5550 SFF**: Intel integrated graphics with efficiency optimizations

### Multi-User Management

- Dynamic user creation per host with role-based access
- Automated group membership and permission management
- Shared configurations with individual customization options
- Secure password management through Agenix integration

### Core Features

- **Flake-based Configuration**: Reproducible builds with locked dependencies
- **Modular Architecture**: Reusable modules for services, hardware, and user configurations
- **Secrets Management**: Comprehensive Agenix-based secret handling for all users
- **Home Manager Integration**: User environment management with dotfiles
- **Hardware Optimization**: Host-specific drivers and performance tuning
- **Development Environment**: Complete toolchain for multiple programming languages
- **Container Support**: Docker and Podman with multi-user access
- **Security Hardening**: Principle of least privilege and audit logging

## 🚀 Quick Start

### Initial Setup

1. **Clone the repository**:

   ```bash
   git clone <repository-url>
   cd nixos-config
   ```

2. **Initialize secrets management**:

   ```bash
   ./scripts/manage-secrets.sh init
   ./scripts/get-keys.sh
   # Edit secrets.nix with your actual SSH public keys
   nano secrets.nix
   ```

3. **Configure for your host**:

   ```bash
   # Copy and customize host configuration
   cp -r hosts/template hosts/your-hostname
   # Edit variables and hardware configuration
   nano hosts/your-hostname/variables.nix
   ```

4. **Apply configuration**:

   ```bash
   sudo nixos-rebuild switch --flake .#your-hostname
   ```

### Adding New Users

1. **Generate SSH keys for the user**:

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
   cat ~/.ssh/id_ed25519.pub  # Copy this key
   ```

2. **Update host configuration**:

   ```nix
   # hosts/your-hostname/variables.nix
   {
     hostUsers = [
       "existing-user"
       "new-user"  # Add new user here
     ];
   }
   ```

3. **Add user to secrets configuration**:

   ```nix
   # secrets.nix
   let
     newuser = "ssh-ed25519 AAAAC3... new-user@hostname";
     allUsers = [ existinguser newuser ];
   in
   {
     "secrets/user-password-newuser.age".publicKeys = [ newuser ] ++ relevantHosts;
   }
   ```

4. **Create user secrets and apply**:

   ```bash
   ./scripts/manage-secrets.sh create user-password-newuser
   ./scripts/manage-secrets.sh rekey
   sudo nixos-rebuild switch --flake .#your-hostname
   ```

## 🔐 Secrets Management

Our secrets management system uses Agenix for encrypted, declarative secret handling across all hosts and users.

### Key Features

- **Encrypted at Rest**: All secrets encrypted with age encryption
- **Role-Based Access**: Fine-grained access control by user role and host
- **Multi-Host Support**: Secrets accessible across designated systems
- **Key Rotation**: Support for SSH key rotation and secret rekeying
- **Recovery Tools**: Comprehensive tooling for handling key mismatches

### Daily Operations

```bash
# Create new secrets
./scripts/manage-secrets.sh create api-key-github
./scripts/manage-secrets.sh create database-password

# Edit existing secrets  
./scripts/manage-secrets.sh edit user-password-username

# Check system status
./scripts/manage-secrets.sh status

# List all secrets
./scripts/manage-secrets.sh list
```

### For detailed secrets management documentation, see [SECRETS_MANAGEMENT.md](docs/SECRETS_MANAGEMENT.md)

## 📁 Directory Structure

```
nixos-config/
├── flake.nix                 # Main flake configuration
├── secrets.nix              # Secret access control definitions
├── hosts/                   # Host-specific configurations
│   ├── p620/               # AMD workstation
│   ├── razer/              # Intel/NVIDIA laptop  
│   ├── p510/               # Intel Xeon workstation
│   └── dex5550/            # Intel SFF system
├── modules/                # Custom NixOS modules
│   ├── containers/         # Docker, Podman configurations
│   ├── desktop/           # Desktop environment modules
│   ├── development/       # Development tool configurations  
│   ├── security/          # Security and secrets management
│   └── default.nix        # Module imports
├── home/                  # Home Manager configurations
├── pkgs/                  # Custom package definitions
├── scripts/               # Management and utility scripts
├── secrets/               # Encrypted secret files (.age)
├── themes/                # Styling and theme configurations
└── docs/                  # Documentation
    ├── SECRETS_MANAGEMENT.md
    ├── HOST_SETUP.md
    └── TROUBLESHOOTING.md
```

## 🛠️ Development

### Building Configurations

```bash
# Test build without switching
nixos-rebuild build --flake .#hostname

# Build specific host configuration  
nix build .#nixosConfigurations.p620.config.system.build.toplevel

# Check flake validity
nix flake check
```

### Module Development

When creating new modules, follow our guidelines:

```nix
# modules/example/default.nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.example = {
    enable = lib.mkEnableOption "example module";
    
    setting = lib.mkOption {
      type = lib.types.str;
      default = "default-value";
      description = "Example setting with clear description";
      example = "example-value";
    };
  };

  config = lib.mkIf config.modules.example.enable {
    # Module implementation
  };
}
```

### Adding New Hosts

1. **Create host directory**: `mkdir hosts/new-hostname`
2. **Create configuration files**:

   ```bash
   # Basic structure
   hosts/new-hostname/
   ├── configuration.nix      # Main configuration
   ├── variables.nix         # Host-specific variables
   └── hardware-configuration.nix  # Hardware configuration
   ```

3. **Update flake.nix** to include the new host
4. **Configure secrets access** in `secrets.nix`
5. **Test and deploy**:

   ```bash
   nixos-rebuild build --flake .#new-hostname
   nixos-rebuild switch --flake .#new-hostname
   ```

## 🧪 Testing

### Configuration Validation

```bash
# Test all configurations
nix flake check

# Test specific host
nixos-rebuild build --flake .#hostname

# Validate Home Manager
home-manager build --flake .#username@hostname
```

### Secrets Testing

```bash
# Test secret decryption
agenix -d secrets/user-password-username.age > /dev/null

# Verify secret access
./scripts/manage-secrets.sh status

# Recovery testing
./scripts/recover-secrets.sh
```

## 🔧 Troubleshooting

### Common Issues

#### Build Failures

- Check flake lock consistency: `nix flake update`
- Verify module imports and syntax
- Check for circular dependencies

#### Secrets Issues  

- Verify SSH keys match `secrets.nix` configuration
- Use recovery tools: `./scripts/recover-secrets.sh`
- Check secret file permissions in `/run/agenix/`

#### User Management

- Ensure users are in host's `hostUsers` list
- Verify group memberships in user configuration
- Check Home Manager integration

### Getting Help

1. **Check documentation**: Review relevant docs in `docs/`
2. **Validate configuration**: Use `nix flake check` and build tests
3. **Check logs**: `journalctl -u nixos-rebuild` and systemd service logs
4. **Recovery tools**: Use provided scripts for secrets and configuration recovery

## 📚 Documentation

- [Secrets Management Guide](docs/SECRETS_MANAGEMENT.md) - Comprehensive secrets handling
- [Host Setup Guide](docs/HOST_SETUP.md) - Adding and configuring new hosts  
- [Module Development](docs/MODULE_DEVELOPMENT.md) - Creating custom modules
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Project Plan](docs/PROJECT_PLAN.md) - Development roadmap and completed features

## 🤝 Contributing

1. **Follow Guidelines**: Adhere to [NixOS contribution guidelines](https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md)
2. **Test Changes**: Validate configurations with `nix flake check`  
3. **Document Changes**: Update relevant documentation
4. **Security Review**: Ensure secrets and security configurations are properly handled

## 📄 License

This configuration is provided as-is for educational and personal use. Please review and understand all configurations before applying to your systems.

---

**Note**: This configuration manages multiple hosts with different hardware profiles and multi-user environments. Always test configurations in a safe environment before deploying to production systems.
