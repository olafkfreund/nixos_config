# Gemini CLI Feature Integration

The Gemini CLI is now available as a configurable feature across all hosts in this NixOS flake.

## Usage

### Enable for a specific host

In your host configuration (e.g., `hosts/p620/configuration.nix`):

```nix
features = {
  ai = {
    enable = true;
    ollama = true;
    gemini-cli = true;  # ← Add this line
  };
};
```

### Available Options

The `programs.gemini-cli` module provides these configuration options:

```nix
programs.gemini-cli = {
  enable = true;  # Enable/disable the service
  
  package = pkgs.gemini-cli;  # Override the package if needed
  
  environmentVariables = {
    GEMINI_API_KEY = "your-api-key";
    GEMINI_MODEL = "gemini-2.5-pro";
  };
  
  enableShellIntegration = true;  # Adds shell aliases and desktop entry
};
```

### Environment Variables

You can configure environment variables for authentication and default settings:

```nix
features = {
  ai = {
    enable = true;
    gemini-cli = true;
  };
};

# Additional configuration
programs.gemini-cli = {
  environmentVariables = {
    GEMINI_API_KEY = "your-api-key-here";
    GEMINI_MODEL = "gemini-2.5-pro";
  };
};
```

### Shell Aliases

When `enableShellIntegration = true` (default), these aliases are available:
- `gemini` - Run the Gemini CLI
- `ai` - Convenient shortcut for `gemini`

### Desktop Integration

A desktop entry is automatically created at `/etc/applications/gemini-cli.desktop` for GUI environments.

## Examples

### Enable on all development hosts

```nix
# In hosts/p620/configuration.nix
features.ai.gemini-cli = true;

# In hosts/razer/configuration.nix  
features.ai.gemini-cli = true;

# In hosts/p510/configuration.nix
features.ai.gemini-cli = true;
```

### Disable for server hosts

```nix
# In hosts/server/configuration.nix
features.ai.gemini-cli = false;  # or just omit the line
```

## Authentication

The Gemini CLI supports multiple authentication methods:

1. **API Key**: Set `GEMINI_API_KEY` environment variable
2. **OAuth**: Interactive Google account login
3. **Workspace**: Google Workspace account login

See the [official documentation](https://github.com/google-gemini/gemini-cli) for detailed authentication setup.

## Commands

Once installed, you can use:

```bash
# Check version
gemini --version

# Get help
gemini --help

# Start interactive session
gemini

# Use specific model
gemini -m gemini-2.5-pro

# Run in sandbox mode
gemini -s

# Debug mode
gemini -d
```

## Module Location

- **Feature definition**: `modules/common/features.nix`
- **Feature implementation**: `modules/common/features-impl.nix`
- **Module definition**: `modules/ai/gemini-cli.nix`
- **Package**: `pkgs/gemini-cli/default.nix`
