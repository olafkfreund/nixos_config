# NixOS and Nixpkgs Patterns Guide

> **Comprehensive best practices guide** for writing idiomatic Nix code, based on official documentation from [nix.dev](https://nix.dev/tutorials/module-system/deep-dive) and the [Nixpkgs Manual](https://nixos.org/manual/nixpkgs/stable/).

## 📚 Table of Contents

- [Module System Patterns](#module-system-patterns)
- [Package Writing Patterns](#package-writing-patterns)
- [Configuration Patterns](#configuration-patterns)
- [Security Patterns](#security-patterns)
- [Performance Patterns](#performance-patterns)

---

## Module System Patterns

### 1. Module Structure and Evaluation

**Pattern: Function-Based Modules**

Modules should be functions that receive arguments and return attribute sets with `options` and `config` sections.

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.services.myservice;
in
{
  options.services.myservice = {
    enable = lib.mkEnableOption "MyService";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port for MyService to listen on";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.myservice = {
      description = "My Service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.myservice}/bin/myservice --port ${toString cfg.port}";
        DynamicUser = true;
      };
    };
  };
}
```

**Why this works:**

- Clear separation between options (what users configure) and config (what gets activated)
- The module system handles merging automatically
- Lazy evaluation allows circular dependencies to resolve correctly

### 2. Type System Best Practices

**Pattern: Choose Appropriate Types**

Use the right type for your data to enable automatic validation and merging.

```nix
options = {
  # Simple types
  enable = lib.mkEnableOption "feature";  # Shorthand for bool with default false
  name = lib.mkOption { type = lib.types.str; };
  count = lib.mkOption { type = lib.types.int; };

  # Constrained types
  port = lib.mkOption {
    type = lib.types.port;  # Integer 0-65535
  };

  logLevel = lib.mkOption {
    type = lib.types.enum [ "debug" "info" "warn" "error" ];
    default = "info";
  };

  age = lib.mkOption {
    type = lib.types.ints.between 0 120;
  };

  # Collection types
  users = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
  };

  settings = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
  };

  # Pattern validation
  email = lib.mkOption {
    type = lib.types.strMatching ".+@.+\\..+";
  };

  # Optional types
  apiKey = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
  };
};
```

**Merging Behavior by Type:**

- `str`: Single definition only (error on multiple)
- `lines`: Multiple definitions concatenated with newlines
- `listOf`: Lists merged by concatenation
- `attrsOf`: Attribute sets merged recursively
- `bool`: Error on conflicting definitions

### 3. Submodules for Nested Configuration

**Pattern: Use Submodules for Complex Structures**

When options have multiple related fields, use submodules to group them logically.

```nix
options.services.myapp = {
  instances = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ name, config, ... }: {
      options = {
        enable = lib.mkEnableOption "this instance";

        host = lib.mkOption {
          type = lib.types.str;
          default = "localhost";
        };

        port = lib.mkOption {
          type = lib.types.port;
          # Use the instance name as part of default
          default = 8000 + (lib.toInt name);
        };

        workers = lib.mkOption {
          type = lib.types.ints.positive;
          default = 4;
        };
      };
    }));
    default = {};
  };
};

# Usage:
config.services.myapp.instances = {
  web = {
    enable = true;
    port = 8080;
    workers = 8;
  };
  api = {
    enable = true;
    port = 8081;
    workers = 4;
  };
};
```

**Special submodule arguments:**

- `name`: The attribute name when used with `attrsOf`
- `config`: The submodule's own config
- Access parent config via the parent's `config` argument

### 4. Module Organization

**Pattern: Split Options from Implementation**

Separate option declarations from their implementations using the `imports` attribute.

```nix
# modules/myservice/default.nix
{
  imports = [
    ./options.nix      # Option declarations
    ./implementation.nix  # Config implementation
  ];
}

# modules/myservice/options.nix
{ lib, ... }:
{
  options.services.myservice = {
    # All options declared here
  };
}

# modules/myservice/implementation.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.services.myservice;
in
{
  config = lib.mkIf cfg.enable {
    # Implementation here
  };
}
```

**Benefits:**

- Clear separation of interface (options) and implementation (config)
- Easier to review changes to public API
- Options can be shared across multiple implementations

### 5. Priority and Defaults

**Pattern: Use mkDefault for Overridable Defaults**

Use `lib.mkDefault` for values that should be easy to override without conflicts.

```nix
config = lib.mkIf cfg.enable {
  # High priority - hard to override (avoid unless necessary)
  networking.hostName = lib.mkForce "myhost";

  # Normal priority - conflicts if set elsewhere
  services.nginx.enable = true;

  # Low priority - easily overridden (PREFERRED for defaults)
  services.nginx.user = lib.mkDefault "nginx";
  services.nginx.group = lib.mkDefault "nginx";

  # Very low priority - absolute fallback
  networking.firewall.enable = lib.mkOverride 1500 true;
};
```

**Priority levels:**

- `mkForce` = 50 (very high priority, avoid)
- Normal = 100 (default)
- `mkDefault` = 1000 (low priority, good for defaults)
- `mkOverride <n>` = custom priority

### 6. Conditional Configuration

**Pattern: Use mkIf for Conditional Blocks**

Use `lib.mkIf` to conditionally include entire configuration sections.

```nix
config = lib.mkMerge [
  # Always applied when service is enabled
  (lib.mkIf cfg.enable {
    systemd.services.myservice = {
      description = "My Service";
      wantedBy = [ "multi-user.target" ];
    };
  })

  # Only when SSL is enabled
  (lib.mkIf (cfg.enable && cfg.ssl.enable) {
    systemd.services.myservice.environment = {
      SSL_CERT = cfg.ssl.certFile;
      SSL_KEY = cfg.ssl.keyFile;
    };
  })

  # Development mode settings
  (lib.mkIf (cfg.enable && cfg.mode == "development") {
    systemd.services.myservice.environment.DEBUG = "1";
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  })
];
```

**Key principle:** Never use `mkIf condition true` - use direct boolean assignment instead.

### 7. Cross-Module Configuration

**Pattern: Access Other Module Options via config**

Modules can read and respond to options defined in other modules.

```nix
{ config, lib, ... }:

let
  cfg = config.services.myservice;
in
{
  config = lib.mkIf cfg.enable {
    # React to nginx being enabled
    services.nginx.virtualHosts = lib.mkIf config.services.nginx.enable {
      "myservice.local" = {
        locations."/".proxyPass = "http://localhost:${toString cfg.port}";
      };
    };

    # Adapt to firewall settings
    systemd.services.myservice.after = lib.mkIf config.networking.firewall.enable [
      "firewall.service"
    ];
  };
}
```

### 8. Making Values Available Across Modules

**Pattern: Use \_module.args for Shared Dependencies**

Make custom values available to all modules using `_module.args`.

```nix
{ lib, pkgs, ... }:

{
  _module.args = {
    # Make custom package set available
    myPkgs = import ./pkgs { inherit pkgs; };

    # Share utility functions
    mkService = name: { /* ... */ };

    # Provide computed values
    hostInfo = {
      isProduction = true;
      domain = "example.com";
    };
  };

  imports = [
    # All imported modules can now access myPkgs, mkService, hostInfo
    ./services
    ./networking
  ];
}
```

### 9. Type-Safe Configuration Generation

**Pattern: Use Format Generators**

For configuration files, use `pkgs.formats` for type-safe generation.

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.services.myservice;

  # Choose appropriate format
  configFormat = pkgs.formats.yaml {};  # or .json, .toml, .ini

  configFile = configFormat.generate "myservice.yaml" {
    inherit (cfg) host port;
    database = {
      inherit (cfg.database) host port name;
      # Never include passwords in store
      passwordFile = cfg.database.passwordFile;
    };
  };
in
{
  options.services.myservice = {
    host = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };

    database = lib.mkOption {
      type = lib.types.submodule {
        options = {
          host = lib.mkOption { type = lib.types.str; };
          port = lib.mkOption { type = lib.types.port; };
          name = lib.mkOption { type = lib.types.str; };
          passwordFile = lib.mkOption { type = lib.types.path; };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.myservice = {
      serviceConfig = {
        ExecStart = "${pkgs.myservice}/bin/myservice --config ${configFile}";
        # Load password at runtime
        LoadCredential = "db-password:${cfg.database.passwordFile}";
      };
    };
  };
}
```

### 10. Assertions and Warnings

**Pattern: Validate Configuration with Assertions**

Use assertions to catch configuration errors early with helpful messages.

```nix
{ config, lib, ... }:

let
  cfg = config.services.myservice;
in
{
  config = lib.mkIf cfg.enable {
    # Hard requirements - build will fail
    assertions = [
      {
        assertion = cfg.database.host != "";
        message = "services.myservice.database.host must be set";
      }
      {
        assertion = cfg.port != cfg.adminPort;
        message = "services.myservice.port and adminPort must be different";
      }
      {
        assertion = cfg.ssl.enable -> (cfg.ssl.certFile != null && cfg.ssl.keyFile != null);
        message = "services.myservice.ssl requires certFile and keyFile";
      }
    ];

    # Soft warnings - build continues but warns user
    warnings = lib.optional (cfg.ssl.enable == false)
      "services.myservice: SSL is disabled - not recommended for production";

    warnings = lib.optional (cfg.workers < 2)
      "services.myservice: Running with less than 2 workers may impact reliability";
  };
}
```

---

## Package Writing Patterns

### 1. Standard Derivation Structure

**Pattern: Use stdenv.mkDerivation Properly**

Follow the standard structure for building packages.

```nix
{ lib
, stdenv
, fetchFromGitHub
, cmake
, pkg-config
, openssl
, zlib
}:

stdenv.mkDerivation rec {
  pname = "myapp";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "myorg";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  # Build-time dependencies
  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  # Runtime dependencies
  buildInputs = [
    openssl
    zlib
  ];

  # Strict dependency separation
  strictDeps = true;

  # CMake flags
  cmakeFlags = [
    "-DENABLE_TESTS=OFF"
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  # Environment variables
  env.NIX_CFLAGS_COMPILE = "-O3";

  # Use phase hooks
  postPatch = ''
    # Patch files before building
    substituteInPlace Makefile \
      --replace /usr/local $out
  '';

  postInstall = ''
    # Additional installation steps
    wrapProgram $out/bin/myapp \
      --prefix PATH : ${lib.makeBinPath [ openssl ]}
  '';

  meta = with lib; {
    description = "Short description of the package";
    longDescription = ''
      Longer description that can span
      multiple lines.
    '';
    homepage = "https://myapp.example.com";
    changelog = "https://github.com/myorg/myapp/releases/tag/v${version}";
    license = licenses.mit;
    maintainers = with maintainers; [ myname ];
    platforms = platforms.linux;
    mainProgram = "myapp";
  };
}
```

**Key principles:**

- Use `rec` sparingly or not at all
- `nativeBuildInputs` for build tools
- `buildInputs` for runtime libraries
- Always include comprehensive `meta` attributes
- Use `runHook preInstall` and `runHook postInstall` in custom phases

### 2. Dependency Management

**Pattern: CallPackage for Automatic Injection**

Use `callPackage` to automatically inject dependencies.

```nix
# pkgs/myapp/default.nix
{ lib, buildGoModule, fetchFromGitHub, installShellFiles }:

buildGoModule rec {
  pname = "myapp";
  version = "1.0.0";

  # Dependencies automatically injected by callPackage
  # ...
}

# In all-packages.nix or overlay
{
  myapp = callPackage ./pkgs/myapp { };

  # Override specific dependencies
  myappCustom = callPackage ./pkgs/myapp {
    buildGoModule = buildGo122Module;  # Use specific Go version
  };
}
```

### 3. Override Patterns

**Pattern: Provide Both override and overrideAttrs**

Make packages customizable with proper override support.

```nix
# Good - packages built with mkDerivation automatically support both

# Override function arguments
myPackageCustom = myPackage.override {
  enableFeatureX = true;
  openssl = openssl_3;
};

# Override derivation attributes (PREFERRED)
myPackagePatched = myPackage.overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or []) ++ [
    ./my-custom.patch
  ];

  postInstall = (oldAttrs.postInstall or "") + ''
    # Additional installation steps
  '';
});
```

**Why overrideAttrs is preferred:**

- Preserves all derivation processing by `stdenv.mkDerivation`
- Allows override of build phases, dependencies, and attributes
- Maintains proper attribute merging

### 4. Multi-Output Packages

**Pattern: Split Large Packages into Multiple Outputs**

Reduce closure size by splitting development files, documentation, etc.

```nix
stdenv.mkDerivation rec {
  pname = "mylib";
  version = "1.0.0";

  # Define outputs
  outputs = [ "out" "dev" "doc" "man" ];

  # out: runtime files (libraries, binaries)
  # dev: headers, pkg-config files
  # doc: documentation
  # man: man pages

  postInstall = ''
    # Move development files
    moveToOutput "include" "$dev"
    moveToOutput "lib/pkgconfig" "$dev"

    # Move documentation
    moveToOutput "share/doc" "$doc"
    moveToOutput "share/man" "$man"
  '';

  meta = {
    # Specify which output contains the main program
    outputsToInstall = [ "out" ];
  };
}

# Usage:
environment.systemPackages = [
  mylib         # Just runtime files
  mylib.dev     # Development files
  mylib.doc     # Documentation
];
```

### 5. Language-Specific Builders

**Pattern: Use Specialized Builders for Each Language**

Nixpkgs provides optimized builders for different languages.

```nix
# Python
{ buildPythonApplication, fetchPypi, requests, pytest }:

buildPythonApplication rec {
  pname = "myapp";
  version = "1.0.0";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-...";
  };

  propagatedBuildInputs = [ requests ];

  nativeCheckInputs = [ pytest ];

  pythonImportsCheck = [ "myapp" ];
}

# Node.js
{ buildNpmPackage, fetchFromGitHub }:

buildNpmPackage rec {
  pname = "myapp";
  version = "1.0.0";

  src = fetchFromGitHub { /* ... */ };

  npmDepsHash = "sha256-...";

  dontNpmBuild = false;  # Run npm build
}

# Go
{ buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "myapp";
  version = "1.0.0";

  src = fetchFromGitHub { /* ... */ };

  vendorHash = "sha256-...";

  ldflags = [
    "-s" "-w"
    "-X main.version=${version}"
  ];
}

# Rust
{ rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage rec {
  pname = "myapp";
  version = "1.0.0";

  src = fetchFromGitHub { /* ... */ };

  cargoHash = "sha256-...";

  nativeBuildInputs = [ /* ... */ ];
  buildInputs = [ /* ... */ ];
}
```

### 6. Overlay Patterns

**Pattern: Create Composable Overlays**

Use overlays to extend or modify the package set systematically.

```nix
# Simple overlay
final: prev: {
  # Add new package
  myCustomPackage = final.callPackage ./pkgs/my-custom-package { };

  # Override existing package
  hello = prev.hello.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or []) ++ [ ./hello.patch ];
  });

  # Compose with other packages
  myApp = final.callPackage ./pkgs/my-app {
    specialLib = final.myCustomPackage;
  };
}

# Overlay with configuration
{ enableFeature ? false }:
final: prev: {
  myApp = prev.myApp.override {
    inherit enableFeature;
  };
}

# System-wide overlays in NixOS
nixpkgs.overlays = [
  (import ./overlays/custom-packages.nix)
  (import ./overlays/patched-packages.nix)
];
```

**Overlay argument conventions:**

- `final` (or `self`): The **final** package set after all overlays
- `prev` (or `super`): The package set from the **previous** overlay
- Always use `final` for dependencies
- Use `prev` only when modifying an existing package

### 7. Testing Patterns

**Pattern: Include Tests in Package Definitions**

Use nixpkgs testers for validation.

```nix
{ lib
, stdenv
, fetchFromGitHub
, testers
, myapp  # Self-reference for passthru.tests
}:

stdenv.mkDerivation rec {
  pname = "myapp";
  version = "1.0.0";

  src = fetchFromGitHub { /* ... */ };

  doCheck = true;

  checkPhase = ''
    runHook preCheck
    ./test-suite
    runHook postCheck
  '';

  # Passthru tests run separately
  passthru.tests = {
    version = testers.testVersion {
      package = myapp;
      command = "myapp --version";
    };

    # Custom test
    basic-functionality = testers.runNixOSTest {
      name = "myapp-basic";
      nodes.machine = { pkgs, ... }: {
        environment.systemPackages = [ pkgs.myapp ];
      };
      testScript = ''
        machine.succeed("myapp --help")
        machine.succeed("myapp check")
      '';
    };
  };

  # Update script for automated version bumps
  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    # ...
  };
}
```

### 8. Shell Script Wrapping

**Pattern: Use writeShellApplication for Scripts**

For shell scripts that need dependencies, use `writeShellApplication`.

```nix
{ lib, pkgs, writeShellApplication, curl, jq, coreutils }:

writeShellApplication {
  name = "my-script";

  runtimeInputs = [
    curl
    jq
    coreutils
  ];

  text = ''
    # Script has curl, jq, and coreutils in PATH
    response=$(curl -s "https://api.example.com/data")
    echo "$response" | jq '.items[] | .name' | sort
  '';

  # Automatic shellcheck validation
  checkPhase = ''
    ${lib.getExe pkgs.shellcheck} $target
  '';
}
```

### 9. Cross-Compilation Support

**Pattern: Proper Build vs Host Dependencies**

Support cross-compilation by correctly categorizing dependencies.

```nix
{ lib
, stdenv
, buildPackages  # For cross-compilation
, cmake
, pkg-config
, zlib
}:

stdenv.mkDerivation {
  pname = "myapp";
  version = "1.0.0";

  strictDeps = true;  # Essential for cross-compilation

  # depsBuildBuild: build platform → build platform
  depsBuildBuild = [
    buildPackages.setuptools  # Tools used during build on build platform
  ];

  # nativeBuildInputs: build platform → host platform
  nativeBuildInputs = [
    cmake       # Runs on build platform
    pkg-config  # Runs on build platform
  ];

  # buildInputs: host platform → host platform
  buildInputs = [
    zlib  # Library linked into final binary
  ];

  # For cross-compilation, use buildPackages when needed
  configurePhase = ''
    ${buildPackages.cmake}/bin/cmake .
  '';
}
```

---

## Configuration Patterns

### 1. Reproducible System Configuration

**Pattern: Declare Everything in configuration.nix**

```nix
{ config, pkgs, ... }:

{
  # System state version - set once, never change
  system.stateVersion = "24.05";

  # All system packages declared
  environment.systemPackages = with pkgs; [
    vim git curl wget
  ];

  # All services configured
  services.openssh.enable = true;

  # All users declared
  users.users.alice = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    # Password set via passwordFile, not inline
    hashedPasswordFile = "/etc/nixos/secrets/alice-password";
  };

  # Network configuration
  networking = {
    hostName = "myhost";
    networkmanager.enable = true;
  };
}
```

### 2. Modular Configuration with Imports

**Pattern: Split Configuration into Logical Modules**

```nix
/etc/nixos/
├── configuration.nix
├── hardware-configuration.nix
├── modules/
│   ├── boot.nix
│   ├── networking.nix
│   ├── security.nix
│   └── users.nix
└── services/
    ├── web.nix
    ├── database.nix
    └── monitoring.nix

# configuration.nix
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/boot.nix
    ./modules/networking.nix
    ./modules/security.nix
    ./modules/users.nix
    ./services/web.nix
    ./services/database.nix
    ./services/monitoring.nix
  ];

  system.stateVersion = "24.05";
}
```

### 3. Home Manager Integration

**Pattern: Separate User and System Configuration**

```nix
# System configuration
environment.systemPackages = with pkgs; [
  # Only system-wide essentials
  vim git wget curl
];

# Home Manager configuration
home-manager.users.alice = { pkgs, ... }: {
  home.stateVersion = "24.05";

  # User-specific packages
  home.packages = with pkgs; [
    firefox
    vscode
    spotify
  ];

  # User program configuration
  programs.git = {
    enable = true;
    userName = "Alice";
    userEmail = "alice@example.com";
  };

  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
    };
  };
};
```

### 4. Feature Flags for Optional Functionality

**Pattern: Use Feature Flags for Host Capabilities**

```nix
{ config, lib, pkgs, ... }:

let
  features = {
    isLaptop = true;
    hasNvidiaGpu = false;
    isServer = false;
    enableGaming = true;
  };
in
{
  # Power management for laptops
  services.tlp.enable = features.isLaptop;
  services.thermald.enable = features.isLaptop;

  # GPU drivers
  services.xserver.videoDrivers = lib.mkIf features.hasNvidiaGpu [ "nvidia" ];

  # Server-specific services
  services.fail2ban.enable = features.isServer;

  # Gaming packages
  environment.systemPackages = lib.mkIf features.enableGaming (with pkgs; [
    steam
    discord
    lutris
  ]);
}
```

---

## Security Patterns

### 1. Systemd Service Hardening

**Pattern: Apply Comprehensive Service Isolation**

```nix
systemd.services.myservice = {
  description = "My Service";
  wantedBy = [ "multi-user.target" ];

  serviceConfig = {
    # User isolation
    DynamicUser = true;  # Automatic user/group creation
    User = "myservice";
    Group = "myservice";

    # Filesystem isolation
    ProtectSystem = "strict";  # Read-only /usr, /boot, /etc
    ProtectHome = true;         # Inaccessible /home
    PrivateTmp = true;          # Private /tmp
    ReadWritePaths = [ "/var/lib/myservice" ];  # Only necessary paths

    # Process restrictions
    NoNewPrivileges = true;     # Can't gain new privileges
    PrivateDevices = true;      # No access to /dev
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictSUIDSGID = true;

    # Capability restrictions
    CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
    AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];

    # System call filtering
    SystemCallFilter = [ "@system-service" "~@privileged" ];
    SystemCallArchitectures = "native";

    # Resource limits
    MemoryMax = "1G";
    TasksMax = 1000;

    # Network restrictions (if service doesn't need network)
    PrivateNetwork = false;  # Set true if no network needed
    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];

    ExecStart = "${pkgs.myservice}/bin/myservice";
  };
};
```

### 2. Secret Management

**Pattern: Never Include Secrets in Store**

```nix
# ❌ NEVER DO THIS
services.myservice = {
  password = "hardcoded-password";  # INSECURE!
};

# ✅ Use file references
services.myservice = {
  passwordFile = "/run/secrets/myservice-password";
};

# ✅ Or use agenix/sops-nix
age.secrets.myservice-password = {
  file = ./secrets/myservice-password.age;
  mode = "0400";
  owner = "myservice";
  group = "myservice";
};

services.myservice = {
  passwordFile = config.age.secrets.myservice-password.path;
};

# ✅ systemd credentials
systemd.services.myservice = {
  serviceConfig = {
    LoadCredential = "password:/etc/myservice/password";
    # Access via $CREDENTIALS_DIRECTORY/password
  };
};
```

### 3. Firewall Configuration

**Pattern: Minimal Port Opening**

```nix
networking.firewall = {
  enable = true;

  # Global rules - minimal
  allowedTCPPorts = [ 22 ];  # SSH only

  # Interface-specific rules
  interfaces = {
    # Internal network
    "enp3s0" = {
      allowedTCPPorts = [ 5432 9090 3000 ];  # Database, Prometheus, Grafana
    };

    # External network
    "enp4s0" = {
      allowedTCPPorts = [ 80 443 ];  # HTTP/HTTPS only
    };
  };

  # Custom rules using iptables
  extraCommands = ''
    # Rate limit SSH connections
    iptables -A nixos-fw -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set
    iptables -A nixos-fw -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
  '';
};
```

---

## Performance Patterns

### 1. Build Optimization

**Pattern: Configure Nix for Optimal Performance**

```nix
nix.settings = {
  # Parallel builds
  max-jobs = "auto";       # Use all available CPU cores
  cores = 0;               # Each job can use all cores

  # Build optimization
  keep-outputs = true;     # Keep build outputs for debugging
  keep-derivations = true; # Keep .drv files

  # Sandbox for reproducibility
  sandbox = true;

  # Binary caches
  substituters = [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
  ];

  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];

  # Experimental features
  experimental-features = [ "nix-command" "flakes" ];
};
```

### 2. Store Management

**Pattern: Automated Garbage Collection**

```nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};

nix.optimise = {
  automatic = true;
  dates = [ "03:45" ];  # Run during low-usage time
};

# Keep specific generations
boot.loader.grub.configurationLimit = 10;
```

### 3. Evaluation Performance

**Pattern: Lazy Evaluation and Minimal IFD**

```nix
# ✅ GOOD - Lazy evaluation, no IFD
let
  # Only evaluated if used
  expensiveComputation = /* ... */;
in
{
  # Computed only when myFeature is enabled
  services.myservice.config = lib.mkIf config.features.myFeature {
    value = expensiveComputation;
  };
}

# ❌ BAD - Import From Derivation
let
  generatedConfig = pkgs.runCommand "config" {} ''
    echo "value=42" > $out
  '';
  configValue = builtins.readFile generatedConfig;  # Forces build during eval!
in { }
```

---

## Documentation Standards

### 1. Module Documentation

**Pattern: Comprehensive Option Documentation**

```nix
options.services.myservice = {
  enable = lib.mkEnableOption "MyService daemon";

  package = lib.mkPackageOption pkgs "myservice" {
    default = pkgs.myservice;
    example = lib.literalExpression "pkgs.myservice.override { enableFeature = true; }";
  };

  host = lib.mkOption {
    type = lib.types.str;
    default = "localhost";
    example = "0.0.0.0";
    description = ''
      Host address for MyService to bind to.

      Use `localhost` for local connections only,
      or `0.0.0.0` to accept connections from any address.
    '';
  };

  settings = lib.mkOption {
    type = with lib.types; attrsOf anything;
    default = {};
    example = lib.literalExpression ''
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
      Settings are serialized to YAML format.
    '';
  };
};
```

### 2. Package Metadata

**Pattern: Complete and Accurate Meta Attributes**

```nix
meta = with lib; {
  description = "Short one-line description";
  longDescription = ''
    Detailed description that can span multiple lines.

    Explain what the package does, its key features,
    and any important usage information.
  '';

  homepage = "https://example.com";
  changelog = "https://github.com/org/repo/releases/tag/v${version}";
  downloadPage = "https://example.com/downloads";

  license = licenses.mit;  # or licenses.gpl3, etc.

  maintainers = with maintainers; [ your-github-username ];

  platforms = platforms.linux;  # or platforms.unix, platforms.all

  # For packages with executables
  mainProgram = "executable-name";

  # Broken or unmaintained
  broken = false;

  # Security-sensitive packages
  priority = 10;  # Lower = higher priority in PATH
};
```

---

## Summary

These patterns represent best practices from official Nix documentation and the NixOS community. Following them ensures:

- **Type Safety**: Proper use of the module system's type checking
- **Composability**: Modules and packages that work well together
- **Maintainability**: Clear, explicit code that's easy to understand
- **Performance**: Efficient evaluation and builds
- **Security**: Properly isolated services and secret management
- **Documentation**: Self-documenting code with comprehensive options

Always refer to the official documentation for the most up-to-date information:

- [Nix Module System Deep Dive](https://nix.dev/tutorials/module-system/deep-dive)
- [Nixpkgs Manual](https://nixos.org/manual/nixpkgs/stable/)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
