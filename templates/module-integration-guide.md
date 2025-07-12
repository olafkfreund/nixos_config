# NixOS Module Integration Guide

This guide explains how to properly integrate new modules into the existing NixOS configuration following the established patterns and conventions.

## Table of Contents

1. [Module Creation Process](#module-creation-process)
2. [Module Categories](#module-categories) 
3. [Integration Steps](#integration-steps)
4. [Feature Flag System](#feature-flag-system)
5. [Host Configuration](#host-configuration)
6. [Testing and Validation](#testing-and-validation)
7. [Best Practices](#best-practices)
8. [Common Pitfalls](#common-pitfalls)

## Module Creation Process

### Step 1: Choose the Right Template

Select the appropriate template based on your module type:

- **Basic Module**: `templates/modules/basic-module.nix` - For simple configuration modules
- **Service Module**: `templates/modules/service-module.nix` - For systemd services
- **Development Tool**: `templates/modules/development-tool.nix` - For programming languages/tools  
- **Desktop Component**: `templates/modules/desktop-module.nix` - For desktop environment components

### Step 2: Copy and Customize

```bash
# Example: Creating a new service module
cp templates/modules/service-module.nix modules/services/myservice.nix

# Edit the file to replace placeholders
# - SERVICE_NAME → myservice
# - SERVICE_DESCRIPTION → "My Service Description"
# - SERVICE_PACKAGE → myservice (if package exists in nixpkgs)
```

### Step 3: Follow Naming Conventions

| Component | Convention | Example |
|-----------|------------|---------|
| File name | `kebab-case.nix` | `my-service.nix` |
| Module path | `modules.category.name` | `modules.services.myService` |
| Config variable | `cfg` | `cfg = config.modules.services.myService` |
| Service user | `service-name` | `myservice` |
| Service group | `service-name` | `myservice` |

## Module Categories

### Directory Structure
```
modules/
├── ai/                    # AI and machine learning tools
├── common/                # Shared/base configurations
├── containers/            # Containerization (Docker, Podman)
├── desktop/               # Desktop environments and WMs
├── development/           # Development tools and languages
├── monitoring/            # Monitoring and observability
├── networking/            # Network configuration
├── programs/              # Application configurations
├── security/              # Security tools and hardening
├── services/              # System services
├── system/                # System-level configurations
├── system-tweaks/         # Performance and system tweaks
└── virt/                  # Virtualization
```

### Category Guidelines

| Category | Purpose | Examples |
|----------|---------|----------|
| `ai/` | AI tools, models, inference | ollama, gemini-cli, ai-providers |
| `services/` | Background services | databases, web servers, daemons |
| `development/` | Dev tools & languages | python, go, rust, editors |
| `desktop/` | GUI components | window managers, themes, panels |
| `security/` | Security & hardening | secrets, ssh, firewall |
| `monitoring/` | Observability tools | prometheus, grafana, exporters |

## Integration Steps

### 1. Create Module File

```bash
# Choose location based on category
mkdir -p modules/services
cp templates/modules/service-module.nix modules/services/myservice.nix
```

### 2. Add to Module Imports

Edit `modules/default.nix` or the category-specific default file:

```nix
# modules/default.nix
{
  imports = [
    # ... existing imports
    ./services/myservice.nix
  ];
}
```

Or for category-specific:
```nix
# modules/services/default.nix  
{
  imports = [
    # ... existing imports
    ./myservice.nix
  ];
}
```

### 3. Define Feature Flag

Add to the features system in the appropriate category:

```nix
# In your module file
options.features.services.myService = mkEnableOption "MyService support";

# In modules/default.nix features definition
features.services = {
  # ... existing services
  myService = mkEnableOption "MyService support";
};
```

### 4. Connect Feature to Module

```nix
# In your module file
config = mkIf config.features.services.myService {
  modules.services.myService.enable = true;
  # Additional feature-level configuration
};
```

## Feature Flag System

### How Features Work

The configuration uses a two-tier system:

1. **Feature Flags** (`features.*`) - High-level toggles in host configs
2. **Module Options** (`modules.*`) - Detailed module configuration

### Feature Categories

```nix
features = {
  development = {
    enable = mkEnableOption "Development environment";
    python = mkEnableOption "Python development";
    go = mkEnableOption "Go development";
    # ... other dev tools
  };
  
  services = {
    enable = mkEnableOption "System services";
    database = mkEnableOption "Database services";
    monitoring = mkEnableOption "Monitoring stack";
    # ... other services
  };
  
  desktop = {
    enable = mkEnableOption "Desktop environment";
    hyprland = mkEnableOption "Hyprland window manager";
    # ... other desktop components
  };
};
```

### Adding New Feature Categories

1. **Define in modules/default.nix**:
```nix
options.features.myCategory = {
  enable = mkEnableOption "My category description";
  feature1 = mkEnableOption "Feature 1";
  feature2 = mkEnableOption "Feature 2";
};
```

2. **Connect to modules**:
```nix
config = mkMerge [
  (mkIf config.features.myCategory.enable {
    # Base category configuration
  })
  
  (mkIf config.features.myCategory.feature1 {
    modules.myCategory.feature1.enable = true;
  })
];
```

## Host Configuration

### Enabling Features in Hosts

In host configuration files (e.g., `hosts/p620/configuration.nix`):

```nix
features = {
  services = {
    enable = true;
    myService = true;  # Enable your new service
  };
  
  development = {
    enable = true;
    python = true;
    myTool = true;     # Enable your new development tool
  };
};
```

### Advanced Module Configuration

For detailed configuration beyond the feature flag:

```nix
# Enable via feature flag
features.services.myService = true;

# Detailed configuration
modules.services.myService = {
  enable = true;  # Set by feature flag
  port = 8080;
  settings = {
    key1 = "value1";
    key2 = "value2";
  };
};
```

## Testing and Validation

### 1. Syntax Check
```bash
just check-syntax
```

### 2. Build Test
```bash
# Test specific host
just test-host p620

# Test all hosts
just test-all
```

### 3. Module-Specific Testing
```bash
# Test module evaluation
nix eval .#nixosConfigurations.p620.config.modules.services.myService.enable

# Test service config
nix eval .#nixosConfigurations.p620.config.systemd.services.myservice
```

### 4. Flake Check
```bash
nix flake check
```

## Best Practices

### 1. Module Structure

- **Always use the standard header pattern**
- **Use `with lib; let cfg = ...` consistently**  
- **Define options before config**
- **Use `mkIf cfg.enable` for all configuration**

### 2. Option Design

- **Provide sensible defaults**
- **Include examples for complex options**
- **Use appropriate types (types.port for ports, etc.)**
- **Add descriptions for all options**

### 3. Security

- **Use dedicated users for services**
- **Apply security hardening by default**
- **Validate sensitive configuration**
- **Use agenix for secrets**

### 4. Validation

- **Add assertions for critical requirements**
- **Include helpful warnings**
- **Validate configuration consistency**

### 5. Documentation

- **Document all options thoroughly**
- **Include usage examples**
- **Explain security implications**

## Common Pitfalls

### 1. ❌ Wrong Import Location
```nix
# DON'T: Add directly to host config
imports = [ ./modules/services/myservice.nix ];

# DO: Add to modules/default.nix
imports = [ ./services/myservice.nix ];
```

### 2. ❌ Missing Feature Flag Connection
```nix
# DON'T: Only module options
modules.services.myService.enable = true;

# DO: Both feature flag and module
features.services.myService = true;
# This automatically enables the module
```

### 3. ❌ Inconsistent Naming
```nix
# DON'T: Inconsistent naming
options.modules.services.my_service = ...;  # snake_case
config.features.services.myservice = ...;   # lowercase

# DO: Consistent camelCase
options.modules.services.myService = ...;
config.features.services.myService = ...;
```

### 4. ❌ Missing lib Import
```nix
# DON'T: Use lib functions without import
{ config, pkgs, ... }: {
  options.test = lib.mkOption { ... };  # lib not imported
}

# DO: Import lib and use with pattern  
{ config, lib, pkgs, ... }:
with lib; {
  options.test = mkOption { ... };
}
```

### 5. ❌ Hardcoded Paths
```nix
# DON'T: Hardcode paths
ExecStart = "/run/current-system/sw/bin/myservice";

# DO: Use package references
ExecStart = "${cfg.package}/bin/myservice";
```

### 6. ❌ Missing Validation
```nix
# DON'T: No validation
port = mkOption {
  type = types.int;
  default = 22;  # Potentially dangerous
};

# DO: Validate and warn
port = mkOption {
  type = types.port;
  default = 8080;
};

assertions = [{
  assertion = cfg.port != 22 || cfg.allowSSHPort;
  message = "Using SSH port requires allowSSHPort = true";
}];
```

## Integration Checklist

Before submitting your new module:

- [ ] Template used and customized appropriately
- [ ] Added to appropriate imports in `modules/default.nix`
- [ ] Feature flag defined and connected
- [ ] Follows naming conventions
- [ ] Includes proper validation (assertions/warnings)
- [ ] Uses security hardening for services
- [ ] Syntax check passes (`just check-syntax`)
- [ ] Build test passes (`just test-all`)
- [ ] Documented with examples
- [ ] Tested in at least one host configuration

## Example: Complete Integration

Here's a complete example of integrating a new service:

1. **Create module file**: `modules/services/myapp.nix`
2. **Add import**: Add to `modules/default.nix`
3. **Add feature flag**: Add to `features.services.myApp`
4. **Connect feature**: Feature enables module automatically
5. **Host config**: Set `features.services.myApp = true;`
6. **Test**: Run `just test-host hostname`
7. **Deploy**: Run `just hostname`

This process ensures consistency and maintainability across the entire NixOS configuration.