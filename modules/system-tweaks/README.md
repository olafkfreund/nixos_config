# System Tweaks

This directory contains NixOS modules for various system-level optimizations and tweaks.

## Directory Structure

- `kernel-tweaks/` - Kernel-level optimizations for different memory configurations
  - `32GB-SYSTEM/` - Optimizations for systems with 32GB RAM
  - `64GB-SYSTEM/` - Optimizations for systems with 64GB RAM
  - `226GB-SYSTEM/` - Optimizations for systems with 226GB RAM
- `storage-tweaks/` - Storage optimizations
  - `SSD/` - Optimizations for SSD storage

## Features

These modules provide:
- Memory management optimizations
- I/O schedulers tuning
- Virtual memory subsystem tweaks
- Filesystem optimizations
- Swap configuration

## Usage

The system tweaks are designed to be imported by host configurations based on their hardware specifications. For example:

```nix
# For a system with 32GB of RAM
imports = [
  ../../modules/system-tweaks/kernel-tweaks/32GB-SYSTEM/32GB-SYSTEM.nix
];

# For a system with SSD storage
imports = [
  ../../modules/system-tweaks/storage-tweaks/SSD/SSD-tweak.nix
];
```

These tweaks should be chosen based on the specific hardware of each system to maximize performance and reliability.