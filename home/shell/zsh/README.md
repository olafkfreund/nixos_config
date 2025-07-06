# 🐚 Enhanced Zsh Configuration

## Overview

This configuration provides a modern, high-performance Zsh environment optimized for developer productivity with AI integration, modern tooling, and seamless workflow management.

## 🚀 Key Features

### Performance Optimizations
- **50,000 command history** with intelligent deduplication
- **Smart completion caching** for faster startup (only rebuilds when needed)
- **Lazy plugin loading** with defer mechanisms
- **Optimized Oh-My-Zsh** configuration with essential plugins only

### AI Integration
- **GitHub Copilot** integration for command suggestions and explanations
- **AIChat** integration for command enhancement and learning
- **Smart keybindings** for instant AI assistance

### Modern Developer Tools
- **Enhanced syntax highlighting** with Gruvbox theme colors
- **Smart autosuggestions** with history and completion strategies
- **fzf-tab integration** with file previews and fuzzy searching
- **Modern tool replacements** (eza, bat, ripgrep, fd, etc.)

## 🎹 Keybindings

### Navigation
- `Ctrl+Right/Left` - Word navigation (forward/backward)
- `Ctrl+Delete` - Delete word forward
- `Ctrl+Backspace` - Delete word backward
- `Home/End` - Line navigation

### AI Assistance
- `Alt+\` - GitHub Copilot suggestions
- `Alt+Shift+\` - GitHub Copilot explanations
- `Alt+E` - AIChat command enhancement

### Productivity
- `Ctrl+F` - Launch tmux-sessionizer for project management
- `Ctrl+E` - Edit command in editor
- `Ctrl+L` - Clear screen and history

### Enhanced Copy Mode
- `v` - Begin selection
- `y` - Copy selection and cancel
- `r` - Rectangle toggle
- `Escape` - Cancel

## 🛠️ Configuration Structure

### Plugin Architecture
```nix
plugins = [
  # Essential productivity
  zsh-fzf-tab           # Enhanced tab completion with fuzzy search
  zsh-nix-shell         # Nix environment integration
  zsh-forgit            # Interactive git operations
  zsh-edit              # Enhanced command editing
  nix-zsh-completions   # Nix-specific completions
  zsh-you-should-use    # Alias learning assistant
]
```

### Oh-My-Zsh Plugins
```nix
plugins = [
  "sudo"         # Prefix commands with sudo via ESC ESC
  "direnv"       # Environment variable management
  "history"      # Advanced history management
  "starship"     # Modern prompt integration
  "git"          # Git aliases and functions
  "forgit"       # Interactive git with fzf
  "terraform"    # Terraform completion and aliases
  "aws"          # AWS CLI integration
  "azure"        # Azure CLI integration
  "1password"    # 1Password CLI integration
]
```

## 📝 Aliases and Functions

### Git Enhancements
```bash
gc="git commit -v"                                    # Verbose commits
gl="git log --oneline --graph --decorate"            # Beautiful git log
```

### Modern Tool Replacements
```bash
ezals="eza --header --git --classify --long --binary --group --time-style=long-iso --links --all --group-directories-first --sort=name --icons"
fzfpreview="fzf --preview 'bat --color=always --line-range :50 {}'"
aiexplain="aichat --role explain"
```

### Productivity Shortcuts
```bash
reload="exec zsh"                                     # Reload shell
weather="curl -s https://wttr.in/London"             # Quick weather
myip="curl -s https://ipinfo.io/ip"                  # External IP
```

## 🎨 Theme Integration

### Syntax Highlighting Colors
```nix
styles = {
  comment = "fg=#928374";        # Gruvbox gray
  string = "fg=#b8bb26";         # Gruvbox green
  keyword = "fg=#fb4934";        # Gruvbox red
  builtin = "fg=#fabd2f";        # Gruvbox yellow
  function = "fg=#83a598";       # Gruvbox blue
  command = "fg=#8ec07c";        # Gruvbox aqua
  unknown-token = "fg=#cc241d";  # Gruvbox dark red
}
```

### Autosuggestion Settings
- **Strategy**: History and completion-based
- **Highlight color**: `fg=#665c54` (Gruvbox gray)
- **Buffer limit**: 20 characters for performance

## 🔧 Environment Variables

### Performance Settings
```bash
export KEYTIMEOUT=1                    # Faster key sequences
export REPORTTIME=10                   # Report long-running commands
export ZSH_AUTOSUGGEST_MANUAL_REBIND=1 # Manual rebinding for performance
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
```

### Tool Configuration
```bash
export EDITOR="nvim"                   # Default editor
export VISUAL="$EDITOR"               # Visual editor
export PAGER="less"                   # Default pager
export MANPAGER="sh -c 'col -bx | bat -l man -p'"  # Colored man pages
export BAT_THEME="gruvbox-dark"       # Consistent theming
```

### History Management
```bash
export HISTSIZE=50000                 # Large in-memory history
export SAVEHIST=50000                # Large saved history
export HISTFILE="$HOME/.zsh_history" # History file location
```

## 🔗 Integration Points

### Claude Code Integration
- **Temperature control**: Configurable for different use cases
- **Terminal support**: Kitty, foot, alacritty, wezterm
- **Temp directory**: `$HOME/.cache/claude-code`

### Modern Tool Integration
- **Zoxide**: Smart directory navigation with `cd` command override
- **Eza**: Modern `ls` replacement with icons and git integration
- **Fzf**: Enhanced fuzzy finding with file previews
- **Bat**: Syntax-highlighted file viewing

### Completion System
- **Smart caching**: Only rebuilds when necessary
- **Enhanced matching**: Case-insensitive with partial matching
- **fzf-tab integration**: Visual completion with previews
- **Nix awareness**: Special handling for Nix commands and packages

## 📊 Performance Features

### Startup Optimization
- **Lazy loading**: Plugins loaded on demand
- **Completion caching**: Avoids rebuilding on every shell start
- **Minimal plugin set**: Only essential functionality included
- **Efficient history**: Smart deduplication and fast searching

### Memory Management
- **Buffer limits**: Prevents memory bloat from large suggestions
- **History limits**: Balanced between functionality and performance
- **Plugin deferring**: Non-critical plugins loaded after shell is ready

## 🎯 Usage Tips

### Daily Workflow
1. **Start projects**: Use `Ctrl+F` to launch tmux-sessionizer
2. **Navigate efficiently**: Use `cd` (zoxide) for intelligent directory jumping
3. **Search files**: Use `fzfpreview` for file searching with previews
4. **Get AI help**: Use `Alt+E` for command enhancement
5. **Learn aliases**: Let `zsh-you-should-use` teach you shortcuts

### Git Workflow
1. Use `forgit` commands for interactive git operations
2. Leverage enhanced `gc` and `gl` aliases for better commits and logs
3. Take advantage of git-aware completions and prompt integration

### Development Workflow
1. Use direnv for project-specific environment management
2. Leverage Nix shell integration for development environments
3. Take advantage of language-specific completions and tools

## 🔧 Customization

### Adding New Aliases
Add to the `shellAliases` section in `zsh.nix`:
```nix
shellAliases = {
  myalias = "command";
}
```

### Adding New Plugins
Add to the `plugins` array:
```nix
{
  name = "plugin-name";
  src = pkgs.plugin-package;
  file = "path/to/plugin.zsh";
}
```

### Environment Variables
Add to the `envExtra` section for shell-specific variables or `sessionVariables` for global variables.

## 🐛 Troubleshooting

### Performance Issues
1. Check completion cache: `rm ~/.zcompdump*` and restart shell
2. Verify plugin loading: Disable plugins one by one to identify issues
3. Check history size: Reduce if experiencing slowdowns

### AI Integration Issues
1. Verify GitHub Copilot authentication: `gh auth status`
2. Check AIChat configuration: Ensure proper API keys are set
3. Test keybindings: Use `bindkey | grep aichat` to verify bindings

### Theme Issues
1. Verify terminal true color support: `echo $TERM`
2. Check font installation: Ensure Nerd Fonts are properly installed
3. Validate color settings: Test with `spectrum_ls` (Oh-My-Zsh)

## 📚 References

- [Zsh Documentation](http://zsh.sourceforge.net/Doc/)
- [Oh-My-Zsh Framework](https://ohmyz.sh/)
- [Starship Prompt](https://starship.rs/)
- [fzf Fuzzy Finder](https://github.com/junegunn/fzf)
- [Gruvbox Theme](https://github.com/morhetz/gruvbox)