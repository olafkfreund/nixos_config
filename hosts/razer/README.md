# Razer Laptop Configuration

This directory contains the NixOS configuration for the Razer laptop.

## Configuration Structure

- `configuration.nix` - Main system configuration file
- `nixos/` - NixOS-specific configurations
  - `hardware-configuration.nix` - Generated hardware configuration
  - `boot.nix` - Boot loader and kernel configuration
  - `nvidia.nix` - NVIDIA GPU configuration
  - `power.nix` - Advanced power management settings for laptop
  - `i18n.nix` - Internationalization settings
  - `envvar.nix` - Environment variables
  - `screens.nix` - Display configuration
- `themes/` - Theme configurations

## Features

- NVIDIA GPU support with Optimus (hybrid graphics)
- Advanced power management for laptop battery life
- Development environment for multiple languages
- Gaming capabilities
- Optimized mobile workflow
- Modern Wayland desktop experience

## Local LLM (served by p620)

razer runs no model itself. p620's Ollama serves Qwen3.6-35B-A3B, a mixture-of-experts
model, on demand over the tailnet. It runs at about 91 tokens/s from razer (#2467).

To use it from razer, point any OpenAI-compatible client at `http://p620:11434/v1`, or call
Ollama's API directly:

```bash
curl -s http://p620:11434/api/generate -d '{"model":"hf.co/unsloth/Qwen3.6-35B-A3B-GGUF:UD-IQ4_XS","prompt":"hello","stream":false}'
```

Using the model unloads p620's coding model (`qwen3.8:27b`) until its next request.

## Hardware

The Razer laptop appears to have:

- Intel CPU
- NVIDIA GPU
- High-resolution display
- SSD storage
- Good amount of RAM for development and gaming

## Usage

This configuration is used as the target for `nixos-rebuild` when deploying to the Razer laptop:

```bash
sudo nixos-rebuild switch --flake /home/olafkfreund/.config/nixos#razer
```
