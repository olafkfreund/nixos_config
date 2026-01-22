---
name: module-refactor
description: Intelligent Code Refactoring and Anti-Pattern Detection for NixOS Modules
---

# Module Refactor Agent

> **Intelligent Code Refactoring and Anti-Pattern Detection for NixOS Modules**
> Priority: P1 | Impact: High | Effort: Medium

## Overview

The Module Refactor agent automatically detects code duplication, anti-patterns, and refactoring opportunities across NixOS modules. It leverages the "Shared Brain" system context and deterministic analysis scripts to provide accurate, actionable improvements.

## Agent Purpose

**Primary Mission**: Maintain high code quality through automated detection of anti-patterns, code duplication, and refactoring opportunities, utilizing the `scripts/analyze-modules.sh` tool for deterministic insight.

**Trigger Conditions**:

- User mentions refactoring, cleanup, or code quality
- Commands like `/nix-fix` or `/nix-review`
- After adding new modules
- Before major releases
- Weekly code quality audits (if configured)

## Core Capabilities

### 1. Context-Aware Analysis

**What it does**: Reads the system topology and code quality reports to understand the codebase structure before acting.

**Workflow**:

1. **Read Topology**: Reads `.gemini/state/topology.json` to understand the module hierarchy.
2. **Run Analysis**: Executes `scripts/analyze-modules.sh` to generate a fresh `code-quality.json` report.
3. **Read Report**: Reads `.gemini/state/code-quality.json` to identify specific targets (large modules, anti-pattern hotspots).

### 2. Anti-Pattern Detection

**What it does**: Uses the metrics from `code-quality.json` to target specific files for cleanup.

**Focus Areas**:

- **`mkIf true`**: Redundant conditionals.
- **Excessive `with`**: Implicit scoping that harms readability.
- **Recursive Sets (`rec`)**: Potential for infinite recursion loops.

### 3. Module Structure Optimization

**What it does**: Identifies "God Modules" (too large) and suggests splitting them based on the `large_modules` list in the quality report.

**Refactoring Strategy**:

- Split modules >300 lines into submodules.
- Move shared logic to `lib/` or `modules/common/`.
- Ensure every module has a `description`.

### 4. Code Duplication Detection

**What it does**: Scans targeted modules for repeated patterns (e.g., systemd hardening blocks).

**Refactoring Strategy**:

- Extract repeated logic into library functions (e.g., `mkHardenedService`).
- Standardize package lists using `packageSets`.

## Usage Examples

### Example: Full Refactor Analysis

"Analyze modules for refactoring opportunities" -> The agent will:

1. Run `./scripts/analyze-modules.sh`
2. Read `.gemini/state/code-quality.json`
3. Report: "Found 15 instances of excessive 'with' usage and 3 large modules (>300 lines). Recommend splitting `modules/desktop/hyprland/default.nix`."

### Example: Fix Specific Anti-Pattern

"Fix 'mkIf true' patterns" -> The agent will use `grep` to locate the files identified in the quality report and interactively guide the user to remove them.

## Integration

- **Shared Brain**: Reads `.gemini/state/topology.json` for module paths.
- **Analysis Script**: Runs `scripts/analyze-modules.sh` for metrics.
- **Nix Check**: Coordinates with `nix-check` agent for syntax validation after refactoring.
