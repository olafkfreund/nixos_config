# Claude Code in LazyVim — Quick Reference

All AI keys use the `<leader>a` prefix. Press `<leader>a` and pause —
which-key will show this menu live.

| Key            | Action                              |
|----------------|-------------------------------------|
| `<leader>aa`   | Toggle Claude session               |
| `<leader>af`   | Focus Claude window                 |
| `<leader>ar`   | Resume previous conversation        |
| `<leader>aC`   | Continue last response              |
| `<leader>am`   | Select model                        |
| `<leader>ab`   | Add current buffer to context       |
| `<leader>as`   | Send visual selection (visual mode) |
| `<leader>aA`   | Accept Claude's proposed diff       |
| `<leader>aD`   | Deny Claude's proposed diff         |

Open this file from inside Neovim with `<leader>?C`.

## How it works

- **Plugin**: [coder/claudecode.nvim](https://github.com/coder/claudecode.nvim)
- **LazyVim extra**: `lazyvim.plugins.extras.ai.claudecode` (enabled in `lua/config/lazy.lua`)
- **CLI**: the `claude` binary is provided by the developer Home Manager
  profile — nothing to install separately.
- **Window**: Claude opens in a floating terminal via `snacks.nvim`. Toggle
  with `<leader>aa`; the same key closes it again.

## Workflow tips

- **Ask about a file**: open the file → `<leader>ab` (add buffer) → `<leader>aa` → ask.
- **Refactor a block**: visual-select → `<leader>as` → describe the change.
- **Review a diff Claude proposes**: `<leader>aA` accepts, `<leader>aD` rejects.
- **Resume yesterday's chat**: `<leader>ar`.

## Documentation

- LazyVim extra: <https://www.lazyvim.org/extras/ai/claudecode>
- Plugin docs: <https://github.com/coder/claudecode.nvim>
