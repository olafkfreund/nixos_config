# Workstation Template

High-performance desktop workstation template optimized for development, content creation, and power users.

## Features

### ✅ Included by Default
- **Desktop Environment**: Hyprland (Wayland) with KDE Plasma fallback
- **Development Tools**: Complete development stack (Python, Go, Rust, Node.js, Java, etc.)
- **Virtualization**: Docker, Podman, MicroVMs, libvirt
- **AI Integration**: OpenAI, Anthropic, Gemini, and local Ollama
- **Gaming Support**: Steam, Lutris, game optimization
- **Media Tools**: Audio/video editing, streaming, content creation
- **Monitoring**: Advanced metrics collection and performance analytics
- **Security**: SSH hardening, fail2ban, secret management

### 🔧 Configurable Options
- **GPU Support**: AMD (ROCm), NVIDIA (CUDA), Intel, or none
- **Display Configuration**: Single/multi-monitor setups
- **Theme and Appearance**: Multiple themes and wallpapers
- **Development Environment**: Language-specific configurations
- **Gaming**: Can be disabled for work-focused systems
- **Resource Management**: Performance vs. efficiency profiles

## Quick Setup

1. **Copy Template**:
   ```bash
   cp -r templates/hosts/workstation hosts/myworkstation
   ```

2. **Customize `variables.nix`**:
   ```nix
   {
     username = "myuser";
     hostName = "myworkstation";
     gpu = "nvidia";  # or "amd", "intel", "none"
     acceleration = "cuda";  # or "rocm", "none"
     # ... other settings
   }
   ```

3. **Generate Hardware Config**:
   ```bash
   nixos-generate-config --show-hardware-config > hosts/myworkstation/nixos/hardware-configuration.nix
   ```

4. **Add to Flake** and **Deploy**

## Customization Options

### GPU Configuration

#### NVIDIA Setup
```nix
gpu = "nvidia";
acceleration = "cuda";
```
- Enables CUDA for AI/ML workloads
- Gaming optimization with proprietary drivers
- Video encoding/decoding acceleration
- AI provider integration

#### AMD Setup
```nix
gpu = "amd";
acceleration = "rocm";
```
- ROCm for AI/ML workloads
- Open-source driver stack
- Gaming with RADV/RadeonSI
- Video acceleration with VA-API

#### Intel Setup
```nix
gpu = "intel";
acceleration = "none";
```
- Integrated graphics optimization
- Power efficiency focus
- Basic gaming capability
- Hardware video acceleration

### Display Configuration

#### Single Monitor
```nix
laptop_monitor = "";
external_monitor = "monitor = DP-1,1920x1080@60,0x0,1";
```

#### Dual Monitor
```nix
laptop_monitor = "monitor = DP-2,1920x1080@60,1920x0,1";
external_monitor = "monitor = DP-1,1920x1080@60,0x0,1";
```

#### High-DPI Setup
```nix
external_monitor = "monitor = DP-1,3840x2160@120,0x0,1.5";
```

### Performance Profiles

#### Maximum Performance
```nix
system.resourceManager.profile = "performance";
networking.performanceTuning.profile = "throughput";
storage.performanceOptimization.profile = "performance";
```

#### Balanced
```nix
system.resourceManager.profile = "balanced";
networking.performanceTuning.profile = "balanced";
storage.performanceOptimization.profile = "balanced";
```

### Development Environment

#### Full Stack Developer
```nix
features.development = {
  enable = true;
  python = true;
  nodejs = true;
  go = true;
  rust = true;
  java = true;
  docker = true;
};
```

#### Systems Developer
```nix
features.development = {
  enable = true;
  rust = true;
  go = true;
  nix = true;
  shell = true;
  cargo = true;
};
```

### AI Configuration

#### Full AI Stack
```nix
features.ai = {
  enable = true;
  ollama = true;
  providers = {
    enable = true;
    openai.enable = true;
    anthropic.enable = true;
    gemini.enable = true;
    ollama.enable = true;
  };
};
```

#### Cloud AI Only
```nix
features.ai = {
  enable = true;
  ollama = false;  # Disable local AI for lower resource usage
  providers = {
    enable = true;
    openai.enable = true;
    anthropic.enable = true;
  };
};
```

## Monitoring Configuration

### Client Mode (Recommended)
```nix
monitoring = {
  enable = true;
  mode = "client";
  serverHost = "dex5550";  # Your monitoring server
  
  features = {
    nodeExporter = true;
    nixosMetrics = true;
    aiMetrics = true;
    amdGpuMetrics = true;  # If using AMD GPU
  };
};
```

### Server Mode (Advanced)
```nix
monitoring = {
  enable = true;
  mode = "server";
  
  features = {
    prometheus = true;
    grafana = true;
    alertmanager = true;
    logging = true;
  };
};
```

## Network Configuration

### Tailscale VPN
```nix
networking.tailscale = {
  enable = true;
  hostname = "myworkstation-desktop";
  subnet = "192.168.1.0/24";  # Advertise local network
  acceptRoutes = true;
  acceptDns = false;  # Prevent DNS conflicts
  ssh = true;
  useRoutingFeatures = "client";
};
```

### Static IP (Optional)
```nix
hostMappings = {
  "192.168.1.100" = "myworkstation";
  # ... other hosts
};
```

## Theme Customization

### Dark Theme (Default)
```nix
theme = {
  scheme = "gruvbox-dark-medium";
  wallpaper = ./themes/dark-wallpaper.jpg;
  cursor = {
    name = "Bibata-Modern-Ice";
    size = 26;
  };
};
```

### Light Theme
```nix
theme = {
  scheme = "gruvbox-light-medium";
  wallpaper = ./themes/light-wallpaper.jpg;
  cursor = {
    name = "Bibata-Modern-Classic";
    size = 24;
  };
};
```

## Security Configuration

### Standard Security
```nix
features.security = {
  enable = true;
  onepassword = true;
  gnupg = true;
};

security.sshHardening = {
  enable = true;
  allowPasswordAuthentication = false;
  enableFail2Ban = true;
};
```

### High Security
```nix
features.security = {
  enable = true;
  onepassword = true;
  gnupg = true;
  auditd = true;
  apparmor = true;
};
```

## Performance Tuning

### Gaming Optimization
```nix
# Enable gaming features
features.gaming = {
  enable = true;
  steam = true;
  lutris = true;
  gamemode = true;
};

# Performance tuning
system.resourceManager = {
  profile = "performance";
  cpuManagement.dynamicGovernor = true;
  memoryManagement.hugePagesOptimization = true;
};
```

### Development Optimization
```nix
# Development focus
system.resourceManager = {
  profile = "balanced";
  cpuManagement.affinityOptimization = true;
  ioManagement.cacheOptimization = true;
};

# Network optimization for remote work
networking.performanceTuning = {
  profile = "latency";
  tcpOptimization.lowLatency = true;
};
```

## Troubleshooting

### Common Issues

**GPU Not Detected**:
- Check `gpu` setting in `variables.nix`
- Verify hardware configuration includes GPU
- Check kernel modules are loaded

**Display Issues**:
- Verify monitor configuration in `variables.nix`
- Check cable connections and display capabilities
- Try fallback to X11 if Wayland has issues

**Performance Issues**:
- Check resource manager profile
- Verify swap configuration
- Monitor system resources with included tools

**Network Issues**:
- Verify Tailscale configuration
- Check DNS settings and conflicts
- Test network connectivity

### Performance Monitoring

The workstation includes comprehensive monitoring tools:
- `htop` and `btop` for system monitoring
- `nvtop` for GPU monitoring (NVIDIA/AMD)
- AI performance metrics via monitoring stack
- Custom performance analytics dashboard

### Getting Help

1. Check system logs: `journalctl -xe`
2. Test configuration: `just test-host myworkstation`
3. Monitor resources: `htop`, `iotop`, `nethogs`
4. Check service status: `systemctl status <service>`

## Example Configurations

### Gaming Workstation
```nix
# High-end gaming and streaming setup
gpu = "nvidia";
acceleration = "cuda";

features = {
  gaming.enable = true;
  virtualization.enable = true;
  ai.enable = true;
  media.streaming = true;
};

system.resourceManager.profile = "performance";
```

### Development Workstation
```nix
# Software development focus
gpu = "intel";  # Power efficient for coding

features = {
  development.enable = true;
  virtualization.docker = true;
  ai.providers.enable = true;
  gaming.enable = false;  # Minimize distractions
};

system.resourceManager.profile = "balanced";
```

### Content Creation Workstation
```nix
# Video/audio editing and creation
gpu = "amd";
acceleration = "rocm";

features = {
  media.enable = true;
  ai.enable = true;  # AI-assisted editing
  virtualization.enable = true;
  development.enable = true;
};

storage.performanceOptimization.profile = "performance";
```

This template provides a solid foundation for any high-performance desktop workstation while remaining flexible enough to customize for specific use cases.