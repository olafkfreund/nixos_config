# Cloud Provider Modules

This directory contains NixOS modules for various cloud provider tools and SDKs.

## Available Modules

- `default.nix` - Main entry point that imports all cloud provider modules
- `aws.nix` - Amazon Web Services (AWS) tools and SDK
- `azure.nix` - Microsoft Azure tools and SDK
- `cloud-tools.nix` - General cloud management tools
- `google.nix` - Google Cloud Platform tools and SDK
- `terraform.nix` - Terraform infrastructure as code tools

## Features

Each module provides:
- CLI tools for the respective cloud provider
- SDKs and development libraries
- Authentication utilities
- Resource management tools

## Usage

These modules can be enabled selectively in host configurations to provide cloud development and management capabilities. Enable them in your host's configuration.nix file:

```nix
{
  aws.packages.enable = true;
  azure.packages.enable = true;
  cloud-tools.packages.enable = true;
  google.packages.enable = true;
  terraform.packages.enable = true;
}
```