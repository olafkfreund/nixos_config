# AI and ChatGPT Tools Module

Provides a comprehensive collection of AI-powered command line tools and interfaces for enhanced productivity and development workflows.

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | boolean | `false` | Enable AI and ChatGPT tools module |
| `packages.chatInterfaces` | boolean | `true` | Enable chat interfaces (ChatGPT CLI, TGPT, Shell-GPT) |
| `packages.codeAssistants` | boolean | `true` | Enable code assistance tools (GitHub Copilot CLI, Aichat) |
| `packages.terminalTools` | boolean | `true` | Enable terminal-based AI tools (OTerm, Gorilla CLI) |
| `packages.mcpTools` | boolean | `false` | Enable Model Context Protocol tools |

## Usage Examples

### Basic Usage
```nix
modules.ai.chatgpt.enable = true;
```

### Selective Categories
```nix
modules.ai.chatgpt = {
  enable = true;
  packages = {
    chatInterfaces = true;
    codeAssistants = true;
    terminalTools = false;
    mcpTools = false;
  };
};
```

## Features

### Shell Aliases
- `ai` → `shell-gpt` - Quick AI assistance
- `chat` → `chatgpt-cli` - Direct ChatGPT access
- `aicode` → `gh copilot suggest` - Code suggestions
- `aiexplain` → `gh copilot explain` - Code explanations

## Setup

Set API keys in your environment:
```bash
export OPENAI_API_KEY="your-key"
export ANTHROPIC_API_KEY="your-key"
```

For GitHub Copilot:
```bash
gh auth login
gh extension install github/gh-copilot
```