# NixOS Core: Derivations, Functions, Imports & Best Practices

> **Comprehensive NixOS Configuration Best Practices Skill**
>
> This skill provides deep knowledge of NixOS fundamentals: derivations, functions, imports, option declarations, and
> the module system. Use this skill when creating, checking, debugging, or correcting NixOS configuration files.

## Overview

This skill enables Claude Code to effectively work with NixOS by understanding:

- **Nix Language**: Functions, let-in, with, inherit, recursion patterns
- **Derivation System**: Building packages with stdenv.mkDerivation
- **Import System**: Module imports, callPackage, overlays
- **Option System**: Declaring and using options with proper types
- **Module System**: Understanding config, lib, pkgs, and module structure
- **Best Practices**: Following community standards and avoiding anti-patterns
- **Debugging**: Techniques for finding and fixing configuration issues

## Nix Language Fundamentals

### Functions in Nix

**Basic Function Syntax:**

```nix
# Simple function
double = x: x * 2

# Multiple arguments (curried)
add = x: y: x + y

# Attribute set argument
mkService = { name, port }: {
  services.${name}.enable = true;
  services.${name}.port = port;
}

# Attribute set with defaults
mkService = { name, port ? 8080 }: {
  services.${name}.enable = true;
  services.${name}.port = port;
}

# Pattern matching (destructuring)
mkService = { name, port, ... }@args: {
  # args contains all attributes
  # name and port are extracted
}

# Variadic arguments
mkService = args: {
  # All arguments in 'args' attribute set
}
```

**Function Application:**

```nix
# Call function with single argument
result = double 5  # Returns 10

# Call curried function
result = add 3 7  # Returns 10
partial = add 3;  # Returns function waiting for second arg
result = partial 7;  # Returns 10

# Call with attribute set
result = mkService { name = "nginx"; port = 80; }

# Call with defaults
result = mkService { name = "nginx"; }  # port defaults to 8080
```

**Higher-Order Functions:**

```nix
# Map over list
doubled = map (x: x * 2) [1 2 3 4]  # [2 4 6 8]

# Filter list
evens = filter (x: x mod 2 == 0) [1 2 3 4]  # [2 4]

# Fold (reduce)
sum = foldl' (acc: x: acc + x) 0 [1 2 3 4]  # 10

# Compose functions
compose = f: g: x: f (g x)
addThenDouble = compose double (add 5)
result = addThenDouble 3  # (3 + 5) * 2 = 16
```

**Library Functions:**

```nix
with lib; {
  # String manipulation
  upperName = toUpper "nixos";  # "NIXOS"
  hasPrefix = hasPrefix "nix" "nixos";  # true

  # List operations
  uniqueList = unique [1 2 2 3 3 3];  # [1 2 3]
  flatList = flatten [[1 2] [3 4]];  # [1 2 3 4]

  # Attribute set operations
  merged = recursiveUpdate { a = 1; } { b = 2; };  # { a = 1; b = 2; }
  filtered = filterAttrs (n: v: v > 5) { a = 3; b = 7; };  # { b = 7; }

  # Optional values
  value = optional (condition) "value";  # ["value"] or []
  values = optionals (condition) ["a" "b"];  # ["a" "b"] or []

  # String conversion
  int = toInt "42";  # 42
  str = toString 42;  # "42"
}
```

### Let-In Expressions

**Basic Usage:**

```nix
let
  # Define local bindings
  name = "nginx";
  port = 80;
  host = "localhost";
in {
  # Use bindings in expression
  services.${name} = {
    enable = true;
    listen = "${host}:${toString port}";
  };
}
```

**Nested Let-In:**

```nix
let
  # Outer scope
  domain = "example.com";

  # Nested let
  serviceConfig = let
    port = 443;
    protocol = "https";
  in {
    url = "${protocol}://${domain}:${toString port}";
  };
in {
  services.nginx.virtualHosts.${domain} = serviceConfig;
}
```

**Best Practices:**

```nix
# ✅ GOOD - Clear, organized bindings
let
  # Configuration
  serviceName = "postgresql";
  servicePort = 5432;

  # Derived values
  connectionString = "postgresql://localhost:${toString servicePort}";

  # Complex expressions
  serviceConfig = {
    enable = true;
    port = servicePort;
  };
in {
  services.${serviceName} = serviceConfig;
}

# ❌ BAD - Everything in one expression
{
  services.postgresql = {
    enable = true;
    port = 5432;
    connectionString = "postgresql://localhost:5432";
  };
}
```

### With Statement (Use Sparingly)

**Basic Usage:**

```nix
# Brings attributes into scope
with pkgs; [
  git
  vim
  tmux
]

# Nested with
with lib; with pkgs; {
  # Can use both lib and pkgs functions
}
```

**Anti-Pattern (Avoid):**

```nix
# ❌ BAD - Unclear origins, shadowing issues
with (import <nixpkgs> {});
with lib;
with stdenv;
buildInputs = [ curl jq ];  # Where do these come from?

# ✅ GOOD - Explicit imports
let
  pkgs = import <nixpkgs> {};
in
with pkgs; buildInputs = [ curl jq ];  # Clear: from pkgs
```

**When to Use:**

```nix
# ✅ GOOD - Limited scope, clear context
environment.systemPackages = with pkgs; [
  # List of packages (obvious they're from pkgs)
  git vim neovim tmux
];

# ✅ GOOD - Single attribute set
let cfg = config.services.myservice; in
with cfg; {
  # Using cfg attributes frequently
}

# ❌ BAD - Multiple attribute sets, unclear origins
with pkgs; with lib; with stdenv;
# Don't stack multiple 'with' statements
```

### Inherit Keyword

**Basic Inherit:**

```nix
let
  a = 1;
  b = 2;
  c = 3;
in {
  # Instead of: a = a; b = b; c = c;
  inherit a b c;

  # Result: { a = 1; b = 2; c = 3; }
}
```

**Inherit From:**

```nix
let
  pkgs = import <nixpkgs> {};
in {
  # Inherit specific attributes from pkgs
  inherit (pkgs) git vim tmux;

  # Equivalent to:
  # git = pkgs.git;
  # vim = pkgs.vim;
  # tmux = pkgs.tmux;
}
```

**In Function Arguments:**

```nix
{ config, lib, pkgs, ... }: {
  # Bring lib functions into scope
  inherit (lib) mkIf mkEnableOption mkOption types;
  inherit (pkgs) writeScript;

  # Now can use: mkIf, mkOption, etc. directly
}
```

**Best Practices:**

```nix
# ✅ GOOD - Clear, concise
{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkEnableOption;
  inherit (pkgs) writeScript;
  cfg = config.services.myservice;
in {
  options.services.myservice = {
    enable = mkEnableOption "MyService";
  };

  config = mkIf cfg.enable {
    # ...
  };
}

# ❌ BAD - Unclear, manual assignment
{ config, lib, pkgs, ... }:
let
  mkIf = lib.mkIf;
  mkEnableOption = lib.mkEnableOption;
  writeScript = pkgs.writeScript;
  # ... repetitive and unclear
in {
  # ...
}
```

### Rec Attribute Sets (Avoid)

**What is Rec:**

```nix
# rec allows self-references within attribute set
rec {
  a = 1;
  b = a + 1;  # Can reference 'a'
  c = b + 1;  # Can reference 'b'
}
# Result: { a = 1; b = 2; c = 3; }
```

**Why Avoid Rec:**

```nix
# ❌ DANGEROUS - Infinite recursion risk
rec {
  a = 1;
  b = let a = a + 1; in a;  # Infinite recursion!
}

# ❌ DANGEROUS - Order-dependent, hard to debug
rec {
  x = y + 1;  # Error if y comes after
  y = 5;
}

# ✅ GOOD - Use let-in instead
let
  a = 1;
  b = a + 1;
  c = b + 1;
in {
  inherit a b c;
}
# Clear, safe, debuggable
```

**When Rec is Acceptable:**

```nix
# ✅ OK - Simple, no shadowing risk
rec {
  name = "myapp";
  version = "1.0.0";
  fullName = "${name}-${version}";
}

# ✅ BETTER - Use let-in even for simple cases
let
  name = "myapp";
  version = "1.0.0";
  fullName = "${name}-${version}";
in {
  inherit name version fullName;
}
```

## Derivation System

### Understanding Derivations

**What is a Derivation:**

A derivation is a build recipe that describes:

- What to build (source, dependencies)
- How to build it (build steps, environment)
- Where to store output (Nix store path)

**Basic Structure:**

```nix
derivation {
  # Required attributes
  name = "hello-2.10";
  system = "x86_64-linux";
  builder = "${bash}/bin/bash";
  args = [ "-c" "echo Hello > $out" ];

  # Optional attributes
  src = fetchurl { url = "..."; sha256 = "..."; };
  buildInputs = [ gcc ];
  # ... many more
}
```

### stdenv.mkDerivation

**Basic Package:**

```nix
{ lib, stdenv, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "myapp";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "user";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  # Essential metadata
  meta = with lib; {
    description = "My application";
    homepage = "https://example.com";
    license = licenses.mit;
    maintainers = with maintainers; [ username ];
    platforms = platforms.linux;
  };
}
```

**Build Inputs:**

```nix
{ lib, stdenv, fetchurl
, pkg-config    # Build-time dependency
, openssl       # Runtime dependency
, zlib          # Runtime dependency
}:

stdenv.mkDerivation {
  pname = "myapp";
  version = "1.0.0";

  src = fetchurl { url = "..."; sha256 = "..."; };

  # Build-time dependencies (not in closure)
  nativeBuildInputs = [
    pkg-config
    cmake
    makeWrapper
  ];

  # Runtime dependencies (in closure)
  buildInputs = [
    openssl
    zlib
  ];

  # Propagated to downstream packages
  propagatedBuildInputs = [
    # Libraries needed by consumers
  ];

  # Check-phase dependencies
  checkInputs = [
    pytest
  ];
}
```

**Build Phases:**

```nix
stdenv.mkDerivation {
  pname = "myapp";
  version = "1.0.0";

  src = fetchurl { url = "..."; sha256 = "..."; };

  # Phase: unpack (automatic for most sources)
  # unpackPhase = "...";

  # Phase: patch
  patches = [ ./fix-build.patch ];

  # Phase: configure
  configureFlags = [
    "--enable-feature"
    "--with-ssl=${openssl}"
  ];

  # Or custom configure
  configurePhase = ''
    ./configure --prefix=$out
  '';

  # Phase: build (usually automatic)
  buildPhase = ''
    make -j$NIX_BUILD_CORES
  '';

  # Make flags
  makeFlags = [
    "PREFIX=$(out)"
    "CC=gcc"
  ];

  # Phase: check (tests)
  doCheck = true;
  checkPhase = ''
    make test
  '';

  # Phase: install
  installPhase = ''
    mkdir -p $out/bin
    cp myapp $out/bin/
  '';

  # Phase: fixup (automatic wrappers, etc.)
  # fixupPhase = "...";

  # Post-install
  postInstall = ''
    wrapProgram $out/bin/myapp \
      --prefix PATH : ${lib.makeBinPath [ openssl ]}
  '';
}
```

**Advanced Patterns:**

```nix
{ lib, stdenv, fetchFromGitHub, cmake, pkg-config }:

stdenv.mkDerivation rec {
  pname = "advanced-app";
  version = "2.0.0";

  src = fetchFromGitHub {
    owner = "user";
    repo = pname;
    rev = "v${version}";
    sha256 = lib.fakeSha256;  # Update after first build
  };

  # Strict dependencies (recommended)
  strictDeps = true;

  nativeBuildInputs = [ cmake pkg-config ];

  buildInputs = [ openssl zlib ];

  # CMake flags
  cmakeFlags = [
    "-DENABLE_TESTS=ON"
    "-DBUILD_SHARED_LIBS=ON"
  ];

  # Environment variables
  NIX_CFLAGS_COMPILE = "-O3 -march=native";

  # Parallel building
  enableParallelBuilding = true;

  # Multiple outputs
  outputs = [ "out" "dev" "doc" ];

  # Conditional dependencies
  buildInputs = lib.optionals stdenv.isDarwin [
    darwin.apple_sdk.frameworks.Security
  ];

  # Platform-specific patches
  patches = lib.optionals stdenv.isLinux [
    ./linux-specific.patch
  ];

  # Post-fixup for multiple outputs
  postFixup = ''
    moveToOutput "share/doc" "$doc"
  '';

  # Comprehensive meta
  meta = with lib; {
    description = "Advanced application";
    longDescription = ''
      Detailed description of the application,
      its features, and use cases.
    '';
    homepage = "https://example.com";
    changelog = "https://example.com/changelog";
    license = licenses.mit;
    maintainers = with maintainers; [ username ];
    platforms = platforms.unix;
    broken = stdenv.isDarwin;  # Mark broken platforms
  };
}
```

**Fetchers:**

```nix
# From GitHub
src = fetchFromGitHub {
  owner = "user";
  repo = "repo";
  rev = "v1.0.0";
  sha256 = "sha256-...";
};

# From GitLab
src = fetchFromGitLab {
  owner = "user";
  repo = "repo";
  rev = "v1.0.0";
  sha256 = "sha256-...";
};

# From URL
src = fetchurl {
  url = "https://example.com/file.tar.gz";
  sha256 = "sha256-...";
};

# From git (full clone)
src = fetchgit {
  url = "https://github.com/user/repo";
  rev = "commit-hash";
  sha256 = "sha256-...";
};

# From tarball with stripRoot
src = fetchzip {
  url = "https://example.com/archive.tar.gz";
  sha256 = "sha256-...";
  stripRoot = false;
};
```

**Hash Generation:**

```nix
# Use lib.fakeSha256 initially
sha256 = lib.fakeSha256;

# Build will fail with actual hash:
# error: hash mismatch in fixed-output derivation
# got: sha256-REAL_HASH_HERE

# Or use nix-prefetch-url
# nix-prefetch-url --type sha256 https://example.com/file.tar.gz

# Or nix-prefetch-git
# nix-prefetch-git https://github.com/user/repo --rev v1.0.0

# Convert to SRI format
# nix hash to-sri --type sha256 <hash>
```

## Import System

### Basic Imports

**Import File:**

```nix
# Import file (returns its content)
imported = import ./file.nix;

# Import with arguments
imported = import ./file.nix { inherit pkgs lib; };

# Import nixpkgs
pkgs = import <nixpkgs> {};
pkgs = import <nixpkgs> { system = "x86_64-linux"; };
```

**Import Directory:**

```nix
# If directory has default.nix
imported = import ./directory;

# Equivalent to
imported = import ./directory/default.nix;
```

### Module Imports

**NixOS Module Structure:**

```nix
{ config, lib, pkgs, ... }: {
  # Imports: Load other modules
  imports = [
    ./module1.nix
    ./module2.nix
  ];

  # Options: Declare what can be configured
  options = {
    services.myservice.enable = lib.mkEnableOption "MyService";
  };

  # Config: Actual configuration
  config = {
    # ... configuration based on options
  };
}
```

**Import Patterns:**

```nix
# ✅ GOOD - Explicit imports
{ config, lib, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./modules/services
    ./modules/desktop
    ./users
  ];
}

# ✅ GOOD - Conditional imports
{ config, lib, pkgs, ... }: {
  imports = [
    ./common.nix
  ] ++ lib.optionals config.features.desktop.enable [
    ./desktop.nix
  ] ++ lib.optionals config.features.development.enable [
    ./development.nix
  ];
}

# ❌ BAD - Magic auto-discovery
{ config, lib, pkgs, ... }:
let
  # Don't do this - hard to debug
  moduleFiles = lib.filesystem.listFilesRecursive ./modules;
  imports = map import moduleFiles;
in {
  inherit imports;
}

# ✅ BETTER - Explicit default.nix that lists imports
# modules/default.nix
{
  imports = [
    ./services/nginx.nix
    ./services/postgres.nix
    ./desktop/gnome.nix
    ./desktop/hyprland.nix
  ];
}
```

### callPackage Pattern

**What is callPackage:**

Automatically supplies dependencies based on function arguments.

```nix
# Package definition (package.nix)
{ lib, stdenv, fetchurl, openssl, zlib }:
stdenv.mkDerivation {
  # Uses openssl and zlib from arguments
  buildInputs = [ openssl zlib ];
}

# In all-packages.nix or overlay
{
  mypackage = callPackage ./package.nix { };

  # Override specific dependency
  mypackage-custom = callPackage ./package.nix {
    openssl = openssl_3_0;
  };
}
```

**callPackage Benefits:**

```nix
# ✅ GOOD - Automatic dependency resolution
mypackage = callPackage ./package.nix { };

# ❌ BAD - Manual dependency passing
mypackage = import ./package.nix {
  inherit lib stdenv fetchurl openssl zlib;
};

# ✅ GOOD - Override when needed
mypackage-custom = callPackage ./package.nix {
  # Only specify what's different
  openssl = openssl_3_0;
};
```

### Overlays

**Creating Overlays:**

```nix
# overlay.nix
final: prev: {
  # Add new package
  mypackage = final.callPackage ./mypackage.nix { };

  # Override existing package
  git = prev.git.overrideAttrs (old: {
    version = "2.43.0";
    src = final.fetchurl {
      url = "https://...";
      sha256 = "...";
    };
  });

  # Modify package
  vim-custom = prev.vim.override {
    python = final.python311;
  };
}
```

**Applying Overlays:**

```nix
# In configuration.nix
{ config, lib, pkgs, ... }: {
  nixpkgs.overlays = [
    (import ./overlays/custom-packages.nix)
    (import ./overlays/version-overrides.nix)
  ];
}

# Or in flake.nix
{
  outputs = { self, nixpkgs }: {
    overlays.default = import ./overlay.nix;

    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        { nixpkgs.overlays = [ self.overlays.default ]; }
        ./configuration.nix
      ];
    };
  };
}
```

**Overlay Best Practices:**

```nix
# ✅ GOOD - Use final for dependencies
final: prev: {
  myapp = final.callPackage ./myapp.nix {
    # Uses modified git from this overlay
    inherit (final) git;
  };
}

# ❌ BAD - Use prev for dependencies (can miss overrides)
final: prev: {
  myapp = final.callPackage ./myapp.nix {
    inherit (prev) git;  # Won't see overlay changes
  };
}

# ✅ GOOD - Organized by purpose
final: prev: {
  # Group related packages
  myPackages = {
    tool1 = final.callPackage ./tool1.nix { };
    tool2 = final.callPackage ./tool2.nix { };
  };
}
```

## Option System

### Declaring Options

**Basic Option Declaration:**

```nix
{ config, lib, pkgs, ... }:
with lib; {
  options.services.myservice = {
    # Simple enable option
    enable = mkEnableOption "MyService daemon";

    # String option with default
    host = mkOption {
      type = types.str;
      default = "localhost";
      description = "Host to bind to";
    };

    # Integer option with validation
    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port to listen on";
    };

    # List of strings
    allowedUsers = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of allowed users";
    };
  };
}
```

**Option Types:**

```nix
with types; {
  # Primitive types
  bool-opt = mkOption { type = types.bool; };
  int-opt = mkOption { type = types.int; };
  float-opt = mkOption { type = types.float; };
  str-opt = mkOption { type = types.str; };
  path-opt = mkOption { type = types.path; };

  # Special string types
  port-opt = mkOption { type = types.port; };  # 0-65535

  # Containers
  list-opt = mkOption { type = types.listOf types.str; };
  attrs-opt = mkOption { type = types.attrsOf types.int; };

  # Complex types
  enum-opt = mkOption {
    type = types.enum [ "debug" "info" "warn" "error" ];
  };

  nullOr-opt = mkOption {
    type = types.nullOr types.str;
    default = null;
  };

  either-opt = mkOption {
    type = types.either types.str types.int;
  };

  # Package type
  package-opt = mkOption {
    type = types.package;
    default = pkgs.nginx;
  };
}
```

**Submodules (Structured Options):**

```nix
{ config, lib, pkgs, ... }:
with lib; {
  options.services.myservice = {
    enable = mkEnableOption "MyService";

    # Submodule for structured config
    settings = mkOption {
      type = types.submodule {
        freeformType = types.attrsOf types.anything;

        options = {
          server = {
            host = mkOption {
              type = types.str;
              default = "localhost";
            };

            port = mkOption {
              type = types.port;
              default = 8080;
            };
          };

          database = {
            url = mkOption {
              type = types.str;
              description = "Database connection URL";
            };

            pool = mkOption {
              type = types.int;
              default = 10;
              description = "Connection pool size";
            };
          };
        };
      };

      default = {};
      description = "Configuration for MyService";
    };
  };
}
```

**Advanced Option Patterns:**

```nix
{ config, lib, pkgs, ... }:
with lib; {
  options.services.myservice = {
    enable = mkEnableOption "MyService";

    # Package option with example
    package = mkPackageOption pkgs "myservice" {
      default = pkgs.myservice;
      example = literalExpression "pkgs.myservice.override { enableFeature = true; }";
    };

    # Option with assertion
    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port to listen on";
    };

    # Derived option (read-only)
    connectionString = mkOption {
      type = types.str;
      readOnly = true;
      default = "http://${cfg.host}:${toString cfg.port}";
      description = "Auto-generated connection string";
    };

    # Option with validation
    logLevel = mkOption {
      type = types.enum [ "debug" "info" "warn" "error" ];
      default = "info";
      description = "Logging level";
    };

    # Complex validation
    replicas = mkOption {
      type = types.int;
      default = 1;
      description = "Number of replicas";
      check = x: x > 0 && x <= 10;
      # Or custom assertion in config
    };
  };

  # Assertions based on options
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.replicas > 0 && cfg.replicas <= 10;
        message = "replicas must be between 1 and 10";
      }
      {
        assertion = cfg.database.url != "";
        message = "database.url must be configured";
      }
    ];
  };
}
```

### Using Options

**Reading Options:**

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.services.myservice;
in {
  config = lib.mkIf cfg.enable {
    # Use option values
    systemd.services.myservice = {
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/myservice --port ${toString cfg.port}";
      };
    };

    # Access nested options
    environment.etc."myservice/config.json".text = builtins.toJSON {
      server = {
        host = cfg.settings.server.host;
        port = cfg.settings.server.port;
      };
    };
  };
}
```

**Option Priorities:**

```nix
{ config, lib, pkgs, ... }:
with lib; {
  # Default priority (1000)
  services.myservice.port = 8080;

  # Lower number = higher priority
  services.myservice.port = mkForce 9090;        # Priority 50
  services.myservice.port = mkOverride 500 9090; # Priority 500
  services.myservice.port = mkDefault 8080;      # Priority 1500

  # Conditional with default
  services.myservice.host = mkDefault "localhost";
  services.myservice.host = mkIf config.features.public.enable "0.0.0.0";
}
```

**Merging Strategies:**

```nix
{ config, lib, pkgs, ... }:
with lib; {
  # List merging (concatenates)
  services.myservice.allowedUsers = [ "alice" ];
  services.myservice.allowedUsers = [ "bob" ];
  # Result: [ "alice" "bob" ]

  # Attribute set merging (recursive)
  services.myservice.settings = {
    server.host = "localhost";
  };
  services.myservice.settings = {
    server.port = 8080;
  };
  # Result: { server = { host = "localhost"; port = 8080; }; }

  # Override merging with mkMerge
  services.myservice.config = mkMerge [
    { base = "config"; }
    (mkIf condition { extra = "value"; })
  ];
}
```

## Module System Best Practices

### Module Structure

**Standard Module Pattern:**

```nix
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.myservice;
in {
  # 1. Options declaration
  options.services.myservice = {
    enable = mkEnableOption "MyService";

    package = mkPackageOption pkgs "myservice" {};

    settings = mkOption {
      type = types.submodule {
        freeformType = types.attrsOf types.anything;
        options = {
          # Structured options
        };
      };
      default = {};
    };
  };

  # 2. Configuration implementation
  config = mkIf cfg.enable {
    # Assertions
    assertions = [
      {
        assertion = cfg.settings.database.url != "";
        message = "database.url must be configured";
      }
    ];

    # Warnings
    warnings = optional (cfg.settings.debug) [
      "Debug mode is enabled - not recommended for production"
    ];

    # System configuration
    systemd.services.myservice = {
      description = "MyService daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/myservice";
        DynamicUser = true;
        # ... security hardening
      };
    };

    # Environment configuration
    environment.systemPackages = [ cfg.package ];

    # File generation
    environment.etc."myservice/config.json" = {
      text = builtins.toJSON cfg.settings;
      mode = "0644";
    };
  };

  # 3. Metadata
  meta = {
    maintainers = with maintainers; [ username ];
    doc = ./myservice.md;
  };
}
```

**Module Organization:**

```nix
# modules/services/myservice.nix
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.myservice;

  # Helper functions
  mkConfigFile = settings: pkgs.writeText "config.json" (builtins.toJSON settings);

  # Validation logic
  validateSettings = settings:
    assert settings.server.port > 0;
    assert settings.server.port < 65536;
    settings;
in {
  # Clear separation: options, config, meta
}
```

### Feature Flag Pattern

**Feature-Based Architecture:**

```nix
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.features.myfeature;
in {
  options.features.myfeature = {
    enable = mkEnableOption "MyFeature functionality";

    # Feature-specific options
    mode = mkOption {
      type = types.enum [ "basic" "advanced" ];
      default = "basic";
    };
  };

  config = mkIf cfg.enable {
    # Enable underlying services
    services.required-service.enable = true;
    services.optional-service.enable = cfg.mode == "advanced";

    # Feature-specific configuration
    environment.systemPackages = with pkgs; [
      feature-tool
    ] ++ optionals (cfg.mode == "advanced") [
      advanced-tool
    ];
  };
}
```

**Conditional Module Loading:**

```nix
{ config, lib, pkgs, ... }: {
  imports = [
    ./base.nix
  ] ++ lib.optionals config.features.desktop.enable [
    ./desktop.nix
    ./gui-apps.nix
  ] ++ lib.optionals config.features.development.enable [
    ./development.nix
    ./devtools.nix
  ];
}
```

### Security Patterns

**Service Hardening:**

```nix
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.myservice;
in {
  config = mkIf cfg.enable {
    systemd.services.myservice = {
      serviceConfig = {
        # User isolation
        DynamicUser = true;
        User = "myservice";
        Group = "myservice";

        # Filesystem protection
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;

        # Capability restrictions
        NoNewPrivileges = true;
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];

        # Namespace isolation
        PrivateNetwork = false;  # Needs network
        RestrictNamespaces = true;

        # System call filtering
        SystemCallFilter = [ "@system-service" "~@privileged" ];
        SystemCallErrorNumber = "EPERM";

        # Resource limits
        MemoryMax = "1G";
        TasksMax = 1000;

        # Working directory
        WorkingDirectory = "/var/lib/myservice";
        StateDirectory = "myservice";
        ReadWritePaths = [ "/var/lib/myservice" ];
      };
    };

    # State directory
    systemd.tmpfiles.rules = [
      "d /var/lib/myservice 0750 myservice myservice -"
    ];
  };
}
```

**Secret Management:**

```nix
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.myservice;
in {
  config = mkIf cfg.enable {
    # ❌ WRONG - Reads secret during evaluation
    # services.myservice.password = builtins.readFile "/secrets/pass";

    # ✅ CORRECT - Runtime loading
    services.myservice.passwordFile = config.age.secrets.myservice-password.path;

    # ✅ CORRECT - Environment file
    systemd.services.myservice = {
      serviceConfig = {
        EnvironmentFile = config.age.secrets.myservice-env.path;
      };
    };

    # Agenix secret definition
    age.secrets.myservice-password = {
      file = ../secrets/myservice-password.age;
      mode = "0400";
      owner = "myservice";
      group = "myservice";
    };
  };
}
```

## Debugging Techniques

### Evaluation Debugging

**Trace Functions:**

```nix
let
  # Print value during evaluation
  value = lib.traceVal someExpression;

  # Print with message
  value = lib.trace "Debug: checking value" someExpression;

  # Conditional trace
  value = lib.traceIf condition "Warning: condition met" someExpression;

  # Trace and stop evaluation
  value = lib.traceSeq someExpression;  # Force evaluation

  # Show attribute set
  value = lib.traceSeqN 2 attrset;  # Show 2 levels deep
in value
```

**REPL Debugging:**

```bash
# Start Nix REPL
nix repl

# Load nixpkgs
:l <nixpkgs>

# Load configuration
:l ./configuration.nix

# Inspect value
config.services.myservice

# Check type
:t config.services.myservice.enable

# Show documentation
:doc lib.mkIf

# Evaluate expression
lib.mkForce "value"

# Reload after changes
:r
```

**Build Debugging:**

```bash
# Show derivation
nix show-derivation .#mypackage

# Build with verbose output
nix build .#mypackage --print-build-logs

# Check what will be built
nix build .#mypackage --dry-run

# Build and keep failed build dir
nix build .#mypackage --keep-failed

# Enter build environment
nix develop .#mypackage
# Then: unpackPhase; cd $sourceRoot; configurePhase; buildPhase

# Show dependencies
nix-store --query --requisites $(nix-build . -A mypackage)

# Show why package is in closure
nix why-depends /run/current-system pkgs.mypackage
```

### Module Debugging

**Option Inspection:**

```bash
# Show all options
nixos-option

# Show specific option
nixos-option services.myservice.enable

# Show option value and definition locations
nixos-option services.myservice.port

# Search options
nixos-option -r services.*

# In REPL
nix repl '<nixpkgs/nixos>'
:l ./configuration.nix
config.services.myservice
```

**Evaluation Errors:**

```nix
# Common error: infinite recursion
rec {
  a = b;
  b = a;  # ❌ Error
}

# Fix: use let-in
let
  a = 1;
  b = a;
in { inherit a b; }

# Common error: attribute not found
config.services.typo.enable = true;  # ❌ If service doesn't exist

# Fix: check spelling, ensure module imported
# Use: nixos-option services. | grep service-name

# Common error: type mismatch
services.myservice.port = "8080";  # ❌ Expects int
services.myservice.port = 8080;    # ✅ Correct

# Common error: missing argument
pkgs.callPackage ./package.nix { };  # ❌ If package expects 'foo'
pkgs.callPackage ./package.nix { foo = ...; };  # ✅ Provide argument
```

## Best Practices Summary

### DO ✅

1. **Use let-in for local bindings** instead of rec attribute sets
2. **Limit 'with' scope** - only for package lists or limited contexts
3. **Use inherit** for cleaner attribute assignments
4. **Explicit imports** - no magic auto-discovery
5. **callPackage pattern** for automatic dependency resolution
6. **Proper option types** - use types.submodule for structured config
7. **Security hardening** - DynamicUser, ProtectSystem, minimal privileges
8. **Runtime secret loading** - passwordFile patterns, never eval-time reads
9. **Assertions and warnings** - validate configuration early
10. **Comprehensive meta** - description, homepage, license, maintainers
11. **strictDeps = true** - proper dependency categorization
12. **Feature flags** - enable/disable functionality cleanly
13. **Documentation** - document all options and their purpose

### DON'T ❌

1. **Avoid rec** - use let-in for safety
2. **Don't stack 'with'** - unclear variable origins
3. **No magic imports** - explicit import lists only
4. **No evaluation-time secrets** - use runtime loading
5. **No root services** - always use DynamicUser
6. **No hardcoded paths** - use ${pkg}/bin/program
7. **No IFD (Import From Derivation)** - keeps eval and build separate
8. **No unquoted URLs** - deprecated since RFC 45
9. **No `mkIf condition true`** - trust the module system
10. **No excessive indirection** - trivial wrappers add no value

### Checklist for New Modules

```nix
# ✅ Complete module checklist
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.myservice;
in {
  # ✅ Clear option structure
  options.services.myservice = {
    enable = mkEnableOption "MyService";
    package = mkPackageOption pkgs "myservice" {};
    settings = mkOption { /* ... */ };
  };

  # ✅ Conditional config with mkIf
  config = mkIf cfg.enable {
    # ✅ Assertions for validation
    assertions = [
      {
        assertion = cfg.settings.required != "";
        message = "required setting must be configured";
      }
    ];

    # ✅ Security hardening
    systemd.services.myservice = {
      serviceConfig = {
        DynamicUser = true;
        ProtectSystem = "strict";
        NoNewPrivileges = true;
        # ... full hardening
      };
    };

    # ✅ Runtime secret loading
    serviceConfig.EnvironmentFile = config.age.secrets.myservice.path;
  };

  # ✅ Metadata
  meta = {
    maintainers = with maintainers; [ username ];
  };
}
```

## Integration with NixOS Infrastructure

This skill integrates with existing commands:

- **`/nix-module`** - Uses these patterns for module creation
- **`/nix-fix`** - Detects and fixes anti-patterns
- **`/nix-review`** - Checks against these best practices
- **`/nix-security`** - Validates security hardening patterns

Refer to:

- **docs/PATTERNS.md** - Complete patterns guide
- **docs/NIXOS-ANTI-PATTERNS.md** - Detailed anti-patterns reference

Use this skill when:

- Creating new NixOS modules
- Writing package derivations
- Debugging configuration issues
- Reviewing code for best practices
- Understanding evaluation errors
- Implementing security patterns

This skill ensures all NixOS configuration follows community standards and infrastructure best practices.
