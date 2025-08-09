# Kubernetes Modules

This directory contains NixOS modules for Kubernetes (K8s) container orchestration tools and utilities.

## Available Modules

- `default.nix` - Main entry point that imports all Kubernetes modules
- `k8s.nix` - Core Kubernetes tools and utilities
- `openshift.nix` - OpenShift-specific tools and configurations

## Features

The Kubernetes modules provide:

- Command-line tools (`kubectl`, `k9s`, `helm`, etc.)
- Deployment and management utilities
- Development tools for Kubernetes
- OpenShift client tools

## Usage

These modules can be enabled in your host configuration:

```nix
{
  k8s.packages.enable = true;
  openshift.packages.enable = true;
}
```

These tools complement the Kubernetes cluster setup available in the P510 host configuration, which uses MicroVMs to create a local K3s cluster.

## Related Configurations

- `/home/olafkfreund/.config/nixos/hosts/p510/guests/` - Contains K3s server and agent configurations
- `/home/olafkfreund/.config/nixos/hosts/p510/nixos/microvm/` - Contains MicroVM configurations for K3s
