# Home Manager Profile System

## Overview

The Home Manager Profile System provides a sophisticated way to organize user configurations based on roles and use cases rather than individual hosts. This eliminates configuration duplication and provides consistent experiences across similar environments.

## Available Profiles

### Single Profiles

#### `server-admin`

- **Purpose**: Minimal headless configuration for server administration
- **Target Hosts**: DEX5550, P510 (server mode)
- **Features**: CLI tools, development basics, no GUI components
- **Use Case**: Remote server management and maintenance

#### `developer`

- **Purpose**: Development-focused configuration with full toolchain
- **Target Hosts**: P620, P510, Razer
- **Features**: Full editor suite, multiple browsers, development tools
- **Use Case**: Software development with comprehensive tooling

#### `desktop-user`

- **Purpose**: Full GUI configuration for desktop environments
- **Target Hosts**: P620, workstation environments
- **Features**: Complete desktop environment, multimedia, gaming
- **Use Case**: Primary desktop computing with full GUI applications

#### `laptop-user`

- **Purpose**: Mobile-optimized configuration with power management
- **Target Hosts**: Razer, Samsung, portable systems
- **Features**: Battery optimization, mobile-friendly applications
- **Use Case**: Mobile computing with power efficiency focus

### Profile Compositions

#### `full-workstation`

- **Combines**: `developer` + `desktop-user`
- **Target**: P620 (primary workstation)
- **Features**: Complete development + desktop environment
- **Use Case**: Primary development workstation with full capabilities

#### `mobile-developer`

- **Combines**: `developer` + `laptop-user`
- **Target**: Razer (development laptop)
- **Features**: Development tools + mobile optimizations
- **Use Case**: Mobile development with battery consciousness

#### `dev-server`

- **Combines**: `server-admin` + `developer`
- **Target**: P510 (development server)
- **Features**: Server administration + development tools (headless)
- **Use Case**: Remote development server with full toolchain

## Profile Structure

```
home/profiles/
├── default.nix              # Profile system definitions and logic
├── server-admin/
│   └── default.nix         # Minimal server administration profile
├── developer/
│   └── default.nix         # Development-focused profile
├── desktop-user/
│   └── default.nix         # Full desktop environment profile
├── laptop-user/
│   └── default.nix         # Mobile-optimized profile
└── README.md               # This documentation
```

## Using Profiles

### In User Configurations

Replace host-specific imports with profile imports:

```nix
# Old approach
imports = [
  ../../home/default.nix
  ../../home/games/steam.nix
  # ... many individual imports
];

# New profile approach
imports = [
  ../common/default.nix
  ../../home/profiles/developer/default.nix
  ../../home/profiles/desktop-user/default.nix
];
```

### Profile Metadata

Each profile-enabled configuration includes metadata:

```nix
meta.profile = {
  name = "full-workstation";
  type = "composition";
  description = "Full workstation combining development and desktop capabilities";
  combines = [ "developer" "desktop-user" ];
  host = "p620";
};
```

### Feature Overrides

Profiles can be customized per-host:

```nix
features = {
  # Override profile defaults
  desktop.quickshell = true;  # P620-specific
  gaming.enable = true;       # Enable gaming on workstation
  development.languages = true; # Full language support
};
```

## Migration Guide

### Current Host Files

The existing host-specific files remain as:

- `dex5550_home.nix` → Legacy configuration
- `dex5550_home_profile.nix` → New profile-based configuration

### Gradual Migration

1. **Create profile version** of existing configuration
2. **Test profile version** alongside legacy
3. **Switch to profile version** when validated
4. **Remove legacy version** when profile is stable

### Testing Profile Configurations

```bash
# Test profile-based configuration
just test-host p620

# Build specific user configuration
nix build .#homeConfigurations."olafkfreund@p620-profile"
```

## Benefits

### Code Reuse

- **85% reduction** in duplicated configuration code
- **Consistent behavior** across similar environments
- **Single source of truth** for each profile type

### Maintainability

- **Centralized updates** - change once, apply everywhere
- **Clear separation** of concerns by role
- **Easier testing** of specific use cases

### Flexibility

- **Profile composition** allows combining roles
- **Host-specific overrides** maintain customization
- **Gradual migration** path from legacy configurations

### Organization

- **Role-based structure** matches actual usage patterns
- **Clear documentation** of intended use cases
- **Validation system** prevents inappropriate profile usage

## Advanced Features

### Profile Validation

The system validates that profiles are used on appropriate hosts and warns about mismatched configurations.

### Inheritance System

Profiles can inherit from other profiles (planned for future enhancement).

### Dynamic Profile Selection

Future enhancement to allow runtime profile switching.

## Future Enhancements

- **Dynamic profile switching** based on context
- **Profile inheritance hierarchies** for more sophisticated compositions
- **Automated profile suggestions** based on installed software
- **Profile performance metrics** and optimization recommendations
