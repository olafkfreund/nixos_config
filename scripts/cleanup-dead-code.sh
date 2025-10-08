#!/usr/bin/env bash
# Dead Code Cleanup Script
# Generated: 2025-10-08
# See docs/DEAD_CODE_ANALYSIS.md for full report

set -euo pipefail

echo "================================================================"
echo "NixOS Configuration Dead Code Cleanup Script"
echo "================================================================"
echo ""
echo "This script identifies dead code for removal."
echo "Review docs/DEAD_CODE_ANALYSIS.md before running."
echo ""
echo "UNCOMMENT sections below to activate cleanup."
echo ""

# Section 1: Remove inactive users
echo "1. Inactive user configurations (SAFE TO DELETE):"
echo "   - Users/htpcuser/dex5550_home.nix"
echo "   - Users/serveruser/p510_home.nix"
echo "   - Users/workuser/p620_home.nix"
# rm -v Users/htpcuser/dex5550_home.nix
# rm -v Users/serveruser/p510_home.nix
# rm -v Users/workuser/p620_home.nix

echo ""
echo "2. Dead feature files (VERIFIED UNREFERENCED):"
echo "   - home/browsers/floorp.nix"
echo "   - home/desktop/git-sync/"
echo "   - home/media/rnoise.nix"
echo "   - home/profiles-compat.nix"
echo "   - home/shell/ai-task-integration.nix"
echo "   - home/development/ai-productivity.nix"
echo "   - home/desktop/file-associations.nix"
# rm -v home/browsers/floorp.nix
# rm -rfv home/desktop/git-sync/
# rm -v home/media/rnoise.nix
# rm -v home/profiles-compat.nix
# rm -v home/shell/ai-task-integration.nix
# rm -v home/development/ai-productivity.nix
# rm -v home/desktop/file-associations.nix

echo ""
echo "3. Obsolete MicroVM configs (SUPERSEDED):"
echo "   - hosts/p510/nixos/microvm/*.nix"
# rm -v hosts/p510/nixos/microvm/k3s-agent-1.nix
# rm -v hosts/p510/nixos/microvm/k3s-agent-2.nix
# rm -v hosts/p510/nixos/microvm/nixvm.nix

echo ""
echo "Cleanup script complete (no files removed - all commands commented)."
echo "Uncomment sections to activate cleanup."
echo "Run 'just test-all' after each section."
