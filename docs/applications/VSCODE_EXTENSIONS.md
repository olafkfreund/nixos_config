# VS Code Extensions Guide for NixOS

This guide shows you how to add VS Code extensions to your NixOS configuration.

## Method 1: Extensions Available in nixpkgs (Recommended)

### Step 1: Search for available extensions

```bash
# Search for specific extensions
nix search nixpkgs vscode-extensions.ms-python
nix search nixpkgs vscode-extensions | grep -i "extension-name"

# List all available VS Code extensions
nix search nixpkgs vscode-extensions
```

### Step 2: Add to your vscode.nix

```nix
# In home/development/vscode.nix, add to the extensions list:
extensions = with pkgs; [
  # Existing extensions...
  vscode-extensions.ms-python.python           # Python support
  vscode-extensions.ms-python.pylance          # Python language server
  vscode-extensions.rust-lang.rust-analyzer    # Rust support
  vscode-extensions.ms-vscode.cpptools         # C++ support
  vscode-extensions.bradlc.vscode-tailwindcss  # Tailwind CSS
  vscode-extensions.esbenp.prettier-vscode     # Prettier formatter
];
```

### Step 3: Rebuild your system

```bash
cd /home/olafkfreund/.config/nixos
sudo nixos-rebuild switch --flake .
```

## Method 2: Extensions NOT in nixpkgs (Advanced)

For extensions not available in nixpkgs, use `buildVscodeMarketplaceExtension`.

### Step 1: Get extension information

Visit the [VS Code Marketplace](https://marketplace.visualstudio.com/vscode) and find:

- Publisher name
- Extension name
- Version number

### Step 2: Get the SHA256 hash

```bash
# Use the provided script
/home/olafkfreund/.config/nixos/scripts/get-extension-hashes.sh

# Or manually:
nix-prefetch-url "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/PUBLISHER/vsextensions/NAME/VERSION/vspackage"
```

### Step 3: Add to customExtensions

```nix
# In home/development/vscode.nix, add to customExtensions:
customExtensions = [
  (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      name = "extension-name";
      publisher = "publisher-name";
      version = "1.0.0";
      sha256 = "sha256-ACTUAL_HASH_HERE";
    };
    meta = {
      description = "Extension description";
      license = lib.licenses.unfree; # or appropriate license
    };
  })
];
```

### Step 4: Add customExtensions to extensions list

```nix
extensions = with pkgs; [
  # Regular nixpkgs extensions...
  vscode-extensions.ms-python.python
] ++ customExtensions; # Add this line
```

## Real-World Examples

### Example 1: Adding Rust support

```nix
# These are available in nixpkgs:
vscode-extensions.rust-lang.rust-analyzer
vscode-extensions.vadimcn.vscode-lldb
vscode-extensions.serayuzgur.crates
```

### Example 2: Adding a marketplace extension (GitHub Copilot Chat)

```nix
# Already available in nixpkgs:
vscode-extensions.github.copilot
vscode-extensions.github.copilot-chat
```

### Example 3: Adding a custom marketplace extension

```nix
customExtensions = [
  (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      name = "vscode-pets";
      publisher = "tonybaloney";
      version = "1.25.0";
      sha256 = "sha256-REPLACE_WITH_ACTUAL_HASH";
    };
    meta = {
      description = "Pets for your VS Code";
      license = lib.licenses.mit;
    };
  })
];
```

## Troubleshooting

### Extension conflicts

If you have manually installed extensions causing conflicts:

```bash
# Clean VS Code extensions
/home/olafkfreund/.config/nixos/scripts/clean-vscode.sh

# Or manually:
rm -rf ~/.vscode/extensions/*
rm ~/.config/Code/User/settings.json
cd /home/olafkfreund/.config/nixos
sudo nixos-rebuild switch --flake .
```

### Finding extension names

1. Go to VS Code Marketplace
2. Look at the URL: `https://marketplace.visualstudio.com/items?itemName=PUBLISHER.NAME`
3. Use PUBLISHER as `publisher` and NAME as `name`

### Getting correct hashes

```bash
# Use the provided script
chmod +x scripts/get-extension-hashes.sh
./scripts/get-extension-hashes.sh

# Or get hash for specific extension:
nix-prefetch-url "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/tonybaloney/vsextensions/vscode-pets/1.25.0/vspackage"
```

## Best Practices

1. **Prefer nixpkgs extensions** - They're tested and maintained
2. **Pin versions** - Specify exact versions for reproducibility
3. **Document custom extensions** - Add comments explaining why they're needed
4. **Test changes** - Always test after adding extensions
5. **Keep it minimal** - Only add extensions you actually use

## Useful Commands

```bash
# List installed extensions
code --list-extensions

# Search nixpkgs for extensions
nix search nixpkgs vscode-extensions | grep -i "search-term"

# Check if extension is in nixpkgs
nix eval nixpkgs#vscode-extensions.publisher.extension-name --json

# Rebuild system after changes
cd /home/olafkfreund/.config/nixos
sudo nixos-rebuild switch --flake .
```
