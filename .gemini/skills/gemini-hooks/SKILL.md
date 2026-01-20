---
name: gemini-hooks
version: 1.0
description: Gemini CLI Hooks Skill
---

# Gemini CLI Hooks Skill

## Overview

**Gemini CLI Hooks** allow you to customize the behavior of the CLI at specific points in its lifecycle. Hooks can be used to set up environments, perform cleanup, log activity, or intercept tool calls.

### Key Features

- **Lifecycle Events**: Trigger scripts on session start, tool execution, model calls, etc.
- **Command Hooks**: Execute shell scripts or system commands.
- **Configurable Filters**: Use matchers to run hooks only for specific tools or prompts.
- **Layered Configuration**: Project-specific hooks can override global user hooks.

## Enablement

Hooks are an experimental feature and must be explicitly enabled in your `settings.json`:

```json
{
  "experimental": {
    "enableAgents": true
  },
  "hooks": {
    "enabled": true
  },
  "tools": {
    "enableHooks": true
  }
}
```

## Supported Events (Hook Names)

| Event Name     | Description                                                  |
| :------------- | :----------------------------------------------------------- |
| `SessionStart` | Triggered when the CLI session begins.                       |
| `SessionEnd`   | Triggered when the CLI session ends.                         |
| `BeforeAgent`  | After user prompt submission, before planning.               |
| `AfterAgent`   | After the agent loop completes.                              |
| `BeforeModel`  | Before sending a request to the LLM.                         |
| `AfterModel`   | After receiving a response from the LLM.                     |
| `BeforeTool`   | Before a tool (e.g., `run_shell_command`) executes.          |
| `AfterTool`    | After a tool has executed.                                   |
| `Notification` | Triggered for system notifications (e.g., tool permissions). |

## Configuration

Hooks are defined in the `hooks` array within your `settings.json` (User or Project scope).

### Basic Configuration Example

```json
{
  "hooks": {
    "enabled": true,
    "hooks": [
      {
        "name": "startup-script",
        "type": "command",
        "command": "~/.gemini/hooks/session-start.sh",
        "description": "Run custom logic on session start"
      }
    ]
  }
}
```

### Advanced Hook with Matcher

Use a `matcher` to target specific tools or events:

```json
{
  "name": "log-shell-commands",
  "type": "command",
  "command": "./scripts/log-tool.sh",
  "matcher": "run_shell_command"
}
```

## Hook Interaction

Hooks communicate using standard input/output:

- **Input**: The CLI sends JSON to the hook's `stdin` containing event details.
- **Output**: The hook can write to `stdout`/`stderr` for logging.
- **Control**: Exit codes determine if the lifecycle continues (0) or fails.

## CLI Commands for Hooks

You can manage hooks directly from the Gemini prompt:

- `/hooks list`: Show all configured hooks and their status.
- `/hooks enable-all`: Enable all hooks.
- `/hooks disable-all`: Disable all hooks.
- `/hooks enable <name>`: Enable a specific hook.
- `/hooks disable <name>`: Disable a specific hook.

## Best Practices

1. **Keep Scripts Fast**: Hooks run blocking; slow scripts will lag the CLI.
2. **Use Project Scope**: Define project-specific setup (like `SessionStart` for repo-specific envs) in `.gemini/settings.json`.
3. **Handle Errors**: Ensure your scripts have proper error handling and return `0` unless you intend to stop the session/tool.
4. **Security**: Only use trusted scripts, especially in project-scoped settings.

This skill provides the foundation for automating your Gemini CLI environment using lifecycle hooks.
