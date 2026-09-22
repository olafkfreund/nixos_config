---
name: nixos-standards
description: Modern NixOS best practices for writing flakes, modules, packages, overlays, secrets (agenix), systemd service hardening, dev shells, and Home Manager modules — plus the anti-patterns to avoid. Use when authoring or reviewing any Nix/NixOS configuration, module, or package derivation.
---

## NixOS Development Standards

### Modern NixOS Best Practices

#### 1. **Flake-First Development**
- Always use `flakes` for new configurations and projects
- Enable experimental features: `nix.settings.experimental-features = [ "nix-command" "flakes" ];`
- Use `flake.lock` for reproducible builds
- Follow semantic versioning in flake inputs
- Prefer `inputs.nixpkgs.follows = "nixpkgs"` for consistency

#### 2. **Module System Excellence**
```nix
# Preferred module structure
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.myservice;
in {
  options.services.myservice = {
    enable = mkEnableOption "MyService";
    package = mkPackageOption pkgs "myservice" {};
    settings = mkOption {
      type = types.submodule {
        freeformType = with types; attrsOf anything;
        options = {
          # Structured options here
        };
      };
      default = {};
      description = "Configuration for MyService";
    };
  };

  config = mkIf cfg.enable {
    # Implementation here
    meta.maintainers = with maintainers; [ username ];
  };
}
```

#### 3. **Advanced Configuration Patterns**

**Feature Flag Architecture:**
```nix
# Use consistent feature flag patterns
features = {
  development = {
    enable = mkEnableOption "Development tools and environments";
    languages = mkOption {
      type = types.attrsOf types.bool;
      default = {};
      description = "Language-specific development tools";
    };
  };
};
```

**Conditional Module Loading:**
```nix
imports = [
  # Conditional imports based on system
  (mkIf (system == "x86_64-linux") ./hardware/intel.nix)
  (mkIf config.features.gaming.enable ./gaming.nix)
];
```

#### 4. **Modern Package Management**

**Overlay Patterns:**
```nix
# Use structured overlays
final: prev: {
  myPackages = prev.myPackages or {} // {
    customTool = prev.callPackage ./pkgs/custom-tool {};
  };
}
```

**Package Derivation Best Practices:**
```nix
{ lib, stdenv, fetchFromGitHub, ... }:
stdenv.mkDerivation rec {
  pname = "my-package";
  version = "1.0.0";
  
  src = fetchFromGitHub {
    owner = "owner";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  
  # Use structured attributes
  strictDeps = true;
  
  meta = with lib; {
    description = "Short description";
    homepage = "https://example.com";
    license = licenses.mit;
    maintainers = with maintainers; [ username ];
    platforms = platforms.linux;
  };
}
```

#### 5. **Security Best Practices**

**Secrets Management (Agenix):**
```nix
# Proper secret handling
age.secrets."api-key" = {
  file = ../secrets/api-key.age;
  mode = "0400";
  owner = config.services.myservice.user;
  group = config.services.myservice.group;
};

# Reference secrets properly
services.myservice.apiKeyFile = config.age.secrets."api-key".path;
```

**Service Hardening:**
```nix
systemd.services.myservice = {
  serviceConfig = {
    # Security hardening
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectControlGroups = true;
    RestrictSUIDSGID = true;
    
    # Resource limits
    MemoryMax = "1G";
    TasksMax = 1000;
    
    # User isolation
    DynamicUser = true;
    User = "myservice";
    Group = "myservice";
  };
};
```

#### 6. **Performance Optimization**

**Build Optimization:**
```nix
# Use parallel builds
nix.settings = {
  max-jobs = "auto";
  cores = 0;  # Use all cores
  
  # Build optimization
  keep-outputs = true;
  keep-derivations = true;
  
  # Sandbox and substituters
  sandbox = true;
  substituters = [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
    "https://your-cache.example.com"
  ];
};
```

**System Optimization:**
```nix
# Modern kernel and optimizations
boot = {
  kernelPackages = pkgs.linuxPackages_latest;
  kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };
};
```

#### 7. **Testing and Validation**

**NixOS Tests:**
```nix
# Create proper NixOS VM tests
import <nixpkgs/nixos/tests/make-test-python.nix> ({ pkgs, ... }: {
  name = "my-service-test";
  
  nodes.machine = { ... }: {
    imports = [ ./my-service-module.nix ];
    services.my-service.enable = true;
  };
  
  testScript = ''
    machine.start()
    machine.wait_for_unit("my-service")
    machine.succeed("curl -f http://localhost:8080/health")
  '';
})
```

**Configuration Validation:**
```nix
# Add assertions and warnings
config = mkIf cfg.enable {
  assertions = [
    {
      assertion = cfg.database.host != "";
      message = "Database host must be configured";
    }
  ];
  
  warnings = optional (cfg.security.enabled == false) [
    "Security is disabled - not recommended for production"
  ];
};
```

#### 8. **Development Environment Standards**

**Dev Shells:**
```nix
# Comprehensive development shells
devShells.default = pkgs.mkShell {
  packages = with pkgs; [
    # Nix tools
    nixd          # LSP
    nil           # Alternative LSP
    statix        # Linter
    deadnix       # Dead code detection
    nix-tree      # Dependency visualization
    nix-diff      # Configuration diffing
    
    # Development tools
    pre-commit
    commitizen
    just
  ];
  
  shellHook = ''
    echo "NixOS development environment loaded"
    pre-commit install --install-hooks
  '';
};
```

#### 9. **Documentation Standards**

**Module Documentation:**
```nix
# Always include comprehensive options documentation
options.services.myservice = {
  enable = mkEnableOption "MyService daemon";
  
  package = mkPackageOption pkgs "myservice" {
    default = pkgs.myservice;
    example = literalExpression "pkgs.myservice.override { enableFeature = true; }";
  };
  
  settings = mkOption {
    type = with types; attrsOf anything;
    default = {};
    example = literalExpression ''
      {
        server = {
          host = "0.0.0.0";
          port = 8080;
        };
        database = {
          url = "postgresql://localhost/myservice";
        };
      }
    '';
    description = ''
      Configuration for MyService.
      
      See <https://myservice.example.com/docs> for available options.
    '';
  };
};
```

#### 10. **Modern Home Manager Integration**

```nix
# Proper Home Manager module structure
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.programs.myprogram;
in {
  options.programs.myprogram = {
    enable = mkEnableOption "MyProgram";
    
    settings = mkOption {
      type = with types; attrsOf anything;
      default = {};
      description = "Configuration written to myprogram config file";
    };
  };
  
  config = mkIf cfg.enable {
    home.packages = [ pkgs.myprogram ];
    
    xdg.configFile."myprogram/config.toml" = mkIf (cfg.settings != {}) {
      source = (pkgs.formats.toml {}).generate "myprogram-config" cfg.settings;
    };
  };
}
```

### NixOS Anti-Patterns to Avoid

#### ❌ **Don't Do:**
- Use `with pkgs;` globally - prefer explicit `pkgs.package`
- Hardcode paths - use `pkgs.writeScript` or similar
- Use `fetchurl` without hash verification
- Mix imperative and declarative approaches
- Use deprecated options (check warnings)
- Ignore deprecation warnings
- Use `builtins.readFile` for secrets
- Skip option documentation
- Use `rec` unnecessarily in attribute sets

#### ✅ **Do Instead:**
- Use explicit package references: `pkgs.hello`
- Use proper derivations for custom scripts
- Always provide hashes for fetchers
- Keep everything declarative
- Migrate to new options promptly
- Fix deprecation warnings immediately
- Use proper secrets management
- Document all options thoroughly
- Use `let` bindings instead of `rec`

### Code Quality Standards

#### **Formatting:**
```bash
# Use nixpkgs-fmt for consistent formatting
nixpkgs-fmt **/*.nix

# Use statix for linting
statix check

# Use deadnix for unused code detection
deadnix
```

#### **Import Organization:**
```nix
# Organize imports consistently
{ config        # NixOS configuration
, lib           # Library functions
, pkgs          # Package set
, modulesPath   # NixOS modules path (if needed)
, ...           # Additional arguments
}:
```

