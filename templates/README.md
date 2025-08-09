# NixOS Module Templates

This directory contains templates and code snippets for creating consistent NixOS modules within this configuration. All templates follow the established patterns and conventions used throughout the codebase.

## 📁 Directory Structure

```
templates/
├── modules/                    # Module templates
│   ├── basic-module.nix       # Basic module template
│   ├── service-module.nix     # Systemd service template
│   ├── development-tool.nix   # Development tool template
│   └── desktop-module.nix     # Desktop component template
├── snippets/                  # Code snippets and patterns
│   ├── common-patterns.nix    # Reusable patterns
│   └── quick-snippets.md      # Quick reference snippets
├── module-integration-guide.md # Comprehensive integration guide
└── README.md                  # This file
```

## 🚀 Quick Start

### 1. Choose a Template

Select the appropriate template based on your module type:

| Template               | Use Case                     | Example                         |
| ---------------------- | ---------------------------- | ------------------------------- |
| `basic-module.nix`     | Simple configuration modules | themes, tweaks, basic apps      |
| `service-module.nix`   | Background services          | databases, web servers, daemons |
| `development-tool.nix` | Programming tools            | languages, IDEs, compilers      |
| `desktop-module.nix`   | Desktop components           | window managers, panels, themes |

### 2. Copy and Customize

```bash
# Example: Creating a new service
cp templates/modules/service-module.nix modules/services/myservice.nix

# Edit the file to replace ALL_CAPS placeholders:
# - SERVICE_NAME → myservice
# - SERVICE_DESCRIPTION → "My Service Description"
# - SERVICE_PACKAGE → myservice-package
# - etc.
```

### 3. Add to Imports

```bash
# Add to modules/default.nix or category-specific default
echo "    ./services/myservice.nix" >> modules/default.nix
```

### 4. Test Your Module

```bash
# Check syntax
just check-syntax

# Test build
just test-host p620

# Deploy if successful
just p620
```

## 📚 Template Overview

### Basic Module Template

**File**: `modules/basic-module.nix`

**Purpose**: Simple modules that primarily configure existing NixOS options or install packages.

**Features**:

- Standard module structure with options/config
- Common option types (string, bool, package, list)
- Validation examples
- Environment variable setup

**Best For**: Themes, system tweaks, simple applications

### Service Module Template

**File**: `modules/service-module.nix`

**Purpose**: Comprehensive template for systemd services with full security hardening.

**Features**:

- Systemd service configuration
- User/group management
- Security hardening (NoNewPrivileges, PrivateTmp, etc.)
- Firewall integration
- Log rotation
- Health checks
- Configuration file generation

**Best For**: Databases, web servers, background daemons

### Development Tool Template

**File**: `modules/development-tool.nix`

**Purpose**: Development environments, programming languages, and dev tools.

**Features**:

- LSP (Language Server Protocol) support
- Debugger integration
- Formatter and linter configuration
- Shell integration
- Editor integration
- Project templates

**Best For**: Programming languages, IDEs, build tools, CLI tools

### Desktop Module Template

**File**: `modules/desktop-module.nix`

**Purpose**: Desktop environment components and window managers.

**Features**:

- Display configuration
- Input management (keyboard, mouse, touchpad)
- Theme and appearance settings
- Keybindings
- Workspace management
- Panel/bar configuration
- XDG portal setup

**Best For**: Window managers, desktop environments, panels, themes

## 🔧 Common Patterns

### Quick Snippets

For rapid development, check `snippets/quick-snippets.md` for:

- Basic module headers
- Common option types
- Service configurations
- User management
- Validation patterns
- Configuration file generation

### Code Patterns

The `snippets/common-patterns.nix` file contains reusable patterns for:

- **Option definitions**: All common types with examples
- **Service patterns**: Basic and hardened service configurations
- **User management**: System and normal user creation
- **Conditional config**: mkIf, optional, optionals patterns
- **Validation**: Assertions and warnings
- **Configuration files**: JSON, INI, YAML generation
- **Networking**: Firewall and service configuration

## 📖 Integration Guide

For detailed instructions on integrating modules into the configuration, see [`module-integration-guide.md`](./module-integration-guide.md).

The guide covers:

- **Module creation process** step-by-step
- **Feature flag system** and how to use it
- **Host configuration** patterns
- **Testing and validation** procedures
- **Best practices** and conventions
- **Common pitfalls** to avoid

## 🎯 Module Conventions

### File Structure

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.modules.CATEGORY.MODULE_NAME;
in {
  options.modules.CATEGORY.MODULE_NAME = {
    enable = mkEnableOption "DESCRIPTION";
    # ... other options
  };

  config = mkIf cfg.enable {
    # ... configuration
  };
}
```

### Naming Conventions

| Component           | Convention                    | Example                                   |
| ------------------- | ----------------------------- | ----------------------------------------- |
| **File name**       | `kebab-case.nix`              | `my-service.nix`                          |
| **Module path**     | `modules.category.camelCase`  | `modules.services.myService`              |
| **Feature flag**    | `features.category.camelCase` | `features.services.myService`             |
| **Config variable** | `cfg`                         | `cfg = config.modules.services.myService` |
| **Service name**    | `kebab-case`                  | `my-service`                              |
| **User/Group**      | `kebab-case`                  | `my-service`                              |

### Directory Categories

| Directory      | Purpose             | Examples                 |
| -------------- | ------------------- | ------------------------ |
| `ai/`          | AI and ML tools     | ollama, gemini-cli       |
| `services/`    | Background services | postgres, nginx, redis   |
| `development/` | Dev tools           | python, go, rust, vscode |
| `desktop/`     | GUI components      | hyprland, plasma, themes |
| `security/`    | Security tools      | secrets, ssh-hardening   |
| `monitoring/`  | Observability       | prometheus, grafana      |

## ✅ Template Checklist

When creating a new module, ensure:

- [ ] **Template selected** appropriately for module type
- [ ] **All placeholders replaced** (search for ALL_CAPS)
- [ ] **Module added to imports** in `modules/default.nix`
- [ ] **Feature flag defined** and connected
- [ ] **Naming conventions followed** consistently
- [ ] **Security hardening applied** (for services)
- [ ] **Validation added** (assertions/warnings)
- [ ] **Syntax check passes** (`just check-syntax`)
- [ ] **Build test passes** (`just test-all`)
- [ ] **Documentation complete** with examples

## 🔍 Testing Your Module

### 1. Syntax Validation

```bash
just check-syntax
```

### 2. Build Testing

```bash
# Test specific host
just test-host p620

# Test all hosts
just test-all
```

### 3. Module Evaluation

```bash
# Check module options
nix eval .#nixosConfigurations.p620.config.modules.services.myService

# Check generated config
nix eval .#nixosConfigurations.p620.config.systemd.services.my-service
```

### 4. Integration Testing

```bash
# Enable in host config
features.services.myService = true;

# Build and deploy
just p620
```

## 🚨 Common Issues

### Missing Imports

**Error**: `error: attribute 'myService' missing`
**Fix**: Add module to imports in `modules/default.nix`

### Type Mismatches

**Error**: `A definition for option ... is not of type ...`
**Fix**: Check option types in template (types.str vs types.package)

### Feature Flag Issues

**Error**: Module not enabled despite feature flag
**Fix**: Ensure feature flag connects to module enable option

### Service Failures

**Error**: Service fails to start
**Fix**: Check user permissions, paths, and security settings

## 📞 Support

For questions or issues:

1. **Check the integration guide** for detailed explanations
2. **Review existing modules** for pattern examples
3. **Test incrementally** to isolate issues
4. **Use syntax and build checks** to catch errors early

## 🎉 Examples

### Simple Service Example

```bash
# 1. Copy template
cp templates/modules/service-module.nix modules/services/redis.nix

# 2. Edit placeholders
# SERVICE_NAME → redis
# SERVICE_PACKAGE → redis
# etc.

# 3. Add to imports
echo "    ./services/redis.nix" >> modules/default.nix

# 4. Enable in host
features.services.redis = true;

# 5. Test and deploy
just test-host p620 && just p620
```

### Development Tool Example

```bash
# 1. Copy template
cp templates/modules/development-tool.nix modules/development/rust.nix

# 2. Customize for Rust
# TOOL_NAME → rust
# TOOL_PACKAGE → rustc
# etc.

# 3. Enable LSP, formatter, etc.
features.development.rust = true;
```

This template system ensures consistency, maintainability, and follows established best practices across the entire NixOS configuration.

---

**Happy NixOS module development!** 🎉
