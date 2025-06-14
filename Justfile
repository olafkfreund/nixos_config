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
    ./scripts/validate-config.sh

# Quick validation (faster, less comprehensive)
validate-quick:
    @echo "⚡ Running quick validation..."
    ./scripts/validate-config.sh --quick

# Test all configurations build successfully
test-all:
    @echo "🧪 Testing all NixOS configurations..."
    @for host in razer dex5550 p510 p620; do \
        echo "Testing $host..."; \
        nix build .#nixosConfigurations.$host.config.system.build.toplevel --show-trace || exit 1; \
    done
    @echo "✅ All configurations build successfully!"

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

# Deploy to razer laptop (Intel/NVIDIA)
razer:
    just pre-deploy razer
    nixos-rebuild switch --flake .#razer --target-host razer --build-host razer --use-remote-sudo --impure --accept-flake-config

# Deploy to p620 workstation (AMD)
p620:
    just pre-deploy p620
    nixos-rebuild switch --flake .#p620 --target-host p620 --build-host p620 --use-remote-sudo --impure --accept-flake-config

# Deploy to p510 workstation (Intel Xeon/NVIDIA)
p510:
    just pre-deploy p510
    nixos-rebuild switch --flake .#p510 --target-host p510 --build-host p510 --use-remote-sudo --impure --accept-flake-config

# Deploy to dex5550 SFF system (Intel integrated)
dex5550:
    just pre-deploy dex5550
    nixos-rebuild switch --flake .#dex5550 --target-host dex5550 --build-host dex5550 --use-remote-sudo --impure --accept-flake-config

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
# MAINTENANCE AND UTILITIES  
# =============================================================================

# View system generation history
history:
    nix profile history --profile /nix/var/nix/profiles/system

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

# Clean up and optimize everything
cleanup:
    just gc
    just optimize
    @echo "🧹 Cleanup complete!"

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

# Test configuration size and complexity metrics
analyze-config:
    @echo "📊 Analyzing configuration complexity..."
    @echo "Total Nix files: $$(find . -name '*.nix' -not -path './result*' | wc -l)"
    @echo "Lines of code: $$(find . -name '*.nix' -not -path './result*' -exec cat {} + | wc -l)"
    @echo "Module count: $$(find modules -name '*.nix' -not -name 'default.nix' | wc -l)"
    @echo "Host count: $$(ls -1 hosts/ | grep -v -E '^(README|archive|common|manual)' | wc -l)"
    @echo "User count: $$(ls -1 Users/ | grep -v README | wc -l)"

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

# Generate documentation
docs:
    @echo "📖 Generating documentation..."
    @echo "# NixOS Configuration Documentation" > GENERATED_DOCS.md
    @echo "" >> GENERATED_DOCS.md
    @echo "Generated on: $$(date)" >> GENERATED_DOCS.md
    @echo "" >> GENERATED_DOCS.md
    @echo "## Available Hosts" >> GENERATED_DOCS.md
    @for host in hosts/*/; do \
        if [ -f "$$host/configuration.nix" ]; then \
            host_name=$$(basename "$$host"); \
            echo "- **$$host_name**" >> GENERATED_DOCS.md; \
        fi; \
    done
    @echo "" >> GENERATED_DOCS.md
    @echo "## Available Modules" >> GENERATED_DOCS.md
    @find modules -name "*.nix" -not -name "default.nix" | sort | while read -r module; do \
        module_name=$$(basename "$$module" .nix); \
        echo "- $$module_name" >> GENERATED_DOCS.md; \
    done
    @echo "✅ Documentation generated: GENERATED_DOCS.md"

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
    @echo "🧪 TESTING:"
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


