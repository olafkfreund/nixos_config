# NixOS Multi-Host Deployment Guide

## Overview

This repository uses an optimized Just-based deployment system for managing 4 NixOS hosts with advanced performance optimizations, parallel operations, and smart change detection.

## Quick Reference

### Fastest Commands (Recommended)

```bash
just quick-test           # Test all hosts in parallel (~1 min)
just quick-deploy HOST    # Deploy only if changed (~30 sec)
just quick-all           # Test all + deploy all (~3 min total)
```

### All Available Deployment Commands

#### Smart Deployment (Recommended)

```bash
just quick-deploy p620    # Deploy P620 only if configuration changed
just quick-deploy razer   # Deploy Razer only if configuration changed
just quick-deploy p510    # Deploy P510 only if configuration changed
just quick-deploy dex5550 # Deploy DEX5550 only if configuration changed
```

#### Standard Optimized Deployment

```bash
just p620     # Deploy to P620 workstation (AMD/ROCm)
just razer    # Deploy to Razer laptop (Intel/NVIDIA)
just p510     # Deploy to P510 media server (Intel Xeon/NVIDIA)
just dex5550  # Deploy to DEX5550 server (Intel integrated)
```

#### Advanced Deployment Options

```bash
just deploy-fast HOST         # Fast deployment with minimal builds
just deploy-local-build HOST  # Build locally, deploy remotely
just deploy-cached HOST       # Deploy with binary cache optimization
just emergency-deploy HOST    # Emergency deployment (skip tests)
```

#### Bulk Operations

```bash
just deploy-all              # Deploy to all hosts sequentially (~8 min)
just deploy-all-parallel     # Deploy to all hosts in parallel (~2 min)
just test-all-parallel       # Test all hosts in parallel (~1 min)
just build-all-parallel      # Build all configs in parallel (no deploy)
```

## Host Configuration

### Active Hosts

- **P620**: AMD workstation with ROCm acceleration
- **Razer**: Intel/NVIDIA laptop with Optimus graphics
- **P510**: Intel Xeon/NVIDIA media server with CUDA
- **DEX5550**: Intel SFF server with integrated graphics

### Network Configuration

- **Internal Network**: 192.168.1.0/24
- **DNS Server**: DEX5550 (192.168.1.222)
- **Binary Cache**: P620 (<http://p620:5000>)
- **Monitoring Server**: DEX5550 (Grafana: port 3001, Prometheus: port 9090)

## Performance Optimizations Applied

### 1. Nixos-rebuild Flags

- `--fast`: Skip unnecessary rebuild steps
- `--keep-going`: Continue on non-critical failures
- `--accept-flake-config`: Accept flake configuration automatically
- Removed `--impure`: No longer needed with pure flakes

### 2. Parallel Operations

- **Testing**: All hosts tested simultaneously
- **Building**: All configurations built in parallel
- **Deployment**: All hosts deployed concurrently

### 3. Smart Change Detection

```bash
# Only deploys if configuration actually changed
just quick-deploy HOST
```

### 4. Binary Cache Integration

```bash
# Uses P620's nix-serve cache for faster builds
just deploy-cached HOST
```

### 5. Network Optimizations

- Build host = target host (reduce network transfer)
- Local builds for slow networks
- SSH connection reuse

## Performance Benchmarks

### Testing Performance

| Operation        | Traditional | Optimized  | Improvement |
| ---------------- | ----------- | ---------- | ----------- |
| Test single host | 45 seconds  | 45 seconds | Same        |
| Test all hosts   | 4 minutes   | 1 minute   | 75% faster  |

### Deployment Performance

| Operation                 | Traditional | Optimized  | Improvement |
| ------------------------- | ----------- | ---------- | ----------- |
| Deploy single host        | 2 minutes   | 45 seconds | 62% faster  |
| Deploy all hosts          | 8 minutes   | 2 minutes  | 75% faster  |
| Smart deploy (no changes) | 2 minutes   | 5 seconds  | 95% faster  |

### Complete Workflows

| Workflow             | Traditional | Optimized    | Improvement |
| -------------------- | ----------- | ------------ | ----------- |
| Test + Deploy single | 3 minutes   | 30 seconds\* | 83% faster  |
| Test + Deploy all    | 12 minutes  | 3 minutes    | 75% faster  |

\*When using smart deployment with no changes

## Deployment Strategies by Scenario

### Development Iteration

**Scenario**: Making frequent configuration changes during development

```bash
# Fastest cycle - only deploys if changed
just quick-deploy HOST
```

### Production Deployment

**Scenario**: Deploying tested changes to production

```bash
# Full validation pipeline
just validate
just test-all-parallel
just deploy-all-parallel
```

### Emergency Fixes

**Scenario**: Critical security patches or urgent fixes

```bash
# Skip all tests for maximum speed
just emergency-deploy HOST
```

### Network Issues

**Scenario**: Deploying over slow or unreliable networks

```bash
# Build locally to minimize network transfer
just deploy-local-build HOST
```

### Initial Setup

**Scenario**: First-time deployment to new hosts

```bash
# Use binary cache for faster initial builds
just deploy-cached HOST
```

### CI/CD Pipeline

**Scenario**: Automated testing and deployment

```bash
# Parallel testing for speed
just test-all-parallel

# Smart deployment to skip unchanged hosts
for host in p620 razer p510 dex5550; do
    just quick-deploy $host
done
```

## Troubleshooting

### Common Issues

#### Deployment Hangs or Times Out

```bash
# Check host connectivity
just ping-hosts

# Try fast deployment
just deploy-fast HOST

# Use local build for network issues
just deploy-local-build HOST
```

#### Build Failures

```bash
# Test configuration first
just test-host HOST

# Check syntax
just check-syntax

# See what would change
just diff HOST
```

#### Slow Performance

```bash
# Use parallel operations
just test-all-parallel    # Instead of just test-all
just deploy-all-parallel  # Instead of just deploy-all

# Use smart deployment
just quick-deploy HOST    # Only if changed

# Check binary cache
just deploy-cached HOST   # Use P620 cache
```

#### No Changes but Still Deploying

```bash
# Verify with smart deployment
just quick-deploy HOST    # Should skip if no changes

# Check configuration diff
just diff HOST           # Shows actual differences
```

### Performance Debugging

#### Check Build Times

```bash
# Benchmark specific host
just bench-host HOST 3   # Run 3 builds and average

# Check parallel efficiency
just perf-parallel       # Test parallel build performance
```

#### Monitor Resource Usage

```bash
# Check memory usage during builds
just perf-memory

# Monitor cache performance
just perf-cache
```

## Advanced Features

### Binary Cache Server

P620 runs a nix-serve binary cache to speed up builds across all hosts:

- **URL**: <http://p620:5000>
- **Usage**: Automatic in `deploy-cached` commands
- **Benefits**: Shared build artifacts reduce rebuild times

### Tailscale VPN Integration

All hosts are connected via Tailscale mesh VPN:

- **Exit Node**: DEX5550 provides internet access
- **Subnet Routing**: Access to 192.168.1.0/24 network
- **Security**: All SSH access secured via Tailscale

### Monitoring Integration

Comprehensive monitoring via DEX5550:

- **Grafana**: <http://dex5550:3001> (or via Tailscale)
- **Prometheus**: <http://dex5550:9090>
- **Metrics**: All deployment performance tracked

## Best Practices

### 1. Use Smart Deployment

Always prefer `just quick-deploy HOST` over `just HOST` for development.

### 2. Test Before Deploy

Run `just quick-test` before bulk deployments.

### 3. Leverage Parallelism

Use parallel commands whenever possible:

- `just test-all-parallel`
- `just deploy-all-parallel`
- `just build-all-parallel`

### 4. Monitor Performance

Check deployment metrics in Grafana to identify bottlenecks.

### 5. Use Appropriate Strategy

Match deployment strategy to scenario:

- Development: `just quick-deploy`
- Production: `just quick-all`
- Emergency: `just emergency-deploy`

## Integration with Other Tools

### Git Hooks

Consider adding pre-commit hooks:

```bash
# .git/hooks/pre-commit
#!/bin/bash
just check-syntax || exit 1
just test-all-parallel || exit 1
```

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
- name: Test NixOS configurations
  run: just test-all-parallel

- name: Deploy if tests pass
  run: just deploy-all-parallel
```

### Monitoring Alerts

Grafana alerts configured for:

- Deployment failures
- Performance degradation
- Host connectivity issues

## Future Optimizations

### Planned Improvements

1. **Remote Build Caching**: Distributed builds across multiple hosts
2. **Incremental Deployments**: Deploy only changed services
3. **Health Checks**: Automated post-deployment validation
4. **Rollback Automation**: Automatic rollback on failure detection

### Performance Targets

- Single host deploy: < 30 seconds
- All hosts deploy: < 90 seconds
- Smart deploy (no changes): < 5 seconds
