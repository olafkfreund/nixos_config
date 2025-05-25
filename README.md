# 🐧✨ NixOS Multi-User Configuration

A comprehensive, flake-based NixOS configuration with Home Manager integration supporting multiple hosts and users with role-based configurations.

📚 **[→ Detailed User Management Guide](USER_MANAGEMENT.md)**

---

## 🖥️ Supported Hosts

This configuration manages four distinct systems with different hardware profiles and use cases:

### P620 Workstation

- **CPU**: AMD processor with high-performance capabilities
- **GPU**: AMD graphics card with ROCm support  
- **Use Case**: High-performance workstation for development and creative work
- **Users**: `olafkfreund` (primary), `workuser` (business/office work)

### Razer Laptop  

- **CPU**: Intel i7-10875H (8 cores/16 threads)
- **GPU**: NVIDIA graphics with Optimus
- **Use Case**: Mobile development platform
- **Users**: `olafkfreund` (single user configuration)

### P510 Workstation

- **CPU**: Intel Xeon processor
- **GPU**: NVIDIA graphics card with CUDA support
- **Use Case**: Server/workstation hybrid for development and hosting
- **Users**: `olafkfreund` (primary), `serveruser` (server management)

### DEX5550 SFF System

- **CPU**: Intel processor (compact form factor)
- **GPU**: Intel integrated graphics
- **Use Case**: Compact desktop/HTPC for media and light computing  
- **Users**: `olafkfreund` (primary), `htpcuser` (media center operations)

---

## 🏗️ Project Structure

```
.
├── flake.nix                    # Main flake with host/user mappings
├── flake.lock                   # Flake dependencies lock file
├── README.md                    # This documentation
├── USER_MANAGEMENT.md           # Detailed user management guide
├── hosts/                       # Host-specific configurations
│   ├── p620/                   # P620 workstation config
│   │   ├── configuration.nix   # System configuration
│   │   ├── variables.nix       # Host variables
│   │   └── nixos/             # NixOS-specific modules
│   ├── razer/                  # Razer laptop config
│   ├── p510/                   # P510 workstation config
│   ├── dex5550/                # DEX5550 SFF system config
│   └── common/                 # Shared host configurations
├── Users/                       # User Home Manager configurations
│   ├── common/                 # Shared user configurations
│   │   └── base-home.nix      # Base Home Manager setup
│   ├── olafkfreund/           # Primary user configs per host
│   ├── workuser/              # Work user configurations
│   ├── serveruser/            # Server user configurations
│   └── htpcuser/              # HTPC user configurations
├── modules/                     # Custom NixOS modules
│   ├── containers/             # Container-related modules
│   │   └── docker.nix         # Multi-user Docker setup
│   ├── development/           # Development environments
│   ├── desktop/               # Desktop environment configs
│   ├── security/              # Security tools and configs
│   └── default.nix           # Module imports
├── home/                       # Home Manager specific modules
├── pkgs/                       # Custom packages and overlays
└── themes/                     # System theming configurations
```

---

## 🚀 Quick Start

### Initial Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url> ~/.config/nixos
   cd ~/.config/nixos
   ```

2. **Build and switch to a host configuration**:
   ```bash
   sudo nixos-rebuild switch --flake .#<hostname>
   ```
   
   Available hostnames: `p620`, `razer`, `p510`, `dex5550`

3. **Update the flake inputs**:
   ```bash
   nix flake update
   ```

### Building Configurations

```bash
# Build without switching (test configuration)
nixos-rebuild build --flake .#p620

# Build and switch to new configuration
sudo nixos-rebuild switch --flake .#razer

# Test configuration (reverts on reboot)
sudo nixos-rebuild test --flake .#p510

# Show detailed build output
nixos-rebuild switch --flake .#dex5550 --show-trace
```

---

## 👥 Multi-User System

This configuration supports multiple users per host with role-based configurations and automatic service integration.

### Current User Mapping

The flake defines users per host based on their intended use:

```nix
hostUsers = {
  p620 = ["olafkfreund" "workuser"];     # Workstation + Business user
  razer = ["olafkfreund"];               # Single user mobile setup  
  p510 = ["olafkfreund" "serveruser"];   # Primary + Server admin
  dex5550 = ["olafkfreund" "htpcuser"];  # Primary + Media center user
};
```

### User Role Descriptions

- **`olafkfreund`**: Primary user with full development environment and admin access
- **`workuser`**: Business-focused user with office applications and communication tools
- **`serveruser`**: Server administrator with system monitoring and network tools
- **`htpcuser`**: Media center user with entertainment applications and minimal system access

---

## ➕ Adding New Users

### Step-by-Step Process

#### 1. Define User in Flake Configuration

Edit `flake.nix` and add the new user to the appropriate host(s):

```nix
hostUsers = {
  p620 = ["olafkfreund" "workuser" "newuser"];  # Add to P620
  p510 = ["olafkfreund" "serveruser"];          # Unchanged
  # ... other hosts
};
```

#### 2. Create User Directory Structure

```bash
mkdir -p Users/newuser
```

#### 3. Create User Home Configuration

Create `Users/newuser/<hostname>_home.nix` for each host where the user exists:

```nix
# Users/newuser/p620_home.nix
{
  pkgs,
  ...
}: {
  imports = [
    ../common/base-home.nix
  ];

  # User-specific packages
  home.packages = with pkgs; [
    # Add packages for this user's role
    firefox
    vscode
    git
    # ... role-specific tools
  ];

  # User-specific program configurations
  programs = {
    git = {
      enable = true;
      userName = "New User";
      userEmail = "newuser@example.com";
    };
    
    # Configure other programs as needed
    zsh = {
      enable = true;
      autosuggestion.enable = true;
    };
  };

  # User-specific services
  services = {
    # Add any user-specific services
    gpg-agent.enable = true;
  };
}
```

#### 4. Apply Configuration

Rebuild the system configuration:

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

The system will automatically:
- Create the user account
- Add the user to appropriate groups (including Docker)
- Apply the Home Manager configuration
- Set up user-specific services

---

## 🔧 User Role Templates

### Work User Template
Ideal for business/office work:

```nix
{
  pkgs,
  ...
}: {
  imports = [ ../common/base-home.nix ];

  home.packages = with pkgs; [
    # Office and productivity
    libreoffice-fresh
    thunderbird
    teams-for-linux
    zoom-us
    slack
    
    # Development tools
    vscode
    postman
    insomnia
    
    # Remote access
    remmina
    anydesk
    
    # File management
    nautilus
    evince
  ];

  programs = {
    firefox = {
      enable = true;
      profiles.work = {
        name = "Work Profile";
        isDefault = true;
        settings = {
          "browser.startup.homepage" = "https://portal.company.com";
        };
      };
    };
    
    git = {
      enable = true;
      userName = "Work User";
      userEmail = "work@company.com";
      extraConfig = {
        init.defaultBranch = "main";
        user.signingkey = "work-gpg-key";
      };
    };
  };
}
```

### Server User Template
Optimized for server administration:

```nix
{
  pkgs,
  ...
}: {
  imports = [ ../common/base-home.nix ];

  home.packages = with pkgs; [
    # Server management tools
    htop
    iotop
    ncdu
    tmux
    screen
    rsync
    
    # Network diagnostics
    nmap
    netcat-gnu
    tcpdump
    wireshark
    dig
    
    # System monitoring
    lm_sensors
    smartmontools
    iostat
    
    # Container management
    docker-compose
    lazydocker
  ];

  programs = {
    tmux = {
      enable = true;
      keyMode = "vi";
      newSession = true;
      extraConfig = ''
        set -g mouse on
        set -g history-limit 10000
      '';
    };
    
    zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      shellAliases = {
        ll = "ls -alF";
        la = "ls -A";
        l = "ls -CF";
        ports = "netstat -tulanp";
        services = "systemctl list-units --type=service";
      };
    };
  };
}
```

### HTPC User Template
Designed for media center operations:

```nix
{
  pkgs,
  ...
}: {
  imports = [ ../common/base-home.nix ];

  home.packages = with pkgs; [
    # Media applications
    vlc
    mpv
    kodi
    plex-media-player
    jellyfin-media-player
    
    # Audio/video utilities
    pavucontrol
    alsamixer
    
    # File management
    ranger
    mc
    
    # Remote access (minimal)
    anydesk
  ];

  programs = {
    firefox = {
      enable = true;
      profiles.htpc = {
        name = "HTPC Profile";
        isDefault = true;
        settings = {
          "media.ffmpeg.vaapi.enabled" = true;
          "media.hardware-video-decoding.enabled" = true;
          "full-screen-api.approval-required" = false;
        };
      };
    };
  };

  # HTPC-specific environment
  home.sessionVariables = {
    BROWSER = "firefox";
    EDITOR = "nano";
  };

  # Create media directories
  home.file = {
    "Media/.keep".text = "";
    "Media/Movies/.keep".text = "";
    "Media/TV Shows/.keep".text = "";
    "Media/Music/.keep".text = "";
  };
}
```

---

## 🐳 Container Integration

The configuration includes automatic multi-user Docker support:

### Features
- **Automatic User Management**: All users in `hostUsers` are automatically added to the docker group
- **Per-Host Configuration**: Docker access is managed per host system
- **Rootless Support**: Optional rootless Docker for enhanced security

### Configuration

The Docker module automatically uses the host's user list:

```nix
# In host configuration
modules.containers.docker = {
  enable = true;
  users = hostUsers;  # Automatically includes all host users
  rootless = false;   # Set to true for rootless Docker
};
```

### User Access Verification

After adding a new user, verify Docker access:

```bash
# Switch to the new user
su - newuser

# Test Docker access
docker run hello-world

# Check group membership
groups
```

---

## 📝 Common Tasks

### Adding System-Wide Packages

Add to the host's `configuration.nix`:

```nix
environment.systemPackages = with pkgs; [
  newpackage
  another-package
];
```

### Adding User-Specific Packages

Add to the user's `<hostname>_home.nix`:

```nix
home.packages = with pkgs; [
  user-specific-package
];
```

### Enabling System Services

In host configuration:

```nix
services.newservice = {
  enable = true;
  # service-specific options
};
```

### Configuring User Services

In user's Home Manager configuration:

```nix
services.user-service = {
  enable = true;
  # user service options
};
```

---

## 🔍 Troubleshooting

### Build Issues

```bash
# Check flake syntax
nix flake check

# Verbose build output
nixos-rebuild switch --flake .#hostname --show-trace

# Test build without switching
nixos-rebuild build --flake .#hostname
```

### User Configuration Issues

```bash
# Build user configuration only
home-manager build --flake .#username@hostname

# Apply user configuration
home-manager switch --flake .#username@hostname

# Debug Home Manager
home-manager switch --flake .#username@hostname --show-trace
```

### Docker Access Issues

```bash
# Check Docker service status
systemctl status docker

# Verify user group membership
groups $USER | grep docker

# Restart Docker service
sudo systemctl restart docker

# Check Docker socket permissions
ls -la /var/run/docker.sock
```

### User Account Issues

```bash
# List all users
cat /etc/passwd | grep -E "(olafkfreund|workuser|serveruser|htpcuser)"

# Check user home directories
ls -la /home/

# Verify user shell
getent passwd username
```

---

## 🔄 Maintenance

### Regular Updates

```bash
# Update flake inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs

# Rebuild with latest inputs
sudo nixos-rebuild switch --flake .#hostname
```

### Cleanup

```bash
# Remove old generations (keep last 3)
sudo nix-collect-garbage --delete-older-than 3d

# Clean user profiles
nix-collect-garbage --delete-older-than 7d

# Optimize nix store
nix-store --optimize
```

### Backup Important Data

```bash
# Export user configurations
cp -r ~/.config/nixos /backup/location/

# Export user data (adapt paths as needed)
rsync -av ~/Documents ~/backup/
rsync -av ~/Pictures ~/backup/
```

---

## 📚 Documentation References

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Package Search](https://search.nixos.org/)
- [Nixpkgs Manual](https://nixos.org/manual/nixpkgs/stable/)
- [Flakes Guide](https://nixos.wiki/wiki/Flakes)

---

## 🤝 Contributing

1. **Code Style**: Follow existing patterns and NixOS best practices
2. **Testing**: Test changes on non-production systems first
3. **Documentation**: Update relevant documentation for new features
4. **Commit Messages**: Use descriptive commit messages explaining changes

### Adding New Hosts

1. Copy an existing host directory as template
2. Update `variables.nix` with hardware-specific settings
3. Modify `configuration.nix` for host-specific needs
4. Add host to flake.nix `nixosConfigurations`
5. Test the configuration before committing

---

## 📄 License

This configuration is for personal use. Feel free to adapt and modify for your own NixOS systems.
