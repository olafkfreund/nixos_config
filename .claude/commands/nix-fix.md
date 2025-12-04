# Fix NixOS Anti-Patterns

Automatically detect and fix common NixOS anti-patterns in your code.

## What I'll Check

### 1. The mkIf true Pattern (Most Common)
```nix
# ❌ BEFORE
services.myservice.enable = mkIf cfg.enable true;
light.enable = mkIf (cfg.profile == "laptop") true;

# ✅ AFTER
services.myservice.enable = cfg.enable;
light.enable = cfg.profile == "laptop";
```

### 2. Trivial Function Wrappers
```nix
# ❌ BEFORE
mkFeature = name: { enable = mkEnableOption name; };

# ✅ AFTER - Use mkEnableOption directly
enable = mkEnableOption "feature name";
```

### 3. Excessive with Usage
```nix
# ❌ BEFORE
with pkgs; with lib; with stdenv;
buildInputs = [ curl jq ];  # Where are these from?

# ✅ AFTER
buildInputs = with pkgs; [ curl jq ];  # Clear scope
```

### 4. Dangerous rec Sets
```nix
# ❌ BEFORE
rec { a = 1; b = a + 1; }  # Risk of infinite recursion

# ✅ AFTER
let
  attrs = { a = 1; b = attrs.a + 1; };
in attrs
```

### 5. Secret Handling
```nix
# ❌ BEFORE
password = builtins.readFile "/secrets/password";

# ✅ AFTER
passwordFile = "/secrets/password";  # Runtime loading
```

### 6. Service Security
```nix
# ❌ BEFORE
systemd.services.myservice = {
  serviceConfig.ExecStart = "${pkgs.myapp}/bin/myapp";
};

# ✅ AFTER
systemd.services.myservice = {
  serviceConfig = {
    ExecStart = "${pkgs.myapp}/bin/myapp";
    DynamicUser = true;
    ProtectSystem = "strict";
    NoNewPrivileges = true;
  };
};
```

## Usage

**Fix specific files:**
```
/nix-fix
Fix modules/services/myservice.nix
```

**Fix recent changes:**
```
/nix-fix
Fix all files I just modified
```

**Fix entire module directory:**
```
/nix-fix
Check and fix all modules in modules/services/
```

## Process

1. **Scan Files**: Identify all anti-patterns using regex patterns
2. **Generate Fixes**: Create corrected code with explanations
3. **Show Diff**: Display before/after for each fix
4. **Apply Changes**: Update files with fixes
5. **Validate**: Run `just check-syntax` to ensure correctness
6. **Report**: Summary of fixes applied

## Safety Features

- **Preview Mode**: Shows all changes before applying
- **Validation**: Syntax check after each fix
- **Rollback**: Keeps backups of original files
- **Explanation**: Each fix includes reasoning

## Speed Optimization

- **Pattern Matching**: Fast regex-based detection (< 5s)
- **Batch Processing**: Fixes multiple files at once
- **Parallel Validation**: Tests all files simultaneously

**Typical Runtime**: 30-60 seconds for entire repository

## Anti-Patterns Checklist

- [ ] mkIf true patterns → direct assignment
- [ ] Trivial wrappers → direct lib functions
- [ ] Excessive with → limited scope
- [ ] rec sets → let bindings
- [ ] Evaluation-time secrets → runtime loading
- [ ] Root services → DynamicUser
- [ ] Bare URLs → quoted strings
- [ ] Magic imports → explicit lists

Ready to fix anti-patterns? Just tell me which files to check!
