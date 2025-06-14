# 🏗️ Host Configuration Guide

This guide explains how to configure hosts, add packages, and use the predefined options in your NixOS configuration.

## 📁 Configuration Structure Overview

Your configuration uses a **feature-based system** that lets you easily enable/disable functionality:

```
hosts/
├── p620/           # AMD workstation
├── razer/          # Intel laptop  
├── p510/           # NVIDIA gaming
├── dex5550/        # Intel HTPC
└── common/         # Shared configurations
```

## 🔧 How to Configure a Host

### 1. **Create a New Host Configuration**

```bash
# Create new host directory
mkdir -p hosts/your-hostname

# Copy from existing host as template
cp -r hosts/p620/* hosts/your-hostname/
```

### 2. **Edit Host Variables**

```bash
# Edit basic host settings
nano hosts/your-hostname/variables.nix
```

```nix
# hosts/your-hostname/variables.nix
{
  hostName = "your-hostname";
  username = "your-username";
  timezone = "Europe/London";
  locale = "en_GB.UTF-8";
}
```

### 3. **Configure Hardware**

```bash
# Generate hardware configuration for your system
sudo nixos-generate-config --show-hardware-config > hosts/your-hostname/nixos/hardware-configuration.nix
```

### 4. **Update Flake Configuration**

```bash
# Edit flake.nix to add your host
nano flake.nix
```

Add your host to the `hostUsers` section and `nixosConfigurations`:

```nix
# In flake.nix, update hostUsers
hostUsers = {
  p620 = ["olafkfreund"];
  razer = ["olafkfreund"];
  p510 = ["olafkfreund"];
  dex5550 = ["olafkfreund"];
  your-hostname = ["your-username"];  # Add this line
};

# And add to nixosConfigurations
nixosConfigurations = {
  # ...existing hosts...
  your-hostname = makeNixosSystem "your-hostname";
};
```

## ⚙️ Using the Features System

Your configuration uses a **declarative features system**. Here's what's available:

### **Development Features**

```nix
# In hosts/your-hostname/configuration.nix
features = {
  development = {
    enable = true;
    # Choose your languages
    python = true;
    go = true;
    nodejs = true;
    java = true;
    lua = true;
    nix = true;
    shell = true;
    ansible = true;
    cargo = true;      # Rust
    github = true;
    devshell = true;
  };
};
```

### **Virtualization Features**

```nix
features = {
  virtualization = {
    enable = true;
    docker = true;
    podman = true;
    incus = false;      # LXC containers
    spice = true;       # VM display
    libvirt = true;     # VM management
    sunshine = true;    # Game streaming
  };
};
```

### **Cloud Features**

```nix
features = {
  cloud = {
    enable = true;
    aws = true;
    azure = true;
    google = true;
    k8s = true;        # Kubernetes
    terraform = true;
  };
};
```

### **Security Features**

```nix
features = {
  security = {
    enable = true;
    onepassword = true;
    gnupg = true;
  };
};
```

### **Networking Features**

```nix
features = {
  networking = {
    enable = true;
    tailscale = true;
  };
};
```

### **AI Features**

```nix
features = {
  ai = {
    enable = true;
    ollama = true;     # Local AI models
  };
};
```

### **Application Features**

```nix
features = {
  programs = {
    lazygit = true;
    thunderbird = true;
    obsidian = true;
    office = true;
    webcam = true;
    print = true;
  };

  media = {
    droidcam = true;   # Use phone as webcam
  };
};
```

## 📦 Adding Custom Packages

### **Method 1: Direct Package Addition**

```nix
# In hosts/your-hostname/configuration.nix
environment.systemPackages = with pkgs; [
  htop
  neofetch
  git
  vim
  # Add any packages you want
];
```

### **Method 2: Using Custom Package Sets**

Your configuration has predefined package categories in `modules/applications/`:

```nix
# Enable browser applications
modules.applications.browsers = {
  enable = true;
  primary = "firefox";  # or "chromium", "brave", "edge"
  packages = with pkgs; [
    firefox
    chromium
    brave
  ];
  extensions.enable = true;
};
```

### **Method 3: Per-Feature Package Customization**

Many features accept additional packages:

```nix
# Add extra Python packages
python.development = {
  enable = true;
  packages = with pkgs.python312Packages; [
    django
    flask
    pandas
    # Your custom Python packages
  ];
};
```

## 🌐 Networking Profiles

Choose a networking profile for your host:

```nix
# In hosts/your-hostname/configuration.nix
networking.profile = "desktop";  # Options: "desktop", "server", "minimal"
```

## 🎯 Complete Example Host Configuration

Here's a complete example for a development workstation:

```nix
# hosts/workstation/configuration.nix
{
  config,
  pkgs,
  lib,
  inputs,
  hostUsers,
  ...
}: let
  vars = import ./variables.nix;
in {
  imports = [
    ./nixos/hardware-configuration.nix
    ./nixos/boot.nix
    ../../modules/default.nix
    ../../modules/development/default.nix
    ../common/hyprland.nix
    ../../modules/security/secrets.nix
    ../../modules/containers/docker.nix
  ];

  # Basic system settings
  networking.hostName = vars.hostName;
  networking.profile = "desktop";

  # Enable features you want
  features = {
    development = {
      enable = true;
      python = true;
      nodejs = true;
      nix = true;
      github = true;
    };

    virtualization = {
      enable = true;
      docker = true;
      libvirt = true;
    };

    security = {
      enable = true;
      onepassword = true;
    };

    programs = {
      obsidian = true;
      office = true;
    };
  };

  # Add custom packages
  environment.systemPackages = with pkgs; [
    firefox
    vscode
    discord
    slack
  ];

  # Enable applications
  modules.applications.browsers = {
    enable = true;
    primary = "firefox";
  };

  # System settings
  system.stateVersion = "24.05";
}
```

## 🚀 Deploying Your Configuration

1. **Test the configuration**:
   ```bash
   nix flake check
   ```

2. **Build without applying**:
   ```bash
   nixos-rebuild build --flake .#your-hostname
   ```

3. **Apply the configuration**:
   ```bash
   sudo nixos-rebuild switch --flake .#your-hostname
   ```

## 📋 Available Modules Reference

### **Core Modules** (`modules/`):
- `development/` - Programming languages and tools
- `applications/` - Desktop applications
- `security/` - Security tools and configurations
- `virtualization/` - VMs and containers
- `cloud/` - Cloud provider tools
- `networking/` - Network tools and VPN
- `ai/` - AI and machine learning tools
- `media/` - Media and webcam tools

### **Package Categories** (`modules/applications/`):
- `browsers.nix` - Web browsers
- `communication.nix` - Chat and communication
- `development.nix` - Development applications
- `media.nix` - Media players and editors
- `productivity.nix` - Office and productivity
- `utilities.nix` - System utilities

## 🔍 Finding Available Packages

1. **Search nixpkgs**:
   ```bash
   nix search nixpkgs firefox
   ```

2. **Browse online**:
   - [NixOS Package Search](https://search.nixos.org/packages)
   - [MyNixOS](https://mynixos.com/)

3. **Check existing modules**:
   ```bash
   # See what's in development modules
   ls modules/development/
   
   # Check application modules
   ls modules/applications/
   ```

## 🎯 Quick Start Checklist

- [ ] Copy existing host as template
- [ ] Update `variables.nix` with your settings
- [ ] Generate `hardware-configuration.nix`
- [ ] Configure features in `configuration.nix`
- [ ] Update `flake.nix` with your host
- [ ] Test with `nix flake check`
- [ ] Deploy with `nixos-rebuild switch`

Your configuration is designed to be modular and declarative - enable what you need, disable what you don't!
