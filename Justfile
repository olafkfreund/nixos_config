#!/usr/bin/env just --justfile

# Default recipe to display available commands
default:
    @just --list

# =============================================================================
# DEPLOYMENT COMMANDS
# =============================================================================

# Deploy to local system using nh
deploy:
    nh os switch --accept-flake-config

# Update local system using nh
update:
    nh os update --accept-flake-config

# Update flake inputs and deploy
update-flake:
    nix flake update
    just deploy

# =============================================================================
# TESTING AND VALIDATION
# =============================================================================

# Run comprehensive validation suite
validate:
    @echo "🧪 Running comprehensive validation..."
    @echo "📋 Feature validation..."
    nix eval .#lib.validateFeatures --json | jq '.isValid'
    @echo "🔒 Security validation..."
    nix eval .#lib.validateSecurity --json | jq '.hasErrors'
    @echo "📝 Configuration syntax check..."
    nix flake check --no-build
    @echo "✅ All validations complete!"

# Quick validation (faster, less comprehensive)
validate-quick:
    @echo "⚡ Running quick validation..."
    ./scripts/validate-config.sh --quick

# Quality validation - check documentation and patterns
validate-quality:
    @echo "📋 Running quality validation..."
    ./scripts/validate-quality.sh

# Full validation - includes quality checks
validate-full:
    @echo "🔍 Running full validation with quality checks..."
    ./scripts/validate-config.sh
    ./scripts/validate-quality.sh

# Test all configurations build successfully
test-all:
    @echo "🧪 Testing all NixOS configurations..."
    @for host in razer dex5550 p510 p620; do \
        echo "Testing $host..."; \
        nix build .#nixosConfigurations.$host.config.system.build.toplevel --show-trace || exit 1; \
    done
    @echo "✅ All configurations build successfully!"

# Test all configurations in parallel (FASTER)
test-all-parallel:
    @echo "🧪 Testing all NixOS configurations in parallel..."
    @( nix build .#nixosConfigurations.razer.config.system.build.toplevel --no-link --show-trace && echo "✅ Razer" || echo "❌ Razer" ) & \
    ( nix build .#nixosConfigurations.dex5550.config.system.build.toplevel --no-link --show-trace && echo "✅ DEX5550" || echo "❌ DEX5550" ) & \
    ( nix build .#nixosConfigurations.p510.config.system.build.toplevel --no-link --show-trace && echo "✅ P510" || echo "❌ P510" ) & \
    ( nix build .#nixosConfigurations.p620.config.system.build.toplevel --no-link --show-trace && echo "✅ P620" || echo "❌ P620" ) & \
    wait && echo "✅ All parallel tests completed!"

# Test specific host configuration
test-host HOST:
    @echo "🧪 Testing {{HOST}} configuration..."
    nix build .#nixosConfigurations.{{HOST}}.config.system.build.toplevel --show-trace

# Validate flake syntax and inputs
check:
    @echo "🔍 Validating flake configuration..."
    nix flake check --show-trace

# Check for available updates
check-updates:
    @echo "📦 Checking for available updates..."
    ./scripts/check-nixos-updates.sh

# Dry-run rebuild to see what would change
dry-run HOST="p620":
    @echo "🔍 Dry-run for {{HOST}}..."
    nixos-rebuild dry-activate --flake .#{{HOST}} --show-trace

# Test build without switching
test-build HOST="p620":
    @echo "🔨 Test building {{HOST}}..."
    nixos-rebuild build --flake .#{{HOST}} --show-trace

# Test build with trace and verbose output
test-build-verbose HOST:
    @echo "🔨 Test building {{HOST}} with verbose output..."
    nixos-rebuild build --flake .#{{HOST}} --show-trace --verbose

# Validate Home Manager configurations  
test-home:
    @echo "🏠 Testing Home Manager configurations..."
    @for host in razer dex5550 p510 p620; do \
        echo "Testing Home Manager for olafkfreund@$host..."; \
        nix build .#homeConfigurations.\"olafkfreund@$host\".activationPackage --show-trace || echo "⚠️  Home Manager config for $host failed"; \
    done

# Test specific user's Home Manager config
test-home-user USER HOST:
    @echo "🏠 Testing Home Manager for {{USER}}@{{HOST}}..."
    nix build .#homeConfigurations.\"{{USER}}@{{HOST}}\".activationPackage --show-trace

# Test secrets decryption
test-secrets:
    @echo "🔐 Testing secrets decryption..."
    @if [ -f "secrets/user-password-olafkfreund.age" ]; then \
        agenix -d secrets/user-password-olafkfreund.age > /dev/null && echo "✅ Secrets decrypt successfully" || echo "❌ Secret decryption failed"; \
    else \
        echo "⚠️  No secrets found to test"; \
    fi

# Test all secrets in secrets directory
test-all-secrets:
    @echo "🔐 Testing all secrets decryption..."
    @for secret in secrets/*.age; do \
        if [ -f "$$secret" ]; then \
            echo "Testing $$secret..."; \
            agenix -d "$$secret" > /dev/null && echo "✅ $$secret decrypts successfully" || echo "❌ $$secret failed to decrypt"; \
        fi; \
    done

# Run comprehensive pre-deploy checks
pre-deploy HOST:
    @echo "🔍 Running pre-deployment checks for {{HOST}}..."
    just check
    just test-host {{HOST}}
    just test-secrets
    @echo "✅ Pre-deployment checks passed for {{HOST}}!"

# Test package builds
test-packages:
    @echo "📦 Testing custom package builds..."
    @packages=$$(nix flake show --json 2>/dev/null | jq -r '.packages."x86_64-linux" | keys[]' 2>/dev/null || echo ""); \
    if [ -n "$$packages" ]; then \
        for package in $$packages; do \
            echo "Testing package: $$package"; \
            nix build .#$$package --show-trace || echo "⚠️  Package $$package failed to build"; \
        done; \
    else \
        echo "No custom packages found to test"; \
    fi

# Test specific package
test-package PACKAGE:
    @echo "📦 Testing package {{PACKAGE}}..."
    nix build .#{{PACKAGE}} --show-trace

# Check Nix file syntax across the entire configuration
check-syntax:
    #!/usr/bin/env bash
    echo "🔍 Checking Nix file syntax..."
    error_found=false
    while IFS= read -r -d '' file; do
        if ! nix-instantiate --parse "$file" > /dev/null 2>&1; then
            echo "❌ Syntax error in $file"
            error_found=true
        fi
    done < <(find . -name "*.nix" -not -path "./result*" -not -path "./.git/*" -print0)
    if [ "$error_found" = false ]; then
        echo "✅ All Nix files have valid syntax"
    fi

# =============================================================================
# REMOTE DEPLOYMENT
# =============================================================================

# Deploy to razer laptop (Intel/NVIDIA) - OPTIMIZED
razer:
    nixos-rebuild switch --flake .#razer --target-host razer --build-host razer --use-remote-sudo --fast --keep-going --accept-flake-config

# Deploy to p620 workstation (AMD) - OPTIMIZED
p620:
    nixos-rebuild switch --flake .#p620 --target-host p620 --build-host p620 --use-remote-sudo --fast --keep-going --accept-flake-config

# Deploy to p510 workstation (Intel Xeon/NVIDIA) - OPTIMIZED  
p510:
    nixos-rebuild switch --flake .#p510 --target-host p510 --build-host p510 --use-remote-sudo --fast --keep-going --accept-flake-config

# Deploy to dex5550 SFF system (Intel integrated) - OPTIMIZED
dex5550:
    nixos-rebuild switch --flake .#dex5550 --target-host dex5550 --build-host dex5550 --use-remote-sudo --fast --keep-going --accept-flake-config

# Deploy to samsung system (Intel integrated)
samsung:
    nixos-rebuild switch --flake .#samsung --target-host 192.168.1.92 --build-host 192.168.1.92 --use-remote-sudo --impure --accept-flake-config

# =============================================================================
# ARCHIVED/LEGACY HOSTS (FOR REFERENCE)
# =============================================================================

# Deploy to hp (archived)
hp:
    @echo "⚠️  hp is archived - use at your own risk"
    nixos-rebuild switch --flake .#hp --target-host hp --build-host hp --use-remote-sudo --impure --accept-flake-config

# Deploy to lms (archived)  
lms:
    @echo "⚠️  lms is archived - use at your own risk"
    nixos-rebuild switch --flake .#lms --target-host lms --build-host lms --use-remote-sudo --impure --accept-flake-config

# Deploy to pvm (archived)
pvm:
    @echo "⚠️  pvm is archived - use at your own risk"
    nixos-rebuild switch --flake .#pvm --target-host pvm --build-host pvm --use-remote-sudo --impure --accept-flake-config

# =============================================================================
# MODERN CONFIGURATION MANAGEMENT
# =============================================================================

# Generate new host configuration from template
create-host HOST TYPE="workstation" HARDWARE="intel":
    @echo "🏗️  Creating new host configuration: {{HOST}}"
    @mkdir -p hosts/{{HOST}}/nixos hosts/{{HOST}}/themes
    @echo "Generating hardware configuration..."
    nixos-generate-config --root /mnt --dir hosts/{{HOST}}/ || echo "Run this on target machine or provide hardware-configuration.nix manually"
    @echo "Creating host variables from template..."
    @cp templates/variables.nix.template hosts/{{HOST}}/variables.nix
    @sed -i 's/HOSTNAME_PLACEHOLDER/{{HOST}}/g' hosts/{{HOST}}/variables.nix
    @sed -i 's/TYPE_PLACEHOLDER/{{TYPE}}/g' hosts/{{HOST}}/variables.nix
    @sed -i 's/HARDWARE_PLACEHOLDER/{{HARDWARE}}/g' hosts/{{HOST}}/variables.nix
    @echo "Creating base configuration from template..."
    @cp templates/configuration.nix.template hosts/{{HOST}}/configuration.nix
    @echo "Creating stylix theme..."
    @cp hosts/p620/themes/stylix.nix hosts/{{HOST}}/themes/stylix.nix
    @echo "✅ Host {{HOST}} created! Edit hosts/{{HOST}}/variables.nix to customize"

# Validate feature dependencies for a host
validate-features HOST:
    @echo "📋 Validating feature configuration for {{HOST}}..."
    nix eval .#nixosConfigurations.{{HOST}}.config.featureValidation --json | jq 'if .isValid then "✅ Feature configuration is valid" else "❌ Feature validation failed" end'

# Show configuration diff between current and new build
diff HOST:
    @echo "📊 Showing configuration diff for {{HOST}}..."
    @current=$(readlink -f /run/current-system 2>/dev/null || echo "no-current") && new=$(nix build .#nixosConfigurations.{{HOST}}.config.system.build.toplevel --no-link --print-out-paths) && if [ "$current" != "no-current" ]; then nix store diff-closures $current $new; else echo "No current system configuration found"; fi

# Analyze configuration size and dependencies
analyze HOST:
    @echo "📈 Analyzing configuration for {{HOST}}..."
    @echo "🔍 Configuration size:"
    nix path-info -rsSh .#nixosConfigurations.{{HOST}}.config.system.build.toplevel | tail -1
    @echo "📦 Top 10 largest dependencies:"
    nix path-info -rsSh .#nixosConfigurations.{{HOST}}.config.system.build.toplevel | sort -k2 -h | tail -10

# Clean up old generations and garbage collect
cleanup GENERATIONS="7":
    @echo "🧹 Cleaning up old generations (keeping {{GENERATIONS}})..."
    sudo nix-collect-garbage --delete-older-than {{GENERATIONS}}d
    @echo "🧹 Optimizing nix store..."
    nix store optimise

# Export configuration documentation
docs:
    @echo "📚 Generating configuration documentation..."
    @mkdir -p docs/generated
    @echo "Extracting module options..."
    nix eval .#nixosConfigurations.p620.options --json > docs/generated/options.json
    @echo "Generating feature matrix..."
    @echo "| Feature | Description | Dependencies | Conflicts |" > docs/generated/features.md
    @echo "|---------|-------------|--------------|-----------|" >> docs/generated/features.md
    nix eval .#lib.featureRegistry --json | jq -r 'to_entries[] | "| \(.key) | \(.value.description) | \(.value.dependencies | join(", ")) | \(.value.conflicts | join(", ")) |"' >> docs/generated/features.md
    @echo "✅ Documentation generated in docs/generated/"

# Show system health and status
status:
    @echo "🏥 System Health Status"
    @echo "======================="
    @echo "💾 Disk Usage:"
    df -h / | tail -1
    @echo "🧠 Memory Usage:"
    free -h | grep Mem
    @echo "📦 Nix Store Size:"
    du -sh /nix/store 2>/dev/null || echo "Cannot access /nix/store"
    @echo "🗂️  Generations Count:"
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | wc -l
    @echo "⚡ Last Update:"
    stat -c %y /run/current-system 2>/dev/null || echo "Unknown"

# View system generation history
history:
    nix profile history --profile /nix/var/nix/profiles/system

# =============================================================================
# CONFIGURATION OPTIMIZATION
# =============================================================================

# Analyze configuration for dead code and duplicates
analyze-config:
    @echo "🔍 Analyzing configuration for optimization opportunities..."
    ./scripts/cleanup-dead-code.sh analysis

# Clean up identified dead code (DESTRUCTIVE - use with caution)
cleanup-dead-code:
    @echo "⚠️  WARNING: This will modify your configuration files!"
    ./scripts/cleanup-dead-code.sh clean

# Migrate host to use shared configurations
migrate-host HOST:
    @echo "🚀 Migrating {{HOST}} to use shared configurations..."
    @echo "Backing up current configuration..."
    @cp -r hosts/{{HOST}} hosts/{{HOST}}.backup.$(date +%Y%m%d_%H%M%S)
    @echo "Updating stylix configuration..."
    @echo 'import ../../shared/themes/stylix-base.nix { inherit pkgs; vars = import ./variables.nix; }' > hosts/{{HOST}}/themes/stylix.nix
    @echo "Updating hyprland VNC if present..."
    @if [ -f "hosts/{{HOST}}/nixos/hypr_override.nix" ]; then \
        echo 'import ../../shared/desktop/hypr-vnc.nix' > hosts/{{HOST}}/nixos/hypr_override.nix; \
    fi
    @echo "✅ Migration complete. Test with: just test-host {{HOST}}"

# Show configuration efficiency metrics
efficiency-report:
    @echo "📊 Configuration Efficiency Report"
    @echo "=================================="
    @echo "📁 Total .nix files: $(find . -name '*.nix' | wc -l)"
    @echo "📄 Default.nix files: $(find . -name 'default.nix' | wc -l)"
    @echo "🔄 Potential duplicates:"
    @find . -name "*.nix" -exec md5sum {} \; | sort | uniq -d -w32 | wc -l
    @echo "💀 Commented code blocks:"
    @rg -c "^\s*#" --type nix . | awk -F: '{sum += $2} END {print sum " lines"}'
    @echo "🏗️  Feature flag usage:"
    @rg -c "enable.*=.*true" --type nix . | awk -F: '{sum += $2} END {print sum " explicit enables"}'
    @echo "📦 Host configurations: $(ls hosts/ | grep -v backup | wc -l)"
    @echo "👤 User configurations: $(find Users/ -name "*_home.nix" | wc -l)"

# Validate migration success
validate-migration HOST:
    @echo "✅ Validating migration for {{HOST}}..."
    @echo "Testing build..."
    just test-host {{HOST}}
    @echo "Checking for shared module usage..."
    @if grep -q "shared/" hosts/{{HOST}}/themes/stylix.nix 2>/dev/null; then \
        echo "✅ Using shared stylix configuration"; \
    else \
        echo "❌ Not using shared stylix configuration"; \
    fi

# Open Nix REPL with nixpkgs
repl:
    nix repl -f flake:nixpkgs

# Garbage collect old generations
gc:
    sudo nix-collect-garbage --delete-old

# Aggressive garbage collection (remove all non-current generations)
gc-aggressive:
    sudo nix-collect-garbage -d

# Optimize nix store
optimize:
    sudo nix-store --optimize


# =============================================================================
# MODULE AND COMPONENT TESTING
# =============================================================================

# Test all modules in the modules directory
test-modules:
    @echo "🧩 Testing all modules..."
    ./scripts/test-modules.sh modules

# Test Home Manager modules
test-home-modules:
    @echo "🏠 Testing Home Manager modules..."
    ./scripts/test-modules.sh home

# Test a specific module
test-module MODULE:
    @echo "🧩 Testing specific module: {{MODULE}}..."
    ./scripts/test-modules.sh specific {{MODULE}}

# Check module documentation
check-module-docs:
    @echo "📚 Checking module documentation..."
    ./scripts/test-modules.sh docs

# =============================================================================
# PERFORMANCE TESTING AND BENCHMARKING
# =============================================================================

# Run comprehensive performance tests
perf-test:
    @echo "⚡ Running comprehensive performance tests..."
    ./scripts/performance-test.sh full

# Test build times for all hosts
perf-build-times:
    @echo "⏱️  Measuring build times..."
    ./scripts/performance-test.sh build-times

# Test memory usage during builds
perf-memory:
    @echo "🧠 Measuring memory usage..."
    ./scripts/performance-test.sh memory

# Test flake evaluation performance
perf-eval:
    @echo "🔍 Measuring evaluation performance..."
    ./scripts/performance-test.sh eval

# Test parallel build efficiency
perf-parallel:
    @echo "⚡ Testing parallel build efficiency..."
    ./scripts/performance-test.sh parallel

# Test cache performance
perf-cache:
    @echo "💾 Testing cache performance..."
    ./scripts/performance-test.sh cache

# Benchmark specific host build time
bench-host HOST RUNS="3":
    @echo "⏱️  Benchmarking {{HOST}} ({{RUNS}} runs)..."
    @total=0; for i in $$(seq 1 {{RUNS}}); do \
        echo "Run $$i/{{RUNS}}..."; \
        start=$$(date +%s.%N); \
        nix build .#nixosConfigurations.{{HOST}}.config.system.build.toplevel --no-link; \
        end=$$(date +%s.%N); \
        runtime=$$(echo "$$end - $$start" | bc); \
        total=$$(echo "$$total + $$runtime" | bc); \
        echo "Run $$i: $${runtime}s"; \
    done; \
    avg=$$(echo "scale=2; $$total / {{RUNS}}" | bc); \
    echo "Average time for {{HOST}}: $${avg}s"

# =============================================================================
# DEVELOPMENT AND DEBUGGING
# =============================================================================

# Show flake info
info:
    nix flake show

# Show flake metadata
metadata:
    nix flake metadata

# Update specific input
update-input INPUT:
    nix flake lock --update-input {{INPUT}}

# Check specific module syntax
check-module MODULE:
    nix-instantiate --parse {{MODULE}} > /dev/null && echo "✅ {{MODULE}} syntax is valid" || echo "❌ {{MODULE}} has syntax errors"

# Format all Nix files
format:
    find . -name "*.nix" -not -path "./result*" -not -path "./.git/*" | xargs alejandra

# Format specific file or directory
format-path PATH:
    alejandra {{PATH}}

# Show package derivation
show-drv PACKAGE:
    nix show-derivation .#{{PACKAGE}}

# Enter development shell for testing
dev-shell:
    nix develop

# Show what would be built for a configuration
show-build HOST:
    @echo "📋 Showing what would be built for {{HOST}}..."
    nixos-rebuild build --flake .#{{HOST}} --dry-run

# Trace evaluation of a specific option
trace-option HOST OPTION:
    @echo "🔍 Tracing option {{OPTION}} for {{HOST}}..."
    nix eval .#nixosConfigurations.{{HOST}}.config.{{OPTION}} --show-trace

# Debug specific module evaluation
debug-module HOST MODULE:
    @echo "🐛 Debugging module {{MODULE}} for {{HOST}}..."
    nix eval .#nixosConfigurations.{{HOST}}.config.modules.{{MODULE}} --show-trace

# Show configuration diff between two hosts
diff-hosts HOST1 HOST2:
    @echo "🔄 Comparing configurations between {{HOST1}} and {{HOST2}}..."
    @diff <(nix eval .#nixosConfigurations.{{HOST1}}.config --json | jq 'keys' | sort) \
          <(nix eval .#nixosConfigurations.{{HOST2}}.config --json | jq 'keys' | sort) || true

# =============================================================================
# CONTINUOUS INTEGRATION AND AUTOMATED TESTING
# =============================================================================

# Run full CI/CD testing pipeline
ci:
    @echo "🚀 Running CI/CD testing pipeline..."
    ./scripts/ci-test.sh

# Run quick CI tests (reduced scope)
ci-quick:
    @echo "⚡ Running quick CI tests..."
    ./scripts/ci-test.sh --quick

# Run CI with custom settings
ci-custom JOBS="4" TIMEOUT="600":
    @echo "🔧 Running CI with {{JOBS}} jobs and {{TIMEOUT}}s timeout..."
    ./scripts/ci-test.sh --jobs {{JOBS}} --timeout {{TIMEOUT}}

# Test only specific hosts in CI
ci-hosts HOSTS:
    @echo "🎯 Running CI for specific hosts: {{HOSTS}}..."
    CI_HOSTS={{HOSTS}} ./scripts/ci-test.sh

# =============================================================================
# ADVANCED TESTING AND UTILITIES
# =============================================================================

# Test configuration rollback capability
test-rollback:
    @echo "🔄 Testing configuration rollback..."
    @echo "Current generation: $$(nixos-rebuild list-generations | tail -n1)"
    @echo "Available generations:"
    nixos-rebuild list-generations | tail -n5

# Test configuration on a specific kernel version
test-kernel-version VERSION:
    @echo "🐧 Testing with kernel version {{VERSION}}..."
    nix build .#nixosConfigurations.$$(hostname).config.system.build.toplevel \
        --override-input nixpkgs github:nixos/nixpkgs/{{VERSION}} \
        --no-link --show-trace

# Test with different nixpkgs channels
test-nixpkgs-stable:
    @echo "📦 Testing with nixpkgs stable..."
    nix build .#nixosConfigurations.$$(hostname).config.system.build.toplevel \
        --override-input nixpkgs github:nixos/nixpkgs/nixos-24.05 \
        --no-link --show-trace

# Validate all user configurations
test-all-users:
    @echo "👥 Testing all user configurations..."
    @for user_dir in Users/*/; do \
        user=$$(basename "$$user_dir"); \
        echo "Testing user: $$user"; \
        for host in razer dex5550 p510 p620; do \
            if [ -f "Users/$$user/$${host}_home.nix" ]; then \
                echo "  Testing $$user@$$host..."; \
                nix build .#homeConfigurations.\"$$user@$$host\".activationPackage --no-link 2>/dev/null || echo "    ⚠️  Failed: $$user@$$host"; \
            fi; \
        done; \
    done


# Check for deprecated options
check-deprecated:
    @echo "⚠️  Checking for deprecated options..."
    @grep -r "mkDefault\|mkForce\|mkOverride" . --include="*.nix" | head -20 || echo "No deprecated patterns found"

# Check for security issues
security-scan:
    @echo "🔒 Running security scan..."
    @echo "Checking for hardcoded secrets..."
    @grep -r -i "password\|secret\|key" . --include="*.nix" --exclude-dir=secrets | grep -v "passwordFile\|secretFile\|keyFile" | head -10 || echo "No obvious hardcoded secrets found"
    @echo "Checking for overly permissive settings..."
    @grep -r "allowUnfree.*true\|permittedInsecurePackages" . --include="*.nix" | head -5 || echo "No overly permissive settings found"

# =============================================================================
# QUICK DEPLOYMENT SHORTCUTS
# =============================================================================

# Quick commands for common operations
quick-test:
    just test-all-parallel

quick-deploy HOST:
    just deploy-smart {{HOST}}

quick-all:
    @echo "🚀 Quick test and deploy all hosts..."
    just test-all-parallel
    @read -p "Tests passed! Deploy all? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
    just deploy-all-parallel

# Emergency deployment (skip tests)
emergency-deploy HOST:
    @echo "🚨 EMERGENCY deployment to {{HOST}} (skipping tests)..."
    @read -p "Are you sure? This skips all safety checks! (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
    nixos-rebuild switch --flake .#{{HOST}} --target-host {{HOST}} --build-host {{HOST}} --use-remote-sudo --fast --keep-going --no-build-nix --accept-flake-config

# =============================================================================
# UTILITIES AND HELPERS
# =============================================================================

# Clean up all build artifacts and caches
clean-all:
    @echo "🧹 Cleaning up everything..."
    sudo nix-collect-garbage -d
    nix-store --gc
    sudo nix-store --optimize
    rm -rf result*
    @echo "✅ Cleanup complete!"

# Create backup of current configuration
backup:
    @echo "💾 Creating configuration backup..."
    @timestamp=$$(date +%Y%m%d-%H%M%S); \
    backup_dir="$${HOME}/nixos-backup-$$timestamp"; \
    cp -r . "$$backup_dir"; \
    echo "✅ Backup created: $$backup_dir"

# Restore from backup
restore BACKUP_PATH:
    @echo "🔄 Restoring from backup: {{BACKUP_PATH}}..."
    @if [ -d "{{BACKUP_PATH}}" ]; then \
        cp -r {{BACKUP_PATH}}/* .; \
        echo "✅ Restore complete"; \
    else \
        echo "❌ Backup path not found: {{BACKUP_PATH}}"; \
    fi


# Interactive host selector for deployment
deploy-interactive:
    @echo "🎯 Interactive deployment"
    @echo "Available hosts:"
    @select host in razer dex5550 p510 p620 "Cancel"; do \
        case $$host in \
            "Cancel") echo "Deployment cancelled"; break ;; \
            "") echo "Invalid selection" ;; \
            *) echo "Deploying to $$host..."; just $$host; break ;; \
        esac; \
    done

# Watch for changes and auto-test
watch:
    @echo "👀 Watching for changes..."
    @echo "Will run 'just check' when .nix files change"
    @while inotifywait -r -e modify,create,delete --include='.*\.nix$$' . 2>/dev/null; do \
        echo "Change detected, running checks..."; \
        just check || true; \
        echo "Waiting for next change..."; \
    done

# =============================================================================
# SECRETS MANAGEMENT
# =============================================================================

# Manage secrets interactively
secrets:
    ./scripts/manage-secrets.sh

# Setup secrets for new host
setup-secrets:
    ./scripts/setup-secrets.sh

# Recover secrets (emergency)
recover-secrets:
    ./scripts/recover-secrets.sh

# Check secrets status
secrets-status:
    ./scripts/manage-secrets.sh status

# =============================================================================
# NETWORKING AND MONITORING
# =============================================================================

# Monitor network stability
network-monitor:
    ./scripts/network-monitor.sh

# Check network stability
network-check:
    ./scripts/network-stability-helper.sh

# =============================================================================
# HOST MANAGEMENT
# =============================================================================

# Deploy to all active hosts (be careful!)
deploy-all:
    @echo "🚨 Deploying to ALL active hosts..."
    @read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
    just razer
    just p620  
    just p510
    just dex5550

# Deploy to all hosts in parallel (FASTEST)
deploy-all-parallel:
    @echo "🚀 Deploying to ALL hosts in parallel..."
    @read -p "Are you sure? This will max out resources! (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
    @echo "Starting parallel deployments..."
    ( just razer & echo "Razer started" ) & \
    ( just p620 & echo "P620 started" ) & \
    ( just p510 & echo "P510 started" ) & \
    ( just dex5550 & echo "DEX5550 started" ) & \
    wait && echo "✅ All deployments completed!"

# Fast deployment with minimal builds
deploy-fast HOST:
    @echo "⚡ Fast deployment to {{HOST}}..."
    nixos-rebuild switch --flake .#{{HOST}} --target-host {{HOST}} --build-host {{HOST}} --use-remote-sudo --fast --keep-going --no-build-nix --accept-flake-config

# Build locally, deploy remotely (for slow remote hosts)
deploy-local-build HOST:
    @echo "🏗️ Building {{HOST}} locally, deploying remotely..."
    nixos-rebuild switch --flake .#{{HOST}} --target-host {{HOST}} --use-remote-sudo --fast --keep-going --accept-flake-config

# Deploy only if changed (smart deployment)
deploy-smart HOST:
    @echo "🧠 Smart deployment to {{HOST}}..."
    @if nix build .#nixosConfigurations.{{HOST}}.config.system.build.toplevel --no-link --print-out-paths | \
     grep -q "$(ssh {{HOST}} readlink /run/current-system 2>/dev/null || echo 'no-current')"; then \
        echo "🔄 No changes detected for {{HOST}}, skipping deployment"; \
    else \
        echo "📝 Changes detected, deploying to {{HOST}}..."; \
        just {{HOST}}; \
    fi

# Parallel build for all hosts (build only, no deployment)
build-all-parallel:
    @echo "🔨 Building all configurations in parallel..."
    ( nix build .#nixosConfigurations.razer.config.system.build.toplevel --no-link & echo "Building Razer..." ) & \
    ( nix build .#nixosConfigurations.p620.config.system.build.toplevel --no-link & echo "Building P620..." ) & \
    ( nix build .#nixosConfigurations.p510.config.system.build.toplevel --no-link & echo "Building P510..." ) & \
    ( nix build .#nixosConfigurations.dex5550.config.system.build.toplevel --no-link & echo "Building DEX5550..." ) & \
    wait && echo "✅ All builds completed!"

# Deploy with binary cache optimization
deploy-cached HOST:
    @echo "💾 Deploying {{HOST}} with cache optimization..."
    nixos-rebuild switch --flake .#{{HOST}} --target-host {{HOST}} --build-host {{HOST}} --use-remote-sudo --fast --keep-going --option binary-caches "https://cache.nixos.org/ http://p620:5000" --accept-flake-config

# Test all hosts can be reached
ping-hosts:
    @echo "🏓 Pinging all hosts..."
    @for host in razer p620 p510 dex5550; do \
        echo -n "$$host: "; \
        ping -c 1 -W 2 $$host >/dev/null 2>&1 && echo "✅ reachable" || echo "❌ unreachable"; \
    done

# Show status of all hosts
status-all:
    @echo "📊 Checking status of all hosts..."
    just ping-hosts

# =============================================================================
# HELP AND INFORMATION
# =============================================================================

# Show extended help with examples
help-extended:
    @echo "🔧 NixOS Configuration Management - Extended Help"
    @echo ""
    @echo "🚀 QUICK START:"
    @echo "  just validate          # Run all validation tests"
    @echo "  just test-host p620    # Test specific host"
    @echo "  just deploy            # Deploy to local system"
    @echo "  just p620              # Deploy to p620 host"
    @echo ""
    @echo "⚡ FAST DEPLOYMENT:"
    @echo "  just quick-test        # Parallel test all hosts"
    @echo "  just quick-deploy p620 # Smart deploy (only if changed)"
    @echo "  just quick-all         # Test all, then deploy all"
    @echo "  just deploy-fast p620  # Fast deploy with minimal builds"
    @echo "  just deploy-all-parallel # Deploy all hosts in parallel"
    @echo ""
    @echo "🧪 TESTING:"
    @echo "  just test-all-parallel # Test all hosts in parallel"
    @echo "  just ci                # Full CI pipeline"
    @echo "  just ci-quick          # Quick CI tests"
    @echo "  just test-all          # Test all configurations"
    @echo "  just perf-test         # Performance benchmarks"
    @echo ""
    @echo "🔧 DEVELOPMENT:"
    @echo "  just format            # Format all Nix files"
    @echo "  just check-syntax      # Check syntax"
    @echo "  just test-modules      # Test module structure"
    @echo ""
    @echo "📦 MAINTENANCE:"
    @echo "  just update            # Update system"
    @echo "  just gc                # Garbage collect"
    @echo "  just clean-all         # Deep clean"
    @echo ""
    @echo "For full command list: just --list"

# Show configuration summary
summary:
    #!/usr/bin/env bash
    echo "📋 NixOS Configuration Summary"
    echo "=============================="
    echo "Active hosts: razer, dex5550, p510, p620"
    echo "Users: $(ls Users/ | grep -v README | tr '\n' ' ')"
    echo "Modules: $(find modules -name '*.nix' -not -name 'default.nix' | wc -l) modules"
    echo "Last update: $(stat -c %y flake.lock | cut -d' ' -f1)"
    echo "Git status: $(git status --porcelain | wc -l) changed files"
    echo ""
    echo "Recent commands to try:"
    echo "  just validate         # Validate everything"
    echo "  just test-host p620   # Test single host"
    echo "  just ci-quick         # Quick tests"


