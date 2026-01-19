# NixOS Testing Suite

Comprehensive testing of NixOS configurations before deployment. Test builds locally without deploying to ensure everything works.

**Replaces Justfile recipes**: `test-all`, `test-all-parallel`, `test-build-all`, `test-build-all-parallel`, `test-home`, `test-secrets`, `test-all-secrets`, `test-packages`, `test-modules`, `test-home-modules`, `test-nixpkgs-stable`, `test-all-users`, `quick-test`, `ci`, `ci-quick`

## Quick Usage

**Test single host**:

```
/nix-test p620
```

**Test all hosts** (parallel - fastest):

```
/nix-test
Test all hosts
```

**Quick test** (validation + build):

```
/nix-test
Quick test
```

**CI mode** (for continuous integration):

```
/nix-test
CI mode
```

## Features

### Test Modes

**Single Host** (~60 seconds):

- ✅ Builds NixOS configuration for specific host
- ✅ Validates configuration structure
- ✅ Checks all dependencies resolve
- ✅ No deployment (safe testing)

**All Hosts Sequential** (~5 minutes):

- ✅ Tests all 4 hosts one at a time
- ✅ Clear progress indication
- ✅ Stops on first failure (fast-fail)
- ✅ Detailed error reporting

**All Hosts Parallel** (~2 minutes - FASTEST):

- ✅ Tests all 4 hosts simultaneously
- ✅ 60% faster than sequential
- ✅ Utilizes multi-core systems
- ✅ Aggregated results at end

**Quick Test** (~30 seconds):

- ✅ Syntax validation
- ✅ Feature validation
- ✅ Security validation
- ✅ No actual build (fastest feedback)

**CI Mode** (~3 minutes):

- ✅ Optimized for CI/CD pipelines
- ✅ All hosts parallel
- ✅ Detailed output for logs
- ✅ Exit codes for pipeline integration

### Additional Test Modes

**Home Manager Test**:

```
/nix-test
Test Home Manager configurations
```

- Tests all user home configurations
- Validates user-specific packages
- Checks dotfile generation

**Secrets Test**:

```
/nix-test
Test secrets access
```

- Verifies all secrets are accessible
- Checks secret permissions
- Validates age key access

**Module Test**:

```
/nix-test
Test modules only
```

- Tests module structure
- Validates module options
- Checks module documentation

## Testing Workflow

### Development Workflow

```bash
# After making changes
/nix-test p620                # Test specific host (60s)

# Before committing
/nix-test
Quick test                    # Fast validation (30s)

# Before PR
/nix-test
Test all hosts                # Full build test (2min)
```

### CI/CD Workflow

```bash
# In GitHub Actions / GitLab CI
/nix-test
CI mode
# Optimized for CI with detailed logging
```

### Pre-Deployment Workflow

```bash
# Test before deploying
/nix-test p620

# If test passes, deploy
/nix-deploy p620
```

## Output Format

### Single Host Success

```
🧪 Testing NixOS Configuration: p620

📋 Validation Phase (10s)
   ✅ Syntax check passed
   ✅ Feature validation passed
   ✅ Security validation passed

🔨 Build Phase (50s)
   Building nixosConfigurations.p620.config.system.build.toplevel
   ✅ Build successful
   📦 Output: /nix/store/xyz...nixos-system-p620-25.11

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ P620 Test Complete - Ready to Deploy
Total Time: 60 seconds
```

### All Hosts Parallel Success

```
🧪 Testing All NixOS Configurations (Parallel)

Starting parallel builds...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ P620    (AMD Workstation)      - 58s
✅ Razer   (Intel/NVIDIA Laptop)  - 62s
✅ P510    (Intel Xeon Server)    - 54s
✅ Samsung (Intel Laptop)         - 51s

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ All Hosts Passed - Ready to Deploy
Total Time: 62 seconds (fastest host time)
Efficiency: 3.2x faster than sequential
```

### Build Failure

```
🧪 Testing NixOS Configuration: p620

📋 Validation Phase (10s)
   ✅ Syntax check passed
   ✅ Feature validation passed
   ⚠️  Security warning: Service 'myservice' missing DynamicUser

🔨 Build Phase (25s)
   Building nixosConfigurations.p620.config.system.build.toplevel

   ❌ Build Failed

   Error: collision between files:
   - /nix/store/abc.../bin/tool
   - /nix/store/def.../bin/tool

   Packages in conflict:
   - python311Packages.tool
   - python312Packages.tool

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ P620 Test Failed
Total Time: 35 seconds

Suggested Fix:
Remove conflicting package or use environment.systemPackages
instead of users.users.USER.packages for one of them.
```

## Implementation Details

### Single Host Test

```bash
# Validate configuration
/nix-validate p620
Quick validation

# Build configuration (no deployment)
nix build .#nixosConfigurations.p620.config.system.build.toplevel \
  --no-link --show-trace
```

### Parallel Test (All Hosts)

```bash
# Start 4 parallel builds
nix build .#nixosConfigurations.p620.config.system.build.toplevel --no-link & \
nix build .#nixosConfigurations.razer.config.system.build.toplevel --no-link & \
nix build .#nixosConfigurations.p510.config.system.build.toplevel --no-link & \
nix build .#nixosConfigurations.samsung.config.system.build.toplevel --no-link & \
wait

# Aggregate results
```

### Quick Test

```bash
# Just validation, no build
/nix-validate
Quick validation

# Check syntax for all hosts
for host in p620 razer p510 samsung; do
  nix eval .#nixosConfigurations.$host.config.system.name
done
```

### Home Manager Test

```bash
# Test all user home configurations
for user in olafkfreund; do
  nix build .#homeConfigurations.$user@p620.activationPackage --no-link
done
```

### Secrets Test

```bash
# Test secret accessibility
for secret in $(ls secrets/*.age); do
  agenix -d $secret > /dev/null 2>&1 && echo "✅ $secret" || echo "❌ $secret"
done
```

## Error Handling

### Common Build Errors

**Collision Error**:

```
❌ Package Collision
   Files in conflict:
   - /nix/store/abc.../bin/tool
   - /nix/store/def.../bin/tool

Fix: Remove duplicate package or use environment.systemPackages
Run: /nix-fix to detect and suggest fixes
```

**Missing Dependency**:

```
❌ Missing Dependency
   Package 'python311Packages.mypackage' not found

Fix: Check package name spelling or update nixpkgs
Run: nix search nixpkgs mypackage
```

**Evaluation Error**:

```
❌ Evaluation Error
   Infinite recursion in feature dependencies

Fix: Check for circular feature dependencies
Run: /nix-validate for detailed dependency analysis
```

**Out of Memory**:

```
❌ Build Failed: Out of Memory
   Process killed during build

Fix: Increase system memory or disable parallel builds
Run: /nix-test p620 (single host uses less memory)
```

## Performance Optimization

### Parallel vs Sequential

**Sequential** (test-all):

```
P620:    60s →
Razer:   62s →
P510:    54s →
Samsung: 51s →
Total:   227s (3min 47s)
```

**Parallel** (test-all-parallel):

```
P620:    60s ↓
Razer:   62s ↓
P510:    54s ↓
Samsung: 51s ↓
Total:   62s (fastest completes)
Speedup: 3.7x faster
```

### Caching Benefits

**First Run** (no cache):

- Build time: ~60s per host
- Downloads: ~500MB
- Total: 3-4 minutes (all hosts)

**Subsequent Runs** (cached):

- Build time: ~10s per host
- Downloads: 0MB (cache hit)
- Total: ~30s (all hosts)

**Binary Cache Usage**:

- P620 nix-serve: Local cache server
- cache.nixos.org: Official cache
- Custom cachix: Organization cache

## Integration with Other Commands

### Before Deployment

```bash
# Test first
/nix-test p620

# If passes, deploy
/nix-deploy p620
```

### With Validation

```bash
# Quick validation + test
/nix-validate
Quick validation

/nix-test p620
```

### In CI/CD Pipeline

```bash
# GitHub Actions / GitLab CI
/nix-test
CI mode

# On success, deploy
if [ $? -eq 0 ]; then
  /nix-deploy production
fi
```

### With Fix Workflow

```bash
# Test and find issues
/nix-test p620

# Fix detected issues
/nix-fix

# Test again
/nix-test p620
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Test NixOS Configurations

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v24

      - name: Test all configurations
        run: |
          claude /nix-test
          CI mode
```

### GitLab CI

```yaml
test-nixos:
  stage: test
  image: nixos/nix:latest
  script:
    - claude /nix-test
    - CI mode
  only:
    - merge_requests
    - main
```

## Best Practices

### DO ✅

- Test before every deployment
- Use parallel mode for multiple hosts (60% faster)
- Test in CI/CD pipelines
- Fix build errors immediately
- Use quick test for rapid iteration

### DON'T ❌

- Skip testing before deployment (asking for trouble)
- Use sequential when parallel is available (waste time)
- Test in production (test locally first)
- Ignore build warnings (become errors later)
- Deploy without successful test (recipe for disaster)

## Troubleshooting

### Parallel Builds Fail

```bash
# Fall back to sequential
/nix-test
Test all hosts sequentially

# Or test individually
/nix-test p620
/nix-test razer
/nix-test p510
/nix-test samsung
```

### Build Takes Too Long

```bash
# Use quick test instead
/nix-test
Quick test

# Or test specific host only
/nix-test p620
```

### Out of Disk Space

```bash
# Clean up before testing
/nix-clean
Standard GC

# Then test
/nix-test p620
```

### Flaky Network Issues

```bash
# Use local cache only
nix build --option substitute false \
  .#nixosConfigurations.p620.config.system.build.toplevel
```

## Test Coverage

### What Gets Tested

✅ **Configuration Syntax**: All Nix expressions
✅ **Module System**: Feature flags, dependencies
✅ **Package Resolution**: All packages build
✅ **Service Configs**: Systemd units valid
✅ **Home Manager**: User configurations
✅ **Secrets**: Age key access
✅ **Hardware Configs**: Device-specific settings
✅ **Network Configs**: Tailscale, firewall

### What Doesn't Get Tested

❌ **Runtime Behavior**: Services actually start
❌ **Hardware Compatibility**: Device drivers work
❌ **Network Connectivity**: Internet access works
❌ **Performance**: System runs efficiently
❌ **User Experience**: Desktop environment usable

**For Runtime Testing**: Deploy to VM or staging first

## Related Commands

- `/nix-validate` - Validate before testing
- `/nix-deploy` - Deploy after successful test
- `/nix-fix` - Fix build errors automatically
- `/review` - Code review before testing
- `/nix-info` - Check system info and build cache

---

**Pro Tip**: Set up automatic testing on every commit:

```bash
/nix-precommit
Install test hook
```

This runs `/nix-test Quick test` automatically before every commit! 🚀
