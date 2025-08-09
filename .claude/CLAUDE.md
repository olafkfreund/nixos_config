# NixOS Infrastructure Project Context

## Project Overview

This is a sophisticated multi-host NixOS configuration using flakes with extensive modularization, secrets management, and automation. The repository manages 4 active hosts with different hardware profiles and supports multi-user environments.

## Active Hosts

- **p620**: AMD Ryzen workstation with ROCm GPU acceleration, monitoring server
- **razer**: Intel/NVIDIA laptop with Optimus graphics, mobile development
- **p510**: Intel Xeon/NVIDIA workstation with CUDA support, high-performance computing
- **dex5550**: Intel SFF with integrated graphics, optimized for efficiency

## Key Architecture Components

- **Flake-based configuration** with extensive modularization
- **Home Manager integration** for user configurations
- **Agenix secrets management** with SSH key-based access control
- **Comprehensive monitoring** with Prometheus/Grafana on DEX5550
- **AI infrastructure** with multi-provider support (Anthropic, OpenAI, Gemini, Ollama)
- **Performance analytics** and hardware monitoring
- **Automated deployment** with Just-based workflows

## Development Patterns

- All services MUST be created as modules in `modules/` directory
- Use feature flags for conditional module loading
- Follow declarative configuration principles
- Maintain security through least privilege and proper secret management
- Test changes with `just test-host HOST` before deploying

## Deployment Workflows

- `just validate` - Comprehensive validation
- `just test-host HOST` - Test specific host configuration
- `just quick-deploy HOST` - Smart deployment (only if changed)
- `just deploy-all-parallel` - Deploy to all hosts simultaneously

When working on this project, always consider multi-host compatibility, security implications, and maintainability.
