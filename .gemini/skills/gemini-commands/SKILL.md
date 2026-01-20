---
name: gemini-commands
version: 1.0
description: Gemini Custom Slash Commands Skill
---

# Gemini Custom Slash Commands Skill

## Overview

**Gemini Custom Slash Commands** allow you to extend the Gemini CLI with your own reusable workflows. These commands are
defined in `.toml` files and can execute complex prompts, run shell commands, and read file contents.

### Key Features

- **Prompt Reuse**: Save frequently used prompts as commands.
- **Context Injection**: Use `{{args}}` to pass user input into specific parts of the prompt.
- **Shell Execution**: Run shell commands with `!{cmd}` and inject their output.
- **File Content**: Read and inject file contents with `@{path}`.
- **User or Project Scope**: Define commands globally or per-project.

## File Structure

Commands are defined in TOML files located in:

- **Project Scope**: `.gemini/commands/` (Takes precedence, version controlled).
- **User Scope**: `~/.gemini/commands/` (Global availability).

### Naming Convention

- The filename determines the command name: `status.toml` -> `/status`
- Subdirectories create namespaced commands: `git/commit.toml` -> `/git:commit`

## Command Format (TOML)

A command file consists of metadata and the prompt definition.

```toml
description = "Brief description of what the command does"

# The prompt sent to the model.
# Use triple quotes """ for multi-line strings.
prompt = """
Instructions for the agent.
...
"""
```

### Argument Handling (`{{args}}`)

- **Explicit Injection**: Use `{{args}}` to place the user's input exactly where needed.

  ```toml
  prompt = "Explain this concept: {{args}}"
  ```

- **Default Behavior**: If `{{args}}` is NOT present, the user's input is appended to the end of the prompt.

### Shell Command Injection (`!{cmd}`)

Execute shell commands and insert their output into the prompt.
**Security Note**: `{{args}}` inside `!{...}` is automatically shell-escaped.

```toml
prompt = """
Summarize the following git diff:
!{git diff {{args}}}
"""
```

### File Content Injection (`@{path}`)

Read file or directory contents and insert them into the prompt.

```toml
prompt = """
Review this code file:
@{src/main.rs}
"""
```

## Examples

### 1. Simple Explanation

```toml
# ~/.gemini/commands/explain.toml
description = "Explain a concept simply"
prompt = """
Explain the following concept to a 5-year old:
{{args}}
"""
```

Usage: `/explain quantum physics`

### 2. Code Review with Context

```toml
# .gemini/commands/review.toml
description = "Review staged changes"
prompt = """
Please review the staged changes in this git repository.
Focus on security and performance.

Changes:
!{git diff --staged}
"""
```

Usage: `/review`

### 3. Log Analysis

```toml
# .gemini/commands/analyze-logs.toml
description = "Analyze logs for errors"
prompt = """
Analyze these logs for critical errors:
!{tail -n 50 /var/log/syslog}
"""
```

Usage: `/analyze-logs`

## Best Practices

1. **Descriptive Names**: Choose clear filenames (e.g., `daily-brief.toml`).
2. **Clear Descriptions**: The `description` field helps you identify the command in `/help`.
3. **Use `{{args}}`**: For precise control over where user input goes.
4. **Leverage Shell Commands**: Use `!{...}` to fetch dynamic data (git status, logs, etc.).

This skill provides everything you need to create your own custom Gemini CLI slash commands!
