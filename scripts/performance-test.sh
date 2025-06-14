#!/usr/bin/env bash

# NixOS Performance Testing Script
# Measure build times, memory usage, and other performance metrics

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

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $*"
}

info() {
    echo -e "${BLUE}${BOLD}INFO:${NC} $*"
}

success() {
    echo -e "${GREEN}${BOLD}SUCCESS:${NC} $*"
}

warning() {
    echo -e "${YELLOW}${BOLD}WARNING:${NC} $*"
}

error() {
    echo -e "${RED}${BOLD}ERROR:${NC} $*"
}

# Measure build time for a host
measure_build_time() {
    local host="$1"
    local runs="${2:-3}"
    
    info "Measuring build time for $host (averaging $runs runs)..."
    
    local total_time=0
    local successful_runs=0
    
    for ((i=1; i<=runs; i++)); do
        info "Run $i/$runs for $host..."
        
        # Clear any existing result
        rm -f result
        
        local start_time
        start_time=$(date +%s.%N)
        
        if nix build ".#nixosConfigurations.$host.config.system.build.toplevel" --no-link 2>/dev/null; then
            local end_time
            end_time=$(date +%s.%N)
            local run_time
            run_time=$(echo "$end_time - $start_time" | bc)
            
            info "Run $i completed in ${run_time}s"
            total_time=$(echo "$total_time + $run_time" | bc)
            successful_runs=$((successful_runs + 1))
        else
            warning "Run $i failed for $host"
        fi
    done
    
    if [ $successful_runs -gt 0 ]; then
        local avg_time
        avg_time=$(echo "scale=2; $total_time / $successful_runs" | bc)
        success "$host average build time: ${avg_time}s (from $successful_runs/$runs successful runs)"
        echo "$host,$avg_time,$successful_runs,$runs" >> /tmp/build-times.csv
    else
        error "All runs failed for $host"
    fi
}

# Measure memory usage during build
measure_memory_usage() {
    local host="$1"
    
    info "Measuring memory usage for $host build..."
    
    # Clear any existing result
    rm -f result
    
    # Start memory monitoring in background
    local mem_log="/tmp/memory-usage-$host.log"
    (
        while true; do
            if pgrep -f "nix.*build.*$host" > /dev/null; then
                local mem_usage
                mem_usage=$(ps aux | grep -E "nix.*build.*$host" | awk '{sum+=$6} END {print sum/1024}' 2>/dev/null || echo "0")
                echo "$(date +%s),$mem_usage" >> "$mem_log"
            fi
            sleep 1
        done
    ) &
    local monitor_pid=$!
    
    # Run the build
    local start_time
    start_time=$(date +%s.%N)
    
    if nix build ".#nixosConfigurations.$host.config.system.build.toplevel" --no-link; then
        local end_time
        end_time=$(date +%s.%N)
        local build_time
        build_time=$(echo "$end_time - $start_time" | bc)
        
        # Stop monitoring
        kill $monitor_pid 2>/dev/null || true
        
        if [ -f "$mem_log" ] && [ -s "$mem_log" ]; then
            local max_memory
            max_memory=$(awk -F, 'BEGIN{max=0} {if($2>max) max=$2} END{print max}' "$mem_log")
            local avg_memory
            avg_memory=$(awk -F, '{sum+=$2; count++} END{if(count>0) print sum/count; else print 0}' "$mem_log")
            
            success "$host memory usage - Max: ${max_memory}MB, Avg: ${avg_memory}MB, Time: ${build_time}s"
            echo "$host,$max_memory,$avg_memory,$build_time" >> /tmp/memory-usage.csv
        else
            warning "No memory data collected for $host"
        fi
        
        rm -f "$mem_log"
    else
        kill $monitor_pid 2>/dev/null || true
        error "Build failed for $host"
        rm -f "$mem_log"
    fi
}

# Measure flake evaluation time
measure_flake_eval_time() {
    info "Measuring flake evaluation time..."
    
    local runs=5
    local total_time=0
    
    for ((i=1; i<=runs; i++)); do
        local start_time
        start_time=$(date +%s.%N)
        
        nix flake show --json > /dev/null 2>&1
        
        local end_time
        end_time=$(date +%s.%N)
        local run_time
        run_time=$(echo "$end_time - $start_time" | bc)
        
        total_time=$(echo "$total_time + $run_time" | bc)
    done
    
    local avg_time
    avg_time=$(echo "scale=3; $total_time / $runs" | bc)
    success "Flake evaluation average time: ${avg_time}s"
    echo "flake-eval,$avg_time,$runs" >> /tmp/performance-metrics.csv
}

# Test build parallelization efficiency
test_parallel_builds() {
    info "Testing parallel build efficiency..."
    
    # Build sequentially
    info "Building hosts sequentially..."
    local seq_start
    seq_start=$(date +%s.%N)
    
    for host in "${ACTIVE_HOSTS[@]:0:2}"; do  # Test with first 2 hosts
        nix build ".#nixosConfigurations.$host.config.system.build.toplevel" --no-link
    done
    
    local seq_end
    seq_end=$(date +%s.%N)
    local seq_time
    seq_time=$(echo "$seq_end - $seq_start" | bc)
    
    # Build in parallel
    info "Building hosts in parallel..."
    local par_start
    par_start=$(date +%s.%N)
    
    local pids=()
    for host in "${ACTIVE_HOSTS[@]:0:2}"; do
        nix build ".#nixosConfigurations.$host.config.system.build.toplevel" --no-link &
        pids+=($!)
    done
    
    # Wait for all parallel builds to complete
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    local par_end
    par_end=$(date +%s.%N)
    local par_time
    par_time=$(echo "$par_end - $par_start" | bc)
    
    local efficiency
    efficiency=$(echo "scale=2; ($seq_time - $par_time) / $seq_time * 100" | bc)
    
    success "Sequential time: ${seq_time}s, Parallel time: ${par_time}s"
    success "Parallel efficiency: ${efficiency}% improvement"
    echo "parallel-efficiency,$seq_time,$par_time,$efficiency" >> /tmp/performance-metrics.csv
}

# Test cache hit rates
test_cache_performance() {
    info "Testing cache performance..."
    
    # First build (cold cache)
    info "Cold cache build..."
    rm -f result
    nix-collect-garbage > /dev/null 2>&1 || true
    
    local cold_start
    cold_start=$(date +%s.%N)
    nix build ".#nixosConfigurations.${ACTIVE_HOSTS[0]}.config.system.build.toplevel" --no-link
    local cold_end
    cold_end=$(date +%s.%N)
    local cold_time
    cold_time=$(echo "$cold_end - $cold_start" | bc)
    
    # Second build (warm cache)
    info "Warm cache build..."
    local warm_start
    warm_start=$(date +%s.%N)
    nix build ".#nixosConfigurations.${ACTIVE_HOSTS[0]}.config.system.build.toplevel" --no-link
    local warm_end
    warm_end=$(date +%s.%N)
    local warm_time
    warm_time=$(echo "$warm_end - $warm_start" | bc)
    
    local cache_efficiency
    cache_efficiency=$(echo "scale=2; ($cold_time - $warm_time) / $cold_time * 100" | bc)
    
    success "Cold cache: ${cold_time}s, Warm cache: ${warm_time}s"
    success "Cache efficiency: ${cache_efficiency}% improvement"
    echo "cache-efficiency,$cold_time,$warm_time,$cache_efficiency" >> /tmp/performance-metrics.csv
}

# Generate performance report
generate_performance_report() {
    info "Generating performance report..."
    
    local report_file="/tmp/nixos-performance-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# NixOS Configuration Performance Report

Generated: $(date)
Configuration: $(pwd)

## Build Times

EOF
    
    if [ -f /tmp/build-times.csv ]; then
        echo "| Host | Average Time (s) | Successful Runs | Total Runs |" >> "$report_file"
        echo "|------|------------------|-----------------|------------|" >> "$report_file"
        while IFS=, read -r host time success total; do
            echo "| $host | $time | $success | $total |" >> "$report_file"
        done < /tmp/build-times.csv
        echo "" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Memory Usage

EOF
    
    if [ -f /tmp/memory-usage.csv ]; then
        echo "| Host | Max Memory (MB) | Avg Memory (MB) | Build Time (s) |" >> "$report_file"
        echo "|------|-----------------|-----------------|----------------|" >> "$report_file"
        while IFS=, read -r host max_mem avg_mem time; do
            echo "| $host | $max_mem | $avg_mem | $time |" >> "$report_file"
        done < /tmp/memory-usage.csv
        echo "" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Performance Metrics

EOF
    
    if [ -f /tmp/performance-metrics.csv ]; then
        echo "| Metric | Value | Details |" >> "$report_file"
        echo "|--------|-------|---------|" >> "$report_file"
        while IFS=, read -r metric value details; do
            echo "| $metric | $value | $details |" >> "$report_file"
        done < /tmp/performance-metrics.csv
    fi
    
    success "Performance report generated: $report_file"
    
    # Cleanup temporary files
    rm -f /tmp/build-times.csv /tmp/memory-usage.csv /tmp/performance-metrics.csv
}

# Main function
main() {
    cd "$CONFIG_DIR"
    
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                        NixOS Performance Tester                             ║"
    echo "║                                                                              ║"
    echo "║  Measure build times, memory usage, and optimization metrics               ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Check for bc dependency
    if ! command -v bc &> /dev/null; then
        error "bc (basic calculator) is required for this script"
        exit 1
    fi
    
    # Initialize CSV files with headers
    echo "host,avg_time,successful_runs,total_runs" > /tmp/build-times.csv
    echo "host,max_memory,avg_memory,build_time" > /tmp/memory-usage.csv
    echo "metric,value,details" > /tmp/performance-metrics.csv
    
    local test_type="${1:-full}"
    
    case "$test_type" in
        "build-times")
            for host in "${ACTIVE_HOSTS[@]}"; do
                measure_build_time "$host" 3
            done
            ;;
        "memory")
            for host in "${ACTIVE_HOSTS[@]}"; do
                measure_memory_usage "$host"
            done
            ;;
        "eval")
            measure_flake_eval_time
            ;;
        "parallel")
            test_parallel_builds
            ;;
        "cache")
            test_cache_performance
            ;;
        "full")
            info "Running comprehensive performance tests..."
            measure_flake_eval_time
            test_cache_performance
            for host in "${ACTIVE_HOSTS[@]:0:2}"; do  # Test subset for full run
                measure_build_time "$host" 2
                measure_memory_usage "$host"
            done
            test_parallel_builds
            ;;
        *)
            error "Unknown test type: $test_type"
            echo "Usage: $0 [build-times|memory|eval|parallel|cache|full]"
            exit 1
            ;;
    esac
    
    generate_performance_report
}

main "$@"
