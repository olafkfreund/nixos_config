# NixOS Anti-Patterns and Best Practices

> **Important**: These patterns were identified through community feedback and code review in GitHub issues #10, #11, and #12. Following these guidelines prevents common mistakes and ensures idiomatic NixOS code.

## 📚 Background

This document captures critical lessons learned from real community feedback about anti-patterns in NixOS configurations. These patterns were found in this repository and fixed based on expert review, helping establish guidelines for future development.

## ❌ **Critical Anti-Patterns to Avoid**

### **1. Nix Language Anti-Patterns**

#### **Unquoted URLs (Deprecated)**

```nix
# ❌ BAD - Unquoted URL
fetchurl {
  url = https://example.com/file.tar.gz;
  sha256 = "...";
}

# ✅ GOOD - Always quote URLs
fetchurl {
  url = "https://example.com/file.tar.gz";
  sha256 = "...";
}
```

**Why problematic:** RFC 45 deprecated unquoted URLs due to parsing ambiguities and static analysis difficulties.

#### **Excessive `with` Usage**

```nix
# ❌ BAD - Unclear variable origins
with (import <nixpkgs> {});
with lib;
with stdenv;
buildInputs = [ curl jq ];  # Where do these come from?

# ✅ GOOD - Explicit imports
let
  pkgs = import <nixpkgs> {};
  inherit (pkgs) lib stdenv;
in
buildInputs = with pkgs; [ curl jq ];  # Limited, clear scope
```

**Why problematic:** Static analysis tools can't determine variable sources, makes refactoring difficult, and creates ambiguity for newcomers.

#### **Dangerous `rec` Usage**

```nix
# ❌ BAD - Infinite recursion risk
rec {
  a = 1;
  b = let a = a + 1; in a;  # Infinite recursion!
}

# ✅ GOOD - Explicit self-reference
let
  attrset = { a = 1; b = attrset.a + 1; };
in attrset
```

#### **Import From Derivation (IFD)**

```nix
# ❌ BAD - IFD blocks evaluation
let
  generatedConfig = pkgs.runCommand "config" {} ''
    echo "some_value = 42" > $out
  '';
  configValue = builtins.readFile generatedConfig;  # Forces build!
in
pkgs.writeText "app-config" configValue

# ✅ GOOD - Keep evaluation and building separate
let
  generatedConfig = pkgs.runCommand "config" {} ''
    echo "some_value = 42" > $out
  '';
in
pkgs.runCommand "app-config" { inherit generatedConfig; } ''
  cp $generatedConfig $out
''
```

**Performance impact:** Can increase evaluation time from seconds to hours for complex projects.

#### **Reading Secrets During Evaluation**

```nix
# ❌ BAD - Exposes password in store
services.myservice = {
  password = builtins.readFile "/secrets/password";  # INSECURE!
}

# ✅ GOOD - Reference paths for runtime loading
services.myservice = {
  passwordFile = "/secrets/password";  # Read at runtime
}

# ✅ BETTER - Use secret management
age.secrets.myservice-password.file = ../secrets/password.age;
services.myservice.passwordFile = config.age.secrets.myservice-password.path;
```

### **2. The `mkIf true` Anti-Pattern**

```nix
# ❌ WRONG - Unnecessary abstraction
services.myservice.enable = mkIf cfg.enable true;
light.enable = mkIf (cfg.profile == "laptop") true;
qemuGuest.enable = mkIf (cfg.type == "qemu" || cfg.type == "auto") true;

# ✅ CORRECT - Direct assignment
services.myservice.enable = cfg.enable;
light.enable = cfg.profile == "laptop";
qemuGuest.enable = cfg.type == "qemu" || cfg.type == "auto";
```

**Why this is wrong**:

- The NixOS module system automatically ignores disabled services
- `mkIf condition true` adds evaluation overhead for no benefit
- Trust the module system to handle enablement correctly
- This pattern was found in 8+ locations in the original codebase

### **2. Trivial Function Wrappers**

```nix
# ❌ WRONG - Pointless re-exports that add no value
mkMerge = lib.mkMerge;
mkIf = condition: config: lib.mkIf condition config;

# Functions that just call other functions with the same parameters
mkService = { name, enable ? true, config ? { } }:
  lib.mkIf enable {  # Also combines with anti-pattern #1
    services.${name} = lib.mkMerge [
      { enable = true; }
      config
    ];
  };

# ✅ CORRECT - Use library functions directly
lib.mkMerge [...]
lib.mkIf condition config

# For services, trust the module system
services.${name} = lib.mkMerge [
  { inherit enable; }
  config
];
```

**Why this is wrong**:

- Re-exporting without adding value creates pointless complexity
- Makes code harder to understand, not easier
- Increases maintenance burden without benefit
- The original `lib/default.nix` was deleted entirely due to this pattern

### **3. Magic Auto-Discovery**

```nix
# ❌ WRONG - Complex auto-discovery that hides behavior
discoverModules = dir:
  let
    entries = builtins.readDir dir;
    moduleEntries = lib.filterAttrs
      (name: type:
        name != "installer" &&
        (type == "directory" ||
         (type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix"))
      )
      entries;
    modulePaths = lib.mapAttrsToList
      (name: type:
        if type == "directory" then
          dir + "/${name}"
        else
          dir + "/${name}"
      )
      moduleEntries;
  in
  modulePaths;

# ✅ CORRECT - Explicit imports are clear and obvious
imports = [
  ./core
  ./desktop
  ./development
  ./gaming
  ./hardware
  ./presets
  ./profiles
  ./security
  ./services
  ./virtualization
  ./wsl
  ./template.nix
];
```

**Why this is wrong**:

- Makes debugging extremely difficult
- Hides module dependencies and load order
- Non-obvious behavior that surprises users
- 30+ lines of complex logic replaced with simple explicit list

### **4. Security Anti-Patterns**

#### **Running Services as Root Unnecessarily**

```nix
# ❌ BAD - Service runs as root by default
systemd.services.myservice = {
  serviceConfig = {
    ExecStart = "${pkgs.myapp}/bin/myapp";
    # No User specified - runs as root!
  };
};

# ✅ GOOD - Dedicated user with hardening
users.users.myservice = {
  isSystemUser = true;
  group = "myservice";
};
users.groups.myservice = {};

systemd.services.myservice = {
  serviceConfig = {
    ExecStart = "${pkgs.myapp}/bin/myapp";
    User = "myservice";
    Group = "myservice";

    # Process isolation
    DynamicUser = true;
    PrivateTmp = true;
    ProtectSystem = "strict";
    ProtectHome = true;

    # Capabilities restrictions
    NoNewPrivileges = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
  };
};
```

#### **Poor Firewall Configuration**

```nix
# ❌ BAD - Security nightmare
networking.firewall.enable = false;
# OR
networking.firewall.allowedTCPPorts = [ 1-65535 ];

# ✅ GOOD - Minimal port opening
networking.firewall = {
  enable = true;
  allowedTCPPorts = [ 80 443 ];  # Only what's needed

  # Interface-specific rules
  interfaces."enp3s0" = {
    allowedTCPPorts = [ 5432 ];  # PostgreSQL on internal only
  };
};
```

### **5. Package Management Anti-Patterns**

#### **Using `nix-env` for System Packages**

```bash
# ❌ BAD - Imperative installation
nix-env -i firefox vim git
```

```nix
# ✅ GOOD - Declarative in configuration.nix
environment.systemPackages = with pkgs; [
  firefox
  vim
  git
];
```

**Why problematic:** Packages installed via `nix-env` aren't tracked in configuration, persist across rebuilds unexpectedly, and make rollbacks incomplete.

#### **Misusing `environment.systemPackages`**

```nix
# ❌ BAD - Everything system-wide
environment.systemPackages = with pkgs; [
  firefox      # Should be user-specific
  vscode       # Development tool
  spotify      # Personal application
];

# ✅ GOOD - Proper separation
environment.systemPackages = with pkgs; [
  wget curl git vim  # System essentials only
];

users.users.alice.packages = with pkgs; [
  firefox vscode spotify  # User-specific
];
```

#### **Monolithic Configuration File**

```nix
# ❌ BAD - 500+ line configuration.nix
{ config, pkgs, ... }: {
  boot.loader.grub.enable = true;
  networking.hostName = "myhost";
  services.nginx.enable = true;
  # ... hundreds more lines
}
```

```
# ✅ GOOD - Modular structure
/etc/nixos/
├── configuration.nix        # Main entry point
├── hardware-configuration.nix
├── modules/
│   ├── networking.nix
│   ├── security.nix
│   └── users.nix
└── services/
    ├── nginx.nix
    └── postgresql.nix
```

### **6. Performance Anti-Patterns**

#### **Never Running Garbage Collection**

```nix
# ❌ BAD - No automated cleanup

# ✅ GOOD - Automated management
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};

nix.optimise = {
  automatic = true;
  dates = [ "03:45" ];
};
```

**Problem:** Store grows unbounded (100GB+).

#### **Poor Binary Cache Configuration**

```nix
# ❌ BAD - Wrong public key
nix.settings = {
  substituters = [ "https://cache.example.org" ];
  trusted-public-keys = [ "wrong-key" ];  # Breaks everything!
};

# ✅ GOOD - Proper cache setup
nix.settings = {
  substituters = [
    "https://cache.nixos.org/"
    "https://nix-community.cachix.org"
  ];
  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];
};
```

#### **Unsafe System Updates**

```bash
# ❌ BAD - Risky
nixos-rebuild switch --upgrade

# ✅ GOOD - Test first
nixos-rebuild build       # Build only
nixos-rebuild test        # Test without making permanent
nixos-rebuild build-vm    # Test in VM
nixos-rebuild switch      # Apply when confident
```

### **7. Home Manager Anti-Patterns**

#### **Missing stateVersion**

```nix
# ❌ BAD - No stateVersion
{
  programs.git.enable = true;
  # Error: The option 'home.stateVersion' is used but not defined
}

# ✅ GOOD - Set once, don't change
{
  home.stateVersion = "24.05";  # Set to current version when starting
  programs.git.enable = true;
}
```

#### **Duplicate Package Management**

```nix
# ❌ BAD - Duplication
# /etc/nixos/configuration.nix
environment.systemPackages = with pkgs; [ neovim git ];

# ~/.config/home-manager/home.nix
home.packages = with pkgs; [ neovim git ];  # Conflict!

# ✅ GOOD - Clear separation
# System: only system-wide essentials
# Home Manager: user-specific packages
```

### **8. Unnecessary Template Functions**

```nix
# ❌ WRONG - Redundant wrappers for every possible variant
mkWorkstation = { hostname, system ? "x86_64-linux", extraModules ? [ ] }:
  mkSystem { inherit hostname system extraModules; profile = "workstation"; };

mkServer = { hostname, system ? "x86_64-linux", extraModules ? [ ] }:
  mkSystem { inherit hostname system extraModules; profile = "server"; };

mkDevelopment = { hostname, system ? "x86_64-linux", extraModules ? [ ] }:
  mkSystem { inherit hostname system extraModules; profile = "development"; };

mkGaming = { hostname, system ? "x86_64-linux", extraModules ? [ ] }:
  mkSystem { inherit hostname system extraModules; profile = "gaming"; };

# ... 5 more similar functions

# ✅ CORRECT - Direct usage with explicit parameters
nixosConfigurations = {
  my-workstation = mkSystem {
    hostname = "my-workstation";
    profile = "workstation";
  };

  my-server = mkSystem {
    hostname = "my-server";
    profile = "server";
    system = "aarch64-linux";
  };
};
```

**Why this is wrong**:

- Creates maintenance burden without adding value
- Users can call the base function directly with desired parameters
- Proliferates similar functions (9 template functions were removed)
- Each wrapper function saved only 1 line of code

### **5. Code Duplication Without Extraction**

```nix
# ❌ WRONG - Repeated definitions across configurations
programs.bash.shellAliases = {
  ll = "ls -alF";
  la = "ls -A";
  l = "ls -CF";
  ".." = "cd ..";
  "..." = "cd ../..";
  gs = "git status";
  ga = "git add";
  gc = "git commit";
  gp = "git push";
  gl = "git log --oneline";
  gd = "git diff";
  # ... more aliases
};

programs.zsh.shellAliases = {
  ll = "ls -alF";        # Exact duplication
  la = "ls -A";          # Exact duplication
  l = "ls -CF";          # Exact duplication
  ".." = "cd ..";        # Exact duplication
  "..." = "cd ../..";    # Exact duplication
  gs = "git status";     # Exact duplication
  ga = "git add";        # Exact duplication
  # ... same aliases repeated
};

# ✅ CORRECT - Shared definition with proper extraction
let
  commonAliases = {
    # System shortcuts
    ll = "ls -alF";
    la = "ls -A";
    l = "ls -CF";
    ".." = "cd ..";
    "..." = "cd ../..";

    # Git shortcuts
    gs = "git status";
    ga = "git add";
    gc = "git commit";
    gp = "git push";
    gl = "git log --oneline";
    gd = "git diff";

    # System monitoring
    psg = "ps aux | grep";
    h = "history";
    j = "jobs -l";

    # Safety aliases
    rm = "rm -i";
    cp = "cp -i";
    mv = "mv -i";

    # Directory shortcuts
    mkdir = "mkdir -pv";
  };
in {
  programs.bash.shellAliases = commonAliases;
  programs.zsh.shellAliases = commonAliases;
}
```

**Why this is wrong**:

- Violates DRY (Don't Repeat Yourself) principle
- Creates maintenance nightmare when aliases need updates
- Easy to have definitions drift apart over time
- 25+ lines of duplication eliminated by proper extraction

## ✅ **Required Patterns for NixOS**

### **1. Always Use Explicit Imports**

- List all module imports explicitly in a clear list
- Avoid auto-discovery mechanisms that hide behavior
- Make dependencies and load order obvious
- Enable easy addition/removal of modules

### **2. Trust the NixOS Module System**

- Don't wrap functionality that already works correctly
- Use direct boolean assignments for service enablement
- Let the type system and module evaluation do their job
- The module system handles disabled services properly

### **3. Extract Common Functionality Properly**

- Use shared variables for truly repeated data
- Create functions only when they add real abstraction value
- Prefer composition over unnecessary wrapper functions
- Extract at the right level (don't over-abstract)

### **4. Follow Community Standards**

- Use established NixOS patterns from nixpkgs
- Don't reinvent existing functionality
- Check how official modules handle similar cases
- Prefer explicit over implicit behavior

### **5. Be Transparent About AI Assistance**

- Always disclose AI involvement prominently in generated code
- Encourage human review of generated configurations
- Welcome community feedback and expert oversight
- Add warnings about reviewing AI-generated content carefully

## **Performance and Maintainability Impact**

The anti-pattern fixes in this repository resulted in:

- **165 lines of code removed** (net reduction from 225 deletions, 60 additions)
- **Elimination of evaluation overhead** from unnecessary `mkIf` wrappers
- **Improved debugging experience** with explicit imports
- **Reduced maintenance burden** by eliminating duplicate code
- **Better alignment with NixOS community patterns**

## **Comprehensive Code Review Checklist**

Before submitting any NixOS configuration changes, verify:

### **Language & Syntax:**

- [ ] **No `mkIf condition true` patterns** - use direct assignment instead
- [ ] **URLs are quoted** - no bare URLs (deprecated since RFC 45)
- [ ] **No excessive `with` usage** - explicit imports for clarity
- [ ] **Using `inherit` where appropriate** - avoid manual assignment repetition
- [ ] **Minimal `rec` usage** - avoid infinite recursion risks
- [ ] **No Import From Derivation (IFD)** - keep evaluation and build separate
- [ ] **Path division uses spacing** - `6 / 3` not `6/3`

### **Security & Safety:**

- [ ] **Secrets not read during evaluation** - use runtime loading or agenix
- [ ] **Services run with minimal privileges** - dedicated users, not root
- [ ] **Firewall enabled with minimal ports** - only necessary ports open
- [ ] **No `nix-env` for system packages** - use declarative configuration
- [ ] **Proper systemd hardening** - DynamicUser, ProtectSystem, etc.

### **Architecture & Organization:**

- [ ] **No magic auto-discovery mechanisms** - use explicit imports
- [ ] **All imports are explicit and clear** - avoid hidden module loading
- [ ] **Modular configuration structure** - no monolithic files
- [ ] **Proper package separation** - system vs user packages
- [ ] **Common functionality is properly extracted** - eliminate duplication
- [ ] **Functions add real value** - avoid trivial wrappers
- [ ] **No trivial function re-exports** - call library functions directly

### **Performance & Maintenance:**

- [ ] **Garbage collection configured** - prevent unbounded store growth
- [ ] **Binary caches properly configured** - correct public keys
- [ ] **Store optimization enabled** - nix.optimise settings
- [ ] **Safe update procedures** - test before production deployment
- [ ] **No blocking direnv operations** - <500ms execution time

### **Home Manager (if applicable):**

- [ ] **stateVersion is set** - most common Home Manager error
- [ ] **No duplicate package management** - clear system/user separation
- [ ] **Gradual config migration** - avoid conflicts with existing dotfiles
- [ ] **Pure configuration** - avoid mkOutOfStoreSymlink in flakes

### **Development Environment:**

- [ ] **Modular flake structure** - no everything-in-flake.nix
- [ ] **Cross-compilation compatible** - proper system handling
- [ ] **Correct dependency categorization** - nativeBuildInputs vs buildInputs
- [ ] **Phase hooks included** - runHook preInstall/postInstall

### **General Best Practices:**

- [ ] **Configuration follows NixOS community patterns** - check nixpkgs for examples
- [ ] **AI assistance is properly disclosed** (if applicable) - transparency in generated content
- [ ] **Detection tools used** - statix check, nixpkgs-hammering when relevant

## **When in Doubt - Decision Framework**

1. **Check nixpkgs**: How do official modules handle similar functionality?
1. **Ask the community**: NixOS Discourse or Matrix channels for guidance
1. **Prefer explicit**: Make behavior obvious and discoverable, not magical
1. **Trust the system**: NixOS modules handle most cases correctly without extra wrapping
1. **Less is more**: Remove code and abstractions rather than adding unnecessary ones

## **Real-World Example: Before and After**

### Before (Anti-patterns)

```nix
# lib/default.nix (32 lines - DELETED ENTIRELY)
{ lib }:
rec {
  mkHost = import ./mkHost.nix { inherit lib; };
  mkIf = condition: config: lib.mkIf condition config;  # Pointless wrapper
  mkMerge = lib.mkMerge;                                # Pointless re-export
  mkService = { name, enable ? true, config ? { } }:   # Unnecessary abstraction
    lib.mkIf enable {                                  # Anti-pattern #1
      services.${name} = lib.mkMerge [
        { enable = true; }
        config
      ];
    };
}

# modules/default.nix (49 lines of auto-discovery logic)
discoverModules = dir: let
  # ... 30+ lines of complex auto-discovery
in modulePaths;

# Multiple files with mkIf true patterns
services.qemuGuest.enable = mkIf (cfg.type == "qemu" || cfg.type == "auto") true;
programs.dconf.enable = mkIf cfg.applications.gnome-boxes true;
# ... 8 more instances

# Duplicate shell aliases in home/profiles/base.nix
programs.bash.shellAliases = { ll = "ls -alF"; la = "ls -A"; /* ... */ };
programs.zsh.shellAliases = { ll = "ls -alF"; la = "ls -A"; /* ... */ };
```

### After (Best practices)

```nix
# lib/default.nix - DELETED (unnecessary abstractions removed)

# modules/default.nix (17 lines - explicit and clear)
{
  imports = [
    ./core
    ./desktop
    ./development
    ./gaming
    ./hardware
    ./presets
    ./profiles
    ./security
    ./services
    ./virtualization
    ./wsl
    ./template.nix
  ];
}

# Direct assignments throughout codebase
services.qemuGuest.enable = cfg.type == "qemu" || cfg.type == "auto";
programs.dconf.enable = cfg.applications.gnome-boxes;

# Shared aliases in home/profiles/base.nix
let
  commonAliases = {
    ll = "ls -alF";
    la = "ls -A";
    # ... defined once
  };
in {
  programs.bash.shellAliases = commonAliases;
  programs.zsh.shellAliases = commonAliases;
}
```

## **Community Feedback Integration**

These patterns were identified through:

- **GitHub Issues #10, #11, #12** from experienced NixOS community members
- **Expert code review** pointing out anti-patterns and suggesting improvements
- **Performance analysis** showing evaluation overhead from unnecessary abstractions
- **Maintainability concerns** about hidden behavior and debugging difficulty

This demonstrates the importance of:

- **Community review** for code quality
- **Transparency** about AI-generated content
- **Responsiveness** to expert feedback
- **Continuous improvement** based on best practices

## **Conclusion**

Following these guidelines ensures NixOS configurations that are:

- **Idiomatic** and follow community standards
- **Maintainable** with clear, explicit behavior
- **Performant** without unnecessary evaluation overhead
- **Debuggable** with obvious module relationships
- **Trustworthy** with proper disclosure of AI assistance

These patterns help both human developers and AI systems create better NixOS code that the community can rely on and build upon.
