# NixVim Configuration

A feature-rich and modular Neovim configuration using the declarative power of Nix and nixvim.

## Migration from LazyVim

This configuration represents a complete migration from LazyVim to nixvim, preserving most of the functionality while taking advantage of the declarative and reproducible nature of Nix.

### Key Benefits of NixVim vs LazyVim

1. **Declarative Configuration**: Define your entire editor setup in a reproducible way
2. **Version Control**: Manage plugins and their versions through Nix
3. **System Integration**: Better integration with the rest of your NixOS configuration
4. **Simplified Updates**: Update plugins through your normal system update process
5. **Portability**: Consistent setup across multiple machines

## Directory Structure

The configuration follows a modular approach for maintainability:

```
nixvim/
├── config/                # Editor core configuration
│   ├── autocmds.nix       # Automatic commands
│   ├── filetypes.nix      # Filetype-specific settings
│   ├── keymaps.nix        # Key mappings
│   └── default.nix        # Config entry point
├── plugins/               # Plugin configurations
│   ├── core/              # Core plugins (colorscheme, which-key)
│   ├── editor/            # Editor enhancements (telescope, treesitter)
│   ├── ui/                # UI components (bufferline, lualine, etc.)
│   ├── coding/            # Coding tools (LSP, completion, etc.)
│   ├── lang/              # Language-specific settings
│   └── default.nix        # Plugins entry point
└── default.nix            # Main entry point
```

## Features

### Core Features

- Modern and elegant colorscheme (Gruvbox)
- Efficient keymapping system with which-key integration
- Automatic commands for improved workflow
- File type specific configurations

### Editor Enhancements

- Fuzzy finding with Telescope
- Syntax highlighting with Tree-sitter
- Git integration with gitsigns
- Auto-pairs, surround, and other text editing helpers

### User Interface

- Beautiful status line with lualine
- Enhanced tab/buffer line with bufferline
- Improved command line and notifications with noice
- Welcome dashboard with alpha-nvim

### Coding Features

- LSP integration for intelligent code completion
- Auto-completion with nvim-cmp
- GitHub Copilot integration
- Code formatting with conform.nvim
- Snippet support

### Language Support

- Language-specific configurations
- Markdown preview and editing tools
- Nix language integration

## Installation & Usage

To use this nixvim configuration:

1. Ensure you have a working NixOS setup with flakes enabled
2. Add the following to your Home Manager configuration:

```nix
{
  imports = [
    # Other imports...
    ./home/shell/nixvim
  ];
}
```

3. Run `nixos-rebuild switch` to apply the changes

## Keybindings

Key mappings follow an organized structure with sensible defaults:

- `<Space>` is used as the leader key
- `<Space>f` - File operations and finding
- `<Space>b` - Buffer operations
- `<Space>w` - Window operations
- `<Space>g` - Git operations
- `<Space>l` - LSP operations
- `<Space>c` - Code operations
- `<Space>s` - Search operations

For a complete list of keybindings, press `<Space>` in normal mode to see available options through which-key.

## Customization

To customize this configuration:

1. Edit the corresponding module files based on the feature you want to modify
2. For plugins, edit the respective plugin configuration file in `plugins/` directory
3. For core editor settings, modify files in the `config/` directory
4. Run `nixos-rebuild switch` to apply your changes

## Testing Your Configuration

Test your nixvim configuration without affecting your system:

```bash
nix run nixpkgs#nixvim -- --arg config 'import ~/.config/nixos/home/shell/nixvim'
```

## Troubleshooting

Common issues and solutions:

- **Plugin not working**: Ensure the plugin is properly configured and imported
- **Keybinding issues**: Check for conflicts in `keymaps.nix`
- **Syntax highlighting problems**: Verify treesitter configuration
- **LSP errors**: Make sure the language server is installed and configured

## Resources

- [nixvim Documentation](https://github.com/nix-community/nixvim)
- [Neovim Documentation](https://neovim.io/doc/)
- [Nixpkgs Manual](https://nixos.org/manual/nixpkgs/stable/)