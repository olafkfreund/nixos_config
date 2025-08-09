# AI Load Testing Guide

## Overview

This guide provides comprehensive information about load testing the AI infrastructure, including test execution, result interpretation, and performance optimization based on load testing results.

## Load Testing Architecture

### Current Configuration

- **Test Duration**: 3 minutes (configurable)
- **Max Concurrent Users**: 8 (configurable)
- **Test Interval**: Weekly (automated)
- **Continuous Load**: Disabled for development systems

### Test Targets

- **AI Providers**: Anthropic, Ollama (local)
- **Service Endpoints**:
  - Prometheus: <http://localhost:9090/-/healthy>
  - Grafana: <http://localhost:3001/api/health>
  - Ollama: <http://localhost:11434/api/tags>

## Load Testing Profiles

### Light Profile

- **Users**: 3 concurrent users
- **Duration**: 1 minute
- **Ramp-up**: 20 seconds
- **Use Case**: Basic functionality testing

### Moderate Profile (Default)

- **Users**: 8 concurrent users
- **Duration**: 3 minutes
- **Ramp-up**: 40 seconds
- **Use Case**: Regular performance validation

### Heavy Profile

- **Users**: 15 concurrent users
- **Duration**: 5 minutes
- **Ramp-up**: 1 minute
- **Use Case**: Stress testing under load

### Stress Profile

- **Users**: 25 concurrent users
- **Duration**: 8 minutes
- **Ramp-up**: 2 minutes
- **Use Case**: Maximum capacity testing

## Load Testing Commands

### Basic Load Testing

```bash
# Run default (moderate) load test
ai-load-test

# Run specific profile
ai-load-test light
ai-load-test moderate
ai-load-test heavy
ai-load-test stress

# Start continuous load testing
ai-load-test continuous

# Stop continuous load testing
ai-load-test stop
```

### Load Test Status and Reports

```bash
# Check load test status
ai-load-test-status

# View latest load test report
ai-load-test-report

# View specific report
ai-load-test-report /mnt/data/load-test-reports/load_test_p620_20250709.json

# Monitor load test in real-time
journalctl -u ai-provider-load-test -f
```

### Shell Aliases

```bash
# Quick aliases available
load-test          # Run moderate load test
load-test-status   # Check status
load-test-report   # View latest report
load-test-light    # Run light profile
load-test-stress   # Run stress profile
```

## Load Test Execution

### Manual Load Testing

```bash
# Step 1: Check system readiness
ai-cli --status
systemctl status ai-*

# Step 2: Run load test
ai-load-test moderate

# Step 3: Monitor progress
journalctl -u ai-provider-load-test -f

# Step 4: Check results
ai-load-test-report
```

### Automated Load Testing

Load tests run automatically on a weekly schedule via systemd timers:

```bash
# Check timer status
systemctl status ai-provider-load-test.timer

# View timer schedule
systemctl list-timers ai-provider-load-test.timer

# Run manual test
systemctl start ai-provider-load-test
```

### Continuous Load Testing

```bash
# Enable continuous load testing (use with caution)
ai-load-test continuous

# Monitor continuous testing
journalctl -u ai-continuous-load-test -f

# Stop continuous testing
ai-load-test stop
```

## Test Result Interpretation

### Success Metrics

- **Response Time**: <8000ms (configured for P620)
- **Error Rate**: <10% (acceptable for development)
- **Throughput**: >5 requests/second minimum
- **Resource Usage**: CPU <75%, Memory <80%

### Load Test Report Structure

```json
{
  "timestamp": "2025-07-09T10:30:00Z",
  "hostname": "p620",
  "load_test_summary": {
    "total_tests": 10,
    "passed_tests": 8,
    "failed_tests": 2,
    "success_rate": 80,
    "test_duration": "3m",
    "max_concurrent_users": 8
  },
  "system_resources": {
    "max_cpu_usage": 65,
    "max_memory_usage": 45,
    "cpu_threshold": 75,
    "memory_threshold": 80
  },
  "test_results": [
    {
      "name": "ai_provider_anthropic_load_test",
      "provider": "anthropic",
      "status": "passed",
      "users": 5,
      "duration": 180,
      "total_requests": 15,
      "success_count": 13,
      "error_count": 2,
      "error_rate": 13,
      "avg_response_time": 2500,
      "max_response_time": 5000,
      "min_response_time": 1200,
      "throughput": 12,
      "timestamp": "2025-07-09T10:30:00Z"
    }
  ]
}
```

### Interpreting Results

#### Success Rate Analysis

- **>90%**: Excellent performance
- **80-90%**: Good performance, monitor trends
- **70-80%**: Acceptable, consider optimization
- **<70%**: Poor performance, optimization required

#### Response Time Analysis

- **<3000ms**: Excellent response time
- **3000-5000ms**: Good response time
- **5000-8000ms**: Acceptable response time
- **>8000ms**: Poor response time, optimization needed

#### Error Rate Analysis

- **<5%**: Excellent reliability
- **5-10%**: Good reliability
- **10-15%**: Acceptable for development
- **>15%**: Poor reliability, investigation required

#### Throughput Analysis

- **>10 req/s**: Excellent throughput
- **5-10 req/s**: Good throughput
- **2-5 req/s**: Acceptable throughput
- **<2 req/s**: Poor throughput, optimization needed

## Performance Optimization Based on Load Testing

### High Response Times

**Symptoms**: Average response time >5000ms
**Investigation**:

```bash
# Check AI provider status
ai-cli --status

# Check system resources during test
htop
free -h
iostat -x 1 5

# Check network connectivity
ping api.anthropic.com
curl -w "@curl-format.txt" -o /dev/null -s "https://api.anthropic.com"
```

**Optimization Actions**:

1. Restart AI provider optimization: `systemctl restart ai-provider-optimization`
2. Clear AI cache: `rm -rf /var/cache/ai-analysis/*`
3. Optimize system performance: `systemctl start ai-system-optimization`
4. Check for resource constraints

### High Error Rates

**Symptoms**: Error rate >10%
**Investigation**:

```bash
# Check AI provider logs
journalctl -u ai-provider-optimization --since "1 hour ago"

# Check API key validity
./scripts/manage-secrets.sh status

# Test individual providers
ai-cli -p anthropic "test"
ai-cli -p ollama "test"
```

**Optimization Actions**:

1. Verify API keys are valid
2. Check API rate limits
3. Restart AI services: `systemctl restart ai-*`
4. Check network connectivity

### Low Throughput

**Symptoms**: Throughput <5 req/s
**Investigation**:

```bash
# Check concurrent request limits
cat /etc/ai-providers.json | jq '.global_settings.max_concurrent_requests'

# Check system bottlenecks
iotop -o
netstat -i
```

**Optimization Actions**:

1. Increase concurrent request limits
2. Optimize system I/O: `systemctl start ai-system-optimization`
3. Check for network bottlenecks
4. Scale concurrent users gradually

### High Resource Usage

**Symptoms**: CPU >75% or Memory >80% during tests
**Investigation**:

```bash
# Monitor resource usage during test
top -d 1
free -h -s 1

# Check resource optimization
systemctl status ai-memory-optimization
systemctl status ai-system-optimization
```

**Optimization Actions**:

1. Run memory optimization: `systemctl start ai-memory-optimization`
2. Adjust load test profile to lower intensity
3. Optimize system resources: `systemctl start ai-system-optimization`
4. Check for resource leaks

## Load Testing Best Practices

### Test Planning

1. **Start Small**: Begin with light profile, gradually increase
2. **Monitor Resources**: Watch CPU, memory, and disk during tests
3. **Test Regularly**: Run weekly automated tests
4. **Document Results**: Keep test reports for trend analysis

### Test Execution

1. **Clean Environment**: Stop unnecessary services before testing
2. **Stable Network**: Ensure stable network connectivity
3. **Monitor Progress**: Watch logs during test execution
4. **Allow Recovery**: Give system time to recover between tests

### Result Analysis

1. **Trend Analysis**: Compare results over time
2. **Performance Baselines**: Establish performance baselines
3. **Optimization Planning**: Use results to guide optimization
4. **Capacity Planning**: Plan for future growth

## Host-Specific Load Testing

### P620 (AMD Workstation)

**Test Focus**: AI provider performance, local inference
**Configuration**:

- Providers: Anthropic, Ollama
- GPU: AMD with ROCm acceleration
- Memory: 32GB DDR4
- Storage: NVMe SSD

**Load Test Commands**:

```bash
# Test AI providers
ai-load-test moderate

# Test local inference specifically
systemctl start ai-load-test-profiles

# Monitor GPU during testing
watch -n 1 rocm-smi
```

**Performance Expectations**:

- Anthropic: <3000ms response time
- Ollama: <2000ms response time (local)
- CPU: <70% under load
- Memory: <60% under load

### P510 (Intel Xeon)

**Test Focus**: High-performance computing, NVIDIA GPU
**Configuration**:

- High storage usage (79.6%)
- NVIDIA GPU acceleration
- Multiple CPU cores

**Load Test Commands**:

```bash
# Careful with storage usage
df -h / && ai-load-test light

# Monitor storage during test
watch -n 1 'df -h / && free -h'
```

**Performance Expectations**:

- Higher throughput due to more cores
- Watch storage usage carefully
- NVIDIA GPU acceleration available

### DEX5550 (Intel SFF)

**Test Focus**: Monitoring server performance
**Configuration**:

- Monitoring services running
- Lower performance expectations

**Load Test Commands**:

```bash
# Light testing only on monitoring server
ai-load-test light

# Monitor monitoring services during test
systemctl status prometheus grafana
```

**Performance Expectations**:

- Lower performance due to monitoring overhead
- Focus on service availability
- Monitor monitoring service impact

## Troubleshooting Load Testing Issues

### Load Test Service Won't Start

**Symptoms**: `systemctl start ai-provider-load-test` fails
**Diagnosis**:

```bash
systemctl status ai-provider-load-test
journalctl -u ai-provider-load-test --since "1 hour ago"
```

**Resolution**:

1. Check service configuration
2. Verify dependencies are running
3. Check disk space for reports
4. Restart service: `systemctl restart ai-provider-load-test`

### No Load Test Reports Generated

**Symptoms**: No files in `/mnt/data/load-test-reports/`
**Diagnosis**:

```bash
ls -la /mnt/data/load-test-reports/
systemctl status ai-provider-load-test
```

**Resolution**:

1. Check directory permissions
2. Verify report path configuration
3. Check disk space
4. Run manual test: `systemctl start ai-provider-load-test`

### Load Test Hangs or Times Out

**Symptoms**: Load test runs indefinitely
**Diagnosis**:

```bash
ps aux | grep -i load
journalctl -u ai-provider-load-test -f
```

**Resolution**:

1. Kill hanging processes: `pkill -f "ai-load-test"`
2. Check AI provider availability
3. Reduce test intensity
4. Restart AI services

### High System Load During Testing

**Symptoms**: System becomes unresponsive
**Diagnosis**:

```bash
uptime
top
htop
```

**Resolution**:

1. Stop load testing: `ai-load-test stop`
2. Reduce test profile intensity
3. Check for resource constraints
4. Optimize system performance

## Advanced Load Testing

### Custom Load Test Profiles

Create custom profiles by modifying the configuration:

```nix
loadTestProfiles = {
  custom = {
    users = 12;
    duration = "4m";
    rampUp = "45s";
  };
};
```

### Load Test Automation

Set up automated load testing with custom schedules:

```bash
# Custom timer configuration
systemctl edit ai-provider-load-test.timer

# Add custom schedule
[Timer]
OnCalendar=Mon,Wed,Fri *-*-* 09:00:00
```

### Performance Regression Testing

Compare load test results over time:

```bash
# Compare last two test results
latest=$(ls -t /mnt/data/load-test-reports/ | head -1)
previous=$(ls -t /mnt/data/load-test-reports/ | head -2 | tail -1)

echo "Latest: $latest"
echo "Previous: $previous"

# Compare success rates
jq '.load_test_summary.success_rate' "/mnt/data/load-test-reports/$latest"
jq '.load_test_summary.success_rate' "/mnt/data/load-test-reports/$previous"
```

---

_This load testing guide should be used with the Operations Runbook and Monitoring Guide._
_For optimal results, run load tests during off-peak hours._
_Last Updated: $(date)_
