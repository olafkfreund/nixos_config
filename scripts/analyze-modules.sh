#!/usr/bin/env bash
# scripts/analyze-modules.sh
# Analyzes NixOS modules for code quality, anti-patterns, and duplication.
# Generates a JSON report for the module-refactor agent.

set -euo pipefail
source scripts/gemini-adapter.sh

REPORT_FILE=".gemini/state/code-quality.json"
mkdir -p .gemini/state

echo "🔍 Analyzing NixOS modules..."

# 1. Count files and lines
FILE_COUNT=$(find modules -name "*.nix" | wc -l)
TOTAL_LINES=$(find modules -name "*.nix" -exec cat {} + | wc -l)

# 2. Check for anti-patterns (using grep as a lightweight statix)
# "mkIf true"
MKIF_TRUE_COUNT=$(grep -r "mkIf.*true" modules | wc -l)

# "with pkgs;" usage (rough estimate)
WITH_USAGE_COUNT=$(grep -r "with.*;" modules | wc -l)

# "rec {" usage
REC_USAGE_COUNT=$(grep -r "rec {" modules | wc -l)

# 3. Identify large modules (>300 lines)
LARGE_MODULES=$(find modules -name "*.nix" -exec wc -l {} + | awk '$1 > 300 {print $2}' | jq -R . | jq -s .)

# 4. Check for documentation (modules without 'description')
# This is a heuristic check
UNDOCUMENTED_MODULES=$(find modules -name "*.nix" -print0 | xargs -0 grep -L "description =" | jq -R . | jq -s .)

# Generate JSON Report
cat <<EOF >"$REPORT_FILE"
{
  "timestamp": "$(date -Iseconds)",
  "metrics": {
    "total_modules": $FILE_COUNT,
    "total_lines": $TOTAL_LINES,
    "avg_lines_per_module": $((TOTAL_LINES / FILE_COUNT))
  },
  "anti_patterns": {
    "mkIf_true": $MKIF_TRUE_COUNT,
    "excessive_with": $WITH_USAGE_COUNT,
    "recursive_sets": $REC_USAGE_COUNT
  },
  "maintenance": {
    "large_modules": $LARGE_MODULES,
    "undocumented_modules": $UNDOCUMENTED_MODULES
  }
}
EOF

echo "✅ Code quality analysis complete. Report: $REPORT_FILE"
echo "    Modules: $FILE_COUNT | Lines: $TOTAL_LINES"
echo "    Issues: mkIf($MKIF_TRUE_COUNT) with($WITH_USAGE_COUNT) rec($REC_USAGE_COUNT)"
