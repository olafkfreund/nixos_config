# Container and Virtualization Modules

This directory contains modules for container runtimes and virtualization technologies.

## Available Modules

### Container Runtimes
- **docker.nix** - Docker container runtime with daemon configuration
- **podman.nix** - Podman rootless container runtime
- **kubernetes.nix** - Kubernetes cluster configuration

## Module Overview

### Docker (`docker.nix`)
Provides Docker container runtime with:
- Daemon configuration and optimization
- Network and storage driver selection
- User group management for Docker access
- Security and resource limit settings

### Podman (`podman.nix`)
Offers rootless container runtime with:
- Rootless operation for improved security
- Compatible with Docker CLI commands
- Integration with systemd for container management
- Support for container networking and volumes

### Kubernetes (`kubernetes.nix`)
Configures Kubernetes cluster components:
- Control plane components (API server, scheduler, controller)
- Worker node configuration (kubelet, proxy)
- Network plugin integration
- Certificate and authentication management

## Usage Examples

### Enable Docker
```nix
{
  modules.containers.docker = {
    enable = true;
    rootless = false;
    enableNvidia = true;  # For GPU support
  };
}
```

### Enable Rootless Podman
```nix
{
  modules.containers.podman = {
    enable = true;
    enableDocker = true;  # Docker CLI compatibility
    registries = [
      "docker.io"
      "registry.fedoraproject.org"
    ];
  };
}
```

### Kubernetes Cluster Node
```nix
{
  modules.containers.kubernetes = {
    enable = true;
    role = "worker";  # or "master"
    clusterCIDR = "10.244.0.0/16";
    serviceCIDR = "10.96.0.0/12";
  };
}
```

## Configuration Considerations

### Security
- Podman is preferred for desktop/development use due to rootless operation
- Docker provides better ecosystem compatibility but requires root privileges
- Both support security profiles and resource constraints

### Performance
- Docker generally offers better performance for production workloads
- Podman has lower overhead for development and testing
- Kubernetes adds significant overhead but provides orchestration features

### Storage
- Configure appropriate storage drivers based on filesystem
- Consider using external volumes for persistent data
- Set up proper cleanup policies to manage disk usage

## Dependencies

Container modules typically require:
- Linux kernel with container support (cgroups, namespaces)
- Adequate storage space for images and containers
- Network configuration for container networking
- Optional: GPU drivers for CUDA/OpenCL support

## Troubleshooting

### Common Issues

1. **Permission denied errors**
   ```bash
   # Add user to docker group
   sudo usermod -aG docker $USER
   
   # For rootless podman
   podman system migrate
   ```

2. **Network connectivity issues**
   ```bash
   # Reset Docker networks
   docker network prune
   
   # Reset Podman networks
   podman network prune
   ```

3. **Storage space issues**
   ```bash
   # Clean up Docker
   docker system prune -a
   
   # Clean up Podman
   podman system prune -a
   ```

### Debug Commands
```bash
# Check Docker daemon
systemctl status docker

# Check Podman
podman info

# Check Kubernetes
kubectl cluster-info
```

## Integration Notes

- Containers can be integrated with systemd for automatic startup
- Use secrets management for sensitive container configuration
- Consider backup strategies for persistent container data
- Monitor resource usage in production environments