# Virtualization Modules

This directory contains NixOS modules for virtualization technologies and container runtimes.

## Available Modules

- `default.nix` - Main entry point that imports all virtualization modules
- `docker.nix` - Docker container runtime configuration
- `incus.nix` - Incus system container manager (LXD fork)
- `libvirt.nix` - LibVirt virtualization platform
- `microvm.nix` - MicroVM lightweight virtual machine configuration
- `podman.nix` - Podman container runtime (daemonless alternative to Docker)
- `qemu.nix` - QEMU virtual machine manager
- `spice.nix` - SPICE protocol for virtual machine display
- `virt-viewer.nix` - Virtual machine viewer application

## Usage

These modules can be enabled selectively in host configurations to provide virtualization capabilities. Each module typically defines:

- Service configuration
- Required packages
- User permissions
- Networking setup
- Storage configuration

Enable these modules in your host's configuration.nix file:

```nix
{
  services.docker.enable = true;
  services.libvirt.enable = true;
  services.podman.enable = true;
  # ... other virtualization modules
}
```

For more complex setups like MicroVMs, refer to the specific module implementations and the host configurations where they are used (e.g., in the p510 host configuration).