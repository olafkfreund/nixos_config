# NixOS Multi-Host Deployment Guide

## Overview

This repository uses an optimized Just-based deployment system for managing 3 NixOS hosts with
advanced performance optimizations, parallel operations, and smart change detection.

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
```

#### Standard Optimized Deployment

```bash
just p620     # Deploy to P620 workstation (AMD/ROCm)
just razer    # Deploy to Razer laptop (Intel/NVIDIA)
just p510     # Deploy to P510 media server (Intel Xeon/NVIDIA)
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

- **p620** (192.168.1.222): AMD workstation with ROCm acceleration
- **razer** (192.168.1.77): Intel/NVIDIA laptop with Optimus graphics
- **p510** (192.168.1.75): Intel Xeon/NVIDIA media server, and a desktop since
  2026-08-31. **Never build or deploy it without asking first.**

DEX5550 is offline; Samsung and HP are decommissioned.

### Network configuration

- **Internal network**: 192.168.1.0/24, gateway 192.168.1.254
- **Host names**: `~/.ssh/config` uses raw LAN IPs. The `.lan` domain died with
  the old router.
- **Binary cache**: none. No nix-serve/harmonia exists in this repo;
  substituters are cache.nixos.org and nix-community.cachix.org only. See
  [Binary cache strategy](CACHE-STRATEGY.md).
- **Monitoring**: removed (Prometheus/Grafana/Loki/Alertmanager). Use
  `journalctl` and `systemctl status`.

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

### 4. Build on the target host

```bash
# Passes --build-host HOST, so the target builds its own closure instead of
# building here and copying it over. Despite the name, no binary cache is
# involved — there isn't one.
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
for host in p620 razer p510; do
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

There is no local binary cache. No nix-serve/harmonia service exists anywhere in this
repo, and nothing listens on p620:5000. `modules/nix/nix.nix` only substitutes from
cache.nixos.org and nix-community.cachix.org.

### Tailscale VPN integration

All hosts are connected via the Tailscale mesh, which is used for remote SSH
access — not for caching, and no host advertises itself as an exit node.

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

### 4. Watch the deploy

There is no metrics stack. Use `journalctl -f` on the target and
`just diff HOST` for the closure delta before switching.

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

### Deploy failures

There are no configured alerts. A failed deploy is caught by reading the
`switch-to-configuration` output and `systemctl --failed` on the target.

Two known false alarms on this fleet:

- **`switch` exits 4 on p510 and razer even on success** — p510 reloads the
  user `dbus-broker` mid-switch; razer has a self-healing `syncthing-init`
  race. Verify `/run/current-system` and `systemctl --failed`, not the exit
  code. Never pipe the build through `tail`, which masks the real exit status.
- **One permanently-dead unit rolls back the whole deploy** (e.g. `thermald`
  on AMD). Read the "the following units failed" line and fix the unit.

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
