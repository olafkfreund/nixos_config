# NixOS Host Templates

This directory contains templates for creating new hosts in the NixOS infrastructure. Each template provides a complete starting point for different types of hosts.

## Available Templates

### 1. Workstation Template (`workstation/`)
Full-featured desktop workstation with:
- Complete desktop environment (Hyprland/KDE)
- Development tools and IDEs
- Virtualization support (Docker, MicroVMs)
- AI provider integration
- Gaming support
- Advanced monitoring client

**Best for**: Primary development machines, powerful desktop systems

### 2. Server Template (`server/`)
Headless server configuration with:
- No desktop environment
- Network services focus
- Monitoring server capabilities
- Container orchestration
- Web services and APIs
- Security hardening

**Best for**: Dedicated servers, monitoring hosts, network services

### 3. Laptop Template (`laptop/`)
Mobile-optimized configuration with:
- Power management optimization
- Battery life optimization
- Mobile display management
- Lightweight resource usage
- Network roaming support
- Sleep/suspend optimization

**Best for**: Laptops, portable devices, battery-powered systems

## Quick Start

1. **Choose a template** based on your host type
2. **Copy the template** to a new host directory:
   ```bash
   cp -r templates/hosts/workstation hosts/new-hostname
   ```
3. **Customize variables.nix** with your host-specific settings
4. **Generate hardware configuration**:
   ```bash
   nixos-generate-config --show-hardware-config > hosts/new-hostname/nixos/hardware-configuration.nix
   ```
5. **Add host to flake.nix** in the nixosConfigurations section
6. **Deploy** the new configuration

## Template Structure

Each template contains:
- `configuration.nix` - Main configuration file
- `variables.nix` - Host-specific variables and settings
- `nixos/` - System configuration files
- `themes/` - Theme files (desktop hosts only)
- `README.md` - Template-specific documentation

## Customization Guide

See the individual template README files for detailed customization instructions:
- [Workstation Template Guide](workstation/README.md)
- [Server Template Guide](server/README.md)
- [Laptop Template Guide](laptop/README.md)

## Feature Matrix

| Feature | Workstation | Server | Laptop |
|---------|-------------|--------|--------|
| Desktop Environment | ✅ | ❌ | ✅ |
| Development Tools | ✅ | 🔧 | 🔧 |
| Virtualization | ✅ | ✅ | 🔧 |
| AI Providers | ✅ | 🔧 | 🔧 |
| Gaming Support | ✅ | ❌ | 🔧 |
| Power Management | 🔧 | ❌ | ✅ |
| Monitoring Client | ✅ | N/A | ✅ |
| Monitoring Server | 🔧 | ✅ | ❌ |

**Legend**: ✅ = Enabled by default, 🔧 = Configurable, ❌ = Not included

## Adding a New Host

### Step-by-Step Process

1. **Copy Template**:
   ```bash
   cp -r templates/hosts/workstation hosts/mynewhost
   ```

2. **Edit variables.nix**:
   - Set hostname, username, and description
   - Choose GPU type (amd/nvidia/intel/none)
   - Configure network settings
   - Set display configuration (if applicable)
   - Choose theme and appearance

3. **Generate Hardware Config**:
   ```bash
   nixos-generate-config --show-hardware-config > hosts/mynewhost/nixos/hardware-configuration.nix
   ```

4. **Update flake.nix**:
   ```nix
   nixosConfigurations = {
     # ... existing hosts
     mynewhost = lib.nixosSystem {
       inherit system;
       specialArgs = {
         inherit inputs system;
         hostUsers = [ "username" ]; # Your user(s)
       };
       modules = [
         ./hosts/mynewhost/configuration.nix
         # ... other common modules
       ];
     };
   };
   ```

5. **Test Configuration**:
   ```bash
   just test-host mynewhost
   ```

6. **Deploy**:
   ```bash
   just mynewhost  # If deploying to local machine
   # OR
   nixos-rebuild switch --flake .#mynewhost --target-host mynewhost
   ```

## Template Customization Options

### GPU Configuration
- **AMD**: ROCm acceleration, gaming support
- **NVIDIA**: CUDA support, AI workloads, gaming
- **Intel**: Integrated graphics, power efficiency
- **None**: Headless systems, servers

### Host Roles
- **Workstation**: Full desktop, development focus
- **Server**: Headless, service focus
- **Laptop**: Mobile optimization, power management

### Network Configuration
- **Static IP**: For servers and fixed workstations
- **DHCP**: For laptops and flexible hosts
- **Tailscale**: VPN integration for all hosts

### Feature Flags
Each template includes comprehensive feature flags:
```nix
features = {
  development.enable = true;    # Development tools
  virtualization.enable = true; # Docker, VMs
  ai.enable = true;             # AI providers
  monitoring.enable = true;     # Metrics collection
  desktop.enable = true;        # GUI (workstation/laptop only)
  gaming.enable = true;         # Gaming support
  media.enable = true;          # Media tools
};
```

## Common Customizations

### Changing GPU Type
Edit `variables.nix`:
```nix
gpu = "nvidia";  # or "amd", "intel", "none"
acceleration = "cuda";  # or "rocm", "none"
```

### Adding Users
Edit `flake.nix` hostUsers:
```nix
hostUsers = [ "username1" "username2" ];
```

### Network Configuration
Edit `variables.nix`:
```nix
hostMappings = {
  "192.168.1.100" = "mynewhost";
  "192.168.1.127" = "p510";
  # ... other hosts
};
```

### Desktop Theme
Edit `themes/stylix.nix` or `variables.nix`:
```nix
theme = {
  scheme = "gruvbox-dark-medium";
  wallpaper = ./themes/my-wallpaper.jpg;
};
```

## Testing Your New Host

### Syntax Check
```bash
just check-syntax
```

### Build Test
```bash
just test-host mynewhost
```

### Full System Test
```bash
just validate
```

### Deploy Test
```bash
# Local deployment
just mynewhost

# Remote deployment
nixos-rebuild switch --flake .#mynewhost --target-host mynewhost --build-host mynewhost
```

## Troubleshooting

### Common Issues

**Build Errors**: Check syntax with `just check-syntax`
**Missing Hardware**: Regenerate `hardware-configuration.nix`
**Network Issues**: Verify host mappings and DNS configuration
**Service Failures**: Check feature flags and module dependencies

### Getting Help

1. Check template-specific README files
2. Review existing host configurations for examples
3. Use incremental testing (`just test-host hostname`)
4. Check the main project documentation

---

**Ready to create your new host!** Choose the appropriate template and follow the step-by-step guide above.