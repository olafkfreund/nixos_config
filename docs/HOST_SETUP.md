# 🖥️ Host Setup Guide

This guide covers adding new hosts to the NixOS configuration with proper secrets management and user access.

## 📋 Prerequisites

- NixOS installed on the target system
- SSH access to the new host
- Secrets management already initialized (see [SECRETS_MANAGEMENT.md](SECRETS_MANAGEMENT.md))

## 🚀 Quick Setup

### 1. Create Host Configuration

```bash
# Create new host directory
mkdir hosts/new-hostname

# Copy template or existing similar host
cp -r hosts/p620/* hosts/new-hostname/
```

### 2. Generate Host SSH Keys

On the new host:
```bash
# Generate host SSH key if not present
sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""

# Extract public key
sudo cat /etc/ssh/ssh_host_ed25519_key.pub
```

### 3. Configure Host Variables

```nix
// hosts/new-hostname/variables.nix
{
  hostName = "new-hostname";
  username = "primary-user";
  fullName = "Primary User";
  
  # Hardware configuration
  gpu = "amd";  # or "nvidia", "intel"
  acceleration = "rocm";  # or "cuda", "vaapi"
  
  # Users for this host
  hostUsers = [
    "primary-user"
    "secondary-user"
  ];
  
  # Hardware-specific settings
  userGroups = [
    "wheel"
    "networkmanager"
    "docker"
    "video"
    "audio"
  ];
  
  nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];
  
  services = {
    nfs = {
      enable = false;
      exports = "";
    };
  };
}
```

### 4. Update Secrets Configuration

Add the new host to `secrets.nix`:

```nix
// secrets.nix
let
  # Add new host key
  newhost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINewHostPublicKey root@new-hostname";
  
  # Update host groups
  allHosts = [ p620 razer p510 dex5550 newhost ];
  workstations = [ p620 razer newhost ];  # If it's a workstation
  # or
  servers = [ p510 dex5550 newhost ];     # If it's a server
in
{
  # Existing secrets get access to new host
  "secrets/user-password-primary-user.age".publicKeys = [ primaryUser ] ++ allHosts;
  
  # Host-specific secrets if needed
  "secrets/host-newhost-specific.age".publicKeys = adminUsers ++ [ newhost ];
}
```

### 5. Add to Flake Configuration

Update `flake.nix`:

```nix
// flake.nix
{
  nixosConfigurations = {
    # ... existing hosts ...
    
    new-hostname = makeNixosSystem "new-hostname";
  };
}
```

### 6. Deploy Configuration

```bash
# Test build
nixos-rebuild build --flake .#new-hostname

# Deploy to new host
nixos-rebuild switch --flake .#new-hostname --target-host root@new-hostname

# Or copy configuration and build locally
nixos-rebuild switch --flake .#new-hostname
```

## 🔧 Hardware-Specific Configuration

### AMD Systems (like P620)

```nix
// hosts/new-hostname/configuration.nix
{
  # AMD GPU configuration
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
    extraPackages = with pkgs; [
      amdvlk
      rocm-opencl-icd
      rocm-opencl-runtime
    ];
  };

  # ROCm for compute workloads
  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocm-runtime}"
  ];

  # Kernel parameters for AMD
  boot.kernelParams = [
    "amdgpu.si_support=1"
    "amdgpu.cik_support=1"
  ];
}
```

### Intel/NVIDIA Systems (like Razer)

```nix
{
  # NVIDIA configuration
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    prime = {
      offload.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Intel graphics
  hardware.opengl.extraPackages = with pkgs; [
    intel-media-driver
    vaapiIntel
    vaapiVdpau
  ];
}
```

### Intel Integrated (like DEX5550)

```nix
{
  # Intel integrated graphics
  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiIntel
      intel-compute-runtime
    ];
  };

  # Power efficiency
  powerManagement.cpuFreqGovernor = "powersave";
}
```

## 👥 User Management for New Hosts

### Adding Users to New Host

1. **Update host variables**:
   ```nix
   // hosts/new-hostname/variables.nix
   {
     hostUsers = [
       "existing-user"
       "new-user"
     ];
   }
   ```

2. **Generate user SSH keys**:
   ```bash
   # As the new user
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
   cat ~/.ssh/id_ed25519.pub
   ```

3. **Update secrets.nix**:
   ```nix
   let
     newuser = "ssh-ed25519 AAAAC3... new-user@new-hostname";
     allUsers = [ existinguser newuser ];
   in
   {
     "secrets/user-password-newuser.age".publicKeys = [ newuser ] ++ relevantHosts;
   }
   ```

4. **Create user secrets**:
   ```bash
   ./scripts/manage-secrets.sh create user-password-newuser
   ./scripts/manage-secrets.sh rekey
   ```

## 🌐 Network Configuration

### Standard Network Setup

```nix
{
  networking = {
    hostName = vars.hostName;
    useNetworkd = true;
    useDHCP = false;
  };

  systemd.network = {
    enable = true;
    networks = {
      "20-wired" = {
        matchConfig.Name = "en*";
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = true;
        };
      };
      "25-wireless" = {
        matchConfig.Name = "wl*";
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = true;
        };
      };
    };
  };
}
```

### Firewall Configuration

```nix
{
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
    allowedUDPPorts = [ 53 ];
    
    # Host-specific ports
    allowedTCPPorts = lib.optionals (vars.hostName == "server-host") [
      3000  # Application port
      5432  # PostgreSQL
    ];
  };
}
```

## 🔒 Security Configuration

### SSH Hardening

```nix
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
    openFirewall = true;
  };
}
```

### Fail2ban Setup

```nix
{
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    jails = {
      sshd = {
        settings = {
          enabled = true;
          port = "ssh";
          filter = "sshd";
          logpath = "/var/log/auth.log";
        };
      };
    };
  };
}
```

## 📊 Monitoring and Logging

### Basic Monitoring

```nix
{
  # System monitoring
  services.prometheus = {
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" "filesystem" "network" ];
      };
    };
  };

  # Log management
  services.journald.extraConfig = ''
    SystemMaxUse=1G
    MaxRetentionSec=1month
  '';
}
```

## 🧪 Testing New Host

### Pre-deployment Tests

```bash
# Test configuration builds
nixos-rebuild build --flake .#new-hostname

# Check flake validity
nix flake check

# Test specific components
nix build .#nixosConfigurations.new-hostname.config.system.build.toplevel
```

### Post-deployment Verification

```bash
# Check system status
systemctl status

# Verify user creation
id username

# Check secrets access
./scripts/manage-secrets.sh status

# Test network connectivity
ping 1.1.1.1

# Verify hardware acceleration
lspci | grep -i gpu
```

## 🔄 Host Migration

### Migrating from Existing Host

1. **Export current configuration**:
   ```bash
   nixos-generate-config --show-hardware-config > new-hardware.nix
   ```

2. **Copy user data**:
   ```bash
   rsync -av /home/username/ new-host:/home/username/
   ```

3. **Transfer secrets**:
   ```bash
   # Secrets automatically available after configuration deployment
   # No manual transfer needed
   ```

4. **Update DNS/network references**:
   ```bash
   # Update any hardcoded IP addresses or hostnames
   ```

## 📚 Reference

### Common Host Patterns

```nix
# Workstation pattern
{
  features = {
    development.enable = true;
    virtualization.enable = true;
    security.enable = true;
    programs = {
      office = true;
      media = true;
    };
  };
}

# Server pattern  
{
  features = {
    networking.enable = true;
    security.enable = true;
    cloud.enable = true;
  };
  
  services = {
    openssh.enable = true;
    fail2ban.enable = true;
  };
}

# Minimal pattern
{
  features = {
    security.enable = true;
  };
  
  services.openssh.enable = true;
}
```

### Troubleshooting

#### Host Not Building
- Check hardware-configuration.nix syntax
- Verify all imports exist
- Test with minimal configuration first

#### Network Issues
- Check systemd-networkd status: `systemctl status systemd-networkd`
- Verify network interface names: `ip link show`
- Test DNS resolution: `nslookup google.com`

#### Secrets Not Working
- Verify host key in secrets.nix
- Check secret file permissions
- Run recovery script: `./scripts/recover-secrets.sh`

This guide should help you successfully add new hosts to your NixOS configuration with proper integration into the secrets management and user systems.