# NixOS Configuration Templates

This directory contains templates for quickly setting up new NixOS hosts with the refactored configuration system.

## Available Templates

### 1. Minimal Template
Basic NixOS configuration with essential features:
- Core system utilities
- Basic security settings
- SSH access
- Minimal package set

Use for: Servers, containers, or minimal installations

### 2. Workstation Template  
Full-featured desktop workstation:
- Desktop environment (Hyprland)
- Development tools
- Multimedia support
- Gaming support (optional)
- AI/ML tools (optional)

Use for: Development workstations, creative work

### 3. Server Template
Server-optimized configuration:
- Security hardening
- Service monitoring
- Backup solutions
- Network optimization
- Container support

Use for: Production servers, home servers

## Usage

### Using Nix Flake Templates
```bash
# Create new configuration from template
nix flake new -t github:yourusername/nixos-config#minimal ./new-host
nix flake new -t github:yourusername/nixos-config#workstation ./new-host
nix flake new -t github:yourusername/nixos-config#server ./new-host
```

### Manual Setup
1. Copy the desired template directory
2. Customize the configuration for your hardware
3. Update hostnames and user information
4. Generate hardware-configuration.nix
5. Build and test the configuration

## Customization Guide

### 1. Hardware Configuration
```bash
# Generate hardware configuration
nixos-generate-config --root /mnt --show-hardware-config > hardware-configuration.nix
```

### 2. Host-Specific Settings
Edit the main configuration file to set:
- Hostname
- User accounts
- Hardware profile
- Enabled features

### 3. Network Configuration
Configure networking for your environment:
- Static IP vs DHCP
- Wireless configuration
- VPN settings
- Firewall rules

### 4. Service Configuration
Enable/disable services as needed:
- SSH server
- Web services
- Database services
- Monitoring tools

## Template Structure

Each template includes:
- `flake.nix` - Main flake configuration
- `configuration.nix` - Host configuration
- `hardware-configuration.nix.example` - Example hardware config
- `README.md` - Template-specific documentation
- `home.nix` - Home Manager configuration (where applicable)

## Best Practices

1. **Start Simple**: Begin with the minimal template and add features as needed
2. **Test Builds**: Always test with `nixos-rebuild build` before switching
3. **Use Profiles**: Leverage the profile system for common configurations
4. **Document Changes**: Keep notes about customizations for future reference
5. **Version Control**: Initialize git repository for configuration tracking
