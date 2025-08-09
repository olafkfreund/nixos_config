#!/usr/bin/env bash

# NixOS CI/CD Testing Script
# Comprehensive automated testing pipeline for continuous integration

set -euo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"
ACTIVE_HOSTS=("razer" "dex5550" "p510" "p620")

# Configuration
CI_LOG_DIR="/tmp/nixos-ci-$(date +%Y%m%d-%H%M%S)"
EXIT_CODE=0
PARALLEL_JOBS=4
TIMEOUT_DURATION=600 # 10 minutes per test

# Logging setup
mkdir -p "$CI_LOG_DIR"
MAIN_LOG="$CI_LOG_DIR/ci-main.log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" | tee -a "$MAIN_LOG"
}

error() {
  echo -e "${RED}${BOLD}ERROR:${NC} $*" | tee -a "$MAIN_LOG"
  EXIT_CODE=1
}

success() {
  echo -e "${GREEN}${BOLD}SUCCESS:${NC} $*" | tee -a "$MAIN_LOG"
}

warning() {
  echo -e "${YELLOW}${BOLD}WARNING:${NC} $*" | tee -a "$MAIN_LOG"
}

info() {
  echo -e "${BLUE}${BOLD}INFO:${NC} $*" | tee -a "$MAIN_LOG"
}

section() {
  echo -e "${PURPLE}${BOLD}=== $* ===${NC}" | tee -a "$MAIN_LOG"
}

# Test execution wrapper with timeout and logging
run_test() {
  local test_name="$1"
  local test_cmd="$2"
  local log_file="$CI_LOG_DIR/${test_name}.log"

  info "Starting test: $test_name"

  if timeout "$TIMEOUT_DURATION" bash -c "$test_cmd" &>"$log_file"; then
    success "Test passed: $test_name"
    return 0
  else
    local exit_code=$?
    if [ $exit_code -eq 124 ]; then
      error "Test timed out: $test_name (after ${TIMEOUT_DURATION}s)"
    else
      error "Test failed: $test_name (exit code: $exit_code)"
    fi
    echo "--- Error log for $test_name ---" | tee -a "$MAIN_LOG"
    tail -20 "$log_file" | tee -a "$MAIN_LOG"
    echo "--- End error log ---" | tee -a "$MAIN_LOG"
    return 1
  fi
}

# Pre-flight checks
preflight_checks() {
  section "Pre-flight Checks"

  local required_commands=("nix" "nixos-rebuild" "jq" "bc" "timeout")
  local missing_commands=()

  for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      missing_commands+=("$cmd")
    fi
  done

  if [ ${#missing_commands[@]} -ne 0 ]; then
    error "Missing required commands: ${missing_commands[*]}"
    return 1
  fi

  # Check if we're in the right directory
  if [[ ! -f "$CONFIG_DIR/flake.nix" ]]; then
    error "flake.nix not found in $CONFIG_DIR"
    return 1
  fi

  # Check git status
  cd "$CONFIG_DIR"
  if ! git status &>/dev/null; then
    warning "Not in a git repository"
  else
    local git_status
    git_status=$(git status --porcelain)
    if [[ -n "$git_status" ]]; then
      warning "Working directory has uncommitted changes"
      echo "$git_status" | tee -a "$MAIN_LOG"
    fi
  fi

  success "Pre-flight checks completed"
}

# Test flake validity
test_flake_validity() {
  section "Flake Validity Tests"

  cd "$CONFIG_DIR"

  run_test "flake-check" "nix flake check --show-trace" || return 1
  run_test "flake-show" "nix flake show --json > /dev/null" || return 1
  run_test "flake-metadata" "nix flake metadata > /dev/null" || return 1

  success "Flake validity tests completed"
}

# Test syntax and evaluation
test_syntax_evaluation() {
  section "Syntax and Evaluation Tests"

  cd "$CONFIG_DIR"

  # Test Nix file syntax
  run_test "syntax-check" "
        find . -name '*.nix' -not -path './result*' -not -path './.git/*' | while read -r file; do
            nix-instantiate --parse \"\$file\" > /dev/null || {
                echo \"Syntax error in \$file\"
                exit 1
            }
        done
    " || return 1

  # Test evaluation of each host configuration
  for host in "${ACTIVE_HOSTS[@]}"; do
    run_test "eval-$host" "
            nix eval .#nixosConfigurations.$host.config.system.stateVersion --raw > /dev/null
        " || return 1
  done

  success "Syntax and evaluation tests completed"
}

# Test host configurations build
test_host_builds() {
  section "Host Build Tests"

  cd "$CONFIG_DIR"

  # Test builds in parallel for efficiency
  local pids=()
  local failed_hosts=()

  for host in "${ACTIVE_HOSTS[@]}"; do
    (
      if run_test "build-$host" "
                nix build .#nixosConfigurations.$host.config.system.build.toplevel --no-link --show-trace
            "; then
        echo "SUCCESS:$host" >"$CI_LOG_DIR/build-$host.result"
      else
        echo "FAILED:$host" >"$CI_LOG_DIR/build-$host.result"
      fi
    ) &
    pids+=($!)

    # Limit parallel jobs
    if [ ${#pids[@]} -ge $PARALLEL_JOBS ]; then
      wait "${pids[0]}"
      pids=("${pids[@]:1}")
    fi
  done

  # Wait for remaining jobs
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  # Check results
  for host in "${ACTIVE_HOSTS[@]}"; do
    if [[ -f "$CI_LOG_DIR/build-$host.result" ]]; then
      local result
      result=$(cat "$CI_LOG_DIR/build-$host.result")
      if [[ "$result" == "FAILED:$host" ]]; then
        failed_hosts+=("$host")
      fi
    else
      failed_hosts+=("$host")
    fi
  done

  if [ ${#failed_hosts[@]} -eq 0 ]; then
    success "All host builds completed successfully"
  else
    error "Failed host builds: ${failed_hosts[*]}"
    return 1
  fi
}

# Test Home Manager configurations
test_home_manager() {
  section "Home Manager Tests"

  cd "$CONFIG_DIR"

  local failed_configs=()

  for host in "${ACTIVE_HOSTS[@]}"; do
    if ! run_test "home-$host" "
            nix build .#homeConfigurations.\"olafkfreund@$host\".activationPackage --no-link --show-trace
        "; then
      failed_configs+=("olafkfreund@$host")
    fi
  done

  if [ ${#failed_configs[@]} -eq 0 ]; then
    success "All Home Manager configurations build successfully"
  else
    warning "Failed Home Manager configs: ${failed_configs[*]}"
    # Don't fail CI for Home Manager issues
  fi
}

# Test secrets
test_secrets() {
  section "Secrets Tests"

  cd "$CONFIG_DIR"

  if [[ ! -d "secrets" ]] || [[ -z "$(ls -A secrets 2>/dev/null)" ]]; then
    info "No secrets found to test"
    return 0
  fi

  run_test "secrets-decrypt" "
        for secret in secrets/*.age; do
            if [[ -f \"\$secret\" ]]; then
                agenix -d \"\$secret\" > /dev/null || {
                    echo \"Failed to decrypt \$secret\"
                    exit 1
                }
            fi
        done
    " || return 1

  success "Secrets tests completed"
}

# Test custom packages
test_custom_packages() {
  section "Custom Package Tests"

  cd "$CONFIG_DIR"

  local packages_output
  if packages_output=$(nix flake show --json 2>/dev/null | jq -r '.packages."x86_64-linux" | keys[]' 2>/dev/null); then
    if [[ -n "$packages_output" ]]; then
      echo "$packages_output" | while read -r package; do
        run_test "package-$package" "
                    nix build .#$package --no-link --show-trace
                " || return 1
      done
    else
      info "No custom packages found to test"
    fi
  else
    warning "Could not enumerate packages for testing"
  fi

  success "Custom package tests completed"
}

# Performance regression tests
test_performance_regression() {
  section "Performance Regression Tests"

  cd "$CONFIG_DIR"

  # Test flake evaluation time
  run_test "perf-eval" "
        start=\$(date +%s.%N)
        nix flake show --json > /dev/null 2>&1
        end=\$(date +%s.%N)
        runtime=\$(echo \"\$end - \$start\" | bc)
        threshold=10.0  # 10 seconds threshold
        if (( \$(echo \"\$runtime > \$threshold\" | bc -l) )); then
            echo \"Flake evaluation too slow: \${runtime}s (threshold: \${threshold}s)\"
            exit 1
        fi
        echo \"Flake evaluation time: \${runtime}s\"
    " || return 1

  # Test build time for a representative host
  local test_host="${ACTIVE_HOSTS[0]}"
  run_test "perf-build" "
        start=\$(date +%s.%N)
        nix build .#nixosConfigurations.$test_host.config.system.build.toplevel --no-link
        end=\$(date +%s.%N)
        runtime=\$(echo \"\$end - \$start\" | bc)
        threshold=300.0  # 5 minutes threshold
        if (( \$(echo \"\$runtime > \$threshold\" | bc -l) )); then
            echo \"Build too slow: \${runtime}s (threshold: \${threshold}s)\"
            exit 1
        fi
        echo \"Build time for $test_host: \${runtime}s\"
    " || return 1

  success "Performance regression tests completed"
}

# Generate CI report
generate_ci_report() {
  section "Generating CI Report"

  local report_file="$CI_LOG_DIR/ci-report.md"
  local end_time
  end_time=$(date)

  cat >"$report_file" <<EOF
# NixOS CI/CD Test Report

**Generated:** $end_time
**Configuration:** $CONFIG_DIR
**Exit Code:** $EXIT_CODE

## Test Summary

| Test Suite | Status | Log File |
|------------|--------|----------|
EOF

  # Add test results to report
  for log_file in "$CI_LOG_DIR"/*.log; do
    if [[ -f "$log_file" && "$(basename "$log_file")" != "ci-main.log" ]]; then
      local test_name
      test_name=$(basename "$log_file" .log)
      local status="❌ FAILED"

      # Check if test passed by looking for success indicators
      if grep -q "SUCCESS" "$log_file" 2>/dev/null || [[ $(wc -c <"$log_file") -eq 0 ]]; then
        status="✅ PASSED"
      fi

      echo "| $test_name | $status | $(basename "$log_file") |" >>"$report_file"
    fi
  done

  cat >>"$report_file" <<EOF

## Host Configurations Tested

$(printf "- %s\\n" "${ACTIVE_HOSTS[@]}")

## Artifacts

- Main log: [ci-main.log](ci-main.log)
- Test logs: Available in the same directory as this report

## Git Information

EOF

  if git status &>/dev/null; then
    cat >>"$report_file" <<EOF
- **Commit:** $(git rev-parse HEAD 2>/dev/null || echo "Unknown")
- **Branch:** $(git branch --show-current 2>/dev/null || echo "Unknown")
- **Status:** $(git status --porcelain | wc -l) changed files
EOF
  else
    echo "- Not a git repository" >>"$report_file"
  fi

  success "CI report generated: $report_file"
}

# Main CI pipeline
main() {
  echo -e "${PURPLE}${BOLD}"
  echo "╔══════════════════════════════════════════════════════════════════════════════╗"
  echo "║                        NixOS CI/CD Testing Pipeline                         ║"
  echo "║                                                                              ║"
  echo "║  Automated testing for continuous integration and deployment                ║"
  echo "╚══════════════════════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"

  log "Starting CI pipeline"
  log "Log directory: $CI_LOG_DIR"
  log "Configuration directory: $CONFIG_DIR"

  # Run test suites
  local test_suites=(
    "preflight_checks"
    "test_flake_validity"
    "test_syntax_evaluation"
    "test_secrets"
    "test_custom_packages"
    "test_host_builds"
    "test_home_manager"
    "test_performance_regression"
  )

  for test_suite in "${test_suites[@]}"; do
    log "Running test suite: $test_suite"
    if ! "$test_suite"; then
      error "Test suite failed: $test_suite"
      EXIT_CODE=1
      # Continue running other tests for comprehensive feedback
    fi
  done

  # Generate report
  generate_ci_report

  if [ $EXIT_CODE -eq 0 ]; then
    success "✅ CI pipeline completed successfully!"
    echo -e "${GREEN}${BOLD}All tests passed!${NC}"
  else
    error "❌ CI pipeline completed with failures!"
    echo -e "${RED}${BOLD}Some tests failed. Check logs for details.${NC}"
  fi

  log "CI pipeline finished with exit code: $EXIT_CODE"

  exit $EXIT_CODE
}

# Help function
show_help() {
  cat <<EOF
NixOS CI/CD Testing Pipeline

Usage: $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  -j, --jobs N            Number of parallel jobs (default: $PARALLEL_JOBS)
  -t, --timeout N         Timeout per test in seconds (default: $TIMEOUT_DURATION)
  -q, --quick             Quick mode (reduced test coverage)
  -v, --verbose           Verbose output

Environment Variables:
  CI_SKIP_PERFORMANCE     Skip performance regression tests
  CI_SKIP_HOME_MANAGER    Skip Home Manager tests
  CI_HOSTS                Override host list (comma-separated)

Examples:
  $0                      # Run full CI pipeline
  $0 --quick              # Quick tests only
  $0 --jobs 8             # Use 8 parallel jobs
  CI_HOSTS=p620,razer $0  # Test only specific hosts
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h | --help)
      show_help
      exit 0
      ;;
    -j | --jobs)
      PARALLEL_JOBS="$2"
      shift 2
      ;;
    -t | --timeout)
      TIMEOUT_DURATION="$2"
      shift 2
      ;;
    -q | --quick)
      # Reduce test scope for quick mode
      ACTIVE_HOSTS=("${ACTIVE_HOSTS[0]}") # Test only first host
      TIMEOUT_DURATION=300
      shift
      ;;
    -v | --verbose)
      set -x
      shift
      ;;
    *)
      error "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Override hosts from environment
if [[ -n "${CI_HOSTS:-}" ]]; then
  IFS=',' read -ra ACTIVE_HOSTS <<<"$CI_HOSTS"
  info "Using hosts from CI_HOSTS: ${ACTIVE_HOSTS[*]}"
fi

# Run the main pipeline
main "$@"
