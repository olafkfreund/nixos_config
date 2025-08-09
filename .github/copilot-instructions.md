# NixOS Development Guidelines for GitHub Copilot

These instructions help GitHub Copilot understand our NixOS configuration preferences and coding standards.

## General Guidelines

- Use declarative configuration with NixOS modules
- Follow the [Nixpkgs contribution guidelines](https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md)
- Maintain pure and reproducible builds
- Use flakes for dependency management
- Prefer functional programming patterns

## Code Style

### Nix Expression Format

```nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Use 2 spaces for indentation
  # Place closing braces on their own line for better readability
}
```

### Naming Conventions

- Use camelCase for variable and function names
- Use descriptive names that reflect purpose
- Prefix private functions with underscore
- Use plural forms for lists/sets (e.g., `users`, `services`)

### Module Structure

- Group related options together
- Use type system for option declarations
- Document options with description field
- Include example values in documentation

## Best Practices

### Option Declarations

```nix
options.myModule = {
  enable = lib.mkEnableOption "my module";

  setting = lib.mkOption {
    type = lib.types.str;
    default = "value";
    description = "Clear description of the option";
    example = "example value";
  };
};
```

### Package Verification

- Always verify package names exist before using them in configurations
- Use the nixos-mcp server for package verification when available
- Alternatively, use `nix-env -f '<nixpkgs>' -qaP` to list and verify available packages
- Check packages against the current version of nixpkgs being used
- Prefer using the exact attribute path (e.g., `pkgs.python3Packages.requests` instead of just `requests`)

### Service Configuration

- Use systemd service units when appropriate
- Handle service dependencies explicitly
- Consider resource limits
- Implement proper shutdown behavior

### File Organization

- Separate concerns into distinct modules
- Use `default.nix` for module entry points
- Keep related configurations together
- Follow the standard NixOS module structure

## Common Patterns

### Package Overlays

```nix
final: prev: {
  myPackage = prev.myPackage.overrideAttrs (old: {
    # modifications
  });
}
```

### Service Definitions

```nix
systemd.services.myService = {
  description = "My Service";
  wantedBy = ["multi-user.target"];
  after = ["network.target"];
  serviceConfig = {
    ExecStart = "${package}/bin/service";
    Restart = "always";
  };
};
```

## Host-Specific Configurations

Our configuration manages several distinct hosts, each with unique hardware specifications that require tailored configurations:

### P620 Workstation

- **CPU**: AMD processor
- **GPU**: AMD graphics card
- **Use Case**: High-performance workstation
- **Special Considerations**:
  - Use AMD-specific drivers (`amdgpu`)
  - Enable ROCm for GPU computation when needed
  - Configure for optimal thermal management under heavy workloads

### Razer Laptop

- **CPU**: Intel processor
- **GPU**: NVIDIA graphics card
- **Use Case**: Mobile development platform
- **Special Considerations**:
  - Power management optimizations for battery life
  - Include laptop-specific modules (backlight, touchpad, etc.)
  - Configure hybrid graphics (NVIDIA Optimus)
  - Implement thermal throttling protection

### P510 Workstation

- **CPU**: Intel Xeon processor
- **GPU**: NVIDIA graphics card
- **Use Case**: Server/workstation hybrid
- **Special Considerations**:
  - Configure for ECC memory if available
  - Optimize for parallel workloads
  - Use NVIDIA proprietary drivers for CUDA support

### DEX5550 SFF System

- **CPU**: Intel processor (smaller form factor)
- **GPU**: Intel integrated graphics
- **Use Case**: Compact desktop/HTPC
- **Special Considerations**:
  - Intel graphics drivers and acceleration
  - Lower power consumption optimizations
  - Silent cooling profile when possible
  - Hardware video decoding support

### Host-Specific Module Pattern

```nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Host-specific imports
  imports = lib.optional (config.networking.hostName == "p620") ./hosts/p620;

  # Conditional configuration based on hostname
  config = lib.mkMerge [
    (lib.mkIf (config.networking.hostName == "razer") {
      # Razer-specific configuration
      hardware.nvidia.prime = {
        offload.enable = true;
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    })

    (lib.mkIf (config.networking.hostName == "dex5550") {
      # DEX5550-specific configuration
      hardware.opengl = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          vaapiIntel
        ];
      };
    })
  ];
}
```

## Testing and Validation

- Test configurations with `nixos-rebuild build`
- Verify service functionality
- Check for option type correctness
- Validate dependencies

## Security Considerations

- Avoid hardcoded secrets
- Use proper file permissions
- Implement least privilege principle
- Consider service isolation

## Performance

- Use binary caches when available
- Optimize build dependencies
- Consider resource usage in services
- Use proper garbage collection settings

## Documentation

### Module Documentation

- Document all custom options
- Include usage examples
- Explain dependencies
- Document any required system configuration

### Comment Style

```nix
# Single-line comments for brief explanations

/* Multi-line comments for
   detailed explanations */

# TODO: Mark todos clearly

# FIXME: Mark issues that need attention
```

## Error Handling

- Use assertions for configuration validation
- Provide helpful error messages
- Handle service failures gracefully
- Log important events

## Version Control

- Use meaningful commit messages
- Tag stable versions
- Document breaking changes
- Keep change history in CHANGELOG.md

## Resource Management

- Clean up temporary files
- Handle service cleanup
- Manage system resources appropriately
- Consider memory and CPU usage

## Integration

- Test with different NixOS versions
- Verify compatibility with common services
- Document integration requirements
- Handle upgrades gracefully

## Home-Manager Configuration

- Use Home-Manager for user-specific configurations
- Define Home-Manager modules in `home.nix` or `default.nix`
- Integrate Home-Manager with NixOS by enabling `programs.home-manager.enable`
- Use flakes for managing Home-Manager dependencies
- Document user-specific configurations for clarity

Remember to maintain reproducibility and purity in all configurations. The goal is to create maintainable, reliable, and well-documented NixOS configurations.
