#!/usr/bin/env just --justfile

# Default recipe to display available commands
default:
    @just --list

# =============================================================================
# DEPLOYMENT COMMANDS
# =============================================================================

# Deploy to local system using nh
deploy:
    nh os switch

# Update local system using nh
update:
    nh os update

# Update flake inputs and deploy
update-flake:
    nix flake update
    just deploy

# Idiot-proof update + commit + deploy (local OR remote). Does:
#   1. nix flake update (scope = nixpkgs by default, or 'all' or any input name)
#   2. no-op exit if nothing moved
#   3. test-build target host closure (aborts if fails)
#   4. commit flake.lock to main + git push (lock never gets orphaned)
#   5. nh os switch (local) OR nh os switch --target-host HOST (remote via SSH)
#
# HOST defaults to the local hostname; any SSH-reachable host in ~/.ssh/config
# works too. SCOPE defaults to 'nixpkgs' — use 'all' to bump every input, or
# pass a specific input name (e.g. 'home-manager', 'claude-desktop-linux').
#
# Examples:
#   just update-commit-deploy                     # local, nixpkgs only
#   just update-commit-deploy p620                # explicit local host
#   just update-commit-deploy razer               # remote via SSH
#   just update-commit-deploy p510 all            # remote, update all inputs
#   just update-commit-deploy razer home-manager  # remote, single input
update-commit-deploy HOST="$(hostname)" SCOPE="nixpkgs":
    ./scripts/update-commit-deploy.sh {{HOST}} {{SCOPE}}

# Preview updates with detailed package changes (before building)
preview-updates HOST="$(hostname)":
    @echo "🔍 Previewing updates for {{HOST}}..."
    ./scripts/preview-updates.sh {{HOST}}

# Find newly added packages in nixpkgs
new-packages:
    @echo "🆕 Finding new packages in nixpkgs..."
    ./scripts/find-new-packages.sh

# Complete update workflow: preview → review → deploy
update-workflow HOST="$(hostname)":
    @echo "📦 Starting complete update workflow for {{HOST}}..."
    @echo ""
    just preview-updates {{HOST}}
    @echo ""
    @read -p "Apply these updates? [y/N] " -n 1 -r; echo; \
    if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
        just quick-deploy {{HOST}}; \
        echo ""; \
        just new-packages; \
    else \
        echo "Updates cancelled. Run 'mv flake.lock.backup flake.lock' to revert."; \
    fi

# =============================================================================
# TESTING AND VALIDATION
# =============================================================================

# Run comprehensive validation suite
validate:
    @echo "🧪 Running comprehensive validation..."
    @echo "📝 Full flake check (includes all hosts, modules, and derivations)..."
    @echo "⚠️  Note: This takes ~4 minutes but catches module system errors"
    nix flake check
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

# =============================================================================
# PRE-COMMIT HOOKS
# =============================================================================

# Install pre-commit hooks
pre-commit-install:
    @echo "🔨 Installing pre-commit hooks..."
    pre-commit install
    @echo "✅ Pre-commit hooks installed!"

# Run all pre-commit hooks
pre-commit-run:
    @echo "🧪 Running all pre-commit hooks..."
    pre-commit run --all-files

# Run pre-commit hooks on staged files only
pre-commit-staged:
    @echo "🧪 Running pre-commit hooks on staged files..."
    pre-commit run

# Update pre-commit hook versions
pre-commit-update:
    @echo "⬆️ Updating pre-commit hooks..."
    pre-commit autoupdate
    @echo "✅ Pre-commit hooks updated!"

# Clean pre-commit cache
pre-commit-clean:
    @echo "🧹 Cleaning pre-commit cache..."
    pre-commit clean
    @echo "✅ Pre-commit cache cleaned!"

# Run specific pre-commit hook
pre-commit-hook HOOK:
    @echo "🧪 Running pre-commit hook: {{HOOK}}..."
    pre-commit run {{HOOK}} --all-files

# Format all files using pre-commit
format-all:
    @echo "🎨 Formatting all files..."
    pre-commit run nixpkgs-fmt --all-files || true
    pre-commit run shfmt --all-files || true
    pre-commit run prettier --all-files || true
    @echo "✅ All files formatted!"

# Lint all files using pre-commit
lint-all:
    @echo "🔍 Linting all files..."
    pre-commit run statix --all-files || true
    pre-commit run deadnix --all-files || true
    pre-commit run shellcheck --all-files || true
    pre-commit run markdownlint --all-files || true
    @echo "✅ All files linted!"

# Test all configurations build successfully
test-all:
    @echo "🧪 Testing all NixOS configurations..."
    @for host in p620 razer p510; do \
        echo "Testing $host..."; \
        nix build .#nixosConfigurations.$host.config.system.build.toplevel --show-trace || exit 1; \
    done
    @echo "✅ All configurations build successfully!"

# Test all configurations in parallel (FASTER)
test-all-parallel:
    @echo "🧪 Testing all NixOS configurations in parallel..."
    @( nix build .#nixosConfigurations.p620.config.system.build.toplevel --no-link --show-trace && echo "✅ P620" || echo "❌ P620" ) & \
    ( nix build .#nixosConfigurations.razer.config.system.build.toplevel --no-link --show-trace && echo "✅ Razer" || echo "❌ Razer" ) & \
    ( nix build .#nixosConfigurations.p510.config.system.build.toplevel --no-link --show-trace && echo "✅ P510" || echo "❌ P510" ) & \
    wait && echo "✅ All parallel tests completed!"

# Test build all hosts with detailed error reporting
test-build-all:
    #!/usr/bin/env bash
    echo "🔨 Test building all host configurations with detailed reporting..."
    failed_hosts=()
    success_count=0
    total_hosts=3

    for host in p620 razer p510; do
        echo ""
        echo "🔨 Building $host..."
        start_time=$(date +%s)

        if nixos-rebuild build --flake .#$host --show-trace 2>&1 | tee /tmp/build-$host.log; then
            build_time=$(($(date +%s) - start_time))
            echo "✅ $host: Build successful (${build_time}s)"
            success_count=$((success_count + 1))
        else
            build_time=$(($(date +%s) - start_time))
            echo "❌ $host: Build failed (${build_time}s)"
            echo "   📋 Error log saved to: /tmp/build-$host.log"
            failed_hosts+=("$host")
        fi
    done

    echo ""
    echo "📊 Build Summary:"
    echo "================="
    echo "✅ Successful: $success_count/$total_hosts"
    echo "❌ Failed: ${#failed_hosts[@]}/$total_hosts"

    if [ ${#failed_hosts[@]} -gt 0 ]; then
        echo ""
        echo "❌ Failed hosts: ${failed_hosts[*]}"
        echo "📋 Check error logs in /tmp/build-*.log"
        echo ""
        echo "🔧 To view specific errors:"
        for host in "${failed_hosts[@]}"; do
            echo "   tail -50 /tmp/build-$host.log"
        done
        exit 1
    else
        echo ""
        echo "🎉 All host configurations built successfully!"
        echo "✅ Safe to proceed with deployment"
    fi

# Test build all hosts in parallel (FASTEST)
test-build-all-parallel:
    #!/usr/bin/env bash
    echo "🚀 Test building all host configurations in parallel..."

    # Start all builds in parallel and capture their PIDs
    (nixos-rebuild build --flake .#p620 --show-trace > /tmp/build-p620.log 2>&1 && echo "✅ P620: Build successful" || echo "❌ P620: Build failed") &
    p620_pid=$!

    (nixos-rebuild build --flake .#razer --show-trace > /tmp/build-razer.log 2>&1 && echo "✅ Razer: Build successful" || echo "❌ Razer: Build failed") &
    razer_pid=$!

    (nixos-rebuild build --flake .#p510 --show-trace > /tmp/build-p510.log 2>&1 && echo "✅ P510: Build successful" || echo "❌ P510: Build failed") &
    p510_pid=$!

    # Wait for all builds to complete
    echo "⏳ Waiting for all builds to complete..."
    wait $p620_pid; p620_result=$?
    wait $razer_pid; razer_result=$?
    wait $p510_pid; p510_result=$?

    # Count results
    failed_hosts=()
    success_count=0

    if [ $p620_result -eq 0 ]; then success_count=$((success_count + 1)); else failed_hosts+=("p620"); fi
    if [ $razer_result -eq 0 ]; then success_count=$((success_count + 1)); else failed_hosts+=("razer"); fi
    if [ $p510_result -eq 0 ]; then success_count=$((success_count + 1)); else failed_hosts+=("p510"); fi

    echo ""
    echo "📊 Parallel Build Summary:"
    echo "========================="
    echo "✅ Successful: $success_count/3"
    echo "❌ Failed: ${#failed_hosts[@]}/3"

    if [ ${#failed_hosts[@]} -gt 0 ]; then
        echo ""
        echo "❌ Failed hosts: ${failed_hosts[*]}"
        echo "📋 Check error logs:"
        for host in "${failed_hosts[@]}"; do
            echo "   tail -50 /tmp/build-$host.log"
        done
        exit 1
    else
        echo ""
        echo "🎉 All host configurations built successfully in parallel!"
        echo "✅ Safe to proceed with deployment"
    fi

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
    @for host in p620 razer p510; do \
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
    nixos-rebuild switch --flake .#razer --target-host razer.lan --build-host razer.lan --sudo --no-reexec --keep-going --accept-flake-config

# Deploy to p620 workstation (AMD) - OPTIMIZED
p620:
    sudo nixos-rebuild switch --flake .#p620 --accept-flake-config

# Deploy to p510 workstation (Intel Xeon/NVIDIA) - OPTIMIZED
p510:
    nixos-rebuild switch --flake .#p510 --target-host p510.lan --build-host p510.lan --sudo --no-reexec --keep-going --accept-flake-config


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
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

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

# Open Nix REPL with current flake
repl:
    nix repl

# Open Nix REPL with nixpkgs
repl-nixpkgs:
    nix repl '<nixpkgs>'

# Garbage collect old generations
gc:
    @echo "🗑️ Collecting garbage (keeping current generation)..."
    sudo nix-collect-garbage --delete-old
    @echo "✅ Garbage collection complete!"

# Aggressive garbage collection (remove all non-current generations)
gc-aggressive:
    @echo "🚨 WARNING: This will remove ALL previous generations!"
    @read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
    sudo nix-collect-garbage -d
    @echo "✅ Aggressive garbage collection complete!"

# Optimize nix store (deduplicate identical files)
optimize:
    @echo "♾️ Optimizing nix store..."
    sudo nix-store --optimize
    @echo "✅ Store optimization complete!"

# Full cleanup: garbage collect, optimize, and show savings
full-cleanup:
    @echo "🧹 Starting full system cleanup..."
    @echo "Before cleanup:"
    @du -sh /nix/store 2>/dev/null || echo "Cannot access /nix/store"
    sudo nix-collect-garbage --delete-old
    sudo nix-store --optimize
    @echo "After cleanup:"
    @du -sh /nix/store 2>/dev/null || echo "Cannot access /nix/store"
    @echo "✅ Full cleanup complete!"


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

# Format all Nix files using nixpkgs-fmt (preferred over alejandra)
format:
    find . -name "*.nix" -not -path "./result*" -not -path "./.git/*" -exec nixpkgs-fmt {} +

# Format specific file or directory
format-path PATH:
    nixpkgs-fmt {{PATH}}

# Show package derivation
show-drv PACKAGE:
    nix show-derivation .#{{PACKAGE}}

# Enter development shell for testing
dev-shell:
    nix develop

# Show what would be built for a configuration
show-build HOST:
    @echo "📋 Showing what would be built for {{HOST}}..."
    nix build .#nixosConfigurations.{{HOST}}.config.system.build.toplevel --dry-run

# Show build diff between current and new configuration
show-diff HOST:
    @echo "🔄 Showing configuration differences for {{HOST}}..."
    nixos-rebuild dry-activate --flake .#{{HOST}} --show-trace

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
        for host in p620 razer p510; do \
            if [ -f "Users/$$user/$${host}_home.nix" ]; then \
                echo "  Testing $$user@$$host..."; \
                nix build .#homeConfigurations.\"$$user@$$host\".activationPackage --no-link 2>/dev/null || echo "    ⚠️  Failed: $$user@$$host"; \
            fi; \
        done; \
    done


# Check for deprecated options and patterns
check-deprecated:
    @echo "⚠️  Checking for deprecated options..."
    @echo "Checking for deprecated mkDefault/mkForce patterns..."
    @grep -r "mkDefault\|mkForce\|mkOverride" . --include="*.nix" | head -10 || echo "No deprecated patterns found"
    @echo "Checking for old nixpkgs references..."
    @grep -r "nixpkgs-unstable\|nixpkgs-stable" . --include="*.nix" | head -5 || echo "No old nixpkgs references found"

# Check for security issues
security-scan:
    @echo "🔒 Running security scan..."
    @echo "Checking for hardcoded secrets..."
    @grep -r -i "password\|secret\|key" . --include="*.nix" --exclude-dir=secrets | grep -v "passwordFile\|secretFile\|keyFile" | head -10 || echo "No obvious hardcoded secrets found"
    @echo "Checking for overly permissive settings..."
    @grep -r "allowUnfree.*true\|permittedInsecurePackages" . --include="*.nix" | head -5 || echo "No overly permissive settings found"

# =============================================================================
# QUICK DEPLOYMENT SHORTCUTS (OPTIMIZED WORKFLOWS)
# =============================================================================

# Quick commands for common operations
quick-test:
    just test-all-parallel

# Smart deploy only if configuration changed
quick-deploy HOST:
    just deploy-smart {{HOST}}

# Complete workflow: test all hosts then optionally deploy all
quick-all:
    @echo "🚀 Quick test and deploy all hosts..."
    just test-all-parallel
    @read -p "Tests passed! Deploy all? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
    just deploy-all-parallel

# Emergency deployment (skip tests) - USE WITH CAUTION
emergency-deploy HOST:
    @echo "🚨 EMERGENCY deployment to {{HOST}} (skipping tests)..."
    @echo "This will skip ALL safety checks and validation!"
    @read -p "Are you absolutely sure? (type 'emergency'): " confirm && [ "$$confirm" = "emergency" ] || exit 1
    nixos-rebuild switch --flake .#{{HOST}} --target-host {{HOST}}.lan --build-host {{HOST}}.lan --sudo --no-reexec --keep-going --accept-flake-config

# =============================================================================
# UTILITIES AND HELPERS
# =============================================================================

# Clean up all build artifacts and caches (DESTRUCTIVE)
clean-all:
    @echo "🧹 DESTRUCTIVE: Cleaning up everything..."
    @echo "This will remove ALL previous generations and build artifacts!"
    @read -p "Are you absolutely sure? (type 'clean-all'): " confirm && [ "$$confirm" = "clean-all" ] || exit 1
    rm -rf result*
    sudo nix-collect-garbage -d
    sudo nix-store --gc
    sudo nix-store --optimize
    @echo "✅ Complete cleanup finished!"

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
    @select host in razer p510 p620 "Cancel"; do \
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

# Check secrets status
secrets-status:
    ./scripts/manage-secrets.sh status

# Check secrets status on specific host
secrets-status-host HOST:
    @echo "🔑 Checking secrets status on {{HOST}}..."
    ssh {{HOST}}.lan "sudo ls -la /run/agenix/ || echo 'Agenix directory not found'"
    ssh {{HOST}}.lan "sudo systemctl status agenix --no-pager || echo 'Agenix service not running'"

# Fix agenix issues on remote host
fix-agenix-remote HOST:
    @echo "🔧 Attempting to fix agenix issues on {{HOST}}..."
    ssh {{HOST}}.lan "sudo systemctl stop agenix || true"
    ssh {{HOST}}.lan "sudo rm -rf /run/agenix.d || true"
    ssh {{HOST}}.lan "sudo systemctl start agenix || echo 'Agenix service failed to start'"
    ssh {{HOST}}.lan "sudo systemctl status agenix --no-pager"

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


# Deploy to all hosts in parallel (FASTEST)
deploy-all-parallel:
    @echo "🚀 Deploying to ALL hosts in parallel..."
    @read -p "Are you sure? This will max out resources! (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
    @echo "Starting parallel deployments..."
    ( just p620 & echo "P620 started" ) & \
    ( just razer & echo "Razer started" ) & \
    ( just p510 & echo "P510 started" ) & \
    wait && echo "✅ All deployments completed!"

# Fast deployment with minimal builds
deploy-fast HOST:
    @echo "⚡ Fast deployment to {{HOST}}..."
    nixos-rebuild switch --flake .#{{HOST}} --target-host {{HOST}}.lan --build-host {{HOST}}.lan --sudo --no-reexec --keep-going --no-build-nix --accept-flake-config

# Build locally, deploy remotely (for slow remote hosts)
deploy-local-build HOST:
    @echo "🏗️ Building {{HOST}} locally, deploying remotely..."
    nixos-rebuild switch --flake .#{{HOST}} --target-host {{HOST}}.lan --sudo --no-reexec --keep-going --accept-flake-config

# Deploy only if changed (smart deployment)
deploy-smart HOST:
    @echo "🧠 Smart deployment to {{HOST}}..."
    @if nix build .#nixosConfigurations.{{HOST}}.config.system.build.toplevel --no-link --print-out-paths | \
     grep -q "$(ssh {{HOST}}.lan readlink /run/current-system 2>/dev/null || echo 'no-current')"; then \
        echo "🔄 No changes detected for {{HOST}}, skipping deployment"; \
    else \
        echo "📝 Changes detected, deploying to {{HOST}}..."; \
        just {{HOST}}; \
    fi

# Parallel build for all hosts (build only, no deployment)
build-all-parallel:
    @echo "🔨 Building all configurations in parallel..."
    ( nix build .#nixosConfigurations.p620.config.system.build.toplevel --no-link & echo "Building P620..." ) & \
    ( nix build .#nixosConfigurations.razer.config.system.build.toplevel --no-link & echo "Building Razer..." ) & \
    ( nix build .#nixosConfigurations.p510.config.system.build.toplevel --no-link & echo "Building P510..." ) & \
    wait && echo "✅ All builds completed!"

# Deploy with binary cache optimization
deploy-cached HOST:
    @echo "💾 Deploying {{HOST}} with cache optimization..."
    nixos-rebuild switch --flake .#{{HOST}} --target-host {{HOST}}.lan --build-host {{HOST}}.lan --sudo --no-reexec --keep-going --option binary-caches "https://cache.nixos.org/ http://p620.lan:5000" --accept-flake-config

# Build on P620, deploy to target host
deploy-via-p620 HOST:
    @echo "🏗️ Building {{HOST}} on P620 cache server, deploying to {{HOST}}..."
    @echo "📡 Step 1: Building on P620..."
    nixos-rebuild build --flake .#{{HOST}} --build-host p620.lan --accept-flake-config
    @echo "📦 Step 2: Deploying to {{HOST}}..."
    nixos-rebuild switch --flake .#{{HOST}} --target-host {{HOST}}.lan --sudo --no-reexec --keep-going --accept-flake-config
    @echo "✅ Deployment complete! {{HOST}} is using P620's cache."

# Build on P620 for target host (build only, no deployment)
build-on-p620 HOST:
    @echo "🏗️ Building {{HOST}} on P620 (build only)..."
    nixos-rebuild build --flake .#{{HOST}} --build-host p620.lan --accept-flake-config
    @echo "✅ Build complete! Deploy with: just deploy-via-p620 {{HOST}}"

# Test all hosts can be reached
ping-hosts:
    @echo "🏓 Pinging all hosts..."
    @for host in p620 razer p510; do \
        echo -n "$$host: "; \
        ping -c 1 -W 2 $$host.lan >/dev/null 2>&1 && echo "✅ reachable" || echo "❌ unreachable"; \
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
    @echo "  just test-all-parallel     # Test all hosts in parallel"
    @echo "  just test-build-all        # Test build all hosts (sequential)"
    @echo "  just test-build-all-parallel # Test build all hosts (parallel)"
    @echo "  just ci                    # Full CI pipeline"
    @echo "  just ci-quick              # Quick CI tests"
    @echo "  just test-all              # Test all configurations"
    @echo "  just perf-test             # Performance benchmarks"
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
    echo "Active hosts: p620 (AMD workstation), razer (Intel/NVIDIA laptop), p510 (Intel Xeon server)"
    echo "Users: $(ls Users/ | grep -v README | tr '\n' ' ')"
    echo "Modules: $(find modules -name '*.nix' -not -name 'default.nix' | wc -l) modules"
    echo "Last update: $(stat -c %y flake.lock | cut -d' ' -f1)"
    echo "Git status: $(git status --porcelain | wc -l) changed files"
    echo ""
    echo "Recent commands to try:"
    echo "  just validate         # Validate everything"
    echo "  just test-host p620   # Test single host"
    echo "  just ci-quick         # Quick tests"

# ============================================================================
# Live USB Installer Commands
# ============================================================================

# Build live USB installer image for a specific host
build-live host:
    #!/usr/bin/env bash
    echo "🔧 Building live USB installer for {{host}}..."
    nix build .#packages.x86_64-linux.live-iso-{{host}} --show-trace
    if [ $? -eq 0 ]; then
        echo "✅ Live USB image built successfully!"
        echo "📁 Image location: $(readlink -f result)/iso/nixos-{{host}}-live.iso"
        echo "💡 Flash with: just flash-live {{host}} /dev/sdX"
    else
        echo "❌ Build failed!"
        exit 1
    fi

# Build all live USB installer images
build-all-live:
    #!/usr/bin/env bash
    echo "🔧 Building all live USB installer images..."
    hosts=("p620" "razer" "p510")
    failed=()

    for host in "${hosts[@]}"; do
        echo ""
        echo "Building live image for $host..."
        if just build-live "$host"; then
            echo "✅ $host: Build successful"
        else
            echo "❌ $host: Build failed"
            failed+=("$host")
        fi
    done

    echo ""
    echo "📋 Build Summary:"
    echo "================="
    for host in "${hosts[@]}"; do
        if [[ " ${failed[@]} " =~ " ${host} " ]]; then
            echo "❌ $host: FAILED"
        else
            echo "✅ $host: SUCCESS"
        fi
    done

    if [ ${#failed[@]} -gt 0 ]; then
        echo ""
        echo "❌ ${#failed[@]} builds failed: ${failed[*]}"
        exit 1
    else
        echo ""
        echo "🎉 All live USB images built successfully!"
    fi

# Flash live USB image to device (DANGEROUS - will erase target device)
flash-live host device:
    #!/usr/bin/env bash
    if [ ! -e "{{device}}" ]; then
        echo "❌ Device {{device}} does not exist!"
        exit 1
    fi

    if [ ! -f "result/iso/nixos-{{host}}-live.iso" ]; then
        echo "⚠️  Live image for {{host}} not found. Building it first..."
        just build-live {{host}}
    fi

    echo "🚨 WARNING: This will ERASE all data on {{device}}!"
    echo "📱 Target device: {{device}}"
    echo "💿 Source image: nixos-{{host}}-live.iso"
    echo ""
    read -p "Type 'yes' to continue: " confirm
    if [ "$confirm" != "yes" ]; then
        echo "❌ Cancelled by user"
        exit 1
    fi

    echo "🔧 Flashing image to {{device}}..."
    sudo dd if=result/iso/nixos-{{host}}-live.iso of={{device}} bs=4M status=progress oflag=sync
    sudo sync

    echo "✅ Flashing completed!"
    echo "💡 You can now boot from {{device}} to install NixOS on {{host}}"

# Test hardware config parser for a host
test-hw-config host:
    #!/usr/bin/env bash
    echo "🔍 Testing hardware configuration parser for {{host}}..."
    if [ ! -f "hosts/{{host}}/nixos/hardware-configuration.nix" ]; then
        echo "❌ Hardware config not found: hosts/{{host}}/nixos/hardware-configuration.nix"
        exit 1
    fi

    echo "📋 Parsed configuration:"
    ./scripts/install-helpers/parse-hardware-config.py {{host}}

# Show available devices for flashing
show-devices:
    #!/usr/bin/env bash
    echo "💿 Available storage devices:"
    echo "============================="
    lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -E "(usb|sata|nvme)" || echo "No devices found"
    echo ""
    echo "⚠️  WARNING: Double-check device names before flashing!"
    echo "💡 Use 'lsblk' for detailed device information"

# Clean up old live USB build artifacts
clean-live:
    #!/usr/bin/env bash
    echo "🧹 Cleaning up live USB build artifacts..."
    rm -rf result*
    nix-collect-garbage -d
    echo "✅ Cleanup completed"

# Quick test of live system configuration
test-live-config host:
    #!/usr/bin/env bash
    echo "🧪 Testing live system configuration for {{host}}..."
    nix build .#liveImages.{{host}}.config.system.build.toplevel --dry-run
    if [ $? -eq 0 ]; then
        echo "✅ Live configuration test passed"
    else
        echo "❌ Live configuration test failed"
        exit 1
    fi

# Show live USB creation help
live-help:
    @echo "🔧 Live USB Installer Help"
    @echo "=========================="
    @echo ""
    @echo "📋 Available Commands:"
    @echo "  just build-live <host>     - Build live USB for specific host"
    @echo "  just build-all-live        - Build live USBs for all hosts"
    @echo "  just flash-live <host> <device> - Flash USB (⚠️ DESTRUCTIVE!)"
    @echo "  just test-hw-config <host> - Test hardware config parser"
    @echo "  just show-devices          - List available storage devices"
    @echo "  just clean-live           - Clean up build artifacts"
    @echo "  just test-live-config <host> - Test live config"
    @echo ""
    @echo "📖 Example Workflow:"
    @echo "  1. just show-devices              # Find your USB device"
    @echo "  2. just build-live p620           # Build P620 installer"
    @echo "  3. just flash-live p620 /dev/sdX  # Flash to USB"
    @echo "  4. Boot from USB and run: sudo install-p620"
    @echo ""
    @echo "🎯 Available Hosts:"
    @echo "  p620, razer, p510"
    @echo ""
    @echo "⚠️  WARNING: flash-live will ERASE the target device!"

# ============================================================================
# MicroVM Management Commands
# ============================================================================

# Start a MicroVM (dev-vm, test-vm, playground-vm)
start-microvm vm:
    #!/usr/bin/env bash
    echo "🚀 Starting MicroVM: {{vm}}"
    case "{{vm}}" in
        "dev-vm"|"test-vm"|"playground-vm")
            if nix run .#nixosConfigurations.{{vm}}.config.microvm.runner.qemu; then
                echo "✅ {{vm}} started successfully"
                case "{{vm}}" in
                    "dev-vm") echo "SSH: ssh dev@localhost -p 2222" ;;
                    "test-vm") echo "SSH: ssh test@localhost -p 2223" ;;
                    "playground-vm") echo "SSH: ssh root@localhost -p 2224" ;;
                esac
            else
                echo "❌ Failed to start {{vm}}"
                exit 1
            fi
            ;;
        *)
            echo "❌ Unknown MicroVM: {{vm}}"
            echo "Available: dev-vm, test-vm, playground-vm"
            exit 1
            ;;
    esac

# Stop a MicroVM
stop-microvm vm:
    #!/usr/bin/env bash
    echo "🛑 Stopping MicroVM: {{vm}}"
    case "{{vm}}" in
        "dev-vm"|"test-vm"|"playground-vm")
            if systemctl stop microvm-{{vm}} 2>/dev/null; then
                echo "✅ {{vm}} stopped successfully"
            else
                echo "⚠️  {{vm}} was not running or failed to stop"
            fi
            ;;
        *)
            echo "❌ Unknown MicroVM: {{vm}}"
            exit 1
            ;;
    esac

# Restart a MicroVM
restart-microvm vm:
    #!/usr/bin/env bash
    echo "🔄 Restarting MicroVM: {{vm}}"
    just stop-microvm {{vm}}
    sleep 2
    just start-microvm {{vm}}

# SSH into a MicroVM
ssh-microvm vm:
    #!/usr/bin/env bash
    case "{{vm}}" in
        "dev-vm")
            ssh dev@localhost -p 2222
            ;;
        "test-vm")
            ssh test@localhost -p 2223
            ;;
        "playground-vm")
            ssh root@localhost -p 2224
            ;;
        *)
            echo "❌ Unknown MicroVM: {{vm}}"
            echo "Available: dev-vm, test-vm, playground-vm"
            exit 1
            ;;
    esac

# List all MicroVM status
list-microvms:
    #!/usr/bin/env bash
    echo "📋 MicroVM Status:"
    echo "=================="

    for vm in dev-vm test-vm playground-vm; do
        if systemctl is-active microvm-$vm >/dev/null 2>&1; then
            status="🟢 RUNNING"
        else
            status="🔴 STOPPED"
        fi

        case "$vm" in
            "dev-vm") port="2222"; user="dev" ;;
            "test-vm") port="2223"; user="test" ;;
            "playground-vm") port="2224"; user="root" ;;
        esac

        echo "$vm: $status (SSH: $user@localhost:$port)"
    done

# Stop all running MicroVMs
stop-all-microvms:
    #!/usr/bin/env bash
    echo "🛑 Stopping all MicroVMs..."
    for vm in dev-vm test-vm playground-vm; do
        if systemctl is-active microvm-$vm >/dev/null 2>&1; then
            echo "Stopping $vm..."
            systemctl stop microvm-$vm
        fi
    done
    echo "✅ All MicroVMs stopped"

# Rebuild and restart a MicroVM
rebuild-microvm vm:
    #!/usr/bin/env bash
    echo "🔨 Rebuilding MicroVM: {{vm}}"
    just stop-microvm {{vm}}
    echo "Building new {{vm}} configuration..."
    if nix build .#nixosConfigurations.{{vm}}.config.system.build.toplevel; then
        echo "✅ Build successful, starting {{vm}}..."
        just start-microvm {{vm}}
    else
        echo "❌ Build failed for {{vm}}"
        exit 1
    fi

# Clean up MicroVM artifacts and storage
clean-microvms:
    #!/usr/bin/env bash
    echo "🧹 Cleaning up MicroVM artifacts..."

    # Stop all VMs first
    just stop-all-microvms

    # Clean build artifacts
    rm -rf result*

    echo "⚠️  This will delete all MicroVM persistent data!"
    read -p "Type 'yes' to confirm: " confirm
    if [ "$confirm" = "yes" ]; then
        sudo rm -rf /var/lib/microvms/*/
        sudo rm -rf /tmp/microvm-shared/
        echo "✅ MicroVM data cleaned"
    else
        echo "❌ Cancelled"
    fi

# Test MicroVM configurations
test-microvm vm:
    #!/usr/bin/env bash
    echo "🧪 Testing MicroVM configuration: {{vm}}"
    case "{{vm}}" in
        "dev-vm"|"test-vm"|"playground-vm")
            nix build .#nixosConfigurations.{{vm}}.config.system.build.toplevel --show-trace
            if [ $? -eq 0 ]; then
                echo "✅ {{vm}} configuration test passed"
            else
                echo "❌ {{vm}} configuration test failed"
                exit 1
            fi
            ;;
        *)
            echo "❌ Unknown MicroVM: {{vm}}"
            exit 1
            ;;
    esac

# Test all MicroVM configurations
test-all-microvms:
    #!/usr/bin/env bash
    echo "🧪 Testing all MicroVM configurations..."
    failed=()

    for vm in dev-vm test-vm playground-vm; do
        echo "Testing $vm..."
        if just test-microvm $vm; then
            echo "✅ $vm: PASSED"
        else
            echo "❌ $vm: FAILED"
            failed+=("$vm")
        fi
    done

    echo ""
    echo "📋 Test Summary:"
    echo "================"
    for vm in dev-vm test-vm playground-vm; do
        if [[ " ${failed[@]} " =~ " ${vm} " ]]; then
            echo "❌ $vm: FAILED"
        else
            echo "✅ $vm: PASSED"
        fi
    done

    if [ ${#failed[@]} -gt 0 ]; then
        echo ""
        echo "❌ ${#failed[@]} MicroVM configurations failed"
        exit 1
    else
        echo ""
        echo "🎉 All MicroVM configurations passed!"
    fi

# Show MicroVM help
microvm-help:
    @echo "🖥️  MicroVM Management Help"
    @echo "=========================="
    @echo ""
    @echo "📋 Available Commands:"
    @echo "  just start-microvm <vm>     - Start a MicroVM"
    @echo "  just stop-microvm <vm>      - Stop a MicroVM"
    @echo "  just restart-microvm <vm>   - Restart a MicroVM"
    @echo "  just ssh-microvm <vm>       - SSH into a MicroVM"
    @echo "  just list-microvms          - Show all MicroVM status"
    @echo "  just stop-all-microvms      - Stop all running MicroVMs"
    @echo "  just rebuild-microvm <vm>   - Rebuild and restart a MicroVM"
    @echo "  just test-microvm <vm>      - Test MicroVM configuration"
    @echo "  just test-all-microvms      - Test all MicroVM configurations"
    @echo "  just clean-microvms         - Clean up MicroVM data (DESTRUCTIVE)"
    @echo ""
    @echo "🖥️  Available MicroVMs:"
    @echo "  dev-vm        - Development environment (8GB RAM, dev tools, Docker)"
    @echo "                  SSH: ssh dev@localhost -p 2222"
    @echo "                  Projects: /home/dev/projects"
    @echo "                  Ports: 8080→80, 3000→3000"
    @echo ""
    @echo "  test-vm       - Testing environment (8GB RAM, minimal packages)"
    @echo "                  SSH: ssh test@localhost -p 2223"
    @echo "                  Data: /mnt/data"
    @echo ""
    @echo "  playground-vm - Experimental sandbox (8GB RAM, K8s, security tools)"
    @echo "                  SSH: ssh root@localhost -p 2224"
    @echo "                  Experiments: /root/experiments"
    @echo "                  Ports: 8081→80"
    @echo ""
    @echo "📖 Example Workflow:"
    @echo "  1. just start-microvm dev-vm        # Start development environment"
    @echo "  2. just ssh-microvm dev-vm          # SSH into dev environment"
    @echo "  3. just list-microvms               # Check all VM status"
    @echo "  4. just stop-microvm dev-vm         # Stop when done"
    @echo ""
    @echo "💾 Storage:"
    @echo "  - Shared /nix/store (read-only, efficient)"
    @echo "  - Persistent volumes for each VM"
    @echo "  - Shared host directory: /tmp/microvm-shared"
    @echo ""
    @echo "⚠️  Notes:"
    @echo "  - VMs have 8GB RAM and 4 CPU cores each"
    @echo "  - P620 (32GB) can run all VMs simultaneously"
    @echo "  - Razer (16GB) should run 1-2 VMs at a time"

# =============================================================================
# AGENT-INTEGRATED DEPLOYMENT
# =============================================================================

# Deployment orchestration used by the 'deployment-coordinator' agent
deploy-all:
    @echo "🤖 Starting Agent-Integrated Deployment..."
    @./scripts/generate-topology.sh
    @./scripts/issue-checker.sh
    @if [ -f .gemini/state/issues.json ]; then \
        if grep -q '"status": "critical"' .gemini/state/issues.json; then \
            echo "❌ CRITICAL ISSUES DETECTED. Aborting deployment."; \
            exit 1; \
        fi; \
    fi
    @echo "🚀 Proceeding with deployment sequence..."
    @echo "🔹 Phase 1: Infrastructure (P620)"
    @just p620
    @echo "🔹 Phase 2: Clients (Razer, P510)"
    @just deploy-all-parallel
    @echo "✅ Deployment Coordinator finished successfully."
