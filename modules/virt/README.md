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

These modules provide virtualization capabilities, each behind a `features.virtualization` flag.
Each module typically defines:

- Service configuration
- Required packages
- User permissions
- Networking setup
- Storage configuration

Enable these modules in your host's configuration.nix file:

```nix
{
  features.virtualization = {
    enable = true;
    docker = true;
    libvirt = true;
    podman = true;
    # incus, spice, spiceGuestAgent, waydroid
  };
}
```

MicroVMs come from nixarchy's templates (`hosts/common/nixos/omarchy-microvm.nix`), not from this directory.
