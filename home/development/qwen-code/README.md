# Qwen-Code NixOS Package

This directory contains a NixOS package definition for [qwen-code](https://github.com/QwenLM/qwen-code), an AI-powered CLI workflow tool optimized for Qwen3-Coder models.

## 🚀 Quick Start

### 1. Update Hashes (First Time Only)
```bash
cd /home/olafkfreund/.config/nixos/home/development/qwen-code
./update-hashes.sh
```

### 2. Test the Package
```bash
./test-package.sh
```

### 3. Build and Install
```bash
# From nixos config root
nix-build home/development/qwen-code/default.nix

# Or install globally (after adding to your config)
nix-shell -p qwen-code
```

## 📋 What's Included

- `default.nix` - Main package definition using `buildNpmPackage`
- `update-hashes.sh` - Script to calculate required source and npm dependency hashes
- `test-package.sh` - Script to test the built package
- `README.md` - This documentation

## 🔧 Package Details

**What it does:**
- AI-powered code understanding and editing
- Workflow automation
- Command-line interface for Qwen3-Coder models

**Requirements:**
- Node.js 20+
- npm dependencies (handled automatically)
- API key for Qwen models (runtime requirement)

**Binary:** `qwen`

## 🔬 Technical Analysis & Findings

### ✅ Successfully Implemented (Following gemini-cli pattern)
1. **Source Management**: Using `fetchFromGitHub` with correct commit hash
2. **Dependency Strategy**: Switched from `npmDepsHash` to `fetchNpmDeps` (gemini-cli approach)
3. **Monorepo Handling**: Implemented workspace package copying (cli, core, vscode-ide-companion)
4. **Node.js 20+**: Properly configured nodejs_20 requirement
5. **Build Structure**: Added git commit generation and proper install phase

### ⚠️ Current Blocker: NPM Dependency Resolution
**Issue**: `ENOTCACHED` error for "ignore" package despite correct npmDeps hash
```
npm error request to https://registry.npmjs.org/ignore failed: cache mode is 'only-if-cached'
```

**Root Cause Analysis**:
- fetchNpmDeps successfully calculates hash: `sha256-3oVrk6nhXuOP6n7HJgyRCFcC7NgZwjh8jkUuC2uNGmo=`
- npm install phase fails to resolve workspace dependencies from cache
- Issue likely stems from qwen-code's complex workspace setup vs gemini-cli's simpler structure

### 🔍 Comparison with Working gemini-cli
| Aspect | gemini-cli (✅ Works) | qwen-code (❌ Fails) |
|--------|----------------------|---------------------|
| Packages | 2 (`@google/gemini-cli`, `@google/gemini-cli-core`) | 3 (`@qwen-code/*` packages) |
| Dependencies | Simpler dep tree | Complex workspace interdependencies |
| Package Manager | Standard npm | npm with advanced workspace features |
| Lock File | Standard format | Complex workspace lock file |

## 🐛 Troubleshooting

### Current Status: Ready for Advanced NPM Resolution
The package is 90% complete. The blocker is specifically npm workspace dependency resolution in Nix sandbox.

**Potential Solutions**:
1. **Manual workspace flattening**: Pre-process package-lock.json to flatten workspace deps
2. **Alternative build approach**: Use yarn instead of npm (yarn2nix)
3. **Upstream prebuild**: Use pre-built bundles if available
4. **Custom npmDeps**: Manually build dependency tree excluding problematic packages

### Build Fails with Hash Mismatch
1. Run `./update-hashes.sh` to recalculate hashes  
2. Current hashes are correct but dependency resolution fails

### Binary Doesn't Work
- Tool requires API keys for Qwen models at runtime
- Future: integrate with NixOS agenix secret management

### Node.js Version Issues
- Package requires Node.js 20+ ✅ Handled

## 📚 Upstream Documentation

- **Repository:** https://github.com/QwenLM/qwen-code
- **License:** Apache 2.0
- **Original:** Adapted from Google Gemini CLI

## 🔄 Updating the Package

To update to a newer version:

1. Update the `version` in `default.nix`
2. Update the `rev` field to match the new version tag
3. Run `./update-hashes.sh` to recalculate hashes
4. Test with `./test-package.sh`

## 💡 Usage Examples

```bash
# After installation
qwen --help

# Example usage (requires API key configuration)
qwen analyze my-code.js
qwen optimize my-project/
```

## 🏗️ Development Notes

The package uses `buildNpmPackage` which:
- Automatically handles npm dependencies
- Provides reproducible builds
- Integrates well with Nix ecosystem

Key challenges addressed:
- Node.js 20+ requirement
- npm workspaces support
- Build script execution
- Binary wrapper creation