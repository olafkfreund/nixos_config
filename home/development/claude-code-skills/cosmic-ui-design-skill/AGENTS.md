# COSMIC Skill Agents Registry

## Registered Agents

All agents are now registered via `skill.json` and ready for use.

| Agent | Shortcut | Primary Focus |
|-------|----------|---------------|
| `cosmic-architect` | Architecture expert | App structure, state management, async patterns |
| `cosmic-theme-expert` | Theming specialist | Theme compliance, hard-coded values, accessibility |
| `cosmic-applet-specialist` | Applet expert | Panel applets, Wayland, popups |
| `cosmic-widget-builder` | Widget specialist | Widget composition, layouts, custom widgets |
| `cosmic-error-handler` | Error handling expert | Unwrap elimination, logging, safe patterns |
| `cosmic-performance-optimizer` | Performance expert | Bottlenecks, memory, async optimization |
| `cosmic-code-reviewer` | Comprehensive reviewer | Full COSMIC compliance review |

## Quick Command Reference

### Cosmic Architect

```text
@cosmic-architect /review-app-structure
@cosmic-architect /suggest-refactoring
```

### Cosmic Theme Expert

```text
@cosmic-theme-expert /audit-theming
@cosmic-theme-expert /convert-hardcoded
```

### Cosmic Applet Specialist

```text
@cosmic-applet-specialist /review-applet
@cosmic-applet-specialist /fix-popup
```

### Cosmic Widget Builder

```text
@cosmic-widget-builder /review-widgets
@cosmic-widget-builder /improve-layout
```

### Cosmic Error Handler

```text
@cosmic-error-handler /remove-unwraps
@cosmic-error-handler /audit-error-handling
```

### Cosmic Performance Optimizer

```text
@cosmic-performance-optimizer /find-bottlenecks
@cosmic-performance-optimizer /optimize-memory
```

### Cosmic Code Reviewer

```text
@cosmic-code-reviewer /full-review
@cosmic-code-reviewer /pre-commit-check
```

## Agent Invocation Methods

### Method 1: Direct Mention (Most Reliable)

```text
Please act as cosmic-theme-expert and review this code for theming issues.
```

### Method 2: With Context Loading

```text
Using the cosmic-theme-expert agent from cosmic-ui-design-skill,
audit this file for hard-coded values.
```

### Method 3: Shortcut Reference

```text
Execute cosmic-code-reviewer /full-review on cosmic-connect/src/main.rs
```

### Method 4: Try @ Syntax (If Supported)

```text
@cosmic-theme-expert /audit-theming
```

Note: @ syntax may not work with custom skills depending on Claude Code configuration.

## Verification

To verify agents are registered, check:

```bash
cat ~/.claude/skills/cosmic-ui-design-skill/skill.json
```

You should see all 7 agents listed with `"invocable": true`.

## Troubleshooting

If agents aren't being recognized:

1. **Restart Claude Code** - Skill changes may require restart
2. **Use conversational invocation** - Direct mentions always work
3. **Check skill.json** - Ensure it's valid JSON
4. **Verify file permissions** - Files should be readable

```bash
chmod 644 ~/.claude/skills/cosmic-ui-design-skill/*.json
chmod 644 ~/.claude/skills/cosmic-ui-design-skill/*.md
```

## Adding New Agents

To add new COSMIC agents:

1. Add entry to `agents.json`:

```json
{
  "name": "your-agent-name",
  "description": "What it does",
  "instructions": "Detailed instructions...",
  "shortcuts": [...]
}
```

1. Register in `skill.json`:

```json
"your-agent-name": {
  "name": "your-agent-name",
  "description": "What it does",
  "invocable": true,
  "context_files": ["SKILL.md"]
}
```

1. Document in USAGE.md

2. Update this registry

---

*Last Updated: January 16, 2026*
*COSMIC UI Design Skill v1.0.0*
