# AI Load Testing Module
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.ai.loadTesting;
in
{
  options.ai.loadTesting = {
    enable = mkEnableOption "Enable AI load testing capabilities";

    testDuration = mkOption {
      type = types.str;
      default = "5m";
      description = "Duration for load tests (e.g., 5m, 10s, 1h)";
    };

    maxConcurrentUsers = mkOption {
      type = types.int;
      default = 10;
      description = "Maximum number of concurrent users for load testing";
    };

    testInterval = mkOption {
      type = types.str;
      default = "daily";
      description = "Interval for automated load testing";
    };

    enableContinuousLoad = mkOption {
      type = types.bool;
      default = false;
      description = "Enable continuous load testing";
    };

    providers = mkOption {
      type = types.listOf types.str;
      default = [ "anthropic" "openai" "gemini" "ollama" ];
      description = "AI providers to test";
    };

    testEndpoints = mkOption {
      type = types.listOf types.str;
      default = [
        "http://localhost:9090/-/healthy" # Prometheus
        "http://localhost:3001/api/health" # Grafana
        "http://localhost:11434/api/tags" # Ollama
      ];
      description = "Service endpoints to load test";
    };

    loadTestProfiles = mkOption {
      type = types.attrs;
      default = {
        light = {
          users = 5;
          duration = "2m";
          rampUp = "30s";
        };
        moderate = {
          users = 15;
          duration = "5m";
          rampUp = "1m";
        };
        heavy = {
          users = 50;
          duration = "10m";
          rampUp = "2m";
        };
        stress = {
          users = 100;
          duration = "15m";
          rampUp = "3m";
        };
      };
      description = "Load testing profiles with different intensities";
    };

    alertThresholds = mkOption {
      type = types.attrs;
      default = {
        responseTime = 5000; # 5 seconds
        errorRate = 5; # 5% error rate
        throughput = 10; # 10 requests per second minimum
        cpuUsage = 80; # 80% CPU usage
        memoryUsage = 85; # 85% memory usage
      };
      description = "Alert thresholds for load testing metrics";
    };

    reportPath = mkOption {
      type = types.str;
      default = "/var/lib/ai-analysis/load-test-reports";
      description = "Path to store load test reports";
    };
  };

  config = mkIf cfg.enable {
    # AI Provider Load Testing Service
    systemd.services.ai-provider-load-test = {
      description = "AI Provider Load Testing Service";
      after = [ "network.target" ];
      wants = [ "network.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        TimeoutStartSec = "20m";
        ExecStart = pkgs.writeShellScript "ai-provider-load-test" ''
          #!/bin/bash

          # Configuration
          REPORT_DIR="${cfg.reportPath}"
          LOG_FILE="/var/log/ai-analysis/load-testing.log"
          HOSTNAME=$(hostname)
          TIMESTAMP=$(date +%Y%m%d_%H%M%S)
          REPORT_FILE="$REPORT_DIR/load_test_$HOSTNAME_$TIMESTAMP.json"

          # Test configuration
          TEST_DURATION="${cfg.testDuration}"
          MAX_USERS=${toString cfg.maxConcurrentUsers}
          PROVIDERS=(${concatStringsSep " " (map (p: "\"${p}\"") cfg.providers)})

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

          echo -e "$(date) ''${BLUE}[INFO]''${NC} Starting AI provider load testing..."
          echo -e "$(date) ''${BLUE}[INFO]''${NC} Test duration: $TEST_DURATION"
          echo -e "$(date) ''${BLUE}[INFO]''${NC} Max concurrent users: $MAX_USERS"
          echo -e "$(date) ''${BLUE}[INFO]''${NC} Hostname: $HOSTNAME"

          # Initialize test results
          TOTAL_TESTS=0
          PASSED_TESTS=0
          FAILED_TESTS=0
          TEST_RESULTS="[]"

          # Function to test AI provider performance
          test_ai_provider() {
            local provider="$1"
            local users="$2"
            local duration="$3"
            local test_name="ai_provider_''${provider}_load_test"

            echo -e "$(date) ''${BLUE}[TEST]''${NC} Testing $provider with $users users for $duration"

            local start_time=$(date +%s)
            local response_times=()
            local error_count=0
            local success_count=0
            local total_requests=0

            # Simple load test implementation
            for ((i=1; i<=users; i++)); do
              {
                local user_start=$(date +%s%3N)

                # Test AI provider with timeout
                if timeout 30 ai-cli -p "$provider" "test load $i" &>/dev/null; then
                  local user_end=$(date +%s%3N)
                  local response_time=$((user_end - user_start))
                  response_times+=($response_time)
                  ((success_count++))
                else
                  ((error_count++))
                fi
                ((total_requests++))
              } &

              # Limit concurrent processes
              if (( i % 5 == 0 )); then
                wait
              fi
            done

            # Wait for all background processes
            wait

            local end_time=$(date +%s)
            local test_duration=$((end_time - start_time))

            # Calculate statistics
            local avg_response_time=0
            local max_response_time=0
            local min_response_time=999999

            if [ ''${#response_times[@]} -gt 0 ]; then
              local sum=0
              for rt in "''${response_times[@]}"; do
                sum=$((sum + rt))
                if [ $rt -gt $max_response_time ]; then
                  max_response_time=$rt
                fi
                if [ $rt -lt $min_response_time ]; then
                  min_response_time=$rt
                fi
              done
              avg_response_time=$((sum / ''${#response_times[@]}))
            fi

            local error_rate=0
            if [ $total_requests -gt 0 ]; then
              error_rate=$((error_count * 100 / total_requests))
            fi

            local throughput=0
            if [ $test_duration -gt 0 ]; then
              throughput=$((total_requests / test_duration))
            fi

            # Determine test result
            local test_status="passed"
            local status_color="''$GREEN"

            if [ $error_rate -gt ${toString cfg.alertThresholds.errorRate} ]; then
              test_status="failed"
              status_color="''$RED"
              ((FAILED_TESTS++))
            elif [ $avg_response_time -gt ${toString cfg.alertThresholds.responseTime} ]; then
              test_status="failed"
              status_color="''$RED"
              ((FAILED_TESTS++))
            elif [ $throughput -lt ${toString cfg.alertThresholds.throughput} ]; then
              test_status="warning"
              status_color="''$YELLOW"
            else
              ((PASSED_TESTS++))
            fi

            ((TOTAL_TESTS++))

            echo -e "$(date) ''${status_color}[$(echo "$test_status" | tr '[:lower:]' '[:upper:]')]''${NC} $provider load test completed"
            echo -e "$(date) ''${BLUE}[INFO]''${NC} Success: $success_count, Errors: $error_count, Error Rate: $error_rate%"
            echo -e "$(date) ''${BLUE}[INFO]''${NC} Avg Response: ''${avg_response_time}ms, Max: ''${max_response_time}ms, Min: ''${min_response_time}ms"
            echo -e "$(date) ''${BLUE}[INFO]''${NC} Throughput: $throughput req/sec"

            # Add to test results
            local test_result="{
              \"name\": \"$test_name\",
              \"provider\": \"$provider\",
              \"status\": \"$test_status\",
              \"users\": $users,
              \"duration\": $test_duration,
              \"total_requests\": $total_requests,
              \"success_count\": $success_count,
              \"error_count\": $error_count,
              \"error_rate\": $error_rate,
              \"avg_response_time\": $avg_response_time,
              \"max_response_time\": $max_response_time,
              \"min_response_time\": $min_response_time,
              \"throughput\": $throughput,
              \"timestamp\": \"$(date -Iseconds)\"
            }"

            TEST_RESULTS=$(echo "$TEST_RESULTS" | jq --argjson result "$test_result" '. + [$result]')
          }

          # Function to test service endpoints
          test_service_endpoint() {
            local endpoint="$1"
            local users="$2"
            local duration="$3"
            local service_name=$(basename "$endpoint")

            echo -e "$(date) ''${BLUE}[TEST]''${NC} Testing endpoint $endpoint with $users users"

            local start_time=$(date +%s)
            local success_count=0
            local error_count=0
            local total_requests=0
            local response_times=()

            # Load test endpoint
            for ((i=1; i<=users; i++)); do
              {
                local req_start=$(date +%s%3N)

                if curl -sf "$endpoint" -m 10 &>/dev/null; then
                  local req_end=$(date +%s%3N)
                  local response_time=$((req_end - req_start))
                  response_times+=($response_time)
                  ((success_count++))
                else
                  ((error_count++))
                fi
                ((total_requests++))
              } &

              # Limit concurrent requests
              if (( i % 10 == 0 )); then
                wait
              fi
            done

            wait

            local end_time=$(date +%s)
            local test_duration=$((end_time - start_time))

            # Calculate statistics
            local avg_response_time=0
            if [ ''${#response_times[@]} -gt 0 ]; then
              local sum=0
              for rt in "''${response_times[@]}"; do
                sum=$((sum + rt))
              done
              avg_response_time=$((sum / ''${#response_times[@]}))
            fi

            local error_rate=0
            if [ $total_requests -gt 0 ]; then
              error_rate=$((error_count * 100 / total_requests))
            fi

            local throughput=0
            if [ $test_duration -gt 0 ]; then
              throughput=$((total_requests / test_duration))
            fi

            # Determine test result
            local test_status="passed"
            local status_color="''$GREEN"

            if [ $error_rate -gt ${toString cfg.alertThresholds.errorRate} ]; then
              test_status="failed"
              status_color="''$RED"
              ((FAILED_TESTS++))
            elif [ $avg_response_time -gt ${toString cfg.alertThresholds.responseTime} ]; then
              test_status="failed"
              status_color="''$RED"
              ((FAILED_TESTS++))
            else
              ((PASSED_TESTS++))
            fi

            ((TOTAL_TESTS++))

            echo -e "$(date) ''${status_color}[$(echo "$test_status" | tr '[:lower:]' '[:upper:]')]''${NC} $service_name endpoint test completed"
            echo -e "$(date) ''${BLUE}[INFO]''${NC} Success: $success_count, Errors: $error_count, Error Rate: $error_rate%"
            echo -e "$(date) ''${BLUE}[INFO]''${NC} Avg Response: ''${avg_response_time}ms, Throughput: $throughput req/sec"

            # Add to test results
            local test_result="{
              \"name\": \"endpoint_''${service_name}_load_test\",
              \"endpoint\": \"$endpoint\",
              \"status\": \"$test_status\",
              \"users\": $users,
              \"duration\": $test_duration,
              \"total_requests\": $total_requests,
              \"success_count\": $success_count,
              \"error_count\": $error_count,
              \"error_rate\": $error_rate,
              \"avg_response_time\": $avg_response_time,
              \"throughput\": $throughput,
              \"timestamp\": \"$(date -Iseconds)\"
            }"

            TEST_RESULTS=$(echo "$TEST_RESULTS" | jq --argjson result "$test_result" '. + [$result]')
          }

          # System resource monitoring during tests
          monitor_system_resources() {
            echo -e "$(date) ''${BLUE}[INFO]''${NC} Monitoring system resources during load test..."

            # Get initial system stats
            local initial_cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
            local initial_memory=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
            local initial_disk=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

            echo -e "$(date) ''${BLUE}[INFO]''${NC} Initial system state:"
            echo -e "$(date) ''${BLUE}[INFO]''${NC} CPU: $initial_cpu%, Memory: $initial_memory%, Disk: $initial_disk%"

            # Monitor during test (background process)
            {
              local max_cpu=0
              local max_memory=0
              local samples=0

              while sleep 5; do
                local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' | cut -d. -f1)
                local memory=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')

                if [ "$cpu" -gt "$max_cpu" ]; then
                  max_cpu=$cpu
                fi

                if [ "$memory" -gt "$max_memory" ]; then
                  max_memory=$memory
                fi

                ((samples++))

                # Check for resource alerts
                if [ "$cpu" -gt ${toString cfg.alertThresholds.cpuUsage} ]; then
                  echo -e "$(date) ''${YELLOW}[WARNING]''${NC} High CPU usage detected: $cpu%"
                fi

                if [ "$memory" -gt ${toString cfg.alertThresholds.memoryUsage} ]; then
                  echo -e "$(date) ''${YELLOW}[WARNING]''${NC} High memory usage detected: $memory%"
                fi

                # Stop after 5 minutes of monitoring
                if [ $samples -gt 60 ]; then
                  break
                fi
              done

              echo "$max_cpu $max_memory" > /tmp/load_test_max_resources
            } &

            local monitor_pid=$!

            # Return monitor PID for cleanup
            echo $monitor_pid
          }

          # Initialize test results JSON
          TEST_RESULTS="[]"

          # Start system monitoring
          monitor_pid=$(monitor_system_resources)

          # Test AI providers
          echo -e "$(date) ''${BLUE}[INFO]''${NC} === AI PROVIDER LOAD TESTING ==="
          for provider in "''${PROVIDERS[@]}"; do
            if command -v ai-cli &>/dev/null; then
              test_ai_provider "$provider" 5 "30s"
            else
              echo -e "$(date) ''${YELLOW}[WARNING]''${NC} ai-cli not available, skipping $provider"
            fi
          done

          # Test service endpoints
          echo -e "$(date) ''${BLUE}[INFO]''${NC} === SERVICE ENDPOINT LOAD TESTING ==="
          ENDPOINTS=(${concatStringsSep " " (map (e: "\"${e}\"") cfg.testEndpoints)})
          for endpoint in "''${ENDPOINTS[@]}"; do
            test_service_endpoint "$endpoint" 10 "30s"
          done

          # Stop monitoring
          kill $monitor_pid 2>/dev/null || true

          # Get final resource usage
          local max_resources=""
          if [ -f /tmp/load_test_max_resources ]; then
            max_resources=$(cat /tmp/load_test_max_resources)
            rm -f /tmp/load_test_max_resources
          fi

          local max_cpu=$(echo "$max_resources" | awk '{print $1}')
          local max_memory=$(echo "$max_resources" | awk '{print $2}')

          # Calculate success rate
          local success_rate=0
          if [ $TOTAL_TESTS -gt 0 ]; then
            success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
          fi

          # Create final report
          echo -e "$(date) ''${BLUE}[INFO]''${NC} === LOAD TEST SUMMARY ==="
          echo -e "$(date) ''${BLUE}[INFO]''${NC} Total Tests: $TOTAL_TESTS"
          echo -e "$(date) ''${GREEN}[INFO]''${NC} Passed: $PASSED_TESTS"
          echo -e "$(date) ''${RED}[INFO]''${NC} Failed: $FAILED_TESTS"
          echo -e "$(date) ''${BLUE}[INFO]''${NC} Success Rate: $success_rate%"
          echo -e "$(date) ''${BLUE}[INFO]''${NC} Max CPU Usage: $max_cpu%"
          echo -e "$(date) ''${BLUE}[INFO]''${NC} Max Memory Usage: $max_memory%"

          # Generate comprehensive report
          cat > "$REPORT_FILE" << EOF
          {
            "timestamp": "$(date -Iseconds)",
            "hostname": "$HOSTNAME",
            "load_test_summary": {
              "total_tests": $TOTAL_TESTS,
              "passed_tests": $PASSED_TESTS,
              "failed_tests": $FAILED_TESTS,
              "success_rate": $success_rate,
              "test_duration": "$TEST_DURATION",
              "max_concurrent_users": $MAX_USERS
            },
            "system_resources": {
              "max_cpu_usage": $max_cpu,
              "max_memory_usage": $max_memory,
              "cpu_threshold": ${toString cfg.alertThresholds.cpuUsage},
              "memory_threshold": ${toString cfg.alertThresholds.memoryUsage}
            },
            "test_results": $TEST_RESULTS,
            "thresholds": {
              "response_time": ${toString cfg.alertThresholds.responseTime},
              "error_rate": ${toString cfg.alertThresholds.errorRate},
              "throughput": ${toString cfg.alertThresholds.throughput}
            }
          }
          EOF

          # Report final status
          if [ $FAILED_TESTS -eq 0 ]; then
            echo -e "$(date) ''${GREEN}[SUCCESS]''${NC} All load tests passed successfully!"
            exit 0
          elif [ $success_rate -ge 80 ]; then
            echo -e "$(date) ''${YELLOW}[WARNING]''${NC} Some tests failed but system performance is acceptable"
            exit 1
          else
            echo -e "$(date) ''${RED}[FAILURE]''${NC} Critical load test failures detected"
            exit 2
          fi
        '';
      };
    };

    # Continuous load testing service
    systemd.services.ai-continuous-load-test = mkIf cfg.enableContinuousLoad {
      description = "AI Continuous Load Testing Service";
      after = [ "network.target" ];
      wants = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Restart = "always";
        RestartSec = "60s";
        ExecStart = pkgs.writeShellScript "ai-continuous-load-test" ''
          #!/bin/bash

          LOG_FILE="/var/log/ai-analysis/continuous-load-test.log"

          # Setup logging
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1

          echo "[$(date)] Starting continuous load testing..."

          while true; do
            # Light load test every 5 minutes
            echo "[$(date)] Running light load test..."

            # Test AI providers with light load
            if command -v ai-cli &>/dev/null; then
              for provider in anthropic ollama; do
                echo "[$(date)] Testing $provider with light load..."

                for i in {1..3}; do
                  timeout 10 ai-cli -p "$provider" "continuous test $i" &>/dev/null &
                done

                wait
              done
            fi

            # Test service endpoints
            for endpoint in http://localhost:9090/-/healthy http://localhost:11434/api/tags; do
              echo "[$(date)] Testing endpoint $endpoint..."
              curl -sf "$endpoint" -m 5 &>/dev/null || echo "[$(date)] Endpoint $endpoint failed"
            done

            # Sleep for 5 minutes
            sleep 300
          done
        '';
      };
    };

    # Load testing profiles service
    systemd.services.ai-load-test-profiles = {
      description = "AI Load Test Profiles Service";
      after = [ "network.target" ];
      wants = [ "network.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        TimeoutStartSec = "30m";
        ExecStart = pkgs.writeShellScript "ai-load-test-profiles" ''
          #!/bin/bash

          PROFILE="''${1:-moderate}"
          LOG_FILE="/var/log/ai-analysis/load-test-profiles.log"

          # Setup logging
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1

          echo "[$(date)] Starting load test profile: $PROFILE"

          # Load test profile configuration
          case "$PROFILE" in
            "light")
              USERS=${toString cfg.loadTestProfiles.light.users}
              DURATION="${cfg.loadTestProfiles.light.duration}"
              RAMP_UP="${cfg.loadTestProfiles.light.rampUp}"
              ;;
            "moderate")
              USERS=${toString cfg.loadTestProfiles.moderate.users}
              DURATION="${cfg.loadTestProfiles.moderate.duration}"
              RAMP_UP="${cfg.loadTestProfiles.moderate.rampUp}"
              ;;
            "heavy")
              USERS=${toString cfg.loadTestProfiles.heavy.users}
              DURATION="${cfg.loadTestProfiles.heavy.duration}"
              RAMP_UP="${cfg.loadTestProfiles.heavy.rampUp}"
              ;;
            "stress")
              USERS=${toString cfg.loadTestProfiles.stress.users}
              DURATION="${cfg.loadTestProfiles.stress.duration}"
              RAMP_UP="${cfg.loadTestProfiles.stress.rampUp}"
              ;;
            *)
              echo "[$(date)] Unknown profile: $PROFILE"
              exit 1
              ;;
          esac

          echo "[$(date)] Profile configuration: $USERS users, $DURATION duration, $RAMP_UP ramp-up"

          # Execute load test with profile
          echo "[$(date)] Starting load test with profile settings..."

          # Simple implementation of ramped load testing
          ramp_seconds=$(echo "$RAMP_UP" | sed 's/[^0-9]//g')
          test_seconds=$(echo "$DURATION" | sed 's/[^0-9]//g')

          if [ "$DURATION" == *"m"* ]; then
            test_seconds=$((test_seconds * 60))
          fi

          if [ "$RAMP_UP" == *"m"* ]; then
            ramp_seconds=$((ramp_seconds * 60))
          fi

          # Ramp up users gradually
          for ((i=1; i<=USERS; i++)); do
            {
              # Run test for specified duration
              local end_time=$(($(date +%s) + test_seconds))

              while [ $(date +%s) -lt $end_time ]; do
                if command -v ai-cli &>/dev/null; then
                  ai-cli -p ollama "profile test user $i" &>/dev/null || true
                fi
                sleep 2
              done
            } &

            # Ramp up delay
            if [ $i -lt $USERS ]; then
              sleep $((ramp_seconds / USERS))
            fi
          done

          # Wait for all users to complete
          wait

          echo "[$(date)] Load test profile '$PROFILE' completed"
        '';
      };
    };

    # Timers for load testing
    systemd.timers.ai-provider-load-test = {
      description = "AI Provider Load Test Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.testInterval;
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
    };

    # Create necessary directories
    systemd.tmpfiles.rules = [
      "d ${cfg.reportPath} 0755 root root -"
      "d /var/log/ai-analysis 0755 ai-analysis ai-analysis -"
    ];

    # Load testing management commands
    environment.systemPackages = [
      pkgs.curl
      pkgs.jq

      (pkgs.writeShellScriptBin "ai-load-test" ''
        #!/bin/bash

        PROFILE="''${1:-moderate}"

        echo "Starting AI load test with profile: $PROFILE"

        case "$PROFILE" in
          "light"|"moderate"|"heavy"|"stress")
            systemctl start ai-load-test-profiles
            ;;
          "continuous")
            if systemctl is-active ai-continuous-load-test &>/dev/null; then
              echo "Continuous load test already running"
            else
              systemctl start ai-continuous-load-test
            fi
            ;;
          "stop")
            systemctl stop ai-continuous-load-test
            echo "Continuous load test stopped"
            ;;
          *)
            echo "Usage: $0 {light|moderate|heavy|stress|continuous|stop}"
            echo "Available profiles:"
            echo "  light    - ${toString cfg.loadTestProfiles.light.users} users, ${cfg.loadTestProfiles.light.duration}"
            echo "  moderate - ${toString cfg.loadTestProfiles.moderate.users} users, ${cfg.loadTestProfiles.moderate.duration}"
            echo "  heavy    - ${toString cfg.loadTestProfiles.heavy.users} users, ${cfg.loadTestProfiles.heavy.duration}"
            echo "  stress   - ${toString cfg.loadTestProfiles.stress.users} users, ${cfg.loadTestProfiles.stress.duration}"
            echo "  continuous - Continuous light load testing"
            echo "  stop     - Stop continuous load testing"
            exit 1
            ;;
        esac
      '')

      (pkgs.writeShellScriptBin "ai-load-test-status" ''
        #!/bin/bash

        echo "=== AI Load Testing Status ==="
        echo

        echo "Load Test Services:"
        systemctl status ai-provider-load-test --no-pager -l
        echo

        if systemctl is-active ai-continuous-load-test &>/dev/null; then
          echo "Continuous Load Test:"
          systemctl status ai-continuous-load-test --no-pager -l
          echo
        fi

        echo "Recent Load Test Reports:"
        ls -la ${cfg.reportPath}/ | tail -10
        echo

        echo "Load Test Logs (last 20 lines):"
        tail -20 /var/log/ai-analysis/load-testing.log 2>/dev/null || echo "No load test logs found"
      '')

      (pkgs.writeShellScriptBin "ai-load-test-report" ''
        #!/bin/bash

        REPORT_FILE="''${1:-latest}"

        if [ "$REPORT_FILE" = "latest" ]; then
          REPORT_FILE=$(ls -t ${cfg.reportPath}/load_test_*.json 2>/dev/null | head -1)
        fi

        if [ -z "$REPORT_FILE" ] || [ ! -f "$REPORT_FILE" ]; then
          echo "No load test report found"
          exit 1
        fi

        echo "=== Load Test Report: $(basename "$REPORT_FILE") ==="
        echo

        # Extract and display key metrics
        jq -r '
          "Timestamp: " + .timestamp,
          "Hostname: " + .hostname,
          "",
          "Summary:",
          "  Total Tests: " + (.load_test_summary.total_tests | tostring),
          "  Passed: " + (.load_test_summary.passed_tests | tostring),
          "  Failed: " + (.load_test_summary.failed_tests | tostring),
          "  Success Rate: " + (.load_test_summary.success_rate | tostring) + "%",
          "",
          "System Resources:",
          "  Max CPU: " + (.system_resources.max_cpu_usage | tostring) + "%",
          "  Max Memory: " + (.system_resources.max_memory_usage | tostring) + "%",
          "",
          "Test Results:"
        ' "$REPORT_FILE"

        # Display individual test results
        jq -r '.test_results[] |
          "  " + .name + ": " + .status +
          " (avg: " + (.avg_response_time | tostring) + "ms, " +
          "errors: " + (.error_rate | tostring) + "%)"
        ' "$REPORT_FILE"
      '')
    ];

    # Shell aliases for load testing
    programs.zsh.shellAliases = mkIf config.programs.zsh.enable {
      "load-test" = "ai-load-test";
      "load-test-status" = "ai-load-test-status";
      "load-test-report" = "ai-load-test-report";
      "load-test-light" = "ai-load-test light";
      "load-test-stress" = "ai-load-test stress";
    };
  };
}
