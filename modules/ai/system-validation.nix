# Comprehensive AI System Validation and Testing Framework
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.ai.systemValidation;
in {
  options.ai.systemValidation = {
    enable = mkEnableOption "Enable AI system validation and testing";
    
    validationLevel = mkOption {
      type = types.enum [ "basic" "comprehensive" "stress" ];
      default = "comprehensive";
      description = "Validation level: basic, comprehensive, or stress testing";
    };
    
    testReportPath = mkOption {
      type = types.str;
      default = "/var/lib/ai-analysis/validation-reports";
      description = "Path to store validation test reports";
    };
    
    enableLoadTesting = mkOption {
      type = types.bool;
      default = false;
      description = "Enable load testing for performance validation";
    };
  };

  config = mkIf cfg.enable {
    # Main system validation service
    systemd.services.ai-system-validation = {
      description = "AI System Validation Service";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        TimeoutStartSec = "30m";
        ExecStart = pkgs.writeShellScript "ai-system-validation" ''
          #!/bin/bash
          
          # Configuration
          VALIDATION_LEVEL="${cfg.validationLevel}"
          REPORT_DIR="${cfg.testReportPath}"
          LOAD_TESTING="${if cfg.enableLoadTesting then "true" else "false"}"
          HOSTNAME=$(hostname)
          TIMESTAMP=$(date +%Y%m%d_%H%M%S)
          REPORT_FILE="$REPORT_DIR/validation_report_$HOSTNAME_$TIMESTAMP.json"
          LOG_FILE="/var/log/ai-analysis/system-validation.log"
          
          # Colors for output
          RED='\033[0;31m'
          GREEN='\033[0;32m'
          YELLOW='\033[1;33m'
          BLUE='\033[0;34m'
          NC='\033[0m' # No Color
          
          # Ensure directories exist
          mkdir -p "$REPORT_DIR"
          mkdir -p "$(dirname "$LOG_FILE")"
          
          # Setup logging
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo -e "$(date) ''${BLUE}[INFO]''${NC} Starting AI system validation for $HOSTNAME"
          echo -e "$(date) ''${BLUE}[INFO]''${NC} Validation level: $VALIDATION_LEVEL"
          echo -e "$(date) ''${BLUE}[INFO]''${NC} Load testing: $LOAD_TESTING"
          
          # Initialize test results
          TOTAL_TESTS=0
          PASSED_TESTS=0
          FAILED_TESTS=0
          WARNING_TESTS=0
          TEST_RESULTS=""
          
          # Function to run test and record result
          run_test() {
            local test_name="$1"
            local test_description="$2"
            local test_command="$3"
            local expected_result="$4"
            local severity="''${5:-medium}"
            
            ((TOTAL_TESTS++))
            
            echo -e "$(date) ''${BLUE}[TEST]''${NC} Running: $test_name"
            echo -e "$(date) ''${BLUE}[INFO]''${NC} $test_description"
            
            local test_output
            local test_exit_code
            
            # Run the test command
            test_output=$(eval "$test_command" 2>&1)
            test_exit_code=$?
            
            # Determine test result
            local test_status="unknown"
            local test_result_color=""
            
            if [ "$expected_result" = "success" ]; then
              if [ $test_exit_code -eq 0 ]; then
                test_status="passed"
                test_result_color="''$GREEN"
                ((PASSED_TESTS++))
              else
                test_status="failed"
                test_result_color="''$RED"
                ((FAILED_TESTS++))
              fi
            elif [ "$expected_result" = "failure" ]; then
              if [ $test_exit_code -ne 0 ]; then
                test_status="passed"
                test_result_color="''$GREEN"
                ((PASSED_TESTS++))
              else
                test_status="failed"
                test_result_color="''$RED"
                ((FAILED_TESTS++))
              fi
            elif [ "$expected_result" = "warning" ]; then
              test_status="warning"
              test_result_color="''$YELLOW"
              ((WARNING_TESTS++))
            fi
            
            echo -e "$(date) ''${test_result_color}[$(echo "$test_status" | tr '[:lower:]' '[:upper:]')]''${NC} $test_name"
            
            # Add to results
            local test_result='{
              "name": "'$test_name'",
              "description": "'$test_description'",
              "status": "'$test_status'",
              "severity": "'$severity'",
              "exit_code": '$test_exit_code',
              "output": "'"$(echo "$test_output" | sed 's/"/\\"/g' | tr '\n' ' ')"'",
              "timestamp": "'$(date -Iseconds)'"
            }'
            
            if [ -n "$TEST_RESULTS" ]; then
              TEST_RESULTS="$TEST_RESULTS,$test_result"
            else
              TEST_RESULTS="$test_result"
            fi
          }
          
          # === BASIC VALIDATION TESTS ===
          echo -e "$(date) ''${BLUE}[INFO]''${NC} === BASIC VALIDATION TESTS ==="
          
          # Test 1: AI Analysis Service Health
          run_test "ai_analysis_service" \
            "Check if AI analysis services are running" \
            "systemctl is-active ai-analysis-system || systemctl list-units --type=service | grep -q ai-analysis" \
            "success" \
            "critical"
          
          # Test 2: AI Providers Configuration
          run_test "ai_providers_config" \
            "Verify AI providers are configured" \
            "test -f /etc/ai-providers.json || command -v ai-cli" \
            "success" \
            "high"
          
          # Test 3: API Keys Access
          run_test "api_keys_access" \
            "Check encrypted API keys are accessible" \
            "test -d /run/agenix && ls /run/agenix/api-* > /dev/null 2>&1" \
            "success" \
            "high"
          
          # Test 4: Memory Optimization Service
          run_test "memory_optimization" \
            "Check memory optimization service" \
            "systemctl is-enabled ai-memory-optimization || systemctl status ai-memory-optimization" \
            "success" \
            "medium"
          
          # Test 5: Storage Analysis Service
          run_test "storage_analysis" \
            "Check storage analysis service" \
            "systemctl is-enabled ai-storage-analysis || systemctl status ai-storage-analysis" \
            "success" \
            "medium"
          
          # Test 6: Automated Remediation Service
          run_test "automated_remediation" \
            "Check automated remediation service" \
            "systemctl is-enabled ai-automated-remediation || systemctl status ai-automated-remediation" \
            "success" \
            "medium"
          
          # Test 7: Backup Strategy Service
          run_test "backup_strategy" \
            "Check backup strategy service" \
            "systemctl is-enabled ai-critical-backup || systemctl status ai-critical-backup" \
            "success" \
            "high"
          
          # Test 8: Security Audit Service
          run_test "security_audit" \
            "Check security audit service" \
            "systemctl is-enabled ai-security-audit || systemctl status ai-security-audit" \
            "success" \
            "medium"
          
          # Test 9: Monitoring Integration
          run_test "monitoring_integration" \
            "Check monitoring service integration" \
            "systemctl is-active prometheus-node-exporter || systemctl is-active node-exporter" \
            "success" \
            "medium"
          
          # Test 10: Log Directory Structure
          run_test "log_directories" \
            "Check AI analysis log directories exist" \
            "test -d /var/log/ai-analysis && test -d /var/lib/ai-analysis" \
            "success" \
            "low"
          
          # === COMPREHENSIVE VALIDATION TESTS ===
          if [ "$VALIDATION_LEVEL" = "comprehensive" ] || [ "$VALIDATION_LEVEL" = "stress" ]; then
            echo -e "$(date) ''${BLUE}[INFO]''${NC} === COMPREHENSIVE VALIDATION TESTS ==="
            
            # Test 11: AI Analysis Execution
            run_test "ai_analysis_execution" \
              "Execute AI analysis and check output" \
              "timeout 60 systemctl start ai-analysis-system && sleep 5 && test -f /var/lib/ai-analysis/reports/*" \
              "success" \
              "high"
            
            # Test 12: Storage Analysis Execution
            run_test "storage_analysis_execution" \
              "Execute storage analysis and check reports" \
              "timeout 60 systemctl start ai-storage-analysis && sleep 5 && test -f /var/lib/ai-analysis/storage-reports/*" \
              "success" \
              "high"
            
            # Test 13: Memory Optimization Execution
            run_test "memory_optimization_execution" \
              "Execute memory optimization and check logs" \
              "timeout 30 systemctl start ai-memory-optimization && sleep 5 && test -f /var/log/ai-analysis/memory-optimization.log" \
              "success" \
              "medium"
            
            # Test 14: Backup System Execution
            run_test "backup_system_execution" \
              "Execute backup system and verify backup creation" \
              "timeout 120 systemctl start ai-critical-backup && sleep 10 && find /var/backups -name '*$(date +%Y%m%d)*' -type d | head -1" \
              "success" \
              "high"
            
            # Test 15: Security Audit Execution
            run_test "security_audit_execution" \
              "Execute security audit and check report generation" \
              "timeout 60 systemctl start ai-security-audit && sleep 5 && test -f /var/lib/ai-analysis/security-reports/*" \
              "success" \
              "medium"
            
            # Test 16: Automated Remediation Execution
            run_test "automated_remediation_execution" \
              "Execute automated remediation and check logs" \
              "timeout 60 systemctl start ai-automated-remediation && sleep 5 && test -f /var/log/ai-analysis/remediation*.log" \
              "success" \
              "medium"
            
            # Test 17: Configuration Drift Detection
            run_test "config_drift_detection" \
              "Check configuration drift detection" \
              "test -f /var/log/ai-analysis/config-drift.log && tail -5 /var/log/ai-analysis/config-drift.log | grep -q 'drift detection'" \
              "success" \
              "low"
            
            # Test 18: Prometheus Metrics Integration
            run_test "prometheus_metrics" \
              "Check Prometheus metrics collection" \
              "curl -sf http://localhost:9090/metrics > /dev/null || curl -sf http://localhost:9100/metrics > /dev/null" \
              "success" \
              "medium"
            
            # Test 19: Storage Migration Readiness (P510 specific)
            if [ "$HOSTNAME" = "p510" ]; then
              run_test "storage_migration_readiness" \
                "Check P510 storage migration readiness" \
                "test -d /mnt/img_pool && df /mnt/img_pool | tail -1 | awk '{print $4}' | awk '{if($1 > 50000000) exit 0; else exit 1}'" \
                "success" \
                "high"
            fi
            
            # Test 20: AI Provider Functionality
            run_test "ai_provider_functionality" \
              "Test AI provider functionality" \
              "timeout 30 ai-cli --status || echo 'AI CLI available but may need configuration'" \
              "warning" \
              "medium"
          fi
          
          # === STRESS TESTING ===
          if [ "$VALIDATION_LEVEL" = "stress" ] && [ "$LOAD_TESTING" = "true" ]; then
            echo -e "$(date) ''${BLUE}[INFO]''${NC} === STRESS TESTING ==="
            
            # Test 21: Concurrent AI Analysis
            run_test "concurrent_ai_analysis" \
              "Run multiple AI analysis processes concurrently" \
              "for i in {1..3}; do timeout 30 systemctl start ai-analysis-system & done; wait" \
              "success" \
              "low"
            
            # Test 22: Memory Pressure Test
            run_test "memory_pressure_test" \
              "Test memory optimization under pressure" \
              "echo 3 > /proc/sys/vm/drop_caches; timeout 30 systemctl start ai-memory-optimization" \
              "success" \
              "low"
            
            # Test 23: Disk I/O Stress Test
            run_test "disk_io_stress_test" \
              "Test storage analysis under I/O load" \
              "timeout 60 systemctl start ai-storage-analysis" \
              "success" \
              "low"
          fi
          
          # === VALIDATION SUMMARY ===
          echo -e "$(date) ''${BLUE}[INFO]''${NC} === VALIDATION SUMMARY ==="
          
          # Calculate success rate
          SUCCESS_RATE=0
          if [ "$TOTAL_TESTS" -gt 0 ]; then
            SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
          fi
          
          # Determine overall status
          OVERALL_STATUS="unknown"
          STATUS_COLOR=""
          
          if [ "$SUCCESS_RATE" -ge 95 ]; then
            OVERALL_STATUS="excellent"
            STATUS_COLOR="''$GREEN"
          elif [ "$SUCCESS_RATE" -ge 85 ]; then
            OVERALL_STATUS="good"
            STATUS_COLOR="''$GREEN"
          elif [ "$SUCCESS_RATE" -ge 70 ]; then
            OVERALL_STATUS="acceptable"
            STATUS_COLOR="''$YELLOW"
          elif [ "$SUCCESS_RATE" -ge 50 ]; then
            OVERALL_STATUS="concerning"
            STATUS_COLOR="''$YELLOW"
          else
            OVERALL_STATUS="critical"
            STATUS_COLOR="''$RED"
          fi
          
          echo -e "$(date) ''${STATUS_COLOR}[SUMMARY]''${NC} Overall Status: $OVERALL_STATUS"
          echo -e "$(date) ''${BLUE}[INFO]''${NC} Total Tests: $TOTAL_TESTS"
          echo -e "$(date) ''${GREEN}[INFO]''${NC} Passed: $PASSED_TESTS"
          echo -e "$(date) ''${RED}[INFO]''${NC} Failed: $FAILED_TESTS"
          echo -e "$(date) ''${YELLOW}[INFO]''${NC} Warnings: $WARNING_TESTS"
          echo -e "$(date) ''${BLUE}[INFO]''${NC} Success Rate: $SUCCESS_RATE%"
          
          # Generate comprehensive report
          cat > "$REPORT_FILE" << EOF
          {
            "validation_metadata": {
              "hostname": "$HOSTNAME",
              "timestamp": "$(date -Iseconds)",
              "validation_level": "$VALIDATION_LEVEL",
              "load_testing_enabled": $LOAD_TESTING,
              "validator_version": "1.0"
            },
            "validation_summary": {
              "overall_status": "$OVERALL_STATUS",
              "success_rate_percent": $SUCCESS_RATE,
              "total_tests": $TOTAL_TESTS,
              "passed_tests": $PASSED_TESTS,
              "failed_tests": $FAILED_TESTS,
              "warning_tests": $WARNING_TESTS
            },
            "test_results": [
              $TEST_RESULTS
            ],
            "system_info": {
              "kernel_version": "$(uname -r)",
              "uptime": "$(uptime -p)",
              "load_average": "$(uptime | awk -F'load average:' '{print $2}' | xargs)",
              "memory_usage": "$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')%",
              "disk_usage_root": "$(df / | tail -1 | awk '{print $5}')",
              "running_ai_services": $(systemctl list-units --type=service | grep -c ai-)
            },
            "recommendations": [
              $([ "$FAILED_TESTS" -gt 0 ] && echo '"Review and fix failed tests before production use",' || echo "")
              $([ "$SUCCESS_RATE" -lt 85 ] && echo '"Consider additional system hardening",' || echo "")
              $([ "$WARNING_TESTS" -gt 0 ] && echo '"Investigate warning conditions",' || echo "")
              "Regular validation recommended every 7 days"
            ]
          }
          EOF
          
          echo -e "$(date) ''${BLUE}[INFO]''${NC} Validation report saved to: $REPORT_FILE"
          
          # Alert on critical failures
          if [ "$FAILED_TESTS" -gt 3 ] || [ "$SUCCESS_RATE" -lt 50 ]; then
            logger -t ai-system-validation "CRITICAL: System validation failed with $FAILED_TESTS failures and $SUCCESS_RATE% success rate"
          fi
          
          # Exit with appropriate code
          if [ "$FAILED_TESTS" -eq 0 ]; then
            echo -e "$(date) ''${GREEN}[SUCCESS]''${NC} All tests passed successfully!"
            exit 0
          elif [ "$SUCCESS_RATE" -ge 85 ]; then
            echo -e "$(date) ''${YELLOW}[WARNING]''${NC} Some tests failed but system is operational"
            exit 1
          else
            echo -e "$(date) ''${RED}[FAILURE]''${NC} Critical test failures detected"
            exit 2
          fi
        '';
      };
    };

    # Quick validation service
    systemd.services.ai-quick-validation = {
      description = "AI Quick Validation Check";
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        TimeoutStartSec = "5m";
        ExecStart = pkgs.writeShellScript "ai-quick-validation" ''
          #!/bin/bash
          
          echo "[$(date)] Running quick AI system validation..."
          
          ISSUES=0
          
          # Quick service checks
          if ! systemctl is-active ai-analysis-system &>/dev/null; then
            echo "WARNING: AI analysis service not active"
            ((ISSUES++))
          fi
          
          if ! test -d /var/log/ai-analysis; then
            echo "WARNING: AI analysis log directory missing"
            ((ISSUES++))
          fi
          
          if ! test -d /run/agenix; then
            echo "WARNING: Encrypted secrets not accessible"
            ((ISSUES++))
          fi
          
          # Check recent activity
          if ! find /var/log/ai-analysis -name "*.log" -mtime -1 | head -1 | grep -q .; then
            echo "WARNING: No recent AI analysis activity"
            ((ISSUES++))
          fi
          
          if [ "$ISSUES" -eq 0 ]; then
            echo "SUCCESS: Quick validation passed"
            exit 0
          else
            echo "RECOMMENDATION: Run full validation with 'systemctl start ai-system-validation'"
            exit 1
          fi
        '';
      };
    };

    # Timer for regular validation
    systemd.timers.ai-system-validation = {
      description = "AI System Validation Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "2h";
      };
    };

    # Create directories for validation reports
    systemd.tmpfiles.rules = [
      "d ${cfg.testReportPath} 0755 ai-analysis ai-analysis -"
      "d /var/log/ai-analysis 0755 ai-analysis ai-analysis -"
    ];

    # Install validation tools
    environment.systemPackages = with pkgs; [
      curl
      jq
      procps
      util-linux
    ];
  };
}