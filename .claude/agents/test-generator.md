# Test Generator Agent

> **Automatic Test Generation for NixOS Configurations and Modules**
> Priority: P2 | Impact: Medium | Effort: Low

## Overview

The Test Generator agent automatically creates comprehensive test suites for NixOS modules, configurations, and deployments. It generates unit tests, integration tests, and smoke tests to ensure configuration reliability and prevent regressions.

## Agent Purpose

**Primary Mission**: Increase test coverage and configuration reliability through automated test generation, ensuring all modules and configurations have appropriate validation.

**Trigger Conditions**:

- User mentions testing, test coverage, or validation
- Commands like `/nix-test` or `just generate-tests`
- After creating new modules
- Before major deployments
- When test coverage is below threshold

## Core Capabilities

### 1. Module Test Generation

**What it does**: Generates unit tests for NixOS modules

**Test types**:

```yaml
Module Unit Tests:

1. Option Validation Tests:
   Module: modules/services/prometheus.nix

   Generated Tests:
     # Test option types
     - verify_enable_option_is_boolean
     - verify_port_option_is_integer
     - verify_retention_option_is_string

     # Test option defaults
     - verify_default_port_is_9090
     - verify_default_retention_is_30d
     - verify_service_disabled_by_default

     # Test option constraints
     - verify_port_in_valid_range
     - verify_retention_format_valid

2. Service Definition Tests:
   # Test service configuration
     - verify_systemd_service_defined
     - verify_service_has_dynamic_user
     - verify_service_has_security_hardening
     - verify_service_dependencies_correct

3. Module Isolation Tests:
   # Test module doesn't affect others
     - verify_module_loads_without_errors
     - verify_no_conflicts_with_other_modules
     - verify_explicit_dependencies_only
```

### 2. Integration Test Generation

**What it does**: Creates tests for module interactions and host configurations

**Integration tests**:

```yaml
Integration Tests:

1. Host Configuration Tests:
   Host: p620

   Generated Tests:
     # Build tests
     - test_p620_builds_successfully
     - test_p620_no_syntax_errors
     - test_p620_all_services_defined

     # Service interaction tests
     - test_prometheus_scrapes_node_exporter
     - test_grafana_connects_to_prometheus
     - test_alertmanager_receives_alerts

     # Network tests
     - test_firewall_allows_required_ports
     - test_tailscale_dns_resolution
     - test_services_accessible_on_network

2. Multi-Host Tests:
   Scenario: Monitoring Infrastructure

   Generated Tests:
     - test_p620_monitoring_server_running
     - test_clients_connect_to_p620
     - test_metrics_flow_end_to_end
     - test_all_exporters_reachable

3. Feature Flag Tests:
   Feature: features.development.enable = true;

   Generated Tests:
     - test_development_packages_installed
     - test_development_services_running
     - test_language_tools_available
     - test_dev_shells_functional
```

### 3. Smoke Test Generation

**What it does**: Creates quick validation tests for deployments

**Smoke tests**:

```yaml
Deployment Smoke Tests:

1. System Boot Tests:
   # Generated for each host
     - test_system_boots_successfully
     - test_no_failed_services
     - test_essential_services_running
     - test_network_connectivity

2. Service Health Tests:
   Service: prometheus

   Generated Tests:
     - test_prometheus_service_active
     - test_prometheus_port_listening
     - test_prometheus_api_responds
     - test_prometheus_targets_up

3. User Environment Tests:
   User: olafkfreund

   Generated Tests:
     - test_user_can_login
     - test_user_shell_works
     - test_user_packages_available
     - test_user_home_directory_exists
```

### 4. Regression Test Generation

**What it does**: Creates tests to prevent known issues from recurring

**Regression tests**:

```yaml
Regression Test Generation:

Based on: Past Issues and Fixes

1. From Issue #67 (P510 Boot Delay):
   Generated Tests:
     - test_fstrim_service_timeout_configured
     - test_boot_time_under_2_minutes
     - test_no_blocking_services_at_boot

2. From Security Fixes:
   Generated Tests:
     - test_no_services_run_as_root
     - test_all_services_have_dynamic_user
     - test_no_secrets_in_nix_store

3. From Package Conflicts:
   Generated Tests:
     - test_no_python_version_conflicts
     - test_no_duplicate_packages
     - test_package_paths_unique
```

### 5. Property-Based Test Generation

**What it does**: Generates property-based tests for complex logic

**Property tests**:

```yaml
Property-Based Tests:

1. Configuration Validity:
   Property: All valid configurations should build

   Generated Test:
     property_test_config_builds:
       for config_variant in [minimal, full, custom]:
         assert builds_successfully(config_variant)

2. Service Isolation:
   Property: Disabling a service shouldn't affect others

   Generated Test:
     property_test_service_isolation:
       for service in all_services:
         config_without_service = disable(service)
         assert other_services_still_work(config_without_service)

3. Resource Constraints:
   Property: System should work within resource limits

   Generated Test:
     property_test_resource_limits:
       for host in [p620, p510, razer, samsung]:
         assert memory_usage_within_limits(host)
         assert cpu_usage_reasonable(host)
```

### 6. NixOS VM Test Generation

**What it does**: Creates automated VM tests using NixOS testing framework

**VM test examples**:

```yaml
NixOS VM Tests:

1. Service Interaction Test:
   ```python
   # Generated test file: tests/prometheus-grafana.nix
   import <nixpkgs/nixos/tests/make-test-python.nix> ({ pkgs, ... }: {
     name = "prometheus-grafana-integration";

     nodes = {
       server = { ... }: {
         imports = [ ../modules/monitoring/prometheus.nix ];
         services.prometheus.enable = true;
       };

       grafana = { ... }: {
         imports = [ ../modules/monitoring/grafana.nix ];
         services.grafana.enable = true;
         services.grafana.provision.datasources.settings.datasources = [{
           name = "Prometheus";
           type = "prometheus";
           url = "http://server:9090";
         }];
       };
     };

     testScript = ''
       start_all()

       # Wait for services
       server.wait_for_unit("prometheus.service")
       grafana.wait_for_unit("grafana.service")

       # Test Prometheus
       server.wait_for_open_port(9090)
       server.succeed("curl -f http://localhost:9090/-/healthy")

       # Test Grafana
       grafana.wait_for_open_port(3000)
       grafana.succeed("curl -f http://localhost:3000/api/health")

       # Test integration
       grafana.succeed("curl -f http://server:9090/api/v1/targets")
     '';
   })
   ```

2. Multi-Host Network Test:
   ```python
   # Generated test: tests/multi-host-network.nix
   import <nixpkgs/nixos/tests/make-test-python.nix> ({ pkgs, ... }: {
     name = "multi-host-networking";

     nodes = {
       p620 = { ... }: {
         imports = [ ../hosts/p620/configuration.nix ];
       };

       razer = { ... }: {
         imports = [ ../hosts/razer/configuration.nix ];
       };
     };

     testScript = ''
       start_all()

       # Test network connectivity
       p620.wait_for_unit("network.target")
       razer.wait_for_unit("network.target")

       # Test ping between hosts
       p620.succeed("ping -c 1 razer")
       razer.succeed("ping -c 1 p620")

       # Test Tailscale if enabled
       if config.services.tailscale.enable:
         p620.wait_for_unit("tailscale.service")
         razer.wait_for_unit("tailscale.service")
     '';
   })
   ```
```

### 7. Test Coverage Analysis

**What it does**: Analyzes test coverage and suggests additional tests

**Coverage analysis**:

```yaml
Test Coverage Report:

Module Coverage:
  Total Modules: 141
  Tested Modules: 85 (60%)
  Untested Modules: 56 (40%)

  Untested modules needing tests:
    - modules/services/new-service.nix
    - modules/features/experimental.nix
    - modules/packages/custom.nix

Host Coverage:
  Total Hosts: 4
  Tested Hosts: 3 (75%)
  Untested: samsung (25%)

  Missing tests:
    - Samsung host configuration build test
    - Samsung-specific hardware tests
    - Samsung service interaction tests

Feature Coverage:
  Total Features: 45
  Tested Features: 30 (67%)
  Untested: 15 (33%)

  High-priority untested features:
    - features.ai-providers (critical)
    - features.monitoring (critical)
    - features.security (critical)

Recommendation:
  - Generate tests for 15 high-priority untested features
  - Add VM integration tests for samsung host
  - Create regression tests for recent fixes
```

### 8. Automated Test Execution

**What it does**: Runs generated tests automatically

**Test execution**:

```yaml
Test Execution Strategy:

1. Unit Tests (Fast):
   - Run on every code change
   - Execute in parallel
   - ~30 seconds total

   Commands:
     just test-modules          # Test all modules
     just test-module MODULE    # Test specific module

2. Integration Tests (Medium):
   - Run before deployment
   - Sequential execution
   - ~5 minutes total

   Commands:
     just test-integration      # All integration tests
     just test-host HOST        # Test specific host

3. VM Tests (Slow):
   - Run in CI/CD
   - Parallel where possible
   - ~15 minutes total

   Commands:
     just test-vm               # All VM tests
     just test-vm-parallel      # Parallel execution

4. Smoke Tests (Very Fast):
   - Run after deployment
   - Quick validation
   - ~1 minute total

   Commands:
     just smoke-test HOST       # Post-deployment validation
```

## Workflow

### Automated Test Generation

```bash
# Triggered by: /nix-test or just generate-tests

1. **Analysis Phase**
   - Scan all modules
   - Identify untested code
   - Analyze module structure
   - Review past issues

2. **Test Planning**
   - Determine test types needed
   - Prioritize by importance
   - Plan test coverage
   - Estimate effort

3. **Test Generation**
   - Generate unit tests
   - Create integration tests
   - Build VM tests
   - Add smoke tests
   - Create regression tests

4. **Test Validation**
   - Run generated tests
   - Verify tests pass
   - Check coverage improvement
   - Fix failing tests

5. **Documentation**
   - Document test suites
   - Update test README
   - Add usage examples
   - Track coverage metrics
```

### Example Test Generation Report

```markdown
# Test Generation Report
Generated: 2025-01-15 20:00:00

## Summary

Tests Generated: 45
Test Files Created: 12
Coverage Increase: 60% → 85% (+25%)
Estimated Execution Time: 8 minutes

## Generated Test Suites

### 1. Module Unit Tests (25 tests)

**modules/services/prometheus.nix** (8 tests):
```nix
# tests/modules/services/prometheus_test.nix
{ pkgs, lib, ... }:

{
  # Option validation
  testcase "enable option is boolean" = {
    expr = (lib.options.types.isBool config.services.prometheus.enable);
    expected = true;
  };

  testcase "default port is 9090" = {
    expr = config.services.prometheus.port;
    expected = 9090;
  };

  # Service configuration
  testcase "service has DynamicUser" = {
    expr = config.systemd.services.prometheus.serviceConfig.DynamicUser;
    expected = true;
  };

  testcase "service has security hardening" = {
    expr = (builtins.hasAttr "ProtectSystem"
            config.systemd.services.prometheus.serviceConfig);
    expected = true;
  };
}
```

**modules/features/development.nix** (12 tests):
- test_python_packages_available
- test_go_tools_installed
- test_rust_toolchain_works
- test_language_servers_functional
- ... (8 more)

### 2. Integration Tests (15 tests)

**Host Build Tests** (4 tests):
```bash
# tests/integration/host_builds_test.sh

test_p620_builds() {
  nix build .#nixosConfigurations.p620.config.system.build.toplevel
  assert_success "P620 should build successfully"
}

test_razer_builds() {
  nix build .#nixosConfigurations.razer.config.system.build.toplevel
  assert_success "Razer should build successfully"
}

test_p510_builds() {
  nix build .#nixosConfigurations.p510.config.system.build.toplevel
  assert_success "P510 should build successfully"
}

test_samsung_builds() {
  nix build .#nixosConfigurations.samsung.config.system.build.toplevel
  assert_success "Samsung should build successfully"
}
```

**Service Interaction Tests** (11 tests):
- test_prometheus_grafana_integration
- test_node_exporter_prometheus_connection
- test_alertmanager_email_notifications
- ... (8 more)

### 3. VM Tests (3 test files)

**tests/vm/monitoring_test.nix**:
```python
import <nixpkgs/nixos/tests/make-test-python.nix> ({ pkgs, ... }: {
  name = "monitoring-infrastructure";

  nodes.server = { ... }: {
    imports = [ ../../hosts/p620/configuration.nix ];
  };

  testScript = ''
    server.start()
    server.wait_for_unit("multi-user.target")

    # Test Prometheus
    server.wait_for_unit("prometheus.service")
    server.wait_for_open_port(9090)
    server.succeed("curl -f http://localhost:9090/-/healthy")

    # Test Grafana
    server.wait_for_unit("grafana.service")
    server.wait_for_open_port(3000)
    server.succeed("curl -f http://localhost:3000/api/health")

    # Test metrics collection
    server.succeed("curl -s http://localhost:9090/api/v1/targets | grep -q '\"health\":\"up\"'")
  '';
})
```

### 4. Smoke Tests (2 test scripts)

**tests/smoke/post_deployment_test.sh**:
```bash
#!/usr/bin/env bash
# Post-deployment smoke test

HOST=$1

echo "Running smoke tests on $HOST..."

# Test SSH connectivity
ssh $HOST "echo 'SSH OK'"

# Test essential services
ssh $HOST "systemctl is-active sshd.service"
ssh $HOST "systemctl is-active network.target"

# Test network
ssh $HOST "ping -c 1 8.8.8.8"

# Test NixOS generation
ssh $HOST "nixos-version"

echo "✅ Smoke tests passed for $HOST"
```

## Test Coverage Improvement

**Before**:
- Modules tested: 85/141 (60%)
- Hosts tested: 3/4 (75%)
- Features tested: 30/45 (67%)

**After**:
- Modules tested: 120/141 (85%) ✅ (+25%)
- Hosts tested: 4/4 (100%) ✅ (+25%)
- Features tested: 40/45 (89%) ✅ (+22%)

## Usage

### Run All Tests
```bash
just test                # Run all test suites
just test-parallel       # Run tests in parallel
```

### Run Specific Tests
```bash
just test-modules        # Unit tests only
just test-integration    # Integration tests
just test-vm            # VM tests
just smoke-test p620     # Smoke test specific host
```

### Coverage Analysis
```bash
just test-coverage       # Show coverage report
just test-coverage-html  # Generate HTML report
```

## Next Steps

1. ✅ Review generated tests
2. ⏭️ Run test suites: `just test`
3. ⏭️ Fix any failing tests
4. ⏭️ Add to CI/CD pipeline
5. ⏭️ Set up automated test runs

---

**Tests Generated**: 2025-01-15 20:00:00
**Next Generation**: On module addition
```

## Integration with Existing Tools

### With `/nix-test` Command

```bash
# /nix-test triggers test generation and execution

/nix-test                 # Generate and run all tests
/nix-test --generate     # Generate tests only
/nix-test --module MODULE # Test specific module
/nix-test --coverage     # Show coverage report
```

### With Deployment Coordinator

```bash
# Pre-deployment testing
Pre-Deployment:
  - Generate smoke tests
  - Run integration tests
  - Validate host builds

Post-Deployment:
  - Run smoke tests
  - Verify services
  - Check health
```

### With CI/CD Pipeline

```yaml
# .github/workflows/test.yml
name: Test Suite
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Generate Tests
        run: just generate-tests

      - name: Run Unit Tests
        run: just test-modules

      - name: Run Integration Tests
        run: just test-integration

      - name: Run VM Tests
        run: just test-vm

      - name: Report Coverage
        run: just test-coverage
```

## Configuration

### Enable Test Generator

```nix
# modules/claude-code/test-generator.nix
{ config, lib, ... }:
{
  options.claude.test-generator = {
    enable = lib.mkEnableOption "Automatic test generation";

    coverage-threshold = lib.mkOption {
      type = lib.types.int;
      default = 80;
      description = "Minimum test coverage percentage";
    };

    auto-generate = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically generate tests for new modules";
    };

    test-types = lib.mkOption {
      type = lib.types.listOf (lib.types.enum [ "unit" "integration" "vm" "smoke" ]);
      default = [ "unit" "integration" "smoke" ];
      description = "Types of tests to generate";
    };
  };
}
```

## Best Practices

### 1. Test New Modules Immediately

```bash
# After creating module
/nix-test --module new-module

# Generate and run tests
just test-module new-module
```

### 2. Maintain High Coverage

```bash
# Check coverage regularly
just test-coverage

# Generate tests for gaps
/nix-test --coverage-analysis
```

### 3. Run Tests Before Deployment

```bash
# Full test suite
just test

# Quick smoke test
just smoke-test HOST
```

## Troubleshooting

### Tests Failing After Generation

**Issue**: Generated tests don't pass

**Solution**:
```bash
# Review failing tests
just test --verbose

# Fix issues
# Re-generate if needed
/nix-test --regenerate
```

### Low Test Coverage

**Issue**: Coverage below threshold

**Solution**:
```bash
# Analyze uncovered code
just test-coverage --detailed

# Generate missing tests
/nix-test --fill-gaps
```

## Future Enhancements

1. **AI-Powered Test Generation**: ML-based test creation
2. **Mutation Testing**: Test quality verification
3. **Performance Testing**: Automated benchmarks
4. **Security Testing**: Automated security tests

## Agent Metadata

```yaml
name: test-generator
version: 1.0.0
priority: P2
impact: medium
effort: low
dependencies:
  - nix-check agent
  - module-refactor agent
triggers:
  - keyword: test, testing, coverage
  - command: /nix-test
  - event: new module created
outputs:
  - tests/
  - test-coverage-report.md
  - test-results.json
```
