# Server Template

Comprehensive NixOS server configuration optimized for headless deployments with enterprise-grade features.

## Features

This server template provides:

- **Headless Operation**: Optimized for servers without GUI
- **Security Hardening**: Enhanced security with fail2ban, firewall, and kernel hardening
- **Container Support**: Docker, Podman, and LXC virtualization
- **Monitoring Integration**: Built-in Prometheus/Grafana monitoring support
- **Media Server Ready**: Optional Plex, Jellyfin, and \*arr services
- **Database Support**: PostgreSQL, MySQL, Redis, MongoDB options
- **Web Services**: Nginx, Apache, Node.js support
- **Network Optimized**: Server-grade networking with systemd-networkd
- **Automatic Updates**: Optional automated system maintenance
- **Backup Integration**: Built-in backup service configuration

## Quick Start

1. **Copy and customize the template:**

   ```bash
   cp -r templates/hosts/server hosts/myserver
   cd hosts/myserver
   ```

2. **Edit variables.nix:**
   - Set `hostName`, `userName`, `userFullName`
   - Configure network settings and open ports
   - Add your SSH public keys
   - Enable desired features (media server, databases, etc.)

3. **Generate hardware configuration:**

   ```bash
   nixos-generate-config --show-hardware-config > nixos/hardware-configuration.nix
   ```

4. **Update flake.nix** (add your server configuration)

5. **Test and deploy:**

   ```bash
   just test-host myserver
   just myserver
   ```

## Configuration Areas

### Network Configuration

Servers use systemd-networkd for enterprise-grade networking:

```nix
network = {
  openPorts = {
    tcp = [ 22 80 443 8080 ];     # Add your service ports
    udp = [ ];
  };

  # Static IP example
  interfaces = {
    "enp3s0" = {
      ipv4.addresses = [{
        address = "192.168.1.100";
        prefixLength = 24;
      }];
    };
  };
};
```

### Service Configuration

Enable services based on your needs:

```nix
features = {
  # Media server stack
  mediaServer = {
    enable = true;
    plex = true;
    sonarr = true;
    radarr = true;
    transmission = true;
  };

  # Database services
  database = {
    enable = true;
    postgresql = true;
    redis = true;
  };

  # Web services
  webServices = {
    enable = true;
    nginx = true;
    nodejs = true;
  };
};
```

### Security Features

- **SSH Hardening**: Key-only authentication, limited users, security settings
- **Firewall**: Configurable ports with logging options
- **Fail2ban**: Automatic IP banning for failed login attempts
- **Kernel Hardening**: Security-focused kernel parameters
- **User Limits**: Resource limits and security policies
- **Audit Logging**: System activity monitoring

### Monitoring Integration

Built-in support for the monitoring stack:

```nix
monitoring = {
  enable = true;
  mode = "client";           # Send metrics to monitoring server
  serverHost = "dex5550";    # Your monitoring server
};
```

Includes:

- Node exporter for system metrics
- Systemd exporter for service monitoring
- Docker metrics (if enabled)
- Storage and disk metrics
- Custom NixOS-specific metrics

### GPU Support

Even servers can have GPUs for AI workloads:

```nix
gpu = "nvidia";              # or "amd", "intel", "none"
acceleration = "cuda";       # or "rocm", "vaapi", "none"
```

### Virtualization

Comprehensive container and VM support:

```nix
virtualization = true;
docker = true;              # Docker containers
podman = false;             # Alternative to Docker
libvirt = false;           # KVM/QEMU VMs
lxc = false;               # System containers
```

### Automatic Maintenance

Optional automated system updates:

```nix
autoUpgrade = {
  enable = true;
  allowReboot = false;      # Set to true for unattended reboots
  schedule = "04:00";       # Daily at 4 AM
};
```

## Security Considerations

This template implements server security best practices:

1. **SSH Security**:
   - Key-only authentication
   - Root login with keys only
   - Limited connection attempts
   - Disabled forwarding and tunneling

2. **Network Security**:
   - Restrictive firewall by default
   - Fail2ban protection
   - Network hardening parameters

3. **System Hardening**:
   - Kernel security parameters
   - Disabled unnecessary services
   - User privilege restrictions
   - Resource limits

4. **Logging and Monitoring**:
   - Centralized logging configuration
   - Security event monitoring
   - System health metrics

## Performance Optimizations

- **Memory Management**: Low swappiness, optimized VM parameters
- **I/O Scheduling**: Server-appropriate I/O scheduler
- **CPU Scaling**: Power-efficient CPU governor
- **Network Tuning**: Optimized network buffer sizes
- **Service Optimization**: Disabled unnecessary desktop services
- **Boot Optimization**: Fast boot with minimal timeout

## Storage Configuration

Flexible storage options:

- **ZFS Support**: Optional ZFS pool management
- **Backup Integration**: Built-in backup service configuration
- **LVM Support**: Logical volume management
- **RAID**: Hardware and software RAID support

## Common Use Cases

### Media Server

```nix
features.mediaServer = {
  enable = true;
  plex = true;
  sonarr = true;
  radarr = true;
  transmission = true;
  nzbget = true;
};
```

### Development Server

```nix
features = {
  development = true;
  docker = true;
  database.postgresql = true;
  webServices.nginx = true;
};
```

### Monitoring Server

```nix
features.monitoring = {
  enable = true;
  mode = "server";          # This server hosts monitoring
};
```

### File Server

```nix
# Add specific file server configuration
# Samba, NFS, or other file sharing services
```

## Network Architecture

Servers integrate seamlessly with the NixOS infrastructure:

- **Tailscale Integration**: Secure mesh VPN connectivity
- **DNS Management**: Proper DNS resolution with systemd-resolved
- **Service Discovery**: Automatic service registration
- **Load Balancing**: Ready for load balancer integration

## Troubleshooting

### Common Issues

1. **SSH Connection Issues**: Check firewall ports and SSH key configuration
2. **Service Startup Failures**: Review systemd logs with `journalctl -u service-name`
3. **Network Connectivity**: Verify interface configuration and routing
4. **Storage Issues**: Check disk space and filesystem health
5. **Performance Problems**: Monitor resource usage and adjust limits

### Diagnostic Commands

```bash
# System status
systemctl status
journalctl -f

# Network diagnostics
ip addr show
ss -tlnp
systemctl status systemd-networkd

# Storage information
df -h
lsblk
smartctl -a /dev/sda

# Service monitoring
htop
iotop
nethogs
```

## Best Practices

1. **Regular Updates**: Keep the system updated with security patches
2. **Backup Strategy**: Implement automated backups with verification
3. **Monitoring**: Enable comprehensive monitoring and alerting
4. **Security Audits**: Regularly review security configurations
5. **Documentation**: Document any custom configurations
6. **Testing**: Test configurations in non-production environments
7. **Capacity Planning**: Monitor resource usage and plan for growth

This server template provides a solid foundation for any headless server deployment while maintaining flexibility for specific use cases.
