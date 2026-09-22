# COSMIC Skill Usage Guide

## Quick Start

The COSMIC UI Design skill provides 7 specialized agents for COSMIC Desktop development. Each agent
is an expert in a specific domain.

## Invoking Agents

### Method 1: Direct Agent Reference (Recommended)

In your conversation with Claude Code, reference the agent with context:

```text
I need help with COSMIC theming. Please act as the cosmic-theme-expert agent
from the cosmic-ui-design-skill and review my code for hard-coded values.

[paste your code]
```

### Method 2: Using Context from agents.json

Reference the specific agent's instructions:

```text
Review this COSMIC application following the cosmic-architect agent guidelines.
Check the architecture, state management, and async patterns.

[paste your code]
```

### Method 3: Using Shortcuts

Reference shortcuts defined in agents.json:

```text
Perform a /full-review of this COSMIC Connect application using the
cosmic-code-reviewer standards.
```

```text
Run /audit-theming on cosmic-connect/src/main.rs to find all hard-coded values.
```

```text
Execute /remove-unwraps on this code to eliminate all panic risks.
```

## Available Agents

### 1. **cosmic-architect**

**Specialty:** Application architecture, state management, async patterns

**Use when:**

- Reviewing Application trait implementation
- Checking state management patterns
- Validating message handling
- Reviewing async operations

**Example:**

```text
As cosmic-architect, review the architecture of cosmic-connect/src/main.rs.
Focus on state management and the Message enum organization.
```

**Shortcuts:**

- `/review-app-structure` - Comprehensive architecture review
- `/suggest-refactoring` - Architectural refactoring suggestions

---

### 2. **cosmic-theme-expert**

**Specialty:** Theming, styling, hard-coded values, accessibility

**Use when:**

- Finding hard-coded colors/dimensions
- Checking theme integration
- Verifying accessibility
- Ensuring light/dark mode compatibility

**Example:**

```text
Acting as cosmic-theme-expert, audit cosmic-connect/src/main.rs for:
1. Hard-coded colors
2. Hard-coded spacing
3. Theme variable usage
4. Text hierarchy issues
```

**Shortcuts:**

- `/audit-theming` - Complete theming audit
- `/convert-hardcoded` - Convert hard-coded values to theme variables

---

### 3. **cosmic-applet-specialist**

**Specialty:** Panel applets, Wayland Layer Shell, popup management

**Use when:**

- Building panel applets
- Working with popups
- Integrating with COSMIC panels
- Creating desktop entries for applets

**Example:**

```text
As cosmic-applet-specialist, review this panel applet code for:
- Proper applet structure
- Popup management
- Desktop entry configuration
```

**Shortcuts:**

- `/review-applet` - Complete applet review
- `/fix-popup` - Fix popup management issues

---

### 4. **cosmic-widget-builder**

**Specialty:** Widget usage, composition, layout patterns

**Use when:**

- Choosing appropriate widgets
- Optimizing widget composition
- Improving layouts
- Creating custom widgets

**Example:**

```text
As cosmic-widget-builder, review the widget usage in my device list view.
Suggest improvements for cleaner composition and better performance.
```

**Shortcuts:**

- `/review-widgets` - Review widget usage
- `/improve-layout` - Suggest layout improvements

---

### 5. **cosmic-error-handler**

**Specialty:** Error handling, logging, eliminating unwrap/expect

**Use when:**

- Removing unwrap/expect calls
- Implementing proper error handling
- Adding appropriate logging
- Ensuring graceful degradation

**Example:**

```text
As cosmic-error-handler, scan cosmic-connect/src/main.rs and:
1. Find all unwrap() and expect() calls
2. Provide safe replacements
3. Add appropriate tracing logs
```

**Shortcuts:**

- `/remove-unwraps` - Remove all unwrap/expect
- `/audit-error-handling` - Complete error handling audit

---

### 6. **cosmic-performance-optimizer**

**Specialty:** Performance, memory optimization, async patterns

**Use when:**

- Identifying bottlenecks
- Optimizing memory usage
- Improving async performance
- Reducing allocations

**Example:**

```text
As cosmic-performance-optimizer, analyze cosmic-connect/src/main.rs for:
- Blocking operations
- Unnecessary allocations
- Expensive computations
- Memory inefficiencies
```

**Shortcuts:**

- `/find-bottlenecks` - Identify performance issues
- `/optimize-memory` - Optimize memory usage

---

### 7. **cosmic-code-reviewer**

**Specialty:** Comprehensive review combining all experts

**Use when:**

- Performing pre-commit reviews
- Getting complete COSMIC compliance analysis
- Reviewing entire applications
- Preparing for production

**Example:**

```text
As cosmic-code-reviewer, perform a /full-review of cosmic-connect.
Provide a comprehensive COSMIC Desktop compliance report covering:
- Architecture
- Theming
- Widgets
- Error handling
- Performance
```

**Shortcuts:**

- `/full-review` - Complete COSMIC compliance review
- `/pre-commit-check` - Pre-commit validation

---

## Best Practices

### 1. **Be Specific**

```text
❌ "Review my code"
✅ "As cosmic-theme-expert, audit this file for hard-coded values and
    provide specific replacements using theme variables"
```

### 2. **Provide Context**

```text
✅ "This is a COSMIC Desktop application for device connectivity.
    As cosmic-architect, review the state management in main.rs,
    focusing on the device synchronization logic."
```

### 3. **Use Shortcuts**

```text
✅ "Run cosmic-code-reviewer /full-review on the changes I made to
    implement theming improvements"
```

### 4. **Combine Agents**

```text
✅ "First, have cosmic-theme-expert check for theming issues.
    Then have cosmic-performance-optimizer review any expensive
    theme lookups it finds."
```

## Example Workflows

### New Application Review

```text
1. cosmic-architect: Review overall architecture
2. cosmic-theme-expert: Audit theming implementation
3. cosmic-widget-builder: Review widget composition
4. cosmic-error-handler: Check error handling
5. cosmic-performance-optimizer: Find bottlenecks
6. cosmic-code-reviewer: Final comprehensive review
```

### Theming Overhaul

```text
1. cosmic-theme-expert /audit-theming
2. Apply suggested fixes
3. cosmic-theme-expert /convert-hardcoded (for any remaining issues)
4. cosmic-code-reviewer: Verify full compliance
```

### Performance Optimization

```text
1. cosmic-performance-optimizer /find-bottlenecks
2. Apply optimizations
3. cosmic-architect: Ensure architecture still sound
4. cosmic-code-reviewer: Final verification
```

---

## Tips

1. **Always provide file paths** when asking for reviews
2. **Paste relevant code** for targeted analysis
3. **Specify what you've already tried** to get better suggestions
4. **Ask for examples** when implementing fixes
5. **Request prioritization** for large lists of issues

---

## Notes

- These agents are **knowledge-based experts** with deep COSMIC expertise
- They have access to the full COSMIC documentation and best practices
- They can reference SKILL.md, QUICK_REFERENCE.md, and other resources
- Each agent provides **specific, actionable recommendations**
- All suggestions follow **official COSMIC Desktop guidelines**

---

*For detailed COSMIC development information, see SKILL.md*
*For quick reference, see QUICK_REFERENCE.md*
*For project structure guidelines, see PROJECT_STRUCTURE.md*
