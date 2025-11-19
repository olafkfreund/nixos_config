# Google Antigravity IDE for NixOS

A NixOS package for **Google Antigravity** - an agentic development platform launched on November 18, 2025.

## What is Google Antigravity?

Google Antigravity is an AI-powered agentic development environment that enables
developers to work at a higher, task-oriented level by managing autonomous agents
across workspaces.

### Key Features

- **Multi-Model AI Support**: Integrates Gemini 3, Claude Sonnet 4.5, and GPT-OSS
- **Agentic Architecture**: Autonomous agents operate across editor, terminal, and browser
- **Dual Interface**:
  - **Editor View**: Traditional IDE experience with AI-enhanced code editing
  - **Manager View**: Orchestrate and monitor agent tasks across projects
- **Task-Oriented Workflow**: Describe high-level goals, let agents handle implementation
- **Free Access**: Generous Gemini 3 Pro rate limits that refresh every 5 hours

## Installation

### Method 1: Enable in Home Manager Configuration

Add to your user configuration (e.g., `Users/olafkfreund/p620_home.nix`):

```nix
programs.antigravity = {
  enable = true;

  # Optional: Configure AI provider API keys
  apiKeys = {
    gemini = "your-google-api-key-here";

    # Or use existing agenix secrets
    anthropic = config.age.secrets."api-anthropic".path;
    openai = config.age.secrets."api-openai".path;
  };
};
```

### Method 2: Add to Development Feature Flags

Alternatively, integrate with the existing features system:

```nix
features = {
  development = {
    enable = true;
    # Add antigravity to development tools
  };
};
```

Then import the module in `home/development/default.nix`:

```nix
imports = [
  ./antigravity
  # ... other development modules
];
```

## API Key Setup

### Option 1: Direct Configuration (Development/Testing)

```nix
programs.antigravity.apiKeys = {
  gemini = "your-google-api-key";
  anthropic = "your-anthropic-api-key";
  openai = "your-openai-api-key";
};
```

### Option 2: Using Agenix Secrets (Recommended for Production)

1. Create encrypted API key secrets:

```bash
# Using the existing secrets management script
./scripts/manage-secrets.sh create api-gemini
./scripts/manage-secrets.sh create api-antigravity-anthropic
./scripts/manage-secrets.sh create api-antigravity-openai
```

2. Reference in configuration:

```nix
programs.antigravity.apiKeys = {
  gemini = config.age.secrets."api-gemini".path;
  anthropic = config.age.secrets."api-anthropic".path;  # Reuse existing
  openai = config.age.secrets."api-openai".path;        # Reuse existing
};
```

### Option 3: Environment Variables (Manual)

Set environment variables in your shell:

```bash
export GOOGLE_API_KEY="your-google-api-key"
export ANTHROPIC_API_KEY="your-anthropic-api-key"
export OPENAI_API_KEY="your-openai-api-key"
```

## Obtaining API Keys

### Google Gemini API Key

1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click "Create API Key"
4. Copy the generated key

### Anthropic Claude API Key

1. Visit [Anthropic Console](https://console.anthropic.com/)
1. Sign up or log in
1. Navigate to API Keys section
1. Generate a new API key

### OpenAI GPT API Key

1. Visit [OpenAI Platform](https://platform.openai.com/api-keys)
2. Sign in to your account
3. Create a new API key
4. Copy the secret key (shown only once)

## Usage

### Launching Antigravity

After installation, launch from:

- **Application Menu**: Search for "Google Antigravity" or "Antigravity"
- **Command Line**: Run `antigravity`
- **Desktop Entry**: Click the Antigravity icon in your application launcher

### First-Time Setup

1. **Launch Antigravity**
2. **Select AI Model**: Choose your preferred model (Gemini 3, Claude, or GPT)
3. **Configure Workspace**: Set up your project directory
4. **Start Coding**: Describe tasks in natural language and let agents work

### Workflow Examples

#### Example 1: Create a Web Application

```text
Prompt: "Create a React web application with user authentication,
         dark mode toggle, and responsive design"

Antigravity will:
1. Generate project structure
1. Implement authentication system
1. Create UI components with dark mode
1. Add responsive CSS
1. Write tests
1. Provide deployment instructions
```

#### Example 2: Refactor Legacy Code

```text
Prompt: "Refactor this Python codebase to use async/await patterns
         and add comprehensive type hints"

Antigravity will:
1. Analyze existing code
1. Identify synchronous operations
1. Convert to async/await
1. Add type annotations
1. Update tests
1. Validate type checking
```

## Configuration Options

### Full Configuration Example

```nix
programs.antigravity = {
  enable = true;

  # Use custom package version (optional)
  package = pkgs.callPackage ./custom-antigravity.nix { };

  # Configure API keys
  apiKeys = {
    gemini = config.age.secrets."api-gemini".path;
    anthropic = config.age.secrets."api-anthropic".path;
    openai = config.age.secrets."api-openai".path;
  };

  # Desktop entry configuration
  desktopEntry.enable = true;
};
```

## Troubleshooting

### Issue: Application won't start

**Check library dependencies:**

```bash
ldd $(which antigravity)
```

**Verify API keys are set:**

```bash
echo $GOOGLE_API_KEY
echo $ANTHROPIC_API_KEY
echo $OPENAI_API_KEY
```

### Issue: API rate limits

- Gemini 3 Pro has generous free limits that refresh every 5 hours
- Monitor usage in the Antigravity Manager view
- Consider rotating between different AI models

### Issue: Wayland compatibility

The package automatically enables Wayland support via `NIXOS_OZONE_WL=1`. If you experience issues:

```bash
# Force X11 mode
unset NIXOS_OZONE_WL
antigravity
```

### Issue: GPU acceleration not working

**Check Vulkan support:**

```bash
vulkaninfo | grep deviceName
```

**Verify OpenGL:**

```bash
glxinfo | grep "OpenGL version"
```

## Building from Source

If you need to build the package manually:

```bash
# Navigate to package directory
cd /home/olafkfreund/.config/nixos/home/development/antigravity

# Build package
nix-build -E '(import <nixpkgs> {}).callPackage ./package.nix {}'

# Test run
./result/bin/antigravity
```

## Integration with Existing Infrastructure

### With AI Provider System

Antigravity complements the existing AI provider infrastructure:

```nix
# Existing AI providers (ai.providers)
ai.providers = {
  enable = true;
  openai.enable = true;
  anthropic.enable = true;
  gemini.enable = true;
};

# Antigravity IDE
programs.antigravity = {
  enable = true;
  # Reuse same API keys
  apiKeys = {
    gemini = config.age.secrets."api-gemini".path;
    anthropic = config.age.secrets."api-anthropic".path;
    openai = config.age.secrets."api-openai".path;
  };
};
```

### Host-Specific Deployment

Enable on specific hosts:

```nix
# P620 (AMD workstation) - Full development environment
programs.antigravity.enable = true;

# Razer (Laptop) - Mobile development
programs.antigravity.enable = true;

# P510 (Server) - Disable
programs.antigravity.enable = false;
```

## Version Information

- **Package Version**: 1.11.2
- **Build ID**: 6251250307170304
- **Platform**: Linux x64
- **License**: Unfree (Google proprietary)
- **Launch Date**: November 18, 2025

## References

- **Official Site**: [antigravity.google](https://antigravity.google)
- **Gemini 3 Blog**: [Google Developers Blog](https://blog.google/technology/developers/gemini-3-developers/)
- **Reference Implementation**: [google-antigravity-nix](https://github.com/ARelaxedScholar/google-antigravity-nix)

## Contributing

Improvements and bug fixes are welcome! Please submit issues or pull requests to
the main repository.

## License

This package configuration is part of the NixOS Infrastructure Hub.
Google Antigravity itself is proprietary software from Google.
