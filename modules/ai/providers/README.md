# 🤖 Unified AI Provider System

The unified AI provider system provides a seamless interface for working with multiple LLM providers with automatic fallback, cost optimization, and provider switching capabilities.

## 🌟 Features

- **Multiple Provider Support**: OpenAI, Anthropic/Claude, Google Gemini, and Ollama
- **Automatic Fallback**: If one provider fails, automatically try the next
- **Cost Optimization**: Choose providers based on cost efficiency
- **Priority-based Selection**: Configure provider priorities
- **Unified CLI**: Single command interface for all providers
- **Shell Integration**: Enhanced shell functions and aliases
- **Provider Switching**: Runtime switching between providers

## 🚀 Quick Start

### Enable the System

```nix
features.ai.providers = {
  enable = true;
  defaultProvider = "openai";
  enableFallback = true;
  costOptimization = false;
  
  openai.enable = true;
  anthropic.enable = true;
  gemini.enable = true;
  ollama.enable = true;
};
```

### Basic Usage

```bash
# Use default provider
ai-cli "Explain quantum computing"

# Use specific provider
ai-cli -p anthropic "Write a Python function"

# Enable fallback
ai-cli -f "Complex analysis task"

# Cost optimization + fallback
ai-cli -c -f "Generate documentation"
```

## 📋 CLI Commands

### Main Interface

```bash
ai-cli [OPTIONS] "prompt"
```

**Options:**
- `-p, --provider PROVIDER` - Use specific provider (openai|anthropic|gemini|ollama)
- `-m, --model MODEL` - Use specific model
- `-f, --fallback` - Enable fallback to other providers on failure
- `-c, --cost-optimize` - Use cost optimization for provider selection
- `-t, --timeout SECONDS` - Request timeout (default: 30)
- `-v, --verbose` - Verbose output
- `-l, --list-providers` - List available providers
- `-M, --list-models` - List available models for provider
- `-s, --status` - Show provider status
- `-h, --help` - Show help

### Management Commands

```bash
# List all providers
ai-cli -l

# Show provider status
ai-cli -s

# List models for specific provider
ai-cli -p openai -M

# Switch default provider for session
ai-switch anthropic
```

## 🔧 Shell Integration

### Quick Functions

```bash
# Quick access with default provider
ai "Hello, world!"

# Fallback-enabled query
ai-fallback "Complex task"

# Cost-optimized query
ai-cost "Generate content"

# Provider-specific shortcuts
ai-openai "OpenAI specific task"
ai-claude "Claude specific task"
ai-gemini "Gemini specific task"
ai-ollama "Local model task"
```

### Provider Management

```bash
# List providers
ai-providers

# List models for current default provider
ai-models

# List models for specific provider
ai-models anthropic

# Show status
ai-status
```

### Specialized Functions

#### Claude/Anthropic
```bash
claude-chat "model" "prompt"
claude-code "model" "code prompt"
claude-analyze "/path/to/file"
```

#### OpenAI
```bash
openai-chat "model" "prompt"
openai-code "model" "code prompt"
```

#### Gemini
```bash
gemini-chat "model" "prompt"
gemini-vision "/path/to/image.jpg" "describe"
gemini-translate "text" "target_language"
```

#### Ollama
```bash
ollama-chat "model" "prompt"
ollama-models
ollama-pull "model_name"
ollama-status
```

## ⚙️ Configuration

### Provider Priorities

Lower numbers = higher priority (1 = highest):

```nix
features.ai.providers = {
  openai.priority = 1;     # Highest priority
  anthropic.priority = 2;  # Second choice
  gemini.priority = 3;     # Third choice
  ollama.priority = 4;     # Fallback/local
};
```

### Model Configuration

Each provider has configurable models:

```nix
ai.providers = {
  openai = {
    models = ["gpt-4o" "gpt-4o-mini" "gpt-3.5-turbo"];
    defaultModel = "gpt-4o-mini";
  };
  
  anthropic = {
    models = ["claude-3-5-sonnet-20241022" "claude-3-5-haiku-20241022"];
    defaultModel = "claude-3-5-sonnet-20241022";
  };
};
```

### API Key Management

API keys are managed through Agenix secrets:

- `/run/secrets/api-openai` - OpenAI API key
- `/run/secrets/api-anthropic` - Anthropic API key
- `/run/secrets/api-gemini` - Google Gemini API key

Ollama doesn't require API keys (local models).

## 🔍 Provider Status

Check provider availability:

```bash
ai-cli --status
```

Example output:
```
AI Provider Status
==================
Default provider: openai
Config file: /etc/ai-providers.json

Available providers:
===================
openai       Priority: 1, Model: gpt-4o-mini             ✓
anthropic    Priority: 2, Model: claude-3-5-sonnet-20241022 ✓
gemini       Priority: 3, Model: gemini-1.5-flash        ✓
ollama       Priority: 4, Model: mistral-small3.1        ✓

System Status:
==============
Ollama service: Running

API Keys:
  openai: ✓
  anthropic: ✓
  gemini: ✓
```

## 🏗️ Architecture

### Configuration Flow

```
Host Configuration
    ↓
Feature Flags (features.ai.providers)
    ↓
Provider Modules (modules/ai/providers/)
    ↓
JSON Config (/etc/ai-providers.json)
    ↓
CLI Tools (ai-cli, ai-switch)
```

### Module Structure

```
modules/ai/providers/
├── default.nix          # Main provider configuration
├── openai.nix          # OpenAI-specific setup
├── anthropic.nix       # Claude-specific setup
├── gemini.nix          # Gemini-specific setup
├── ollama.nix          # Ollama-specific setup
└── unified-client.nix  # CLI tools and shell integration
```

## 🎯 Cost Optimization

When enabled, cost optimization considers:

1. **Model costs** per token
2. **Provider reliability** 
3. **Response speed**
4. **Current API limits**

Priority order for cost optimization:
1. Ollama (free, local)
2. Gemini (cost-effective)
3. OpenAI (balanced)
4. Anthropic (premium)

## 🔄 Fallback Behavior

When fallback is enabled:

1. Try primary provider (based on priority or specified)
2. On failure, try next available provider by priority
3. Retry each provider up to `maxRetries` times
4. If all providers fail, exit with error

## 📝 Examples

### Development Workflow

```bash
# Code review with fallback
ai-cli -f "Review this code for security issues: $(cat script.py)"

# Generate documentation with cost optimization
ai-cli -c "Generate API documentation for this function"

# Interactive coding session
ai-switch ollama  # Use local model for privacy
ai "Help me debug this function"
```

### Multi-Provider Analysis

```bash
# Compare responses from different providers
echo "Explain quantum computing" | ai-cli -p openai
echo "Explain quantum computing" | ai-cli -p anthropic  
echo "Explain quantum computing" | ai-cli -p gemini
```

## 🚨 Troubleshooting

### Common Issues

1. **API Key Not Found**
   ```bash
   ai-cli --status  # Check API key status
   # Ensure secrets are properly deployed
   ```

2. **Ollama Service Not Running**
   ```bash
   systemctl start ollama
   ollama-status
   ```

3. **Provider Timeout**
   ```bash
   ai-cli -t 60 "prompt"  # Increase timeout
   ```

4. **Model Not Available**
   ```bash
   ai-cli -p provider -M  # List available models
   ```

### Debug Mode

```bash
ai-cli -v "prompt"  # Verbose output for debugging
```

## 🔄 Migration from Legacy Setup

The new system maintains backward compatibility:

- Existing `chatgpt-cli`, `gemini-cli` commands still work
- Old environment variables are preserved
- Gradual migration is supported

To migrate:

1. Enable unified providers: `features.ai.providers.enable = true`
2. Configure provider priorities
3. Test with `ai-cli`
4. Gradually replace direct tool usage with unified interface

## 📚 Related Documentation

- [API Keys Management](../../secrets/api-keys.nix)
- [Ollama Configuration](../../services/ollama/)
- [Shell Integration](../../../home/shell/)
- [Feature Flags](../../common/features.nix)