# Security Modules

This directory contains NixOS modules for security-related tools and configurations.

## Available Modules

- `default.nix` - Main entry point that imports all security modules
- `gnupg.nix` - GnuPG configuration for encryption and signing
- `onepassword.nix` - 1Password password manager integration
- `yubikey.nix` - YubiKey hardware security key support

## Features

The security modules provide:
- Password and secret management with 1Password
- Encryption and digital signatures with GnuPG
- Hardware-based two-factor authentication with YubiKey
- Integration with system authentication mechanisms

## Usage

These modules can be enabled selectively in host configurations:

```nix
{
  security.onepassword.enable = true;
  security.gnupg.enable = true;
  # Other security modules
}
```

For optimal security, combine these modules with proper system hardening settings in your NixOS configuration.