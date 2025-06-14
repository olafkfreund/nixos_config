# 👥 User Management Guide

This guide provides detailed instructions for managing users in the multi-user NixOS configuration.

## 📋 Overview

The configuration supports multiple users per host with role-based configurations. Each user gets:

- Automatic system account creation
- Role-specific Home Manager configuration  
- Automatic Docker group membership
- Host-specific package and service configurations

## 🗺️ Current User Layout

### Host-User Mapping

```nix
hostUsers = {
  p620 = ["olafkfreund" "workuser"];     # Workstation + Business
  razer = ["olafkfreund"];               # Mobile development
  p510 = ["olafkfreund" "serveruser"];   # Server administration
  dex5550 = ["olafkfreund" "htpcuser"];  # Media center
};
```

### User Roles

| User | Role | Hosts | Purpose |
|------|------|-------|---------|
| `olafkfreund` | Primary Admin | All | Full development environment, system administration |
| `workuser` | Business User | P620 | Office applications, business communication tools |
| `serveruser` | Server Admin | P510 | Server management, monitoring, network diagnostics |
| `htpcuser` | Media User | DEX5550 | Media center applications, entertainment |

## ➕ Adding New Users

### Step 1: Plan User Configuration

Before adding a user, determine:

- **Host assignment**: Which systems need this user?
- **Role definition**: What is the user's primary purpose?
- **Package requirements**: What applications does the user need?
- **Access level**: What system permissions are required?

### Step 2: Update Flake Configuration

Edit `flake.nix` to add the user to appropriate hosts:

```nix
# Example: Adding 'devuser' to P620 and P510
hostUsers = {
  p620 = ["olafkfreund" "workuser" "devuser"];
  razer = ["olafkfreund"];
  p510 = ["olafkfreund" "serveruser" "devuser"]; 
  dex5550 = ["olafkfreund" "htpcuser"];
};
```

### Step 3: Create User Directory

```bash
mkdir -p Users/devuser
```

### Step 4: Create Home Configurations

Create a configuration file for each host where the user exists:

#### For P620 (Development Workstation)

Create `Users/devuser/p620_home.nix`:

```nix
{
  pkgs,
  ...
}: {
  imports = [
    ../common/base-home.nix
  ];

  # Development-focused packages
  home.packages = with pkgs; [
    # Programming languages
    nodejs
    python3
    rustc
    cargo
    go
    
    # Development tools
    vscode
    vim
    git
    github-cli
    
    # Containers and virtualization
    docker-compose
    kubectl
    
    # Debugging and profiling
    gdb
    valgrind
    strace
    
    # Documentation
    man-pages
    tldr
  ];

  programs = {
    git = {
      enable = true;
      userName = "Developer User";
      userEmail = "devuser@company.com";
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
        core.editor = "code --wait";
      };
    };
    
    vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        ms-python.python
        rust-lang.rust-analyzer
        bradlc.vscode-tailwindcss
      ];
    };
    
    zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      shellAliases = {
        ll = "ls -alF";
        dev = "cd ~/Development";
        gc = "git commit";
        gp = "git push";
        gl = "git log --oneline";
      };
    };
  };

  # Development services
  services = {
    gpg-agent = {
      enable = true;
      defaultCacheTtl = 1800;
    };
  };

  # Create development directories
  home.file = {
    "Development/.keep".text = "";
    "Development/Projects/.keep".text = "";
    "Development/Scripts/.keep".text = "";
  };
}
```

#### For P510 (Server Environment)

Create `Users/devuser/p510_home.nix`:

```nix
{
  pkgs,
  ...
}: {
  imports = [
    ../common/base-home.nix
  ];

  # Server development packages
  home.packages = with pkgs; [
    # Server languages and tools
    nodejs
    python3
    go
    
    # Container and orchestration
    docker-compose
    kubectl
    helm
    
    # Server monitoring
    htop
    iotop
    
    # Network tools
    curl
    wget
    jq
    
    # Text processing
    vim
    tmux
  ];

  programs = {
    git = {
      enable = true;
      userName = "Developer User";
      userEmail = "devuser@company.com";
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
      };
    };
    
    tmux = {
      enable = true;
      keyMode = "vi";
      extraConfig = ''
        set -g mouse on
        set -g history-limit 50000
      '';
    };
  };
}
```

### Step 5: Apply Configuration

Rebuild the affected hosts:

```bash
# For P620
sudo nixos-rebuild switch --flake .#p620

# For P510  
sudo nixos-rebuild switch --flake .#p510
```

### Step 6: Verify User Creation

```bash
# Check user account exists
getent passwd devuser

# Verify home directory
ls -la /home/devuser

# Check group membership
groups devuser

# Test Docker access (if applicable)
sudo -u devuser docker run hello-world
```

## 🔧 User Role Templates

### Developer User Template

```nix
{
  pkgs,
  ...
}: {
  imports = [ ../common/base-home.nix ];

  home.packages = with pkgs; [
    # Core development
    git
    github-cli
    vscode
    vim
    
    # Programming languages
    nodejs
    python3
    rustc
    cargo
    go
    
    # Build tools
    cmake
    gnumake
    gcc
    
    # Container tools
    docker-compose
    kubectl
    
    # Debugging
    gdb
    strace
  ];

  programs = {
    git = {
      enable = true;
      userName = "Developer";
      userEmail = "dev@example.com";
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
        core.editor = "code --wait";
      };
    };
    
    vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        ms-python.python
        rust-lang.rust-analyzer
        ms-vscode.cpptools
      ];
    };
  };
}
```

### Designer User Template

```nix
{
  pkgs,
  ...
}: {
  imports = [ ../common/base-home.nix ];

  home.packages = with pkgs; [
    # Design tools
    gimp
    inkscape
    blender
    krita
    
    # Web design
    firefox
    chromium
    
    # File management
    nautilus
    
    # Productivity
    libreoffice-fresh
    
    # Media utilities
    vlc
    imagemagick
  ];

  programs = {
    git = {
      enable = true;
      userName = "Designer";
      userEmail = "design@example.com";
    };
    
    firefox = {
      enable = true;
      profiles.design = {
        name = "Design Profile";
        isDefault = true;
      };
    };
  };

  # Create design directories
  home.file = {
    "Design/.keep".text = "";
    "Design/Projects/.keep".text = "";
    "Design/Assets/.keep".text = "";
    "Design/Fonts/.keep".text = "";
  };
}
```

### Testing User Template

```nix
{
  pkgs,
  ...
}: {
  imports = [ ../common/base-home.nix ];

  home.packages = with pkgs; [
    # Testing tools
    selenium-server-standalone
    postman
    
    # Browsers for testing
    firefox
    chromium
    
    # Performance testing
    apache-bench
    wrk
    
    # API testing
    curl
    jq
    
    # Documentation
    pandoc
  ];

  programs = {
    git = {
      enable = true;
      userName = "QA Tester";
      userEmail = "qa@example.com";
    };
  };
}
```

## 🔄 Modifying Existing Users

### Adding Packages to User

Edit the user's `<hostname>_home.nix` file:

```nix
home.packages = with pkgs; [
  # existing packages...
  new-package
  another-package
];
```

Apply changes:

```bash
sudo nixos-rebuild switch --flake .#hostname
```

### Changing User Configuration

Modify program configurations in the user's home file:

```nix
programs.git = {
  enable = true;
  userName = "Updated Name";
  userEmail = "new-email@example.com";
  extraConfig = {
    # new git settings
  };
};
```

### Moving User Between Hosts

1. **Add user to new host** in `flake.nix`
2. **Create configuration** for new host
3. **Remove from old host** (if desired)
4. **Apply configurations** to both hosts

## ❌ Removing Users

### Step 1: Remove from Flake

Edit `flake.nix` to remove user from host:

```nix
hostUsers = {
  p620 = ["olafkfreund" "workuser"];  # removed devuser
  # ...
};
```

### Step 2: Apply Configuration

```bash
sudo nixos-rebuild switch --flake .#hostname
```

### Step 3: Clean Up User Data (Optional)

```bash
# Backup user data if needed
sudo tar -czf /backup/devuser-$(date +%Y%m%d).tar.gz /home/devuser

# Remove user account and home directory
sudo userdel -r devuser
```

### Step 4: Remove Configuration Files

```bash
# Remove user configuration directory
rm -rf Users/devuser
```

## 🔍 Troubleshooting User Issues

### User Account Not Created

```bash
# Check if rebuild completed successfully
sudo nixos-rebuild switch --flake .#hostname --show-trace

# Manually create user if needed
sudo useradd -m -s /bin/bash username
```

### Home Manager Configuration Not Applied

```bash
# Build user configuration directly
home-manager build --flake .#username@hostname

# Apply with verbose output
home-manager switch --flake .#username@hostname --show-trace
```

### Docker Access Issues

```bash
# Check Docker group membership
groups username | grep docker

# Add user to Docker group manually if needed
sudo usermod -aG docker username

# Restart Docker service
sudo systemctl restart docker
```

### Permission Issues

```bash
# Fix home directory permissions
sudo chown -R username:username /home/username

# Check user shell
getent passwd username

# Reset user password if needed
sudo passwd username
```

## 📚 Best Practices

### Security Considerations

- **Principle of Least Privilege**: Only grant necessary permissions
- **Regular Updates**: Keep user configurations updated
- **Access Review**: Periodically review user access and permissions
- **Strong Authentication**: Use SSH keys and proper authentication

### Configuration Management

- **Version Control**: Track all user configuration changes
- **Testing**: Test user configurations on non-production systems
- **Documentation**: Document user roles and purposes
- **Consistency**: Use consistent naming and structure patterns

### Performance Optimization

- **Package Selection**: Only include necessary packages per user
- **Service Management**: Disable unused services
- **Resource Limits**: Consider setting user resource limits
- **Storage Management**: Implement proper home directory quotas

## 🔗 Related Documentation

- [NixOS User Management](https://nixos.org/manual/nixos/stable/#sec-user-management)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Docker Multi-User Setup](https://docs.docker.com/engine/install/linux-postinstall/)
- [NixOS Security Guidelines](https://nixos.org/manual/nixos/stable/#sec-security)