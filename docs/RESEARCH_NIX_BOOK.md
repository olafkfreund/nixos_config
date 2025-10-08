# Research Analysis: Nix Book Best Practices

> **Source**: <https://mhwombat.codeberg.page/nix-book/>
> **Research Date**: 2025-01-15
> **Purpose**: Extract learnings and apply to our NixOS configuration

## Executive Summary

Comprehensive analysis of the Nix Book by mhwombat, focusing on Nix language fundamentals, flake best practices, and common pitfalls. Key findings have been integrated into anti-pattern documentation and will guide future development.

### Key Takeaways

1. **Nix Language is Functional**: Immutable values, first-class functions, declarative approach
2. **Spacing Matters**: Operators without spaces cause type interpretation issues
3. **Type System is Strict**: No implicit conversions, use `toString` or `${}`
4. **Flakes Need Discipline**: Commit lockfiles, separate dependencies, clean git state
5. **Command Clarity Essential**: `develop`, `shell`, `run`, and `build` serve different purposes

---

## 1. Nix Language Fundamentals

### Core Principles

**Functional Programming Paradigm**:

- Values are immutable (no reassignment)
- Functions are first-class (can be passed, returned, assigned)
- Declarative approach (describe desired result, not steps)
- Pure functions (same input = same output)

### Data Types

| Type              | Example             | Notes                         |
| ----------------- | ------------------- | ----------------------------- |
| **String**        | `"hello"`           | Use `${}` for interpolation   |
| **Integer**       | `42`                | Division truncates to integer |
| **Float**         | `3.14`              | Requires decimal point        |
| **Boolean**       | `true`, `false`     | Lowercase only                |
| **Path**          | `./src/main.nix`    | Relative or absolute          |
| **List**          | `[ 1 2 3 ]`         | Space-separated, homogeneous  |
| **Attribute Set** | `{ a = 1; b = 2; }` | Key-value pairs               |
| **Function**      | `x: x + 1`          | Lambda syntax                 |

### Critical Language Rules

**1. Spacing Around Operators**

```nix
# ❌ WRONG - No spaces
6/2          # Interpreted as path <6/2>
x+y          # May work but inconsistent
./src/main   # Path interpretation

# ✅ CORRECT - With spaces
6 / 2        # Integer division = 3
x + y        # Clear addition
./src / main # Path with spaces
```

**Impact**: Unexpected type errors, hard-to-debug issues.

**2. Immutability**

```nix
# ❌ WRONG - Attempting mutation
let
  x = 1;
  x = 2;  # ERROR: attribute 'x' already defined
in x

# ✅ CORRECT - New bindings
let
  x = 1;
  y = x + 1;  # Create new binding
in y
```

**Impact**: Compilation errors, need to restructure code.

**3. Type Conversion**

```nix
# ❌ WRONG - Implicit conversion
"Port: " + 8080  # ERROR: cannot coerce integer to string

# ✅ CORRECT - Explicit conversion
"Port: ${toString 8080}"     # String interpolation
"Port: " + (toString 8080)   # Manual conversion
```

**Impact**: Type errors, build failures.

**4. Floating Point Arithmetic**

```nix
# ❌ WRONG - Integer division
5 / 2        # Result: 2 (truncated)

# ✅ CORRECT - Float division
5.0 / 2.0    # Result: 2.5
```

**Impact**: Incorrect calculations in performance tuning, resource allocation.

---

## 2. Flake Architecture Best Practices

### Standard Flake Structure

```nix
{
  # 1. Description (required)
  description = "Brief description of what this flake provides";

  # 2. Inputs (dependencies)
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  # 3. Outputs (what the flake produces)
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        # Packages (installable outputs)
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "mypackage";
          version = "1.0.0";
          src = ./.;
        };

        # Apps (executable outputs)
        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/myapp";
        };

        # Development shells
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            # Development-time tools only
            gcc
            gdb
            valgrind
          ];
        };
      }
    );

  # 4. nixConfig (optional, rarely used)
  nixConfig = {
    extra-substituters = [ "https://cache.nixos.org" ];
    extra-trusted-public-keys = [ "cache.nixos.org-1:..." ];
  };
}
```

### Flake Best Practices

**1. Input Management**

```nix
# ✅ GOOD - Simple, clear inputs
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";  # Avoid duplicate nixpkgs
  };
};

# ❌ AVOID - Overcomplicated inputs
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs?rev=abc123&ref=main&dir=subdir";
  # Too many follows, hard to maintain
  something = {
    url = "...";
    inputs.a.follows = "b";
    inputs.c.follows = "d";
    inputs.e.follows = "f";
  };
};
```

**Principles**:

- Keep input references simple
- Use `.follows` to avoid duplicate dependencies
- Only add complexity when necessary

**2. Lockfile Management**

```bash
# ✅ ALWAYS commit flake.lock
git add flake.lock
git commit -m "chore: Update flake.lock"

# ❌ NEVER ignore flake.lock
# .gitignore
flake.lock  # DON'T DO THIS!
```

**Why**: `flake.lock` ensures reproducible builds across machines and time.

**3. Multi-Platform Support**

```nix
# ✅ GOOD - Support multiple systems
outputs = { self, nixpkgs, flake-utils }:
  flake-utils.lib.eachDefaultSystem (system:
    let pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.default = /* ... */;
    }
  );

# ❌ AVOID - Hardcoded system
outputs = { self, nixpkgs }:
  let pkgs = nixpkgs.legacyPackages.x86_64-linux;  # Only one platform
  in {
    packages.x86_64-linux.default = /* ... */;
  };
```

**Benefits**: Works on x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin.

---

## 3. Development Workflows

### Understanding Nix Commands

| Command       | Purpose                  | Use Case                 | Shell Type  |
| ------------- | ------------------------ | ------------------------ | ----------- |
| `nix develop` | Enter dev environment    | Modifying package source | Development |
| `nix shell`   | Temporary package access | Trying packages          | Ephemeral   |
| `nix run`     | Build and execute        | Running applications     | Runtime     |
| `nix build`   | Build only (./result)    | Testing builds           | Build       |

### Workflow Patterns

**High-Level Workflow (Quick Iterations)**:

```bash
# 1. Make changes
vim src/main.hs

# 2. Rebuild and run in one command
nix run

# 3. See errors, fix issues
vim flake.nix

# 4. Repeat
nix run
```

**When to Use**: Rapid development, quick testing, simple changes.

**Low-Level Workflow (Detailed Control)**:

```bash
# 1. Enter development shell with tools
nix develop

# 2. Use language tools directly
cabal build
cabal test
cabal run

# 3. Debug with GDB if needed
gdb ./dist/build/myapp/myapp

# 4. Exit when done
exit
```

**When to Use**: Debugging, complex builds, need for specific tools.

---

## 4. Dependency Management

### Build vs Development Dependencies

**Critical Distinction**:

```nix
{
  # Runtime/build dependencies (end up in package closure)
  buildInputs = [
    openssl      # Runtime dependency
    zlib         # Runtime dependency
    curl         # Runtime dependency
  ];

  # Build-time tools (not in runtime closure)
  nativeBuildInputs = [
    pkg-config   # Build helper
    cmake        # Build system
    makeWrapper  # Packaging tool
  ];

  # Development shell (for developers only)
  devShells.default = pkgs.mkShell {
    packages = [
      gcc        # Compiler
      gdb        # Debugger
      valgrind   # Profiler
      # NOT in final package
    ];
  };
}
```

**Rules**:

1. **buildInputs**: Libraries and tools needed at runtime
2. **nativeBuildInputs**: Build-time tools (don't ship with package)
3. **devShells**: Development tools (never in package)

**Common Mistake**: Adding development tools to `buildInputs`, bloating package size.

---

## 5. Common Pitfalls and Solutions

### Pitfall 1: Git "Dirty" Tree

**Problem**:

```bash
$ nix build
warning: Git tree is dirty
error: file 'new-module.nix' not found
```

**Cause**: Flakes only see files tracked by Git.

**Solution**:

```bash
# Stage new files
git add new-module.nix

# Or commit
git commit -am "feat: Add new module"

# Then build
nix build
```

**Rule**: **Always stage files before building flakes**.

---

### Pitfall 2: Wrong Nix Command

**Problem**: Using `nix shell` when you need `nix develop`.

**Symptoms**:

- Development tools not available
- Can't modify package source
- Confusion about which environment you're in

**Solution**:

```bash
# Developing a package (modifying source)
nix develop

# Temporarily trying a package
nix shell nixpkgs#cowsay
cowsay "Hello"
exit

# Building and running an app
nix run
```

**Rule**: Match command to task:

- **Develop** = Modify package
- **Shell** = Try package
- **Run** = Execute package
- **Build** = Create package

---

### Pitfall 3: Path String Confusion

**Problem**:

```nix
# Unexpected path interpretation
let config = ./config/main.conf;  # Path type
```

**When It Goes Wrong**:

```nix
# Trying to concatenate
configPath = ./config/main.conf + "/extra";  # ERROR
```

**Solution**:

```nix
# Use strings explicitly
configPath = "${./config}/main.conf";

# Or use toString
configPath = toString ./config + "/main.conf";
```

**Rule**: Use `./` for actual file paths; use strings for path manipulation.

---

### Pitfall 4: Excessive `with` Usage

**Problem**:

```nix
with pkgs;
with lib;
with stdenv;
{
  # Where does 'filter' come from?
  myList = filter (x: x > 0) numbers;
  # lib.filter? builtins.filter? Unclear!
}
```

**Solution**:

```nix
# Limited scope
{
  packages = with pkgs; [ gcc vim git ];  # Clear context

  # Or fully explicit
  myList = lib.filter (x: x > 0) numbers;  # Obvious source
}
```

**Rule**: **Minimize `with` usage**; prefer explicit `pkgs.`, `lib.` prefixes.

---

### Pitfall 5: Recursive Attribute Set Overuse

**Problem**:

```nix
# Using rec unnecessarily
rec {
  version = "1.0.0";
  name = "myapp-${version}";  # Self-reference
  url = "https://example.com/${name}";  # Risk of recursion
}
```

**Solution**:

```nix
# Prefer let
let
  version = "1.0.0";
  name = "myapp-${version}";
in {
  inherit version name;
  url = "https://example.com/${name}";
}
```

**Benefits**:

- Clearer scoping
- No recursion risks
- Easier to refactor

**Rule**: **Prefer `let` over `rec`** - only use `rec` when absolutely necessary.

---

## 6. Language-Specific Patterns

### Haskell Projects

```nix
{
  description = "Haskell project with cabal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    haskell-flake.url = "github:srid/haskell-flake";
  };

  outputs = { self, nixpkgs, haskell-flake }:
    haskell-flake.lib.mkHaskellPackage {
      src = ./.;
      name = "myapp";
    };
}
```

**Benefits**: Automatic dependency detection, standardized build.

### Python Projects

```nix
{
  description = "Python project with setuptools";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      packages.default = pkgs.python3Packages.buildPythonApplication {
        pname = "myapp";
        version = "1.0.0";
        src = ./.;
        propagatedBuildInputs = with pkgs.python3Packages; [
          requests
          click
        ];
      };
    };
}
```

**Benefits**: Automatic Python packaging, dependency management.

---

## 7. How This Applies to Our Configuration

### Patterns We're Already Using Correctly ✅

1. **Immutable Values**: All configurations are declarative
2. **Feature Flags**: `features.*` namespace for conditional config
3. **Flake Lockfile**: Always committed
4. **Multi-Platform Support**: Using `flake-utils.lib.eachDefaultSystem`
5. **Development Shells**: Separate dev environments
6. **Explicit Imports**: No auto-discovery, all imports explicit

### Patterns We Should Improve ⚠️

1. **Limited `with` Usage**: Currently use `with lib;` extensively
   - **Action**: Review and reduce `with` usage
   - **Priority**: Medium

2. **Type Conversions**: Some implicit type assumptions
   - **Action**: Audit for missing `toString` calls
   - **Priority**: Low

3. **Dependency Separation**: Some mixing of build/dev dependencies
   - **Action**: Review all modules for proper separation
   - **Priority**: Medium

4. **Git Workflow**: Occasionally build without staging
   - **Action**: Document workflow in CLAUDE.md
   - **Priority**: Low

### New Patterns to Adopt 🌟

1. **Floating Point Precision**: Add `.0` for float calculations
   - **Where**: Performance tuning, resource allocation
   - **Priority**: Low

2. **Path String Handling**: Use `toString` or `${}` consistently
   - **Where**: File path manipulation
   - **Priority**: Low

3. **Command Clarity**: Document when to use each Nix command
   - **Where**: Development workflows
   - **Priority**: High (for team onboarding)

---

## 8. Action Items

### Immediate (This Week)

1. ✅ Create `.claude/NIX_ANTIPATTERNS.md` - **COMPLETED**
2. ✅ Document Nix command usage patterns - **COMPLETED**
3. ⏭️ Add to CLAUDE.md as reference
4. ⏭️ Review deduplication report against these patterns

### Short-Term (Next Sprint)

1. ⏭️ Audit modules for `with` overuse
2. ⏭️ Review type conversion practices
3. ⏭️ Ensure build/dev dependency separation
4. ⏭️ Add pre-commit hook for Git staging check

### Long-Term (Next Quarter)

1. ⏭️ Create development workflow guide
2. ⏭️ Add language-specific flake templates
3. ⏭️ Conduct team training on Nix best practices
4. ⏭️ Integrate anti-patterns into code review checklist

---

## 9. Integration with Existing Documentation

### Cross-References

- **Anti-Patterns**: `.claude/NIX_ANTIPATTERNS.md` (NEW)
- **NixOS Anti-Patterns**: `docs/NIXOS-ANTI-PATTERNS.md`
- **Research**: `docs/RESEARCH_USMCAMP_DOTFILES.md`
- **Deduplication**: `docs/DEDUPLICATION_REPORT.md`

### Documentation Hierarchy

```
CLAUDE.md (main reference)
  ├── .claude/NIX_ANTIPATTERNS.md (language-level patterns)
  ├── docs/NIXOS-ANTI-PATTERNS.md (system-level patterns)
  ├── docs/RESEARCH_USMCAMP_DOTFILES.md (advanced patterns)
  └── docs/DEDUPLICATION_REPORT.md (code quality)
```

---

## 10. Learning Highlights

### Most Valuable Insights

1. **Spacing is Critical**: Not just style - affects type interpretation
2. **Command Clarity**: `develop`, `shell`, `run`, `build` are fundamentally different
3. **Lockfile is Sacred**: Must be committed for reproducibility
4. **Git Integration**: Flakes only see tracked files
5. **Type System is Strict**: No implicit conversions, explicit is better

### Common Misconceptions Corrected

| Misconception                    | Reality                                     |
| -------------------------------- | ------------------------------------------- |
| "Nix is just a package manager"  | It's a full functional programming language |
| "Spacing is just style"          | Spacing affects type interpretation         |
| "Variables can be reassigned"    | All values are immutable                    |
| "Types convert automatically"    | Must use `toString` or `${}`                |
| "`nix shell` is for development" | Use `nix develop` for dev work              |

---

## 11. Recommendations Summary

### High-Priority Recommendations

1. **Document Nix Commands**: Create guide for team (develop vs shell vs run vs build)
2. **Reduce `with` Usage**: Audit and make code more explicit
3. **Git Workflow**: Enforce staging before building
4. **Anti-Pattern Training**: Share `.claude/NIX_ANTIPATTERNS.md` with team

### Medium-Priority Recommendations

1. Review dependency separation across all modules
2. Add pre-commit hooks for common issues
3. Create language-specific flake templates
4. Standardize string interpolation patterns

### Low-Priority Recommendations

1. Audit float vs integer division
2. Improve path string handling
3. Document recursive attribute set usage
4. Create troubleshooting guide for common errors

---

## 12. Conclusion

The Nix Book provides essential foundational knowledge that complements our existing best practices documentation. Key learnings have been codified in `.claude/NIX_ANTIPATTERNS.md` for immediate reference.

### Key Takeaways

1. **Nix Language Matters**: Understanding language fundamentals prevents subtle bugs
2. **Flake Discipline**: Lockfiles, clean git state, proper dependencies are non-negotiable
3. **Command Clarity**: Using the right command for the right task saves time
4. **Type Safety**: Explicit conversions prevent errors
5. **Simplicity Wins**: Avoid `rec`, limit `with`, keep flakes simple

### Integration with Our Work

- ✅ Anti-pattern documentation created and integrated
- ✅ Cross-referenced with existing documentation
- ⏭️ Ready to apply in deduplication work
- ⏭️ Will guide future module development

**Next Steps**: Review deduplication report through lens of these patterns, apply learnings to ongoing work.

---

**Research Completed**: 2025-01-15
**Documentation Created**: `.claude/NIX_ANTIPATTERNS.md`, `docs/RESEARCH_NIX_BOOK.md`
**Status**: Ready for application
**Priority**: HIGH - Use as reference for all future work
