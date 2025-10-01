# Installing GitHub spec-kit on NixOS with uv2nix

**uv2nix brings Python 3.11+ spec-kit to NixOS through a modern packaging approach that combines uv's fast dependency resolution with Nix's reproducibility guarantees.** This guide walks through installing GitHub's Spec-Driven Development toolkit using the next-generation Python packaging toolchain. The process requires understanding uv2nix's overlay-based architecture and adapting it for Git-sourced packages that aren't on PyPI. By the end, you'll have spec-kit's AI-powered development CLI running reproducibly on NixOS with all dependencies properly managed.

## Understanding uv2nix: Modern Python packaging for Nix

uv2nix translates uv workspaces and lock files into Nix derivations using pure Nix code, serving as both a development environment manager and production package builder. The tool represents the next generation of Python-Nix integration, explicitly designed as the successor to poetry2nix by the same author (@adisbladis). Unlike its predecessor, **uv2nix generates Nix overlays dynamically** from `uv.lock` files rather than requiring manual package definitions, leveraging uv's Rust-based speed for dependency resolution while adding Nix's reproducibility for deployment.

The architecture centers on three key operations: parsing `pyproject.toml` and `uv.lock` files from a workspace, generating Nix overlays containing package derivations, and aggregating packages into virtual environments. uv2nix heavily relies on pyproject.nix's build infrastructure and doesn't attempt to replace what uv already does well—dependency resolution and lock file generation remain uv's responsibility. The tool recently shed its "experimental" label, indicating API stability for core features.

**The overlay pattern is fundamental to how uv2nix works.** Rather than building a monolithic package set, uv2nix creates composable overlays that you stack together. A typical stack includes the build-systems overlay (providing setuptools, hatchling, etc.), the uv2nix-generated overlay (your locked dependencies), and custom overrides (build fixes). This design shifts responsibility for package overrides away from bundled definitions that suffer bit-rot, giving users explicit control over their build pipeline.

One critical limitation: **uv doesn't lock build systems in uv.lock**, a known issue tracked in uv #5190. Building packages from source requires build systems like setuptools or hatchling, but these aren't captured in the lock file. uv2nix addresses this through the pyproject-build-systems repository, which provides overlays containing common build tools. This workaround is necessary but adds an extra input to your flake.

## Prerequisites and initial setup

**Minimum requirements for using uv2nix:**

**System requirements:**
- NixOS or Nix with flakes enabled
- Python 3.11 or newer (required by spec-kit)
- Git (optional but recommended for repository operations)
- Network access (for downloading Python packages and GitHub templates)

**Required flake inputs:** Every uv2nix project needs four interconnected inputs that must follow the same nixpkgs to prevent version conflicts:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  
  pyproject-nix = {
    url = "github:pyproject-nix/pyproject.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  
  uv2nix = {
    url = "github:pyproject-nix/uv2nix";
    inputs.pyproject-nix.follows = "pyproject-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  
  pyproject-build-systems = {
    url = "github:pyproject-nix/build-system-pkgs";
    inputs.pyproject-nix.follows = "pyproject-nix";
    inputs.uv2nix.follows = "uv2nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

The `follows` declarations ensure all inputs use the same nixpkgs version, preventing incompatibilities from mixing package sets. This pattern is mandatory for stability.

**Initial project structure:** For most projects, you'd start with `uv init --app --package` to create a standard structure, but for spec-kit we're packaging an existing GitHub project. The tool expects at minimum a `pyproject.toml` defining project metadata and a `uv.lock` file with pinned dependencies. Since spec-kit comes from GitHub rather than a local workspace, we'll need to fetch it first and generate the lock file.

**Quick start with templates:** uv2nix provides templates to bootstrap projects quickly:

```bash
# Basic production template
nix flake init --template github:pyproject-nix/uv2nix#hello-world

# Development-only impure template (uses uv to manage venv)
nix flake init --template github:pyproject-nix/pyproject.nix#impure
```

These templates provide working examples of the overlay composition pattern and proper environment variable configuration.

## Installing spec-kit: Git-based package workflow

spec-kit presents unique packaging challenges: it's **not published to PyPI** (per issue #204 in their repository), requires installation from GitHub, and downloads AI agent templates from GitHub at runtime. The standard uv2nix workflow assumes PyPI packages, so we must adapt the approach for Git-sourced dependencies.

### Step 1: Fetch spec-kit and prepare the workspace

First, fetch spec-kit locally to examine its structure and generate a lock file:

```bash
# Clone spec-kit repository
git clone https://github.com/github/spec-kit.git
cd spec-kit

# Install uv if not already available
nix-shell -p uv python311

# Generate uv.lock file
uv lock
```

This creates `uv.lock` with pinned versions of spec-kit's dependencies: **typer** (CLI framework), **rich** (terminal formatting), **platformdirs** (cross-platform paths), **readchar** (keyboard input), and **httpx** (HTTP client). All are pure Python packages from PyPI with no C extensions, making them straightforward to package.

**Key spec-kit characteristics:**
- Package name: `specify-cli` (not `spec-kit`)
- Version: 0.0.17
- Python requirement: >=3.11
- Build backend: Modern pyproject.toml with likely hatchling
- No workspace structure: single package project
- Runtime behavior: Downloads templates from GitHub API at runtime

### Step 2: Create flake.nix for spec-kit

Create a `flake.nix` in the spec-kit directory with the complete packaging definition:

```nix
{
  description = "GitHub spec-kit packaged with uv2nix for NixOS";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  
  outputs = { self, nixpkgs, uv2nix, pyproject-nix, pyproject-build-systems, ... }:
  let
    inherit (nixpkgs) lib;
    
    # Define supported system
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    
    # Use Python 3.11 (minimum required by spec-kit)
    python = pkgs.python311;
    
    # Load the workspace (spec-kit's pyproject.toml and uv.lock)
    workspace = uv2nix.lib.workspace.loadWorkspace { 
      workspaceRoot = ./.; 
    };
    
    # Generate overlay from uv.lock
    # Prefer wheels over source distributions for better compatibility
    overlay = workspace.mkPyprojectOverlay {
      sourcePreference = "wheel";
    };
    
    # Custom overrides for build fixes
    pyprojectOverrides = final: prev: {
      # spec-kit specific overrides if needed
      # All dependencies are pure Python, should work without fixes
      
      # If building from source, may need to ensure build systems
      # Example pattern (likely not needed for spec-kit):
      # specify-cli = prev.specify-cli.overrideAttrs (old: {
      #   nativeBuildInputs = old.nativeBuildInputs ++ 
      #     final.resolveBuildSystem { hatchling = []; };
      # });
    };
    
    # Create Python base set with build infrastructure
    pythonBase = pkgs.callPackage pyproject-nix.build.packages {
      inherit python;
    };
    
    # Compose final Python package set with overlays
    pythonSet = pythonBase.overrideScope (
      lib.composeManyExtensions [
        # Provide common build systems (setuptools, hatchling, etc.)
        pyproject-build-systems.overlays.default
        # Add packages from uv.lock
        overlay
        # Apply custom build fixes
        pyprojectOverrides
      ]
    );
    
    # Create virtual environment with spec-kit and dependencies
    # Package name MUST match [project.name] in pyproject.toml
    specKitEnv = pythonSet.mkVirtualEnv "specify-cli-env" {
      specify-cli = [];  # No extras needed
    };
    
  in {
    # Production package
    packages.${system}.default = specKitEnv;
    
    # Convenience wrapper for the specify command
    packages.${system}.specify-cli = pkgs.writeShellScriptBin "specify" ''
      exec ${specKitEnv}/bin/specify "$@"
    '';
    
    # Development shell with uv and the built environment
    devShells.${system}.default = pkgs.mkShell {
      packages = [
        python
        pkgs.uv
        pkgs.git  # spec-kit uses git for repository initialization
        specKitEnv
      ];
      
      env = {
        # Prevent uv from downloading managed Python interpreters
        UV_PYTHON_DOWNLOADS = "never";
        # Use Nix-provided Python
        UV_PYTHON = "${python}/bin/python";
      };
      
      shellHook = ''
        # Unset PYTHONPATH to avoid Nixpkgs builder contamination
        unset PYTHONPATH
        
        echo "spec-kit development environment"
        echo "Run 'specify --help' to get started"
      '';
    };
    
    # Alternative: Impure development shell (simpler, uses uv-managed venv)
    devShells.${system}.impure = pkgs.mkShell {
      packages = [ 
        python 
        pkgs.uv 
        pkgs.git
      ];
      
      env = {
        UV_PYTHON_DOWNLOADS = "never";
        UV_PYTHON = "${python}/bin/python";
      };
      
      shellHook = ''
        unset PYTHONPATH
        
        # Let uv manage the virtual environment
        echo "Impure development mode"
        echo "Run: uv venv && source .venv/bin/activate"
        echo "Then: uv pip install -e ."
      '';
    };
  };
}
```

### Step 3: Build and install spec-kit

With the flake defined, build and test spec-kit:

```bash
# Build the package (creates virtual environment with all dependencies)
nix build

# Test the built package
./result/bin/specify --help

# Run directly
nix run . -- --help

# Install to user profile
nix profile install .

# Or add to system configuration (configuration.nix)
# environment.systemPackages = [ 
#   (inputs.spec-kit.packages.${system}.default) 
# ];
```

The build process:
1. uv2nix loads workspace metadata from `pyproject.toml` and `uv.lock`
2. Generates Nix derivations for each dependency (typer, rich, platformdirs, readchar, httpx)
3. Applies the build-systems overlay to provide setuptools/hatchling
4. Builds each package as a Nix derivation with reproducible hashes
5. Aggregates everything into a virtual environment
6. Exposes the `specify` command as the entry point

### Step 4: Enter development environment

For active development on spec-kit or projects using it:

```bash
# Enter the development shell
nix develop

# spec-kit commands are now available
specify init my-project --ai copilot
specify check
```

The development shell provides **spec-kit plus uv, git, and Python 3.11**, with environment variables configured to prevent uv from downloading managed interpreters or interfering with the Nix-managed environment.

## Configuration files explained

### pyproject.toml structure

spec-kit's `pyproject.toml` follows modern Python packaging standards (PEP 621):

```toml
[project]
name = "specify-cli"  # CRITICAL: This exact name must be used in Nix
version = "0.0.17"
description = "Specify CLI, part of GitHub Spec Kit."
requires-python = ">=3.11"
dependencies = [
  "typer",
  "rich", 
  "platformdirs",
  "readchar",
  "httpx",
]

[project.scripts]
specify = "specify_cli:main"  # Entry point for the CLI

[build-system]
requires = ["hatchling"]  # or setuptools
build-backend = "hatchling.build"
```

**Key points:**
- The `name` field must exactly match references in Nix expressions
- `requires-python` sets minimum Python version (3.11)
- `dependencies` lists runtime requirements (all from PyPI)
- `project.scripts` defines console commands
- `build-system` specifies what builds the package

### uv.lock structure

Generated by `uv lock`, this file contains:
- **Exact dependency versions** with cryptographic hashes
- **Resolved dependency tree** including transitive dependencies  
- **Source locations** (PyPI URLs, Git repos, file paths)
- **Platform markers** for conditional dependencies
- **Integrity hashes** for reproducible builds

uv2nix parses this file to generate Nix derivations. The lock file ensures identical dependencies across all environments, but **doesn't capture build systems**—hence the need for pyproject-build-systems overlay.

### Critical Nix expressions

**Workspace loading:**
```nix
workspace = uv2nix.lib.workspace.loadWorkspace { 
  workspaceRoot = ./.; 
};
```
Recursively discovers projects, parses all `pyproject.toml` files, loads `uv.lock`, and creates a workspace object with metadata and dependency specifications.

**Overlay generation:**
```nix
overlay = workspace.mkPyprojectOverlay {
  sourcePreference = "wheel";  # Prefer binary wheels over source
};
```
Translates `uv.lock` into a Nix overlay function that adds Python packages to the package set. Choosing `"wheel"` makes builds more likely to succeed without manual intervention.

**Package set composition:**
```nix
pythonSet = pythonBase.overrideScope (
  lib.composeManyExtensions [
    pyproject-build-systems.overlays.default  # Build tools
    overlay                                    # Locked dependencies
    pyprojectOverrides                         # Custom fixes
  ]
);
```
Stacks overlays in order: base build infrastructure, then locked packages, then custom overrides. Later overlays can modify packages from earlier ones.

**Virtual environment creation:**
```nix
pythonSet.mkVirtualEnv "specify-cli-env" {
  specify-cli = [];  # Include specify-cli with no optional extras
}
```
Aggregates the package and its dependencies into a virtual environment. The key `specify-cli` must match the package name in `pyproject.toml` exactly.

## Common pitfalls and troubleshooting

### Missing build systems cause failures

**Problem:** Building from source fails with errors about missing setuptools, hatchling, or other build tools. This occurs because uv.lock doesn't capture build-time dependencies.

**Solution:** Always include the build-systems overlay in your composition:

```nix
lib.composeManyExtensions [
  pyproject-build-systems.overlays.default  # This provides build tools
  overlay
  pyprojectOverrides
]
```

For spec-kit's dependencies, this shouldn't be an issue since we're using `sourcePreference = "wheel"` and all dependencies have wheels available. If you switch to building from source (`sourcePreference = "sdist"`), you may need to add explicit build system overrides:

```nix
pyprojectOverrides = final: prev: {
  typer = prev.typer.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ 
      final.resolveBuildSystem { 
        hatchling = []; 
        hatch-vcs = []; 
      };
  });
};
```

### Package name mismatches break builds

**Problem:** Error "attribute 'spec-kit' missing" or similar when trying to reference the package.

**Solution:** The package name in Nix **must exactly match** `[project.name]` in `pyproject.toml`. For spec-kit, the project name is `specify-cli`, not `spec-kit`:

```nix
# WRONG - will fail
pythonSet.spec-kit

# CORRECT - matches pyproject.toml
pythonSet.specify-cli
```

Check `pyproject.toml` for the exact name. Python package naming uses hyphens, not underscores, in distribution names.

### PYTHONPATH contamination causes import errors

**Problem:** Packages import incorrectly or fail to find dependencies, especially in development shells.

**Solution:** Always unset PYTHONPATH in shell hooks to prevent Nixpkgs Python builders from leaking environment variables:

```nix
shellHook = ''
  unset PYTHONPATH
'';
```

This is a known issue with Nixpkgs Python infrastructure that affects all uv2nix projects.

### Dynamically linked executables fail on NixOS

**Problem:** Error "cannot run dynamically linked executables" when uv tries to download managed Python interpreters.

**Solution:** Prevent uv from managing Python by setting environment variables:

```nix
env = {
  UV_PYTHON_DOWNLOADS = "never";  # Disable Python downloads
  UV_PYTHON = "${python}/bin/python";  # Use Nix Python
};
```

NixOS cannot run dynamically linked executables without proper loader configuration. Always use Nix-provided Python interpreters instead of uv-managed ones.

### Runtime template downloads require network access

**Problem specific to spec-kit:** The CLI downloads AI agent templates from GitHub at runtime, which may fail in pure Nix builds or restricted networks.

**Considerations:**
- Development shells need network access for `specify init` to download templates
- If packaging for pure offline use, you'd need to pre-fetch templates and patch URLs
- For most use cases, allowing network access in the development shell is acceptable

**Pattern for offline use (advanced):**
```nix
# Pre-fetch templates as fixed-output derivations
templates = pkgs.fetchFromGitHub {
  owner = "github";
  repo = "spec-kit";
  # ... specify release and hash
};

# Patch spec-kit to use local templates
specify-cli = prev.specify-cli.overrideAttrs (old: {
  postPatch = ''
    substituteInPlace src/specify_cli/__init__.py \
      --replace 'https://api.github.com/repos/github/spec-kit/releases' \
                '${templates}'
  '';
});
```

This level of patching is usually unnecessary unless you're deploying spec-kit in a completely offline environment.

### Wheel vs source distribution confusion

**Problem:** Some packages fail to build or have missing dependencies depending on source preference.

**Best practice:** Prefer `sourcePreference = "wheel"` for production. Binary wheels are prebuilt and contain all necessary metadata. Source distributions require more overrides and are more prone to failures.

**When to use sdist:**
- Package has no wheel for your platform
- You need to apply patches to source code
- Building from source for security auditing

For spec-kit and its dependencies, wheels are available for all packages on all common platforms, so stick with wheel preference.

### Lock file format changes

**Problem:** Errors about unrecognized lock file fields like `required-markers` indicate version mismatches between uv and uv2nix.

**Solution:** Keep uv and uv2nix versions aligned. If you encounter lock file format issues:

1. Check uv2nix GitHub issues for known incompatibilities
2. Try updating uv2nix to the latest version
3. Or downgrade uv if needed for compatibility
4. Regenerate `uv.lock` after version adjustments

The tooling is actively evolving, so occasional format changes are expected.

### Editable installs for local development

**Problem:** Changes to spec-kit source code don't take effect without rebuilds.

**Solution:** Use editable overlays for development (though note this is marked unstable in uv2nix):

```nix
editableOverlay = workspace.mkEditablePyprojectOverlay {
  root = "$REPO_ROOT";
  members = [ "specify-cli" ];
};

editablePythonSet = pythonSet.overrideScope editableOverlay;

devShell = pkgs.mkShell {
  packages = [ 
    (editablePythonSet.mkVirtualEnv "dev-env" workspace.deps.all)
  ];
  shellHook = ''
    export REPO_ROOT=$(git rev-parse --show-toplevel)
    unset PYTHONPATH
  '';
};
```

This installs packages as pointers to source trees rather than copying files, allowing immediate change activation. However, **consider using the impure development shell instead**—it's simpler and lets uv manage editable installs directly.

## Alternative approach: System-wide installation

For installing spec-kit globally on NixOS rather than per-project:

### Method 1: NixOS configuration

Add to `/etc/nixos/configuration.nix`:

```nix
{ config, pkgs, ... }:

let
  spec-kit = pkgs.callPackage /path/to/spec-kit-flake { };
in {
  environment.systemPackages = [
    spec-kit.packages.x86_64-linux.specify-cli
  ];
}
```

Then rebuild: `sudo nixos-rebuild switch`

### Method 2: User profile installation

```bash
# From the spec-kit directory with flake.nix
nix profile install .

# Or directly from a flake output
nix profile install /path/to/spec-kit#specify-cli
```

This installs spec-kit into your user profile, making the `specify` command available system-wide without modifying NixOS configuration.

### Method 3: Home Manager integration

For home-manager users:

```nix
{ config, pkgs, ... }:

{
  home.packages = [
    (import /path/to/spec-kit-flake).packages.x86_64-linux.specify-cli
  ];
}
```

Then activate: `home-manager switch`

## Comparison with uv tool install

**Standard uv approach:**
```bash
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
```

This is simpler but lacks Nix's reproducibility guarantees. The uv2nix approach provides:

- **Pinned nixpkgs versions:** All dependencies come from a specific nixpkgs revision
- **Declarative specification:** Your flake.nix fully describes the environment
- **Integration with NixOS:** Can include in system or home-manager configurations  
- **Reproducible across machines:** `flake.lock` ensures identical builds everywhere
- **Development environment consistency:** Dev shells have exact production dependencies

**Trade-offs:** uv2nix adds complexity with flake.nix, overlays, and uv.lock management. For simple personal use, `uv tool install` may suffice. For team development, CI/CD, or production deployment on NixOS, the uv2nix approach provides stronger guarantees.

## Conclusion: Modern Python tooling meets Nix

Installing spec-kit with uv2nix demonstrates the power of next-generation Python packaging on NixOS. The process combines uv's fast dependency resolution with Nix's reproducibility through a composable overlay architecture. While the setup requires understanding workspace loading, overlay composition, and build system handling, the result is a fully reproducible spec-kit installation that integrates cleanly with NixOS system management.

**Key success factors:** Using Python 3.11+, preferring wheel sources over sdist, including the build-systems overlay, matching package names exactly, and unsetting PYTHONPATH. spec-kit's pure Python dependencies and modern pyproject.toml structure make it an ideal candidate for uv2nix packaging—no C extensions, no complex build requirements, just straightforward Python packages from PyPI.

The uv2nix approach scales beyond spec-kit to any Python project using modern packaging standards. As the recommended successor to poetry2nix, it represents the current state of the art for Python-Nix integration, with active development and API stability for core features. Whether developing locally or deploying to production, uv2nix provides the reproducible Python environments that NixOS users expect.