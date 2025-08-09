# FlareSolverr Service Module

## Overview

FlareSolverr is a proxy server that helps bypass Cloudflare protection for web scraping applications. This module provides a comprehensive NixOS configuration for running FlareSolverr as a systemd service.

## Features

- **Secure Service**: Runs with restricted permissions and security hardening
- **Configurable**: Extensive configuration options for different use cases
- **Monitoring Ready**: Optional Prometheus metrics export
- **Resource Limited**: Memory and CPU quotas to prevent resource exhaustion
- **Firewall Integration**: Optional automatic firewall configuration

## Configuration Options

### Basic Configuration

```nix
services.flaresolverr = {
  enable = true;
  port = 8191;                    # Default port
  host = "0.0.0.0";              # Bind to all interfaces
  logLevel = "info";             # Log verbosity
  openFirewall = true;           # Open firewall automatically
};
```

### Advanced Configuration

```nix
services.flaresolverr = {
  enable = true;
  port = 8191;
  host = "127.0.0.1";            # Bind to localhost only
  logLevel = "debug";            # More verbose logging
  logHtml = true;                # Log HTML content for debugging
  captchaSolver = "hcaptcha-solver";  # Enable CAPTCHA solving
  sessionTtl = 300000;           # 5 minutes session timeout
  browserTimeout = 60000;        # 1 minute browser timeout
  headless = true;               # Run in headless mode

  # Custom environment variables
  extraEnvironment = {
    PROMETHEUS_ENABLED = "true";
    PROMETHEUS_PORT = "8192";
    CUSTOM_VAR = "value";
  };

  # Security settings
  user = "flaresolverr";
  group = "flaresolverr";
  dataDir = "/var/lib/flaresolverr";
};
```

## Usage Examples

### Basic Setup for Local Development

```nix
services.flaresolverr = {
  enable = true;
  host = "127.0.0.1";
  port = 8191;
  logLevel = "debug";
};
```

### Production Setup with Monitoring

```nix
services.flaresolverr = {
  enable = true;
  host = "0.0.0.0";
  port = 8191;
  logLevel = "info";
  openFirewall = true;

  extraEnvironment = {
    PROMETHEUS_ENABLED = "true";
    PROMETHEUS_PORT = "8192";
  };

  # Performance tuning
  sessionTtl = 600000;           # 10 minutes
  browserTimeout = 30000;        # 30 seconds
};
```

### Integration with Sonarr/Radarr

```nix
services.flaresolverr = {
  enable = true;
  host = "127.0.0.1";
  port = 8191;
  logLevel = "info";

  # Optimized for media automation
  sessionTtl = 900000;           # 15 minutes
  browserTimeout = 45000;        # 45 seconds
  captchaSolver = "harvester";   # Enable CAPTCHA solving
};
```

## API Usage

Once running, FlareSolverr provides a REST API on the configured port:

```bash
# Test the service
curl -X POST http://localhost:8191/v1 \
  -H "Content-Type: application/json" \
  -d '{"cmd": "request.get", "url": "https://example.com"}'

# Check service status
curl http://localhost:8191/v1 \
  -H "Content-Type: application/json" \
  -d '{"cmd": "sessions.list"}'
```

## Security Considerations

- **Sandboxing**: Service runs with strict systemd security settings
- **User Isolation**: Runs as dedicated unprivileged user
- **Resource Limits**: Memory and CPU quotas prevent resource exhaustion
- **Network**: Bind to localhost only for security (configurable)
- **Firewall**: Firewall rules are optional and disabled by default

## Monitoring

### Prometheus Integration

```nix
services.flaresolverr = {
  enable = true;
  extraEnvironment = {
    PROMETHEUS_ENABLED = "true";
    PROMETHEUS_PORT = "8192";
  };
};
```

### Service Logs

```bash
# View service logs
journalctl -u flaresolverr -f

# Check service status
systemctl status flaresolverr
```

## Troubleshooting

### Common Issues

1. **Service won't start**: Check logs with `journalctl -u flaresolverr`
2. **Permission denied**: Ensure data directory has correct permissions
3. **Browser fails**: Check Chrome/Chromium installation and permissions
4. **High memory usage**: Reduce sessionTtl or adjust memory limits

### Debug Mode

```nix
services.flaresolverr = {
  enable = true;
  logLevel = "debug";
  logHtml = true;
  headless = false;  # For debugging browser issues
};
```

## Performance Tuning

### Resource Limits

The service includes default resource limits:

- Memory: 2GB maximum
- CPU: 200% (2 cores)
- Tasks: 1024 maximum

### Session Management

- `sessionTtl`: Longer sessions reduce overhead but use more memory
- `browserTimeout`: Shorter timeouts improve responsiveness
- `headless`: Always keep true for production

## Integration Examples

### Docker Compose Translation

If migrating from Docker Compose:

```yaml
# Docker Compose
flaresolverr:
  image: ghcr.io/flaresolverr/flaresolverr:latest
  container_name: flaresolverr
  environment:
    - LOG_LEVEL=info
    - LOG_HTML=false
    - CAPTCHA_SOLVER=none
    - TZ=Europe/London
  ports:
    - "8191:8191"
  restart: unless-stopped
```

Becomes:

```nix
services.flaresolverr = {
  enable = true;
  port = 8191;
  logLevel = "info";
  logHtml = false;
  captchaSolver = "none";
  openFirewall = true;
};
```

## Dependencies

- **Chromium**: Required for browser automation
- **Python**: Runtime dependency (included with package)
- **Selenium**: Web automation framework (included with package)

## References

- [FlareSolverr GitHub](https://github.com/FlareSolverr/FlareSolverr)
- [FlareSolverr API Documentation](https://github.com/FlareSolverr/FlareSolverr/wiki/API)
- [Cloudflare Bypass Techniques](https://github.com/FlareSolverr/FlareSolverr/wiki/How-it-works)
