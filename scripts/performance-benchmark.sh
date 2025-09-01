#!/usr/bin/env bash
set -euo pipefail

# NixOS Configuration Performance Benchmark
# Measures evaluation and build times with detailed profiling

HOSTNAME=${1:-p620}
ITERATIONS=${2:-3}
RESULTS_DIR="/tmp/nixos-perf-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$RESULTS_DIR"

echo "🚀 NixOS Performance Benchmark - Host: $HOSTNAME"
echo "📊 Results will be saved to: $RESULTS_DIR"

# Function to measure command execution time
measure_time() {
    local cmd="$1"
    local label="$2"
    local output_file="$RESULTS_DIR/${label}.log"
    
    echo "⏱️  Testing: $label"
    
    # Run multiple iterations and calculate average
    local total_time=0
    for i in $(seq 1 $ITERATIONS); do
        echo "  Iteration $i/$ITERATIONS"
        # Use GNU time for detailed resource usage
        /usr/bin/time -v bash -c "$cmd" 2>"$output_file.$i" >/dev/null
        local iteration_time=$(grep "Elapsed" "$output_file.$i" | awk '{print $8}' | tr ':' ' ' | awk '{print $1*60 + $2}')
        total_time=$(echo "$total_time + $iteration_time" | bc -l)
    done
    
    local avg_time=$(echo "scale=2; $total_time / $ITERATIONS" | bc -l)
    echo "  ✅ Average time: ${avg_time}s"
    echo "$avg_time" > "$output_file.average"
}

# Benchmark different configuration aspects
echo "📊 Starting comprehensive performance analysis..."

# 1. Pure evaluation time (no building)
measure_time "nix eval --raw .#nixosConfigurations.$HOSTNAME.config.system.build.toplevel.outPath" "01-evaluation"

# 2. Dry-run build (planning phase)
measure_time "nix build --dry-run .#nixosConfigurations.$HOSTNAME.config.system.build.toplevel" "02-dry-run"

# 3. Module import time (specific to your architecture)
measure_time "nix eval --expr 'let flake = builtins.getFlake \".\"; in flake.nixosConfigurations.$HOSTNAME.config.system.build.toplevel'" "03-module-imports"

# 4. Feature flag evaluation time
measure_time "nix eval --json .#nixosConfigurations.$HOSTNAME.config.features" "04-feature-flags"

# 5. Service configuration evaluation
measure_time "nix eval --json .#nixosConfigurations.$HOSTNAME.config.services" "05-services"

# 6. Package resolution time
measure_time "nix eval --json .#nixosConfigurations.$HOSTNAME.config.environment.systemPackages" "06-packages"

# Generate performance report
generate_report() {
    local report_file="$RESULTS_DIR/performance-report.md"
    
    cat > "$report_file" << EOF
# NixOS Performance Report - $(date)

## Configuration Details
- **Host**: $HOSTNAME
- **Iterations**: $ITERATIONS
- **Module Count**: $(find modules/ -name "*.nix" | wc -l)
- **Import Chain Depth**: $(find modules/ -name "default.nix" | wc -l)

## Performance Results (Average over $ITERATIONS runs)

| Test | Time (seconds) | Performance Level |
|------|---------------:|-------------------|
| Evaluation | $(cat $RESULTS_DIR/01-evaluation.log.average) | $([ $(echo "$(cat $RESULTS_DIR/01-evaluation.log.average) < 10" | bc -l) -eq 1 ] && echo "🟢 Excellent" || echo "🔴 Needs Optimization") |
| Dry Run | $(cat $RESULTS_DIR/02-dry-run.log.average) | $([ $(echo "$(cat $RESULTS_DIR/02-dry-run.log.average) < 30" | bc -l) -eq 1 ] && echo "🟢 Good" || echo "🔴 Slow") |
| Module Imports | $(cat $RESULTS_DIR/03-module-imports.log.average) | $([ $(echo "$(cat $RESULTS_DIR/03-module-imports.log.average) < 15" | bc -l) -eq 1 ] && echo "🟢 Good" || echo "🔴 Too Complex") |
| Feature Flags | $(cat $RESULTS_DIR/04-feature-flags.log.average) | $([ $(echo "$(cat $RESULTS_DIR/04-feature-flags.log.average) < 5" | bc -l) -eq 1 ] && echo "🟢 Fast" || echo "🔴 Slow") |

## Optimization Recommendations

EOF

    # Add specific recommendations based on results
    if [ $(echo "$(cat $RESULTS_DIR/01-evaluation.log.average) > 30" | bc -l) -eq 1 ]; then
        echo "- ⚠️  **Evaluation time > 30s**: Consider module consolidation" >> "$report_file"
    fi
    
    if [ $(echo "$(cat $RESULTS_DIR/03-module-imports.log.average) > 20" | bc -l) -eq 1 ]; then
        echo "- ⚠️  **Module imports > 20s**: Implement lazy loading" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "## Raw Data" >> "$report_file"
    echo "Detailed logs available in: $RESULTS_DIR" >> "$report_file"
    
    echo "📋 Performance report generated: $report_file"
    cat "$report_file"
}

generate_report

echo ""
echo "🎯 Performance Benchmark Complete!"
echo "💡 To improve performance:"
echo "   1. Use consolidated modules (reduces import chains)"
echo "   2. Enable lazy loading (loads only needed features)"  
echo "   3. Optimize caching (binary cache + eval cache)"
echo "   4. Reduce feature flag complexity"