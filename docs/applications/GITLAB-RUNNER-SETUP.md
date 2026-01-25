# GitLab Runner Setup Guide

> Complete guide for setting up GitLab Runner on your NixOS infrastructure

## Overview

GitLab Runner is an application that works with GitLab CI/CD to run jobs in a pipeline. This guide covers setting up a local GitLab Runner for CI/CD testing and automation.

## Prerequisites

1. **GitLab Account**: Access to GitLab.com or self-hosted GitLab instance
2. **Registration Token**: From your GitLab project/group/instance
3. **Docker** (optional): Required for Docker executor

## Quick Start

### 1. Get Registration Token

**For Project Runner:**

```bash
# Navigate to: GitLab Project → Settings → CI/CD → Runners
# Click "New project runner"
# Select platform: Linux
# Add tags (optional): docker, linux, nix
# Copy the registration token
```

**For Group Runner:**

```bash
# Navigate to: GitLab Group → Settings → CI/CD → Runners
# Copy the registration token
```

### 2. Store Registration Token Securely

Using agenix for secure token storage:

```bash
# Create secret file
./scripts/manage-secrets.sh create gitlab-runner-token

# Add the following content:
CI_SERVER_URL=https://gitlab.com
REGISTRATION_TOKEN=your-registration-token-here

# Encrypt and commit
```

### 3. Configure GitLab Runner in Your Host

**Example: P620 Workstation (Docker Runner)**

Add to `hosts/p620/configuration.nix`:

```nix
{
  services.gitlab-runner-local = {
    enable = true;
    concurrent = 4;  # Run up to 4 jobs simultaneously

    # Optional: Use agenix secret for registration
    # registrationConfigFile = config.age.secrets.gitlab-runner-token.path;

    services = [
      {
        name = "docker-runner-p620";
        url = "https://gitlab.com";
        executor = "docker";
        dockerImage = "nixos/nix:latest";  # Use Nix-enabled image
        dockerPrivileged = false;  # Set true for Docker-in-Docker
        dockerVolumes = [ "/cache" "/nix:/nix:ro" ];  # Mount Nix store read-only
        tagList = [ "docker" "linux" "nix" "amd" ];
        runUntagged = false;
        limit = 2;  # Maximum 2 concurrent jobs for this runner
      }
    ];
  };

  # Ensure Docker is available
  virtualisation.docker.enable = true;
}
```

**Example: Razer Laptop (Shell Runner)**

Add to `hosts/razer/configuration.nix`:

```nix
{
  services.gitlab-runner-local = {
    enable = true;
    concurrent = 2;  # Laptop has fewer resources

    services = [
      {
        name = "shell-runner-razer";
        url = "https://gitlab.com";
        executor = "shell";  # Run directly on system
        tagList = [ "shell" "linux" "mobile" ];
        runUntagged = false;
        limit = 1;
      }
    ];
  };
}
```

### 4. Deploy Configuration

```bash
# Test configuration
just test-host p620

# Deploy
just quick-deploy p620

# Or use traditional deployment
just p620
```

## Manual Registration (First Time Setup)

After deploying, you need to register the runner with GitLab:

```bash
# SSH to the host
ssh p620

# Register runner (interactive)
sudo gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.com" \
  --registration-token "YOUR_TOKEN_HERE" \
  --executor "docker" \
  --docker-image "nixos/nix:latest" \
  --description "P620 Docker Runner" \
  --tag-list "docker,linux,nix,amd" \
  --run-untagged="false" \
  --locked="false" \
  --access-level="not_protected"

# Verify registration
sudo gitlab-runner list
```

## Executor Types

### 1. Docker Executor (Recommended)

**Pros:**

- Isolated environment for each job
- Easy to configure
- Supports custom Docker images
- Clean state for every build

**Cons:**

- Requires Docker daemon
- Slightly more overhead
- Need to handle Nix store access

**Configuration:**

```nix
{
  executor = "docker";
  dockerImage = "nixos/nix:latest";  # Or "alpine:latest"
  dockerPrivileged = false;  # Enable for Docker-in-Docker
  dockerVolumes = [
    "/cache"
    "/nix:/nix:ro"  # Mount Nix store (read-only)
  ];
}
```

**Recommended Docker Images:**

- `nixos/nix:latest` - Full Nix support
- `alpine:latest` - Minimal, fast
- `ubuntu:latest` - Compatible with most tools
- `debian:latest` - Stable, reliable

### 2. Shell Executor

**Pros:**

- Direct access to system tools
- No container overhead
- Simple configuration
- Fast execution

**Cons:**

- No isolation between jobs
- State persists between builds
- Security concerns
- Cleanup required

**Configuration:**

```nix
{
  executor = "shell";
  # Jobs run as gitlab-runner user
}
```

### 3. Docker+Machine Executor

**Pros:**

- Auto-scaling runners
- Dynamic provisioning
- Cost-effective for cloud
- Ideal for burst workloads

**Cons:**

- Complex setup
- Requires cloud provider
- Additional costs

### 4. Kubernetes Executor

**Pros:**

- Cloud-native
- Advanced orchestration
- Resource management
- Scalable

**Cons:**

- Requires K8s cluster
- Complex configuration
- Overkill for local use

## Configuration Examples

### High-Performance Workstation (P620)

```nix
services.gitlab-runner-local = {
  enable = true;
  concurrent = 8;  # More parallel jobs

  services = [
    # Docker runner for general CI/CD
    {
      name = "docker-general";
      executor = "docker";
      dockerImage = "nixos/nix:latest";
      dockerVolumes = [ "/cache" "/nix:/nix:ro" ];
      tagList = [ "docker" "nix" ];
      limit = 4;
    }

    # Shell runner for NixOS builds
    {
      name = "nixos-builder";
      executor = "shell";
      tagList = [ "nixos" "nix-build" ];
      limit = 2;
    }

    # Privileged Docker for Docker-in-Docker
    {
      name = "docker-dind";
      executor = "docker";
      dockerImage = "docker:latest";
      dockerPrivileged = true;
      dockerVolumes = [ "/cache" "/var/run/docker.sock:/var/run/docker.sock" ];
      tagList = [ "docker-in-docker" "dind" ];
      limit = 2;
    }
  ];
};
```

### Laptop (Razer/Samsung)

```nix
services.gitlab-runner-local = {
  enable = true;
  concurrent = 2;  # Conservative for battery

  services = [
    {
      name = "mobile-shell-runner";
      executor = "shell";
      tagList = [ "shell" "mobile" ];
      limit = 1;
    }
  ];
};
```

### Media Server (P510)

```nix
services.gitlab-runner-local = {
  enable = true;
  concurrent = 4;

  services = [
    # Lightweight runner for deployments
    {
      name = "deployment-runner";
      executor = "docker";
      dockerImage = "alpine:latest";
      tagList = [ "deploy" "server" ];
      limit = 2;
    }
  ];
};
```

## Testing Your Runner

### 1. Create Test Pipeline

Create `.gitlab-ci.yml` in your project:

```yaml
# Simple test pipeline
stages:
  - test
  - build

test-job:
  stage: test
  tags:
    - docker # Must match your runner tags
  script:
    - echo "Testing GitLab Runner"
    - date
    - hostname
    - uname -a
  only:
    - branches

nix-build-test:
  stage: build
  tags:
    - nix # For Nix-enabled runners
  script:
    - nix-shell --version
    - nix --version
  only:
    - main
```

### 2. Push and Monitor

```bash
# Commit and push
git add .gitlab-ci.yml
git commit -m "feat: add GitLab CI test pipeline"
git push

# Monitor in GitLab UI:
# Your Project → CI/CD → Pipelines
```

### 3. Check Runner Status

```bash
# On the runner host
sudo systemctl status gitlab-runner

# List registered runners
sudo gitlab-runner list

# Check runner logs
sudo journalctl -u gitlab-runner -f

# Verify runner
sudo gitlab-runner verify
```

## Advanced Configuration

### Using Nix in Docker Runner

For NixOS/Nix projects, mount the Nix store:

```nix
{
  executor = "docker";
  dockerImage = "nixos/nix:latest";
  dockerVolumes = [
    "/cache"
    "/nix:/nix:ro"  # Read-only Nix store
    "/tmp:/tmp"     # Temporary files
  ];
}
```

### Docker-in-Docker (DinD)

For building Docker images in CI:

```nix
{
  executor = "docker";
  dockerImage = "docker:latest";
  dockerPrivileged = true;  # Required for DinD
  dockerVolumes = [
    "/cache"
    "/var/run/docker.sock:/var/run/docker.sock"  # Socket passthrough
  ];
  tagList = [ "dind" "docker-build" ];
}
```

### Resource Limits

```nix
systemd.services.gitlab-runner.serviceConfig = {
  MemoryMax = "8G";      # Maximum memory
  CPUQuota = "400%";     # 4 CPUs worth
  TasksMax = 2000;       # Process limit
};
```

## Troubleshooting

### Runner Not Appearing in GitLab

```bash
# Check service status
sudo systemctl status gitlab-runner

# Verify registration
sudo gitlab-runner list

# Check logs
sudo journalctl -u gitlab-runner -n 100

# Re-register if needed
sudo gitlab-runner unregister --name "runner-name"
sudo gitlab-runner register  # Follow prompts
```

### Jobs Stuck in Pending

1. **Check runner tags**: Job tags must match runner tags
2. **Verify runner is online**: GitLab UI → CI/CD → Runners
3. **Check concurrent limit**: Might be at capacity
4. **Review runner logs**: Look for errors

```bash
sudo gitlab-runner verify
sudo journalctl -u gitlab-runner -f
```

### Docker Permission Errors

```bash
# Add gitlab-runner to docker group
sudo usermod -aG docker gitlab-runner

# Restart runner service
sudo systemctl restart gitlab-runner

# Test Docker access
sudo -u gitlab-runner docker ps
```

### Nix Store Access in Docker

```bash
# Ensure Nix store is mounted
# Check dockerVolumes configuration

# Verify in running container
docker exec <container-id> ls /nix/store

# If missing, add to config:
dockerVolumes = [ "/nix:/nix:ro" ];
```

### High Memory Usage

```bash
# Check concurrent jobs
# Reduce concurrent = N in configuration

# Set memory limits
systemd.services.gitlab-runner.serviceConfig.MemoryMax = "4G";

# Monitor usage
systemctl status gitlab-runner
```

## Security Best Practices

### 1. Use Privileged Mode Sparingly

Only enable `dockerPrivileged = true` when absolutely necessary (Docker-in-Docker). It grants full system access.

### 2. Limit Runner Scope

```nix
{
  runUntagged = false;  # Only run tagged jobs
  tagList = [ "specific-project" ];  # Restrict to specific use
}
```

### 3. Secure Registration Token

```bash
# Use agenix for token storage
./scripts/manage-secrets.sh create gitlab-runner-token

# In configuration:
registrationConfigFile = config.age.secrets.gitlab-runner-token.path;
```

### 4. Network Isolation

```nix
# Restrict network access if needed
systemd.services.gitlab-runner.serviceConfig = {
  PrivateNetwork = false;  # Set true for strict isolation
  RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
};
```

### 5. Protected Runners

For production environments:

- Use protected runners (in GitLab settings)
- Limit to protected branches only
- Require approval for new jobs

## Monitoring

### Check Runner Health

```bash
# Service status
sudo systemctl status gitlab-runner

# Recent logs
sudo journalctl -u gitlab-runner -n 50

# Active jobs
sudo gitlab-runner status

# Runner configuration
sudo cat /etc/gitlab-runner/config.toml
```

### GitLab UI

Navigate to: **Settings → CI/CD → Runners**

- **Green dot**: Runner is online and available
- **Gray dot**: Runner is offline or paused
- **Job count**: Number of jobs processed

## Integration with Your Infrastructure

### Add to Monitoring Stack

The runner automatically integrates with your Prometheus/Grafana monitoring:

```nix
# Already configured in monitoring module
services.prometheus.scrapeConfigs = [
  {
    job_name = "gitlab-runner";
    static_configs = [{
      targets = [ "localhost:9252" ];  # GitLab Runner metrics
    }];
  }
];
```

### CI/CD for NixOS Configurations

Example pipeline for testing NixOS configs:

```yaml
# .gitlab-ci.yml
stages:
  - validate
  - build
  - deploy

validate-syntax:
  stage: validate
  tags: [nix]
  script:
    - nix flake check
    - nix flake show

build-p620:
  stage: build
  tags: [nix, docker]
  script:
    - nix build .#nixosConfigurations.p620.config.system.build.toplevel

deploy-p620:
  stage: deploy
  tags: [shell]
  script:
    - just test-host p620
    - just quick-deploy p620
  only:
    - main
  when: manual
```

## Useful Commands

```bash
# Service management
sudo systemctl start gitlab-runner
sudo systemctl stop gitlab-runner
sudo systemctl restart gitlab-runner
sudo systemctl status gitlab-runner

# Runner management
sudo gitlab-runner list                    # List all runners
sudo gitlab-runner verify                  # Verify registration
sudo gitlab-runner status                  # Check runner status
sudo gitlab-runner run                     # Run in foreground (debug)

# Registration
sudo gitlab-runner register                # Interactive registration
sudo gitlab-runner unregister --name NAME  # Remove runner
sudo gitlab-runner unregister --all-runners # Remove all

# Logs
sudo journalctl -u gitlab-runner -f        # Follow logs
sudo journalctl -u gitlab-runner -n 100    # Last 100 lines
sudo journalctl -u gitlab-runner --since "1 hour ago"

# Configuration
sudo cat /etc/gitlab-runner/config.toml    # View config
sudo gitlab-runner verify --delete         # Remove invalid runners
```

## Next Steps

1. **Set up monitoring**: Add GitLab Runner to Grafana dashboards
2. **Create pipelines**: Define CI/CD workflows for your projects
3. **Optimize performance**: Tune concurrent jobs and resource limits
4. **Scale runners**: Add more runners to different hosts
5. **Implement caching**: Speed up builds with GitLab CI cache

## References

- [GitLab Runner Documentation](https://docs.gitlab.com/runner/)
- [Executors Documentation](https://docs.gitlab.com/runner/executors/)
- [GitLab CI/CD Pipeline Configuration](https://docs.gitlab.com/ee/ci/yaml/)
- [NixOS GitLab Runner Options](https://search.nixos.org/options?query=gitlab-runner)

---

For more help, check the troubleshooting section or review the runner logs:

```bash
sudo journalctl -u gitlab-runner -f
```
