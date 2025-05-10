# AI Tool Modules

This directory contains NixOS modules for AI-related tools and utilities.

## Available Modules

- `chatgpt.nix` - OpenAI ChatGPT CLI integration
- `ollama.nix` - Ollama for running local large language models

## Features

The AI modules provide:
- Local language model support through Ollama
- Command-line interface for ChatGPT
- Optimization for running AI models on your hardware

## Usage

These modules can be enabled selectively in host configurations to provide AI capabilities:

```nix
{
  ai.ollama.enable = true;
  # Other AI-related modules
}
```

The ollama module supports different acceleration types (CUDA, ROCm, CPU) depending on your hardware. This can be configured in your host configuration:

```nix
{
  services.ollama.acceleration = "cuda"; # For NVIDIA GPUs
  # or
  services.ollama.acceleration = "rocm"; # For AMD GPUs
  # or
  services.ollama.acceleration = "cpu"; # For CPU-only systems
}
```