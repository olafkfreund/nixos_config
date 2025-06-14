# NixOS Configuration Refactor Documentation

## Overview

This refactored NixOS configuration implements a modular, type-safe, and maintainable approach to system configuration following NixOS best practices.

## Key Improvements

### 1. Simplified Flake Structure
- **Reduced Input Complexity**: Fewer direct inputs with strategic `follows` declarations
- **Cleaner Outputs**: Organized host configurations using our standardized builder
- **Development Tools**: Added dev shell with linting and formatting tools

### 2. Modular Architecture
```
lib/                    # Library functions
├── default.nix        # Main library exports
├── host-builders.nix  # Host configuration builders
├── profiles.nix       # Configuration profiles
├── hardware.nix       # Hardware abstraction
├── utils.nix          # Utility functions
└── testing.nix        # Testing framework

profiles/              # Reusable configuration profiles
├── base.nix          # Minimal base system
├── desktop.nix       # Desktop environment
├── development.nix   # Development tools
└── server.nix        # Server configuration

modules/               # Organized by function
├── core/             # Core system modules
├── hardware/         # Hardware abstraction
├── desktop/          # Desktop environments
├── development/      # Development tools
├── applications/     # Applications
├── security/         # Security settings
└── services/         # System services
```

### 3. Type-Safe Configuration
- **Proper Option Declarations**: All custom modules now declare options with types
- **Validation**: Built-in validation for common misconfigurations
- **Documentation**: All options include descriptions and examples

### 4. Hardware Abstraction
- **Hardware Profiles**: Predefined profiles for different hardware types
- **Conditional Configuration**: Hardware-specific settings applied automatically
- **Modular Design**: Easy to add new hardware profiles

## Usage

### Host Configuration
```nix
# Simple host setup
p620 = lib.mkHost {
  hostname = "p620";
  hostType = "workstation";
  users = ["olafkfreund"];
  hardwareProfile = "amd-workstation";
};
```

### Profile System
```nix
# Enable features through profiles
{
  custom.base.enable = true;
  custom.desktop.enable = true;
  custom.development.enable = true;
}
```

### Hardware Profiles
Available profiles:
- `amd-workstation`: AMD CPU + GPU workstation
- `intel-laptop`: Intel laptop with power management
- `nvidia-gaming`: NVIDIA gaming system
- `htpc-intel`: HTPC with Intel graphics

### Custom Module Options
```nix
# Desktop configuration
custom.desktop = {
  enable = true;
  session = "hyprland";
  theme.name = "gruvbox-dark";
};

# Development configuration
custom.development = {
  enable = true;
  languages = ["nix" "rust" "python"];
  editors = ["nixvim" "vscode"];
  containers.enable = true;
};
```

## Migration Guide

### 1. Backup Current Configuration
```bash
cp flake.nix flake.nix.backup
cp -r modules modules.backup
```

### 2. Gradual Migration
1. Start with the new flake structure
2. Migrate one host at a time
3. Use compatibility shims for existing modules
4. Test each change thoroughly

### 3. Host-Specific Migration
For each host:
1. Create hardware profile if needed
2. Update host configuration to use new builder
3. Migrate custom settings to new option system
4. Test build and deployment

## Testing

### Build Testing
```bash
# Test specific host
nixos-rebuild build --flake .#p620

# Test all hosts
nix flake check
```

### Validation
```nix
# Use built-in testing framework
nix-instantiate --eval -E '(import ./lib/testing.nix {}).runTests'
```

## Development Workflow

### Setup Development Environment
```bash
nix develop
```

### Code Quality
```bash
# Format code
alejandra .

# Lint code
statix check .

# Find dead code
deadnix .
```

### Adding New Features

#### 1. New Module
```nix
# modules/category/new-module.nix
{config, lib, pkgs, ...}: let
  cfg = config.custom.category.newModule;
in {
  options.custom.category.newModule = {
    enable = lib.mkEnableOption "new module";
    # ... other options
  };
  
  config = lib.mkIf cfg.enable {
    # ... implementation
  };
}
```

#### 2. New Hardware Profile
```nix
# modules/hardware/profiles/new-profile.nix
{config, lib, pkgs, ...}: let
  cfg = config.custom.hardware;
in {
  config = lib.mkIf (cfg.profile or null == "new-profile") {
    # Hardware-specific configuration
  };
}
```

#### 3. New Host
```nix
# In flake.nix
newHost = lib.mkHost {
  hostname = "newhost";
  hostType = "workstation";
  users = ["username"];
  hardwareProfile = "profile-name";
  extraModules = [
    # Host-specific modules
  ];
};
```

## Troubleshooting

### Common Issues

1. **Module Import Errors**
   - Check import paths in module default.nix files
   - Ensure all required modules are imported

2. **Option Type Errors**
   - Verify option declarations match usage
   - Check for typos in option paths

3. **Hardware Detection Issues**
   - Ensure hardware profile matches actual hardware
   - Check kernel modules and drivers

4. **Service Conflicts**
   - Use built-in validation to detect conflicts
   - Check service dependencies

### Debug Mode
```bash
# Enable debug output
nixos-rebuild switch --flake .#hostname --show-trace
```

## Best Practices

### Module Design
1. Always declare options with proper types
2. Use `lib.mkIf` for conditional configuration
3. Document all options with descriptions
4. Include examples for complex options

### Configuration Management
1. Use profiles for common patterns
2. Keep host-specific config minimal
3. Prefer composition over inheritance
4. Test changes in isolated environment

### Performance
1. Use binary caches for common packages
2. Minimize evaluation overhead
3. Cache frequently used derivations
4. Use overlays sparingly

## Future Enhancements

### Planned Features
1. **Configuration Templates**: Standardized templates for common setups
2. **Automated Testing**: CI/CD integration for configuration validation
3. **Deployment Tools**: Automated deployment and rollback tools
4. **Monitoring Integration**: Built-in monitoring and alerting

### Extensibility
The refactored configuration is designed to be easily extensible:
- Add new profiles without changing existing code
- Hardware profiles are self-contained
- Module system allows easy feature additions
- Testing framework ensures stability
