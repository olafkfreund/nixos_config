# Nix Anti-Patterns and Best Practices

> **Source**: Based on research from mhwombat.codeberg.page/nix-book
> **Purpose**: Guide for avoiding common Nix pitfalls in this configuration
> **Status**: Living document - update as we discover new patterns

## 🚨 Critical Anti-Patterns to Avoid

### 1. Path and String Concatenation Pitfalls

**❌ WRONG - Missing Spaces Around Operators**
```nix
# This is interpreted as a path, not division!
let result = 6/2;  # result = <path 6/2>

# This is interpreted as a path
let path = ./src/main;  # Unexpected path interpretation
```

**✅ CORRECT - Always Use Spaces**
```nix
# Proper numeric division
let result = 6 / 2;  # result = 3

# Proper path with spaces
let path = ./src / main;  # OR use string: "src/main"

# String concatenation
let fullPath = "${basePath}/config";
```

**Why It Matters**: Nix interprets adjacent tokens without spaces as paths, leading to confusing type errors.

**Rule**: **Always use spaces around operators** (`+`, `-`, `*`, `/`, `==`, etc.)

---

### 2. Variable Immutability - No Reassignment

**❌ WRONG - Attempting to Mutate Variables**
```nix
let
  x = 1;
  x = 2;  # ERROR: attribute 'x' already defined
in x
```

**✅ CORRECT - Immutable Bindings**
```nix
let
  x = 1;
  y = x + 1;  # Create new binding instead
in y
```

**Why It Matters**: Nix is a functional language - all values are immutable. Attempting reassignment causes errors.

**Rule**: **Never attempt to reassign variables** - create new bindings instead.

---

### 3. Type Mixing Without Conversion

**❌ WRONG - Mixing Types Implicitly**
```nix
let
  port = 8080;
  url = "http://localhost:" + port;  # ERROR: cannot coerce integer to string
in url
```

**✅ CORRECT - Explicit Type Conversion**
```nix
let
  port = 8080;
  url = "http://localhost:${toString port}";  # Interpolation converts automatically
  # OR
  url2 = "http://localhost:" + (toString port);
in url
```

**Why It Matters**: Nix doesn't implicitly convert types. String interpolation `${}` handles conversion automatically.

**Rule**: **Use string interpolation** `${}` or explicit `toString` for type conversion.

---

### 4. Floating Point vs Integer Division

**❌ WRONG - Assuming Integer Division**
```nix
let result = 5 / 2;  # result = 2 (integer division!)
```

**✅ CORRECT - Explicit Floating Point**
```nix
let result = 5.0 / 2.0;  # result = 2.5 (float division)
```

**Why It Matters**: Nix performs integer division unless both operands are floats.

**Rule**: **Add decimal points** (.0) for floating-point arithmetic.

---

### 5. Development vs Runtime Dependencies Confusion

**❌ WRONG - Mixing Build and Development Dependencies**
```nix
{
  buildInputs = [
    # Development tools don't belong here!
    gcc
    gdb
    valgrind
    # Only runtime dependencies!
  ];
}
```

**✅ CORRECT - Proper Separation**
```nix
{
  # Runtime/build dependencies
  buildInputs = [
    openssl
    zlib
  ];

  # Development tools
  nativeBuildInputs = [
    pkg-config
    cmake
  ];

  # Separate development shell
  devShells.default = pkgs.mkShell {
    packages = [
      gcc
      gdb
      valgrind
    ];
  };
}
```

**Why It Matters**: Mixing concerns pollutes runtime environments and increases closure size.

**Rule**: **Separate runtime, build, and development dependencies** into appropriate sections.

---

### 6. Not Committing flake.lock

**❌ WRONG - Ignoring flake.lock**
```gitignore
# .gitignore
flake.lock  # DON'T ignore this!
```

**✅ CORRECT - Commit Lockfile**
```bash
git add flake.lock
git commit -m "chore: Update flake.lock for reproducibility"
```

**Why It Matters**: `flake.lock` ensures exact dependency versions for reproducible builds across machines.

**Rule**: **Always commit flake.lock** to version control.

---

### 7. Overly Complex Flake References

**❌ WRONG - Overcomplicated Input References**
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    mylib.url = "github:user/repo?rev=abc123&ref=main&dir=subdir";
    someflake = {
      url = "github:another/repo";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
      inputs.random.follows = "something";
    };
  };
}
```

**✅ CORRECT - Simple, Clear References**
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    mylib.url = "github:user/repo";
    someflake = {
      url = "github:another/repo";
      inputs.nixpkgs.follows = "nixpkgs";  # Only essential follows
    };
  };
}
```

**Why It Matters**: Complex references are hard to maintain and understand. Simple is better.

**Rule**: **Keep input references simple** - only add complexity when necessary.

---

### 8. Shell Command Confusion

**❌ WRONG - Misusing Nix Commands**
```bash
# Confusing commands
nix develop     # For modifying the package
nix shell       # For trying packages temporarily
nix run         # For building and running

# Using all three interchangeably
```

**✅ CORRECT - Right Tool for the Job**
```bash
# Development workflow (modifying code)
nix develop        # Enter dev shell with build tools
# Then: cargo build, go run, etc.

# Temporary package usage
nix shell nixpkgs#cowsay   # Temporarily add package to PATH

# Build and run
nix run            # Build and execute default app

# Build only
nix build          # Build package, create ./result symlink
```

**Why It Matters**: Each command serves a specific purpose. Using the wrong one wastes time.

**Rule**:
- **`nix develop`**: Modify/develop package
- **`nix shell`**: Temporarily use package
- **`nix run`**: Build and run app
- **`nix build`**: Build without running

---

### 9. Ignoring Git "Dirty" Warnings

**❌ WRONG - Building with Uncommitted Changes**
```bash
# Warning: Git tree is dirty
nix build  # Proceeds anyway, but may not work correctly
```

**✅ CORRECT - Clean Git State**
```bash
# Add new files
git add new-file.nix

# Or commit changes
git commit -am "feat: Add new configuration"

# Then build
nix build
```

**Why It Matters**: Flakes only see files tracked by Git. Uncommitted files are invisible to Nix.

**Rule**: **Commit or stage files before building flakes**.

---

### 10. Excessive Use of `with`

**❌ WRONG - Overusing `with` Statement**
```nix
with pkgs;
with lib;
with stdenv;
with builtins;
{
  # Where does 'filter' come from?
  packages = filter (x: x != null) [ gcc vim git ];
  # lib.filter? builtins.filter? Unclear!
}
```

**✅ CORRECT - Limited, Explicit `with` Usage**
```nix
{
  packages = with pkgs; [
    gcc    # Clear: from pkgs
    vim
    git
  ];

  # Or even better - fully explicit
  packages = [
    pkgs.gcc
    pkgs.vim
    pkgs.git
  ];

  # Use lib functions explicitly
  filtered = lib.filter (x: x != null) someList;
}
```

**Why It Matters**: Nested `with` statements make it unclear where identifiers originate, reducing code clarity.

**Rule**: **Limit `with` usage** to small scopes; prefer explicit references (`pkgs.`, `lib.`).

---

## 📘 Best Practices from Nix Book

### 1. Function Parameter Patterns

**✅ RECOMMENDED - Set Patterns for Functions**
```nix
# Named parameters with defaults
{ pkgs
, lib
, config
, myOption ? "default"  # Optional with default
, ...                   # Accept extra args
}:
{
  # Function body
}
```

**Benefits**:
- Clear parameter names
- Optional parameters with defaults
- Extensible with `...`

---

### 2. Let Expressions for Local Scope

**✅ RECOMMENDED - Use `let` for Local Variables**
```nix
let
  basePort = 8080;
  serviceName = "myapp";
  fullUrl = "http://localhost:${toString basePort}/${serviceName}";
in {
  services.${serviceName} = {
    enable = true;
    port = basePort;
    url = fullUrl;
  };
}
```

**Benefits**:
- Scoped variable definitions
- Improved readability
- Avoid repetition

---

### 3. Recursive Attribute Sets

**✅ RECOMMENDED - Use `rec` Sparingly**
```nix
# Use rec only when necessary
rec {
  version = "1.0.0";
  name = "myapp-${version}";  # Self-reference
}

# Better: Use let instead
let
  version = "1.0.0";
in {
  inherit version;
  name = "myapp-${version}";
}
```

**Why**: `rec` can cause infinite recursion. `let` is clearer and safer.

**Rule**: **Prefer `let` over `rec`** - only use `rec` when absolutely necessary.

---

### 4. String Interpolation Best Practices

**✅ RECOMMENDED - Consistent String Interpolation**
```nix
let
  port = 8080;
  host = "localhost";
  protocol = "http";
in {
  # Good - using interpolation
  url = "${protocol}://${host}:${toString port}";

  # Also good - for simple cases
  greeting = "Hello, ${name}!";

  # Multi-line strings
  config = ''
    server {
      listen ${toString port};
      server_name ${host};
    }
  '';
}
```

**Rule**: **Use `${}` for variable interpolation** - automatic type conversion and clarity.

---

### 5. Flake Structure Best Practices

**✅ RECOMMENDED - Standard Flake Template**
```nix
{
  description = "Brief description of what this flake does";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "mypackage";
          version = "1.0.0";
          src = ./.;
          buildInputs = [ /* runtime deps */ ];
          nativeBuildInputs = [ /* build deps */ ];
        };

        devShells.default = pkgs.mkShell {
          packages = [ /* development tools */ ];
        };
      }
    );
}
```

**Structure**:
1. **Description**: Brief, clear description
2. **Inputs**: Dependencies and sources
3. **Outputs**: Packages, apps, devShells
4. **Multi-platform**: Use `flake-utils` for cross-platform support

---

### 6. Development Workflow Patterns

**✅ RECOMMENDED - Two-Tier Development Approach**

**High-Level Workflow (Iterative)**:
```bash
# Make changes to code or flake.nix
vim src/main.hs

# Rebuild and run in one command
nix run

# Fix any issues
vim flake.nix

# Repeat
nix run
```

**Low-Level Workflow (Detailed)**:
```bash
# Enter development shell
nix develop

# Use language tools directly
cabal build
cabal run
cargo test
go run main.go

# Exit when done
exit
```

**When to Use Each**:
- **High-level**: Quick iterations, testing changes
- **Low-level**: Debugging, detailed control, complex builds

---

## 🎯 Patterns Specific to This Configuration

### 1. Module Option Definitions

**✅ CORRECT - Consistent Option Pattern**
```nix
{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.features.myfeature;
in {
  options.features.myfeature = {
    enable = mkEnableOption "MyFeature description";

    option1 = mkOption {
      type = types.str;
      default = "default-value";
      description = "Description of option1";
    };
  };

  config = mkIf cfg.enable {
    # Configuration when enabled
  };
}
```

**Required Elements**:
- Clear option naming: `config.features.*`
- `mkEnableOption` for enable flags
- `mkOption` with type, default, description
- `mkIf cfg.enable` for conditional config

---

### 2. Feature Flag Pattern

**✅ CORRECT - Feature-Based Architecture**
```nix
# In host configuration
features = {
  desktop.enable = true;
  development = {
    enable = true;
    languages = {
      python = true;
      go = true;
    };
  };
  monitoring = {
    enable = true;
    mode = "client";
  };
};
```

**Don't**:
- Don't enable services directly in host configs
- Don't duplicate service configurations

**Do**:
- Use feature flags
- Let modules handle service configuration
- Enable features, not services

---

### 3. Secret Management Pattern

**✅ CORRECT - Runtime Secret Loading**
```nix
# Use file paths, not content
services.myservice = {
  enable = true;
  passwordFile = config.age.secrets."myservice-password".path;
  apiKeyFile = "/run/agenix/api-key";
};

# NOT this
services.myservice = {
  password = builtins.readFile "/secrets/password";  # ❌ Exposes in store!
};
```

**Rule**: **Never read secrets during evaluation** - use file path references for runtime loading.

---

### 4. Template-Based Host Configuration

**✅ CORRECT - Use Host Templates**
```nix
# hosts/p620/configuration.nix
{ lib, ... }:
{
  imports = [
    ../../lib/hostTypes.workstation  # Use template
    ./hardware-configuration.nix
    ./amd.nix  # Hardware-specific only
  ];

  # Host-specific overrides and features
  features.desktop.enable = true;
}
```

**Don't**:
- Don't duplicate common configurations
- Don't redefine services in host configs

**Do**:
- Import appropriate template
- Add only host-specific configurations
- Use feature flags

---

## 📋 Quick Reference Checklist

Before committing code, verify:

- [ ] All operators have spaces around them
- [ ] No variable reassignments
- [ ] Type conversions use `toString` or `${}`
- [ ] Floating-point division uses `.0`
- [ ] Development vs runtime dependencies separated
- [ ] `flake.lock` is committed
- [ ] Flake inputs are simple and clear
- [ ] Correct Nix command used (`develop`, `shell`, `run`, `build`)
- [ ] All files are staged in Git before building
- [ ] `with` usage is minimal and scoped
- [ ] `rec` usage is minimal (prefer `let`)
- [ ] String interpolation uses `${}`
- [ ] Secrets use file paths, not content
- [ ] Module options follow standard pattern
- [ ] Feature flags used instead of direct service config

---

## 📚 Additional Resources

- **Nix Book**: https://mhwombat.codeberg.page/nix-book/
- **Our Anti-Patterns Doc**: `docs/NIXOS-ANTI-PATTERNS.md`
- **Research on Best Practices**: `docs/RESEARCH_USMCAMP_DOTFILES.md`
- **Deduplication Report**: `docs/DEDUPLICATION_REPORT.md`

---

## 🔄 Living Document

This document should be updated when:
- New anti-patterns are discovered
- Best practices evolve
- Community standards change
- We learn from mistakes

**Last Updated**: 2025-01-15
**Next Review**: Q2 2025
