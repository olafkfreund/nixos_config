# Qwen-Code NixOS Package

A NixOS package for [qwen-code](https://github.com/QwenLM/qwen-code), an AI-powered coding assistant using Qwen3-Coder models.

## Overview

This package provides the `qwen-code` CLI tool with comprehensive AI-assisted development capabilities:

- **Interactive Terminal UI**: React-based interface for seamless coding assistance
- **Code Analysis**: Intelligent file context analysis and code understanding
- **Sandbox Execution**: Safe code execution environment
- **Multiple AI Providers**: Support for various Qwen3-Coder model variants
- **IDE Integration**: Compatible with various development environments

## Usage

The package provides two command variants:

```bash
# Primary command
qwen-code --help

# Short alias
qwen --help
```

### Basic Examples

```bash
# Interactive mode
qwen-code

# Direct prompt
qwen-code -p "Explain this Python function"

# Include all files in context
qwen-code --all-files -p "Review my entire codebase"

# Debug mode
qwen-code --debug -p "Help me debug this issue"
```

### Configuration

Set your API key via environment variable:

```bash
export QWEN_API_KEY="your-api-key-here"
```

Or configure via agenix (automatically detected at `/run/agenix/api-qwen`).

## Build and Install

```bash
# Build the package
nix-build -E "with import <nixpkgs> {}; callPackage ./default.nix {}"

# Test the result
./result/bin/qwen --help
```

### Integration in NixOS Configuration

This package is already integrated into the NixOS configuration and available system-wide on:

- P620 (AMD workstation)
- P510 (Intel/NVIDIA server)
- Razer (Intel/NVIDIA laptop)

## Source

Built from the [sid115/qwen-code](https://github.com/sid115/qwen-code) fork, which provides proper NixOS packaging support using `buildNpmPackage` with pre-fetched npm dependencies.

## License

Apache 2.0 - See the [upstream repository](https://github.com/QwenLM/qwen-code) for details.
