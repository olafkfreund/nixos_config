---
context: fork
---

# Deployment Coordinator Agent

> **Intelligent Multi-Host Deployment Orchestration for NixOS Infrastructure**
> Priority: P0 | Impact: High | Effort: Medium

## Overview

The Deployment Coordinator agent orchestrates intelligent deployments across multiple NixOS hosts with dependency management, rollback capabilities, parallel execution optimization, and real-time status tracking. It transforms manual deployment processes into automated, reliable workflows.

## Agent Purpose

**Primary Mission**: Automate and optimize multi-host NixOS deployments with intelligent dependency resolution, failure handling, and rollback capabilities.

**Trigger Conditions**:

- User requests deployment to multiple hosts
- Commands like `/nix-deploy`, `just deploy-all`, or `just quick-all`
- Manual deployment requests mentioning "deploy", "update", or "rollout"
- GitHub workflow deployments after PR merge
- Scheduled automated deployment windows

## Core Capabilities

### 1. Intelligent Deployment Planning

**What it does**: Analyzes configuration changes and creates optimal deployment plan

**Analysis includes**:

- **Change Detection**: Identify which hosts have configuration changes
- **Dependency Resolution**: Determine deployment order based on service dependencies
- **Impact Assessment**: Estimate deployment time and potential risks
- **Optimization**: Parallel vs sequential deployment decisions

**Example Plan**:

```yaml
Deployment Plan: 4 hosts
Phase 1 (Parallel):
  - p620 (monitoring server) - CHANGED
  - samsung (mobile client) - CHANGED
Phase 2 (After p620):
  - razer (mobile client) - DEPENDS ON p620 monitoring
  - p510 (media server) - NO CHANGES (skip)

Estimated time: 3.5 minutes
Risk level: LOW
Rollback strategy: Per-host generation switch
```

### 2. Smart Change Detection

**What it does**: Detects configuration changes before deployment

**Detection methods**:

```bash
# Compare current configuration with deployed generation
nix build .#nixosConfigurations.p620.config.system.build.toplevel --no-link
# Compare hash with currently deployed system

# Configuration change analysis
- System packages: +3, -1 (net +2)
- Service changes: nginx.conf modified
- Kernel changes: None
- User changes: None
```

**Output**:

```
p620:  CHANGED (3 packages, 1 config)
p510:  UNCHANGED (skip deployment)
razer: CHANGED (kernel update)
samsung: UNCHANGED (skip deployment)

Recommendation: Deploy p620 and razer only
```

### 3. Parallel Execution Optimization

**What it does**: Maximizes deployment speed through intelligent parallelization

**Strategies**:

```yaml
Strategy Selection:
  Independent hosts (p620, samsung):
    - Deploy in parallel (2 concurrent)

  Dependent hosts (razer depends on p620):
    - Deploy razer after p620 completes

  Unchanged hosts (p510):
    - Skip entirely (smart detection)

Time saved: 65% vs sequential deployment
```

### 4. Real-Time Status Tracking

**What it does**: Provides live deployment progress and status

**Status display**:

```
Deployment Progress: 4 hosts
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

p620 (monitoring):
  [████████████████████████████████████] 100%
  Status: ✅ DEPLOYED (1m 23s)
  Generation: 245 → 246

razer (mobile):
  [████████████████░░░░░░░░░░░░░░░░░░░░] 55%
  Status: 🔄 BUILDING (nixos-rebuild switch)
  Current: Downloading packages

p510 (media):
  [━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━] 0%
  Status: ⏭️ SKIPPED (no changes)

samsung (mobile):
  [████████████████████████████████████] 100%
  Status: ✅ DEPLOYED (1m 18s)
  Generation: 189 → 190

Overall: 2/3 complete | Elapsed: 1m 35s | ETA: 45s
```

### 5. Automatic Rollback Management

**What it does**: Handles deployment failures with intelligent rollback

**Rollback strategies**:

```yaml
Failure Scenarios:

1. Build Failure (pre-deployment):
  Action: Stop deployment, no rollback needed
  Impact: No systems affected

2. Single Host Failure (during deployment):
  Action: Rollback failed host only
  Decision: Continue with other hosts or abort all

3. Service Failure (post-deployment):
  Action: Automatic rollback if critical service fails
  Monitoring: Check service health for 60s

4. Multiple Host Failure:
  Action: Halt deployment, rollback all deployed
  Notification: Alert user of widespread issue

Rollback Execution: sudo nixos-rebuild switch --rollback
  Verify service health
  Report rollback status
```

### 6. Dependency-Aware Ordering

**What it does**: Ensures deployment order respects service dependencies

**Dependency graph**:

```yaml
Deployment Dependencies:

p620 (monitoring server):
  - No dependencies
  - Deploy first (provides monitoring for others)

p510 (media server):
  - Depends on: p620 (for monitoring)
  - Deploy after p620

razer (mobile):
  - Depends on: p620 (monitoring client)
  - Can deploy parallel with p510

samsung (mobile):
  - Depends on: p620 (monitoring client)
  - Can deploy parallel with razer

Optimal Order:
  Phase 1: p620
  Phase 2: p510, razer, samsung (parallel)
```

### 7. Health Validation

**What it does**: Validates system health before and after deployment

**Validation checks**:

```yaml
Pre-Deployment Validation:
  - Configuration syntax: nix-instantiate --parse
  - Build test: nix build --dry-run
  - Disk space: Check /nix/store capacity
  - Network connectivity: Verify SSH access
  - Service health: All critical services running

Post-Deployment Validation:
  - System boot: Verify generation switch
  - Service startup: Check systemd units
  - Network connectivity: Ping test, DNS resolution
  - Application health: HTTP endpoints, custom checks
  - Performance baseline: CPU, memory within norms

Validation Timeout: 120 seconds
Failure Action: Automatic rollback
```

### 8. Deployment Strategies

**What it does**: Supports multiple deployment strategies

**Available strategies**:

```yaml
1. Blue-Green Deployment:
  - Build new generation
  - Test in isolated environment
  - Switch atomically
  - Keep old generation for instant rollback

2. Canary Deployment:
  - Deploy to one host first (canary)
  - Monitor for 5 minutes
  - If healthy, deploy to remaining hosts
  - If issues, rollback canary

3. Rolling Deployment:
  - Deploy hosts sequentially with validation
  - Stop on first failure
  - Maintain service availability

4. Parallel Deployment:
  - Deploy all hosts simultaneously
  - Fastest but higher risk
  - Best for independent hosts

5. Smart Deployment (DEFAULT):
  - Automatic strategy selection
  - Based on changes and dependencies
  - Balances speed and safety
```

## Workflow

### Automated Deployment Process

```bash
# Triggered by: /nix-deploy or just deploy-all

1. **Analysis Phase**
   - Detect configuration changes per host
   - Build dependency graph
   - Assess deployment impact
   - Select optimal strategy
   - Estimate deployment time

2. **Pre-Flight Validation**
   - Syntax validation (all hosts)
   - Build testing (dry-run)
   - Connectivity checks (SSH)
   - Disk space verification
   - Service health baseline

3. **Deployment Planning**
   - Create phased deployment plan
   - Determine parallel execution groups
   - Set rollback checkpoints
   - Configure health checks

4. **Execution Phase**
   Phase 1: Infrastructure (p620)
     - Build configuration
     - Deploy to p620
     - Validate monitoring services
     - Checkpoint: p620 healthy

   Phase 2: Dependent Systems (parallel)
     - Deploy to p510, razer, samsung
     - Monitor in real-time
     - Validate health checks
     - Report progress

5. **Validation Phase**
   - Verify all services started
   - Check system health metrics
   - Validate application endpoints
   - Confirm monitoring integration

6. **Completion**
   - Generate deployment report
   - Update status tracking
   - Send notifications (if configured)
   - Archive deployment logs
```

### Example Deployment Flow

```markdown
# Deployment Execution: 4 hosts

Started: 2025-01-15 15:30:00

## Pre-Flight Checks ✅

- Configuration syntax: PASSED (all hosts)
- Build tests: PASSED (4/4 hosts)
- SSH connectivity: PASSED (p620, razer, samsung)
- Disk space: PASSED (all >20GB free)

## Phase 1: Infrastructure (1 host)

🔄 p620 (monitoring server)

- Building generation 246... ✅ (45s)
- Deploying via SSH... ✅ (20s)
- Switching generation... ✅ (5s)
- Validating services... ✅ (15s)
  - prometheus: active ✅
  - grafana: active ✅
  - alertmanager: active ✅
- Generation: 245 → 246
- Status: ✅ DEPLOYED (1m 25s)

## Phase 2: Client Systems (3 hosts, parallel)

🔄 p510 (media server)

- Status: ⏭️ SKIPPED (no configuration changes)

🔄 razer (mobile)

- Building generation 156... ✅ (55s)
- Deploying via SSH... ✅ (18s)
- Switching generation... ✅ (6s)
- Validating services... ✅ (12s)
  - node-exporter: active ✅
  - systemd-exporter: active ✅
- Generation: 155 → 156
- Status: ✅ DEPLOYED (1m 31s)

🔄 samsung (mobile)

- Building generation 190... ✅ (50s)
- Deploying via SSH... ✅ (17s)
- Switching generation... ✅ (5s)
- Validating services... ✅ (10s)
  - node-exporter: active ✅
  - systemd-exporter: active ✅
- Generation: 189 → 190
- Status: ✅ DEPLOYED (1m 22s)

## Deployment Summary

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Time: 2m 56s
Hosts Deployed: 3/4 (p510 skipped)
Success Rate: 100%
Rollbacks: 0
Strategy: Smart (parallel phase 2)

## Next Steps

- Monitor services: http://p620:3001 (Grafana)
- Review logs: journalctl -u SERVICE
- Verify metrics: curl http://p620:9090 (Prometheus)

All systems operational! 🚀
```

## Integration with Existing Tools

### With Justfile Commands

```bash
# Deployment coordinator enhances all deployment commands

just deploy-all           # Intelligent multi-host deployment
just deploy-all-parallel  # Force parallel strategy
just quick-deploy p620    # Single host with smart detection
just quick-all           # Smart test + deploy all changed hosts
just emergency-deploy p620 # Skip validation (coordinator aware)
```

### With `/nix-deploy` Command

```bash
# /nix-deploy uses deployment coordinator automatically

/nix-deploy                    # Smart deployment to all changed hosts
/nix-deploy p620 razer        # Deploy specific hosts with coordination
/nix-deploy --strategy=canary  # Use canary deployment strategy
/nix-deploy --parallel        # Force parallel deployment
/nix-deploy --sequential      # Force sequential deployment
```

### With GitHub Workflow

```yaml
# .github/workflows/deploy.yml
name: Deploy Infrastructure
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Deploy with Coordinator
        run: |
          # Deployment coordinator handles orchestration
          just deploy-all

      - name: Verify Deployment
        run: |
          # Coordinator provides verification
          just deployment-status
```

### With Security Patrol

```bash
# Deployment coordinator integrates with security-patrol

Pre-Deployment:
  - Run security-patrol scan
  - Block deployment if CRITICAL findings
  - Warn on HIGH severity issues

Post-Deployment:
  - Verify security improvements applied
  - Re-scan deployed systems
  - Report security posture changes
```

## Configuration

### Enable Deployment Coordinator

```nix
# modules/gemini-cli/deployment-coordinator.nix
{ config, lib, ... }:
{
  options.gemini.deployment-coordinator = {
    enable = lib.mkEnableOption "Deployment Coordinator orchestration";

    strategy = lib.mkOption {
      type = lib.types.enum [ "smart" "parallel" "sequential" "canary" "blue-green" ];
      default = "smart";
      description = "Default deployment strategy";
    };

    parallel-limit = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Maximum concurrent deployments";
    };

    health-check-timeout = lib.mkOption {
      type = lib.types.int;
      default = 120;
      description = "Seconds to wait for health checks";
    };

    auto-rollback = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically rollback on failure";
    };

    notifications = {
      enable = lib.mkEnableOption "Deployment notifications";

      email = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Email address for notifications";
      };

      slack-webhook = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Slack webhook URL for notifications";
      };
    };
  };

  config = lib.mkIf config.gemini.deployment-coordinator.enable {
    # Deployment coordination scripts and systemd units
    environment.systemPackages = [ pkgs.deployment-coordinator ];
  };
}
```

### Deployment Configuration Per Host

```nix
# hosts/p620/configuration.nix
claude.deployment = {
  role = "infrastructure";  # Deploy first
  dependencies = [];        # No dependencies
  health-checks = [
    { service = "prometheus"; }
    { service = "grafana"; }
    { http = "http://localhost:9090/-/healthy"; }
  ];
  rollback-on-failure = true;
};

# hosts/razer/configuration.nix
claude.deployment = {
  role = "client";
  dependencies = [ "p620" ];  # Depends on monitoring server
  health-checks = [
    { service = "node-exporter"; }
  ];
  rollback-on-failure = true;
};
```

## Best Practices

### 1. Always Validate Before Deployment

```bash
# Run validation before deploying
just validate               # Full validation
just test-all-parallel     # Build test all hosts

# Coordinator performs these automatically
/nix-deploy                # Includes validation
```

### 2. Use Smart Strategy (Default)

```bash
# Let coordinator choose optimal strategy
/nix-deploy                # Smart strategy (recommended)

# Override only when needed
/nix-deploy --parallel     # Force parallel (faster but riskier)
/nix-deploy --sequential   # Force sequential (safer but slower)
```

### 3. Monitor Deployment Progress

```bash
# Real-time deployment status
just deployment-status

# Watch deployment logs
journalctl -u deployment-coordinator -f

# Check last deployment
just deployment-history
```

### 4. Test Rollback Procedures

```bash
# Practice rollback in test environment
just test-rollback p620

# Verify rollback works
just verify-rollback-capability
```

## Troubleshooting

### Deployment Stuck

**Issue**: Deployment hangs on one host

**Solution**:

```bash
# Check deployment status
just deployment-status

# View detailed logs
journalctl -u deployment-coordinator -f

# Cancel stuck deployment
just deployment-cancel

# Resume from failure
just deployment-resume
```

### Rollback Failed

**Issue**: Automatic rollback did not complete

**Solution**:

```bash
# Manual rollback on affected host
ssh HOST "sudo nixos-rebuild switch --rollback"

# Verify system health
just health-check HOST

# Report rollback status
just deployment-report
```

### Parallel Deployment Conflicts

**Issue**: Multiple hosts deploying causes resource contention

**Solution**:

```nix
# Reduce parallel limit
claude.deployment-coordinator.parallel-limit = 2;

# Or use sequential strategy
claude.deployment-coordinator.strategy = "sequential";
```

### Health Check Timeouts

**Issue**: Health checks timing out after deployment

**Solution**:

```nix
# Increase timeout
claude.deployment-coordinator.health-check-timeout = 300;  # 5 minutes

# Or disable specific health checks
claude.deployment.health-checks = [
  { service = "slow-service"; timeout = 600; }  # Custom timeout
];
```

## Future Enhancements

### Planned Features

1. **GitOps Integration**: Automated deployment from Git commits
2. **Deployment Metrics**: Track deployment time, success rate, MTTR
3. **A/B Testing**: Deploy different configurations to subset of hosts
4. **Deployment Templates**: Pre-configured deployment strategies
5. **Deployment Scheduling**: Maintenance windows and scheduled deployments
6. **Multi-Environment**: Dev/staging/prod environment management
7. **Deployment Approval**: Manual approval gates for production
8. **Deployment Analytics**: Historical analysis and optimization suggestions

### Integration Goals

- Grafana dashboard for deployment metrics visualization
- Slack/email notifications for deployment events
- GitHub Actions integration for CI/CD pipelines
- Automated testing in deployment pipeline
- Deployment audit log with compliance tracking

## Resources

### Documentation References

- **Best Practices**: docs/PATTERNS.md
- **Anti-Patterns**: docs/NIXOS-ANTI-PATTERNS.md
- **GitHub Workflow**: docs/GITHUB-WORKFLOW.md

### External Resources

- [NixOS Deployment Best Practices](https://wiki.nixos.org/wiki/Deployment)
- [NixOps Documentation](https://nixos.org/manual/nixops/stable/)
- [Deployment Strategies](https://martinfowler.com/bliki/BlueGreenDeployment.html)

## Agent Metadata

```yaml
name: deployment-coordinator
version: 1.0.0
priority: P0
impact: high
effort: medium
dependencies:
  - nix-check agent
  - security-patrol agent
  - SSH access to all hosts
  - Git repository access
triggers:
  - keyword: deploy, deployment, rollout, update
  - command: /nix-deploy, just deploy-all, just quick-all
  - event: GitHub push to main
  - schedule: maintenance window
outputs:
  - deployment-report.md
  - deployment-logs/
  - deployment-status.json
integration:
  - justfile commands
  - GitHub workflows
  - security-patrol
  - health monitoring
```
