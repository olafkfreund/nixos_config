# 🚀 NixOS Configuration - Quick Start Guide

## 🎯 **CURRENT STATUS: SINGLE UNIFIED FLAKE**

**✅ Migration Complete**: The configuration now uses a **single, unified flake.nix** that incorporates the best of both the legacy and modern architectures. No migration needed - you can start using it immediately!

## ✅ Ready-to-Use Configuration

- [ ] Verify current configuration is working: `nix flake check`
- [ ] Review available hosts and configurations below
- [ ] Apply to your system or create new host configuration
- [ ] All important data backed up (recommended)

## 🏠 Host Configuration - Quick Deploy

### **Ready-to-Use Hosts (Single Flake)**

Your unified `flake.nix` already includes these pre-configured hosts:

```nix
# AMD Workstation (P620)
# Command: sudo nixos-rebuild switch --flake .#p620
p620 = {
  hostname = "p620";
  hardware = "amd-workstation";  # AMD + ROCm support
  profile = "workstation";       # Full desktop + development
  users = ["olafkfreund"];
};

# Intel Laptop (Razer)  
# Command: sudo nixos-rebuild switch --flake .#razer
razer = {
  hostname = "razer";
  hardware = "intel-laptop";     # Intel + power management
  profile = "laptop";            # Desktop + laptop optimizations
  users = ["olafkfreund"];
};

# NVIDIA Gaming (P510)
# Command: sudo nixos-rebuild switch --flake .#p510
p510 = {
  hostname = "p510";
  hardware = "nvidia-gaming";    # NVIDIA + CUDA + gaming
  profile = "workstation";       # Full desktop + development
  users = ["olafkfreund"];
};

# HTPC (DEX5550)
# Command: sudo nixos-rebuild switch --flake .#dex5550
dex5550 = {
  hostname = "dex5550";
  hardware = "htpc-intel";       # Intel + media acceleration
  profile = "htpc";              # Desktop + media + efficiency
  users = ["olafkfreund"];
};
```

### **Quick Deploy to Your System**

1. **Test the configuration**: `nix flake check`
2. **Build for your host**: `nixos-rebuild build --flake .#hostname`
3. **Deploy**: `sudo nixos-rebuild switch --flake .#hostname`

### **Add New Host to Single Flake**

Add to your `flake.nix` nixosConfigurations:

```nix
your-hostname = nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    ./hosts/your-hostname  # Your host-specific config
    ./profiles/base.nix    # Choose appropriate profile
    # Add other modules as needed
  ];
};
```

### **Hardware Profiles Available**
- `amd-workstation` - AMD CPU + GPU with ROCm support
- `intel-laptop` - Intel with power management + touchpad
- `nvidia-gaming` - NVIDIA with CUDA + gaming optimizations
- `htpc-intel` - Intel with media acceleration

### **Host Types Available**
- `workstation` - Full desktop with development tools
- `laptop` - Desktop + power management + laptop hardware
- `server` - Minimal + security hardening + services
- `htpc` - Desktop + media applications + efficiency

## ⚙️ Configuration Options Quick Reference

### **Base System**
```nix
custom.base = {
  enable = true;
  timezone = "Europe/London";
  locale = "en_GB.UTF-8";
  users = ["username"];
};
```

### **Desktop Environment**
```nix
custom.desktop = {
  enable = true;
  session = "hyprland"; # or "plasma", "gnome"
  displayManager = "greetd"; # or "sddm", "gdm"
  audio = {
    enable = true;
    lowLatency = false;
  };
};
```

### **Development Environment**
```nix
custom.development = {
  enable = true;
  languages = ["nix" "rust" "python" "javascript"];
  editors = ["nixvim" "vscode"];
  tools = ["git" "docker"];
  containers = {
    enable = true;
    runtime = "docker"; # or "podman"
  };
};
```

### **Server Configuration**
```nix
custom.server = {
  enable = true;
  ssh = {
    enable = true;
    port = 22;
    allowedUsers = ["username"];
  };
  firewall.strict = true;
  monitoring.enable = false;
};
```

## 🔧 Common Commands

### **Building and Switching (Single Flake)**

```bash
# Validate the unified configuration
nix flake check

# Build configuration (test without applying)
nixos-rebuild build --flake .#hostname

# Switch to new configuration  
sudo nixos-rebuild switch --flake .#hostname

# Home Manager switch
home-manager switch --flake .#username@hostname
```

### **Development**

```bash
# Enter development shell
nix develop

# Format Nix files
alejandra .

# Lint Nix files  
statix check .

# Find dead code
deadnix .
```

### **Validation and Testing**

```bash
# Full validation of unified flake
nix flake check

# Extended validation with custom scripts
./scripts/validate-config.sh

# Test specific components (if validation scripts support it)
./scripts/validate-config.sh syntax
```

## 🆘 Troubleshooting

### **Build Failures**

1. Check flake syntax: `nix flake check`
2. Validate with scripts: `./scripts/validate-config.sh syntax`
3. Review error messages for missing imports
4. Compare with working host configurations
5. Check hardware profile matches your system

### **Module Import Errors**

1. Verify import paths in `modules/default.nix` and profile files
2. Check that all required modules exist in the modules directory
3. Review the single flake's module organization structure

### **Option Declaration Errors**

1. Ensure options are declared before use in modules
2. Check option types match the values provided
3. Review examples in existing module files

### **Hardware Profile Issues**

1. Verify hardware profile name matches available profiles in `modules/hardware/profiles/`
2. Check that `hardware-configuration.nix` is up to date
3. Review hardware-specific modules for your system type

### **System Recovery**

```bash
# If something breaks, rollback to previous generation
sudo nixos-rebuild switch --rollback

# Or use nix rollback
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
sudo nix-env --switch-generation [generation-number] --profile /nix/var/nix/profiles/system

# Then reboot to activate the rollback
sudo reboot
```

## 📚 Key Files Reference

### **Single Flake Configuration**
- `flake.nix` - **Unified flake** with all host configurations
- `flake.lock` - Locked dependencies for reproducible builds

### **Core Library**
- `lib/default.nix` - Main library exports
- `lib/host-builders.nix` - Host configuration functions (if used)
- `lib/profiles.nix` - Profile definitions
- `lib/hardware.nix` - Hardware abstraction

### **Configuration Profiles**
- `profiles/base.nix` - Essential system configuration
- `profiles/desktop.nix` - Desktop environment setup  
- `profiles/development.nix` - Development tools
- `profiles/server.nix` - Server optimizations

### **Hardware Profiles**
- `modules/hardware/profiles/` - Hardware-specific configurations
- `modules/hardware/` - Hardware abstraction modules

### **Templates**
- `templates/minimal/` - Basic system template
- `templates/workstation/` - Full desktop template

### **Scripts**
- `scripts/validate-config.sh` - Configuration validation
- `scripts/manage-secrets.sh` - Secrets management

## 📞 Getting Help

1. **Documentation**: Check `README.md` and `docs/` for detailed information
2. **Examples**: Review templates and existing host configurations  
3. **Validation**: Use `nix flake check` and validation scripts to identify issues
4. **Community**: NixOS manual and community resources

---

**🎉 Ready to go! Your unified flake is ready to use immediately! 🚀**
