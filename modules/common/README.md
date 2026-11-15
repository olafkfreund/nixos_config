# Common NixOS Modules

This directory contains common modules that form the core of the modular NixOS configuration system.
These modules provide standardized configurations and a flexible feature flag system that can be
selectively enabled across different host machines.

## Feature Flag System

`features.nix` declares the grouped flags. Each implementing module reads its flag directly, e.g.
`modules/development/go.nix` gates on `config.features.development.enable && config.features.development.go`.
There is no separate implementation file (#2934). The Home Manager flags live in `Users/common/features.nix`.

### How It Works

The feature system provides a declarative way to enable or disable specific functionality across
your NixOS systems. Rather than using multiple `lib.mkForce` calls or complex conditionals, you can
simply toggle features on and off in your host configuration:

```nix
# Example host configuration
{ ... }: {
  # Enable development features
  features = {
    development = {
      enable = true;  # Master switch for all development tools
      python = true;  # Enable Python development specifically
      go = true;      # Enable Go development
      nodejs = false; # Disable Node.js
      # ...other options
    };

    # Enable virtualization with specific tools
    virtualization = {
      enable = true;
      docker = true;
      podman = false;
    };

    # ... other feature categories
  };
}
```

### Available Feature Categories

The system currently supports the following feature categories:

1. **Development Tools**
   - Python, Go, Node.js, Java, Lua, Nix
   - Shell, Cargo/Rust, GitHub, Devshell

2. **Virtualization**
   - Docker, Podman, Incus containers
   - SPICE, libvirt, Sunshine streaming

3. **Cloud Tools**
   - AWS, Azure, Google Cloud
   - Kubernetes, Terraform

4. **Security Tools**
   - 1Password, GnuPG

5. **Networking**
   - Tailscale VPN

6. **AI Tools**
   - Ollama AI

7. **Programs**
   - LazyGit, Thunderbird, Obsidian
   - Office tools, Webcam tools, Printing

8. **Media**
   - DroidCam

### Benefits

- **Consistency**: Standardized configuration across systems
- **Maintainability**: Change implementation in one place
- **Clarity**: Easy to see which features are enabled on each host
- **Modularity**: Add new features without changing host configs

## Other Common Modules

Besides the feature system, this directory contains other important shared configurations:

- `base-user.nix`: Standard user configuration
- `default.nix`: Entry point for common modules
- `electron.nix`: Electron applications configuration
- `environment.nix`: Common environment variables
- `merge-packages.nix`: Helper for merging package lists
- `networking.nix`: Shared networking configurations
- `sample-host-config.nix`: Template for new host configurations
- `sway.nix`: Sway window manager configuration

## Usage

To use these common modules, simply import the directory in your configuration:

```nix
{ ... }: {
  imports = [
    # Path to this common directory
    ../modules/common
    # ... other imports
  ];

  # Then configure features as needed
  features.development.enable = true;
  features.development.python = true;
  # ... other feature flags
}
```

## Extending the System

To add new features:

1. Add the flag in `features.nix` (or declare `features.<name>.enable` in the new module itself)
2. In the module that implements it, gate `config` on the flag directly
3. Import the module by path where it is needed

This modular approach allows for an easily extensible system that grows with your needs.
