# Gaming Configuration

This directory contains configurations for gaming-related tools and applications.

## Components

- `steam.nix` - Steam gaming platform configuration with Proton support

## Features

The gaming configurations provide:

- Steam platform with Linux native and Windows game support via Proton
- Performance optimizations for gaming
- Controller support
- Integration with system theme

## Usage

The Steam configuration can be imported in the user's Home Manager configuration. It's typically enabled on systems with dedicated graphics hardware like the Razer laptop and P620 workstation.

When used with the NVIDIA or AMD configurations from the host-specific settings, these configurations provide an optimized gaming experience with proper GPU acceleration.
