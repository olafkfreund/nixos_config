# cargo2nix Skill

> **Expert guidance for packaging Rust applications with Nix**
> Granular per-crate builds with reproducible, cacheable dependencies

## Overview

cargo2nix is a tool that brings Nix dependency management to Rust projects, enabling reproducible builds, efficient per-crate caching, and complete control over the build environment. Unlike simpler approaches, cargo2nix creates individual Nix derivations for each crate, allowing fine-grained dependency sharing across projects and optimal build caching.

**Key Features**:

- **Per-Crate Derivations**: Each dependency gets its own derivation for optimal caching
- **Reproducible Builds**: Pure builds with nixpkgs integration
- **Development Shells**: Automatic dev environments with all dependencies
- **Workspace Support**: Full Cargo workspace compatibility
- **Cross-Compilation**: Target specification for different platforms
- **Build Caching**: Skip unnecessary work in CI/CD pipelines

**Project Status**:

- Latest Release: 0.12
- License: MIT
- Repository: <https://github.com/cargo2nix/cargo2nix>
- Stable Branches: release-0.11.0, release-0.12

## When to Use cargo2nix

### cargo2nix vs Other Tools

The Rust/Nix ecosystem offers **8+ different solutions**. Understanding when to use cargo2nix is critical:

| Tool                 | Derivations        | Generated Files | Best For                             | Trade-offs                     |
| -------------------- | ------------------ | --------------- | ------------------------------------ | ------------------------------ |
| **buildRustPackage** | 1 (monolithic)     | None            | Simple projects, nixpkgs integration | No dependency caching          |
| **naersk**           | 2 (deps + project) | None            | Better caching than buildRustPackage | Less granular than cargo2nix   |
| **crane**            | Composable         | None            | Modern approach, Cargo-driven        | Bundles dependencies together  |
| **crate2nix**        | Per-crate          | Yes (Cargo.nix) | Fine-grained caching                 | Experimental cross-compilation |
| **cargo2nix**        | Per-crate          | Yes (Cargo.nix) | Shared deps, custom toolchains       | Requires Cargo.nix maintenance |
| **dream2nix**        | Varies             | Varies          | Multi-language projects              | Additional abstraction layer   |

### ✅ Use cargo2nix When

1. **Shared Dependencies Across Projects**
   - Multiple Rust projects share common crates
   - Want to cache dependencies in binary cache
   - Building a monorepo with multiple Rust packages

2. **Fine-Grained Build Control**
   - Need per-crate customization and overrides
   - Complex build.rs scripts require special handling
   - Platform-specific dependency management

3. **Advanced Caching Requirements**
   - CI/CD pipelines benefit from per-crate caching
   - Updating one dependency shouldn't rebuild everything
   - Binary cache size matters

4. **Custom Rust Toolchains**
   - Need specific Rust versions not in nixpkgs
   - Using nightly features or specific dates
   - Require rust-analyzer, clippy, miri, etc.

### ❌ Use Alternatives When

**Use buildRustPackage** if:

- Simple project with few dependencies
- Want nixpkgs native integration
- Don't need fine-grained caching

**Use crane** if:

- Want modern, composable approach
- Prefer Cargo-driven builds
- Don't need per-crate granularity

**Use naersk** if:

- Need simple dependency separation
- Want dynamic Cargo.lock importing
- Two-derivation model is sufficient

**Use crate2nix** if:

- devenv recommends it (as of 2025)
- Want per-crate builds without custom toolchains
- Experimental cross-compilation is acceptable

## Installation

### Prerequisites

- Nix with flakes enabled
- Existing Rust project with `Cargo.toml` and `Cargo.lock`

### Quick Start

**Generate Cargo.nix** (one-time):

```bash
# Using nix run
nix run github:cargo2nix/cargo2nix

# Or in development shell
nix develop github:cargo2nix/cargo2nix#bootstrap
cargo2nix

# Commit the generated file
git add Cargo.nix
git commit -m "Add Cargo.nix for cargo2nix"
```

**Update Cargo.nix** (when Cargo.lock changes):

```bash
nix run github:cargo2nix/cargo2nix
git add Cargo.nix
git commit -m "Update Cargo.nix"
```

### Version Pinning

Specify cargo2nix version in `flake.nix`:

```nix
{
  inputs = {
    # Latest release (recommended)
    cargo2nix.url = "github:cargo2nix/cargo2nix";

    # Specific version (stable)
    cargo2nix.url = "github:cargo2nix/cargo2nix/release-0.12";

    # Development version (unstable)
    cargo2nix.url = "github:cargo2nix/cargo2nix/main";
  };
}
```

Update specific version:

```bash
nix flake lock --update-input cargo2nix
```

## Basic Usage

### Minimal Flake Configuration

```nix
{
  description = "Rust project using cargo2nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cargo2nix = {
      url = "github:cargo2nix/cargo2nix/release-0.12";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, cargo2nix, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ cargo2nix.overlays.default ];
        };

        # Build Rust package set
        rustPkgs = pkgs.rustBuilder.makePackageSet {
          rustVersion = "1.75.0";
          packageFun = import ./Cargo.nix;
        };

      in {
        packages = {
          # Expose your binary
          myapp = rustPkgs.workspace.myapp {};
          default = self.packages.${system}.myapp;
        };

        # Development shell
        devShells.default = rustPkgs.workspaceShell {
          packages = with pkgs; [
            rust-analyzer
            cargo-watch
            cargo-edit
          ];
        };
      }
    );
}
```

### Build and Run

```bash
# Build your project
nix build

# Run the binary
./result/bin/myapp

# Enter development shell
nix develop

# Inside dev shell
cargo build
cargo test
cargo run
```

## Workspace Support

### Multi-Crate Workspace

cargo2nix fully supports Cargo workspaces:

```toml
# Cargo.toml (workspace root)
[workspace]
members = [
  "crates/mylib",
  "crates/mybin",
  "crates/common",
]
```

**Flake Configuration**:

```nix
{
  outputs = { self, nixpkgs, cargo2nix, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ cargo2nix.overlays.default ];
        };

        rustPkgs = pkgs.rustBuilder.makePackageSet {
          rustVersion = "1.75.0";
          packageFun = import ./Cargo.nix;

          # Workspace-wide features
          rootFeatures = [ "mylib/default" "mybin/cli" ];
        };

      in {
        packages = {
          # Expose individual workspace members
          mylib = rustPkgs.workspace.mylib {};
          mybin = rustPkgs.workspace.mybin {};
          common = rustPkgs.workspace.common {};

          # Default to main binary
          default = self.packages.${system}.mybin;
        };

        devShells.default = rustPkgs.workspaceShell {
          packages = with pkgs; [
            rust-analyzer
            cargo-nextest  # Modern test runner
          ];
        };
      }
    );
}
```

### Accessing Individual Crates

```nix
# Workspace crates
rustPkgs.workspace.myapp {}
rustPkgs.workspace.mylib {}

# Registry crates (dependencies)
rustPkgs."registry+https://github.com/rust-lang/crates.io-index".serde."1.0.193" {}
rustPkgs."registry+https://github.com/rust-lang/crates.io-index".tokio."1.35.1" {}

# Git dependencies
rustPkgs."git+https://github.com/user/repo".mycrate."0.1.0" {}
```

## makePackageSet Configuration

### Core Arguments

```nix
rustPkgs = pkgs.rustBuilder.makePackageSet {
  # Rust version (REQUIRED)
  rustVersion = "1.75.0";  # Specific version
  # OR
  rustVersion = "2024-01-15";  # Nightly date

  # Rust channel (default: "stable")
  rustChannel = "stable";    # or "beta", "nightly"

  # Rust profile (default: "default")
  rustProfile = "minimal";   # or "default" (includes docs, rustfmt)

  # Additional components
  extraRustComponents = [
    "rust-analyzer"
    "clippy"
    "rustfmt"
    "miri"
  ];

  # Package function (REQUIRED)
  packageFun = import ./Cargo.nix;

  # Workspace source override
  workspaceSrc = ./.;  # Default: uses Cargo.toml location

  # Root features
  rootFeatures = [
    "default"
    "mylib/serde"
    "mybin/cli"
  ];

  # Package overrides
  packageOverrides = pkgs: [
    (pkgs.rustBuilder.rustLib.makeOverride {
      name = "openssl-sys";
      overrideAttrs = drv: {
        propagatedBuildInputs = drv.propagatedBuildInputs or [] ++ [
          pkgs.openssl
          pkgs.pkg-config
        ];
      };
    })
  ];

  # Cross-compilation target
  target = "x86_64-unknown-linux-musl";
};
```

### Common Rust Versions

```nix
# Stable (specific version)
rustVersion = "1.75.0";

# Stable (latest from nixpkgs)
rustVersion = pkgs.rustc.version;

# Nightly (specific date)
rustVersion = "2024-01-15";
rustChannel = "nightly";

# Beta
rustChannel = "beta";

# Using rust-overlay for latest nightly
inputs.rust-overlay.url = "github:oxalica/rust-overlay";

rustToolchain = pkgs.rust-bin.nightly.latest.default.override {
  extensions = [ "rust-src" "rust-analyzer" ];
};
```

## Package Overrides

### Common System Dependencies

```nix
packageOverrides = pkgs: pkgs.rustBuilder.overrides.all ++ [
  # OpenSSL
  (pkgs.rustBuilder.rustLib.makeOverride {
    name = "openssl-sys";
    overrideAttrs = drv: {
      propagatedBuildInputs = drv.propagatedBuildInputs or [] ++ [
        pkgs.openssl
        pkgs.pkg-config
      ];
    };
  })

  # libsqlite3
  (pkgs.rustBuilder.rustLib.makeOverride {
    name = "libsqlite3-sys";
    overrideAttrs = drv: {
      propagatedBuildInputs = drv.propagatedBuildInputs or [] ++ [
        pkgs.sqlite
      ];
    };
  })

  # onig (for syntect)
  (pkgs.rustBuilder.rustLib.makeOverride {
    name = "onig_sys";
    overrideAttrs = drv: {
      buildInputs = drv.buildInputs or [] ++ [ pkgs.oniguruma ];
    };
  })

  # PostgreSQL
  (pkgs.rustBuilder.rustLib.makeOverride {
    name = "pq-sys";
    overrideAttrs = drv: {
      propagatedBuildInputs = drv.propagatedBuildInputs or [] ++ [
        pkgs.postgresql
      ];
    };
  })

  # libgit2
  (pkgs.rustBuilder.rustLib.makeOverride {
    name = "libgit2-sys";
    overrideAttrs = drv: {
      buildInputs = drv.buildInputs or [] ++ [
        pkgs.libgit2
        pkgs.pkg-config
      ];
    };
  })
];
```

### Override Patterns

**Use Existing Overrides**:

```nix
packageOverrides = pkgs: pkgs.rustBuilder.overrides.all;
```

**Combine with Custom Overrides**:

```nix
packageOverrides = pkgs: pkgs.rustBuilder.overrides.all ++ [
  (pkgs.rustBuilder.rustLib.makeOverride {
    name = "my-custom-crate";
    overrideAttrs = drv: {
      # Custom build dependencies
      nativeBuildInputs = drv.nativeBuildInputs or [] ++ [
        pkgs.cmake
        pkgs.protobuf
      ];

      # Environment variables
      LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

      # Pre-build script
      preConfigure = ''
        export CUSTOM_VAR="value"
      '';
    };
  })
];
```

### Platform-Specific Overrides

```nix
packageOverrides = pkgs: [
  (pkgs.rustBuilder.rustLib.makeOverride {
    name = "ring";
    overrideAttrs = drv: {
      # Only on aarch64-darwin
      buildInputs = drv.buildInputs or [] ++
        pkgs.lib.optionals pkgs.stdenv.isDarwin [
          pkgs.darwin.apple_sdk.frameworks.Security
        ];
    };
  })
];
```

## Cross-Compilation

### Basic Cross-Compilation

```nix
rustPkgs = pkgs.rustBuilder.makePackageSet {
  rustVersion = "1.75.0";
  packageFun = import ./Cargo.nix;

  # Cross-compile to x86_64 musl (static binary)
  target = "x86_64-unknown-linux-musl";
};
```

### Common Targets

```nix
# Static Linux binary (musl)
target = "x86_64-unknown-linux-musl";

# ARM 64-bit Linux
target = "aarch64-unknown-linux-gnu";

# Windows
target = "x86_64-pc-windows-gnu";

# macOS ARM (M1/M2)
target = "aarch64-apple-darwin";

# WebAssembly
target = "wasm32-unknown-unknown";
```

### Multi-Target Builds

```nix
{
  outputs = { self, nixpkgs, cargo2nix, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ cargo2nix.overlays.default ];
        };

        mkApp = target:
          (pkgs.rustBuilder.makePackageSet {
            rustVersion = "1.75.0";
            packageFun = import ./Cargo.nix;
            inherit target;
          }).workspace.myapp {};

      in {
        packages = {
          default = mkApp null;  # Native
          linux-musl = mkApp "x86_64-unknown-linux-musl";
          linux-arm = mkApp "aarch64-unknown-linux-gnu";
          windows = mkApp "x86_64-pc-windows-gnu";
        };
      }
    );
}
```

## Development Shells

### Basic Shell

```nix
devShells.default = rustPkgs.workspaceShell {
  packages = with pkgs; [
    # Development tools
    rust-analyzer
    cargo-watch
    cargo-edit
    cargo-udeps
    cargo-audit

    # Additional utilities
    just          # Command runner
    bacon         # Background Rust compiler
  ];
};
```

### Enhanced Shell with Environment

```nix
devShells.default = rustPkgs.workspaceShell {
  packages = with pkgs; [
    rust-analyzer
    cargo-nextest
    cargo-llvm-cov  # Code coverage
  ];

  shellHook = ''
    echo "🦀 Rust development environment loaded"
    echo "Rust version: ${rustPkgs.rustVersion}"

    # Set up environment
    export RUST_BACKTRACE=1
    export RUST_LOG=debug

    # Aliases
    alias t='cargo nextest run'
    alias b='cargo build'
    alias r='cargo run'
    alias c='cargo check'

    # Display workspace info
    echo ""
    echo "Workspace members:"
    cargo metadata --no-deps | jq -r '.workspace_members[]'
  '';
};
```

### Shell with Database

```nix
devShells.default = rustPkgs.workspaceShell {
  packages = with pkgs; [
    rust-analyzer
    postgresql_15
    diesel-cli
  ];

  shellHook = ''
    # Set up PostgreSQL
    export PGDATA="$PWD/.pgdata"
    export DATABASE_URL="postgresql://localhost/myapp_dev"

    if [ ! -d "$PGDATA" ]; then
      echo "Initializing PostgreSQL database..."
      initdb --no-locale --encoding=UTF8
      echo "unix_socket_directories = '$PWD/.pgdata'" >> "$PGDATA/postgresql.conf"
      pg_ctl start -l "$PGDATA/server.log"
      psql -d postgres -c "CREATE DATABASE myapp_dev;"
    else
      pg_ctl start -l "$PGDATA/server.log"
    fi

    echo "Database ready at $DATABASE_URL"
  '';
};
```

## Debugging Builds

### Isolated Build Environment

Enter the exact build environment cargo2nix uses:

```bash
# Get derivation path
nix build --print-out-paths .#myapp

# Enter isolated build environment
nix develop --ignore-environment /nix/store/...-myapp-0.1.0

# Inside, run build hooks
runHook preConfigure
runHook configureCargo
runHook runCargo
```

### Common Debug Commands

```bash
# Check what Cargo.nix was generated from
head -n 20 Cargo.nix

# Verify Cargo.lock hash matches
nix eval .#rustPkgs.workspace.myapp.cargoLockHash

# Inspect package set
nix repl
> :lf .
> rustPkgs.workspace
> rustPkgs."registry+https://github.com/rust-lang/crates.io-index".serde

# Build with verbose output
nix build -L  # Show build logs
nix log .#myapp  # View previous build log
```

### Debugging Overrides

```nix
# Add debug output to overrides
packageOverrides = pkgs: [
  (pkgs.rustBuilder.rustLib.makeOverride {
    name = "problematic-crate";
    overrideAttrs = drv: {
      # Print all environment variables
      preBuild = ''
        echo "=== Build Environment ==="
        env | sort
        echo "=== Build Inputs ==="
        echo "nativeBuildInputs: $nativeBuildInputs"
        echo "buildInputs: $buildInputs"
      '';
    };
  })
];
```

## Troubleshooting

### 1. Cargo.lock Needs Update

**Problem**: Error: "Cargo.lock needs to be updated but --locked was passed"

**Solution**:

```bash
# Update Cargo.lock
cargo update

# Regenerate Cargo.nix
nix run github:cargo2nix/cargo2nix

# Commit both files
git add Cargo.lock Cargo.nix
git commit -m "Update dependencies"
```

### 2. Hash Mismatch

**Problem**: Cargo.nix hash doesn't match Cargo.lock

**Temporary Workaround**:

```nix
rustPkgs = pkgs.rustBuilder.makePackageSet {
  rustVersion = "1.75.0";
  packageFun = import ./Cargo.nix;

  # Disable hash check (NOT RECOMMENDED for production)
  ignoreLockHash = true;
};
```

**Proper Solution**:

```bash
# Regenerate Cargo.nix from current Cargo.lock
nix run github:cargo2nix/cargo2nix
```

### 3. System Dependencies Missing

**Problem**: build.rs fails with "library not found"

**Solution**: Add package override

```nix
packageOverrides = pkgs: pkgs.rustBuilder.overrides.all ++ [
  (pkgs.rustBuilder.rustLib.makeOverride {
    name = "failing-crate-sys";
    overrideAttrs = drv: {
      propagatedBuildInputs = drv.propagatedBuildInputs or [] ++ [
        pkgs.the-missing-library
        pkgs.pkg-config
      ];
    };
  })
];
```

### 4. Git Dependencies with Private Repos

**Problem**: Can't fetch private git dependencies

**Solution**:

```nix
# Use builtins.fetchGit with SSH
packageOverrides = pkgs: [
  (pkgs.rustBuilder.rustLib.makeOverride {
    name = "private-crate";
    overrideAttrs = drv: {
      src = builtins.fetchGit {
        url = "git@github.com:org/private-repo.git";
        ref = "main";
        rev = "abc123...";
      };
    };
  })
];
```

**Note**: Cannot use with `--restrict-eval`

### 5. Non-Deterministic Builds

**Problem**: Binary output differs between builds

**Solution**:

```nix
rustPkgs.workspace.myapp {
  # Prefer local build (don't use binary cache)
  preferLocalBuild = true;
}
```

### 6. TOML Parsing Errors

**Problem**: Complex `cfg()` attributes fail to parse

**Solution**: Use newer cargo2nix version

```nix
cargo2nix.url = "github:cargo2nix/cargo2nix/release-0.12";
```

### 7. Rust Version Not Available

**Problem**: Specific Rust version not in nixpkgs

**Solution**: Use rust-overlay

```nix
{
  inputs = {
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { nixpkgs, rust-overlay, cargo2nix, ... }:
    let
      pkgs = import nixpkgs {
        overlays = [
          rust-overlay.overlays.default
          cargo2nix.overlays.default
        ];
      };

      rustPkgs = pkgs.rustBuilder.makePackageSet {
        # Use rust-overlay for any version
        rustToolchain = pkgs.rust-bin.stable."1.75.0".default;
        packageFun = import ./Cargo.nix;
      };
    in { ... };
}
```

### 8. Build Performance Issues

**Problem**: Slow builds in CI/CD

**Solutions**:

```nix
# 1. Use binary cache
nix.settings = {
  substituters = [ "https://cache.nixos.org" ];
  trusted-public-keys = [ "cache.nixos.org-1:..." ];
};

# 2. Enable distributed builds
nix.distributedBuilds = true;
nix.buildMachines = [ ... ];

# 3. Optimize build cores
nix.settings = {
  max-jobs = "auto";
  cores = 0;  # Use all cores
};
```

## Golden Path: Best Practices

### 1. ✅ Always Commit Cargo.nix

**Do**: Version control the generated file

```bash
git add Cargo.nix
git commit -m "Add/update Cargo.nix"
```

**Why**: Essential for reproducible builds, team collaboration

### 2. ✅ Pin cargo2nix Version

**Do**: Use specific release branch

```nix
cargo2nix.url = "github:cargo2nix/cargo2nix/release-0.12";
```

**Why**: Avoid breaking changes, ensure stability

### 3. ✅ Use Common Overrides First

**Do**: Start with built-in overrides

```nix
packageOverrides = pkgs: pkgs.rustBuilder.overrides.all ++ [
  # Your custom overrides
];
```

**Why**: Handles 90% of common system dependencies

### 4. ✅ Regenerate After Cargo.lock Changes

**Do**: Update Cargo.nix when dependencies change

```bash
cargo update
nix run github:cargo2nix/cargo2nix
git add Cargo.lock Cargo.nix
```

**Why**: Keeps Nix expressions in sync with Cargo

### 5. ✅ Use workspaceShell for Development

**Do**: Leverage generated dev shell

```nix
devShells.default = rustPkgs.workspaceShell {
  packages = [ pkgs.rust-analyzer ];
};
```

**Why**: Automatically includes all dependencies

### 6. ✅ Test Cross-Compilation Early

**Do**: Add cross-compile targets in CI

```nix
packages = {
  default = rustPkgs.workspace.myapp {};
  static = mkApp "x86_64-unknown-linux-musl";
};
```

**Why**: Catch platform issues before release

### 7. ✅ Document Custom Overrides

**Do**: Add comments explaining why overrides exist

```nix
packageOverrides = pkgs: [
  # Required for OpenSSL 3.0 compatibility
  (pkgs.rustBuilder.rustLib.makeOverride {
    name = "openssl-sys";
    # ...
  })
];
```

**Why**: Future maintainers understand decisions

### 8. ✅ Use Flake Lock for Reproducibility

**Do**: Commit flake.lock

```bash
git add flake.lock
git commit -m "Lock dependencies"
```

**Why**: Ensures identical builds across machines

### 9. ✅ Separate Dev Dependencies

**Do**: Use dev-dependencies in Cargo.toml

```toml
[dev-dependencies]
criterion = "0.5"  # Benchmarking
proptest = "1.4"   # Property testing
```

**Why**: Production builds exclude dev dependencies

### 10. ✅ Validate Builds in CI

**Do**: Test nix builds in CI pipeline

```yaml
- name: Build with Nix
  run: nix build -L
- name: Run tests
  run: nix develop -c cargo test
```

**Why**: Catch Nix-specific issues early

## Anti-Patterns: What to Avoid

### 1. ❌ Forgetting to Regenerate Cargo.nix

**Don't**: Update Cargo.lock without updating Cargo.nix

```bash
# Bad
cargo update
git add Cargo.lock
git commit  # Missing Cargo.nix update!
```

**Why**: Builds will fail with hash mismatches

**Do Instead**:

```bash
cargo update
nix run github:cargo2nix/cargo2nix
git add Cargo.lock Cargo.nix
```

### 2. ❌ Using ignoreLockHash in Production

**Don't**: Disable hash verification

```nix
# Bad: Disables safety checks
rustPkgs = pkgs.rustBuilder.makePackageSet {
  ignoreLockHash = true;
};
```

**Why**: Loses reproducibility guarantees

**Do Instead**: Fix root cause (regenerate Cargo.nix)

### 3. ❌ Not Pinning cargo2nix Version

**Don't**: Use floating reference

```nix
# Bad: Could break unexpectedly
cargo2nix.url = "github:cargo2nix/cargo2nix";
```

**Why**: Unstable, breaking changes

**Do Instead**: Pin to release branch

```nix
cargo2nix.url = "github:cargo2nix/cargo2nix/release-0.12";
```

### 4. ❌ Overriding Everything Manually

**Don't**: Ignore existing overrides

```nix
# Bad: Reinventing the wheel
packageOverrides = pkgs: [
  # Manually writing openssl-sys override...
];
```

**Why**: Duplicates work, misses updates

**Do Instead**: Use `pkgs.rustBuilder.overrides.all`

### 5. ❌ Committing Build Artifacts

**Don't**: Track result symlinks

```bash
# Bad
git add result
```

**Why**: Not reproducible, wastes space

**Do Instead**: Add to `.gitignore`

```gitignore
result
result-*
```

### 6. ❌ Mixing rustup and Nix

**Don't**: Use rustup inside nix shell

```bash
# Bad: In nix develop
rustup install nightly
```

**Why**: Defeats Nix reproducibility

**Do Instead**: Use cargo2nix's rustVersion/rustToolchain

### 7. ❌ Hardcoding Paths

**Don't**: Use absolute paths in overrides

```nix
# Bad: Not portable
LIBCLANG_PATH = "/usr/lib/llvm-15/lib";
```

**Why**: Breaks on other systems

**Do Instead**: Use Nix packages

```nix
LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
```

### 8. ❌ Skipping Tests in CI

**Don't**: Only build, never test

```yaml
# Bad: No testing
- run: nix build
```

**Why**: Misses test failures

**Do Instead**: Run tests in Nix environment

```yaml
- run: nix develop -c cargo test
```

### 9. ❌ Using --impure Unnecessarily

**Don't**: Rely on impure evaluation

```bash
# Bad: Breaks reproducibility
nix build --impure
```

**Why**: Not reproducible, defeats Nix purpose

**Do Instead**: Fix evaluation to be pure

### 10. ❌ Ignoring Build Warnings

**Don't**: Suppress or ignore warnings

```nix
# Bad: Hiding problems
RUSTFLAGS = "-A warnings"
```

**Why**: Masks real issues

**Do Instead**: Fix warnings, use deny in CI

```nix
RUSTFLAGS = "-D warnings"  # Deny warnings
```

## Complete Examples

### Example 1: Simple CLI Tool

**Project Structure**:

```
my-cli/
├── Cargo.toml
├── Cargo.lock
├── Cargo.nix          # Generated
├── flake.nix
├── flake.lock
└── src/
    └── main.rs
```

**Cargo.toml**:

```toml
[package]
name = "my-cli"
version = "0.1.0"
edition = "2021"

[dependencies]
clap = { version = "4.4", features = ["derive"] }
serde = { version = "1.0", features = ["derive"] }
```

**flake.nix**:

```nix
{
  description = "My CLI tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cargo2nix.url = "github:cargo2nix/cargo2nix/release-0.12";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, cargo2nix, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ cargo2nix.overlays.default ];
        };

        rustPkgs = pkgs.rustBuilder.makePackageSet {
          rustVersion = "1.75.0";
          packageFun = import ./Cargo.nix;
        };

      in {
        packages = {
          my-cli = rustPkgs.workspace.my-cli {};
          default = self.packages.${system}.my-cli;
        };

        devShells.default = rustPkgs.workspaceShell {
          packages = with pkgs; [ rust-analyzer ];
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.my-cli}/bin/my-cli";
        };
      }
    );
}
```

**Usage**:

```bash
# Generate Cargo.nix
nix run github:cargo2nix/cargo2nix
git add Cargo.nix

# Build
nix build

# Run
nix run

# Development
nix develop
cargo run -- --help
```

### Example 2: Workspace with Multiple Binaries

**Project Structure**:

```
my-workspace/
├── Cargo.toml         # Workspace root
├── Cargo.lock
├── Cargo.nix          # Generated
├── flake.nix
├── crates/
│   ├── server/
│   │   ├── Cargo.toml
│   │   └── src/main.rs
│   ├── client/
│   │   ├── Cargo.toml
│   │   └── src/main.rs
│   └── common/
│       ├── Cargo.toml
│       └── src/lib.rs
└── flake.lock
```

**flake.nix**:

```nix
{
  description = "My multi-binary workspace";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cargo2nix.url = "github:cargo2nix/cargo2nix/release-0.12";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, cargo2nix, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ cargo2nix.overlays.default ];
        };

        rustPkgs = pkgs.rustBuilder.makePackageSet {
          rustVersion = "1.75.0";
          packageFun = import ./Cargo.nix;
          rootFeatures = [
            "server/default"
            "client/default"
            "common/default"
          ];
        };

      in {
        packages = {
          server = rustPkgs.workspace.server {};
          client = rustPkgs.workspace.client {};
          common = rustPkgs.workspace.common {};

          default = self.packages.${system}.server;

          # Bundle both binaries
          all = pkgs.symlinkJoin {
            name = "my-workspace-all";
            paths = [
              self.packages.${system}.server
              self.packages.${system}.client
            ];
          };
        };

        devShells.default = rustPkgs.workspaceShell {
          packages = with pkgs; [
            rust-analyzer
            cargo-nextest
            cargo-watch
          ];
        };

        apps = {
          server = {
            type = "app";
            program = "${self.packages.${system}.server}/bin/server";
          };
          client = {
            type = "app";
            program = "${self.packages.${system}.client}/bin/client";
          };
        };
      }
    );
}
```

### Example 3: With System Dependencies

**flake.nix** (PostgreSQL + OpenSSL):

```nix
{
  outputs = { self, nixpkgs, cargo2nix, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ cargo2nix.overlays.default ];
        };

        rustPkgs = pkgs.rustBuilder.makePackageSet {
          rustVersion = "1.75.0";
          packageFun = import ./Cargo.nix;

          # System dependency overrides
          packageOverrides = pkgs: pkgs.rustBuilder.overrides.all ++ [
            # PostgreSQL native library
            (pkgs.rustBuilder.rustLib.makeOverride {
              name = "pq-sys";
              overrideAttrs = drv: {
                propagatedBuildInputs = drv.propagatedBuildInputs or [] ++ [
                  pkgs.postgresql
                ];
              };
            })

            # OpenSSL
            (pkgs.rustBuilder.rustLib.makeOverride {
              name = "openssl-sys";
              overrideAttrs = drv: {
                propagatedBuildInputs = drv.propagatedBuildInputs or [] ++ [
                  pkgs.openssl
                  pkgs.pkg-config
                ];
              };
            })
          ];
        };

      in {
        packages.default = rustPkgs.workspace.myapp {};

        devShells.default = rustPkgs.workspaceShell {
          packages = with pkgs; [
            rust-analyzer
            postgresql_15
            diesel-cli
          ];

          shellHook = ''
            export DATABASE_URL="postgresql://localhost/myapp_dev"
            echo "Database: $DATABASE_URL"
          '';
        };
      }
    );
}
```

## Resources and References

### Official Documentation

- [cargo2nix GitHub](https://github.com/cargo2nix/cargo2nix)
- [cargo2nix Releases](https://github.com/cargo2nix/cargo2nix/releases)
- [NixOS Wiki - Rust](https://nixos.wiki/wiki/Rust)

### Related Tools

- [crane](https://github.com/ipetkov/crane) - Modern Cargo-driven approach
- [crate2nix](https://github.com/nix-community/crate2nix) - Alternative per-crate tool
- [naersk](https://github.com/nix-community/naersk) - Dynamic Cargo.lock import
- [rust-overlay](https://github.com/oxalica/rust-overlay) - Rust toolchain versions

### Community Resources

- [NixOS Discourse - Rust](https://discourse.nixos.org/c/learn/56)
- [Rust Nix Comparison (2025)](https://devenv.sh/blog/2025/08/22/closing-the-nix-gap-from-environments-to-packaged-applications-for-rust/)
- [Building Nix Flakes from Rust Workspaces](https://www.tweag.io/blog/2022-09-22-rust-nix/)

### Learning Resources

- [How to Package a Rust App Using Nix](https://dev.to/misterio/how-to-package-a-rust-app-using-nix-3lh3)
- [Compiling Rust Projects with Nix](https://www.sobyte.net/post/2022-08/rust-nix/)
- [A Flake for Your Crate](https://hoverbear.org/blog/a-flake-for-your-crate/)

---

**Remember**: cargo2nix provides fine-grained per-crate builds at the cost of maintaining Cargo.nix. For simpler projects, consider buildRustPackage or crane. For maximum caching and shared dependencies across projects, cargo2nix is the right choice.
