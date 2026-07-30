#!/usr/bin/env bash
set -euo pipefail

# SessionStart Hook for Claude Code 2.1.2+
# Displays infrastructure context and quick reference on session start

echo "🚀 NixOS Infrastructure Hub - Session Started"
echo ""

# Show agent type if specified (new in Claude Code 2.1.2)
if [ -n "${AGENT_TYPE:-}" ]; then
  echo "   🤖 Agent: $AGENT_TYPE"
fi

# Infrastructure context
echo "   📦 Project: NixOS Infrastructure Hub"
echo "   🖥️  Active Hosts: P620, P510, Razer"
echo "   🧩 Modules: 141+"
echo "   📐 Architecture: Template-based (95% code deduplication)"
echo ""

# Quick command reference
echo "💡 Quick Commands:"
echo "   /nix-help              - Complete command reference"
echo "   /nix-check-tasks       - Review open GitHub issues"
echo "   /nix-deploy            - Smart deployment"
echo "   /nix-fix               - Auto-fix anti-patterns"
echo "   /nix-review            - Code review"
echo ""

# Best practices reminder
echo "📚 Before Coding:"
echo "   • Read docs/PATTERNS.md (NixOS best practices)"
echo "   • Check docs/NIXOS-ANTI-PATTERNS.md (avoid mistakes)"
echo "   • Use /nix-module for new modules"
echo "   • Run /nix-fix before commits"
echo ""

# Configuration status
echo "✅ Configuration Status:"
if command -v just >/dev/null 2>&1; then
  echo "   • Justfile commands: Available"
else
  echo "   • Justfile commands: Not found"
fi

if [ -d ".git" ]; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
  echo "   • Git branch: $BRANCH"
fi

echo "   • Claude Code: v2.1.2+"
echo "   • Skills hot-reload: Enabled"
echo "   • Agent isolation: context:fork enabled"
echo ""

echo "Happy coding! 🎯"
