# Claude Powerline - Statusline for Claude Code

> **Real-time API monitoring, git integration, and performance analytics** for Claude Code with a beautiful
> Gruvbox Dark theme.

## Overview

Claude Powerline is a vim-style statusline for Claude Code that provides comprehensive monitoring and development
context directly in your Claude Code environment.

### Key Features

- ⏱️ **Real-time API Usage Tracking**: Monitor costs and token usage within 5-hour billing windows
- 💰 **Budget Monitoring**: Track session, daily, and block budgets with configurable alerts
- 🌳 **Git Integration**: Display branch status, commits, and working tree changes
- 📊 **Performance Analytics**: Track API response times, session duration, and code impact
- 🎨 **Custom Gruvbox Dark Theme**: Beautiful, eye-friendly color scheme matching your development environment
- ⚡ **Lightweight Performance**: < 250ms statusline updates with minimal resource usage

## Installation

Claude Powerline is installed automatically as part of the `developer` Home Manager profile.

### Enable in Your Profile

The module is already enabled in the developer profile with these settings:

```nix
programs.claude-powerline = {
  enable = true;
  theme = "custom";       # Gruvbox Dark theme
  style = "powerline";    # Vim-style powerline separators
  budget = {
    session = 10.0;       # $10 per 5-hour session
    daily = 25.0;         # $25 per day
    block = 15.0;         # $15 per block
  };
};
```

### Available Hosts

Claude Powerline is available on all hosts using the developer profile:

- ✅ **P620** (primary workstation)
- ✅ **Razer** (laptop)
- ✅ **P510** (media server with development mode)
- ✅ **Samsung** (laptop)

## Configuration

### Theme Customization

The Gruvbox Dark theme is configured with the following color palette:

**Background Colors:**

- `#282828` - Main background (dark0)
- `#3c3836` - Alternative background (dark1)
- `#1d2021` - Dark variant (dark0_hard)

**Foreground Colors:**

- `#ebdbb2` - Main foreground (light1)
- `#d5c4a1` - Alternative foreground (light2)
- `#bdae93` - Dark foreground (light3)

**Accent Colors:**

- **Blue** `#458588` - Directory segment
- **Green** `#98971a` - Git segment
- **Purple** `#b16286` - Model segment
- **Yellow** `#d79921` - Session budget segment
- **Aqua** `#689d6a` - Daily budget segment
- **Orange** `#d65d0e` - Context usage segment

### Statusline Layout

The statusline is organized into two lines for comprehensive information display:

#### **Line 1: Development Context**

```text
┌──────────────┬──────────────┬──────────────┐
│  Directory   │     Git      │    Model     │
│   (Blue)     │   (Green)    │   (Purple)   │
└──────────────┴──────────────┴──────────────┘
```

- **Directory**: Current working directory
- **Git**: Branch name, commits ahead/behind, working tree status
- **Model**: Active Claude model (Sonnet, Opus, etc.)

#### **Line 2: Resource Monitoring**

```text
┌──────────────┬──────────────┬──────────────┐
│   Session    │    Today     │   Context    │
│  (Yellow)    │    (Aqua)    │   (Orange)   │
└──────────────┴──────────────┴──────────────┘
```

- **Session**: Costs and usage within current 5-hour billing window
- **Today**: Daily total spending and usage
- **Context**: Context window usage for the active model

### Budget Configuration

Customize budget limits by modifying the configuration in your profile:

```nix
programs.claude-powerline.budget = {
  session = 10.0;  # 5-hour rolling window limit (USD)
  daily = 25.0;    # Daily spending limit (USD)
  block = 15.0;    # Block spending limit (USD)
};
```

#### **Recommended Budget Levels**

**Conservative (Light Usage):**

```nix
session = 5.0;
daily = 10.0;
block = 10.0;
```

**Moderate (Regular Usage):**

```nix
session = 10.0;
daily = 25.0;
block = 15.0;
```

**Aggressive (Heavy Usage):**

```nix
session = 20.0;
daily = 50.0;
block = 30.0;
```

### Warning Thresholds

Budget warnings are triggered at **80%** of configured limits:

- 🟢 **Green** (< 70%): Under budget, normal operation
- 🟡 **Yellow** (70-80%): Approaching limit, monitor usage
- 🟠 **Orange** (80-90%): Warning threshold exceeded
- 🔴 **Red** (> 90%): Critical, approaching limit

## Usage

### Viewing the Statusline

The statusline appears automatically at the bottom of your Claude Code session when:

1. Claude Code is running
2. You're working in a project with git repository
3. The Home Manager configuration is deployed

### Understanding Segment Information

#### **Directory Segment** (Blue)

Displays the current working directory with smart path truncation:

```text
~/nixos_config          # Full path when space available
~/n/config             # Truncated when space limited
```

#### **Git Segment** (Green)

Shows repository status with visual indicators:

```text
 main                  # Clean repository on main branch
 feature/123 ↑2       # 2 commits ahead of remote
 develop ↓1           # 1 commit behind remote
 hotfix +3 ~2 -1      # 3 staged, 2 modified, 1 deleted
```

**Git Status Indicators:**

- `↑` - Commits ahead of remote
- `↓` - Commits behind remote
- `+` - Staged changes
- `~` - Modified files
- `-` - Deleted files
- `?` - Untracked files

#### **Model Segment** (Purple)

Displays the active Claude model:

```text
 sonnet-4-5           # Claude 4.5 Sonnet
 opus-4               # Claude 4 Opus
 haiku-4              # Claude 4 Haiku
```

#### **Session Segment** (Yellow)

Shows 5-hour rolling window costs:

```text
$2.45 / $10.00       # $2.45 spent, $10 limit
$8.90 / $10.00 ⚠️    # Warning: 89% of budget
```

#### **Daily Segment** (Aqua)

Displays daily total spending:

```text
$12.50 / $25.00      # $12.50 spent today, $25 limit
$21.00 / $25.00 ⚠️   # Warning: 84% of daily budget
```

#### **Context Segment** (Orange)

Shows context window usage for the active model:

```text
45K / 200K           # 45K tokens used of 200K limit
180K / 200K ⚠️       # Warning: 90% of context used
```

**Context Limits by Model:**

- Sonnet 4.5: 200K tokens (1M for tier 4+ users)
- Opus 4: 200K tokens
- Haiku 4: 200K tokens

## Performance

### Resource Usage

Claude Powerline is designed for minimal performance impact:

- **CPU**: < 1% average usage
- **Memory**: < 50MB
- **Network**: None (reads from Claude session data)
- **Update Time**: 80-250ms depending on configuration

### Optimization Tips

**For Faster Updates:**

- Reduce number of enabled segments
- Use `minimal` style instead of `powerline`
- Increase update interval

**For Maximum Information:**

- Keep all segments enabled
- Use `powerline` style for visual clarity
- Accept slightly longer update times (~240ms)

## Troubleshooting

### Statusline Not Appearing

**Check Claude Code Settings:**

```bash
cat ~/.config/claude/settings.json
```

Should contain:

```json
{
  "statusLine": {
    "type": "command",
    "command": "npx -y @owloops/claude-powerline@latest --style=powerline"
  }
}
```

**Verify Node.js Availability:**

```bash
node --version  # Should be v22.x or higher
npx --version   # Should be installed
```

**Check Configuration File:**

```bash
cat ~/.config/claude-powerline/config.json
```

Should contain the Gruvbox Dark theme configuration.

### Budget Warnings Not Showing

**Verify Budget Configuration:**

Check that budget limits are set in your Home Manager configuration:

```bash
grep -A 5 "claude-powerline" ~/.config/home-manager/*.nix
```

**Test Warning Thresholds:**

The default warning threshold is 80%. Warnings appear when spending exceeds:

- Session: 80% of configured session budget
- Daily: 80% of configured daily budget
- Block: 80% of configured block budget

### Git Information Missing

**Verify Git Repository:**

```bash
cd ~/your-project
git status  # Should show repository information
```

**Check Git Binary:**

```bash
which git   # Should return path to git
git --version  # Should be 2.0 or higher
```

### Colors Not Displaying Correctly

**Check Terminal Support:**

```bash
echo $COLORTERM  # Should be "truecolor" or "24bit"
tput colors      # Should return 256 or more
```

**Test Unicode Support:**

```bash
echo "      "  # Should display powerline separators
```

**Environment Variables:**

The following environment variables are set automatically:

```bash
CLAUDE_POWERLINE_THEME=custom
CLAUDE_POWERLINE_STYLE=powerline
CLAUDE_POWERLINE_CONFIG=/home/USER/.config/claude-powerline/config.json
```

### Performance Issues

**If updates are slow (> 250ms):**

1. **Reduce segments**: Disable less critical segments
2. **Change style**: Use `minimal` instead of `powerline`
3. **Check system resources**: Ensure adequate CPU/memory

**Benchmark statusline performance:**

```bash
time npx -y @owloops/claude-powerline@latest --style=powerline
```

Should complete in < 250ms for full configuration.

## Advanced Configuration

### Custom Theme Colors

To create your own color theme, modify the `themeConfig` in `home/development/claude-powerline.nix`:

```nix
themeConfig = {
  theme = "custom";
  colors = {
    background = "#YOUR_BG_COLOR";
    foreground = "#YOUR_FG_COLOR";
    # ... customize all colors
  };
};
```

### Segment Customization

Enable or disable specific segments by modifying the `lines` configuration:

```nix
lines = [
  {
    segments = {
      directory.enabled = true;   # Show/hide directory
      git.enabled = true;         # Show/hide git
      model.enabled = false;      # Disable model segment
    };
  }
];
```

### Alternative Styles

Change the separator style:

```nix
programs.claude-powerline.style = "minimal";    # Simple separators
# or
programs.claude-powerline.style = "capsule";    # Rounded capsules
# or
programs.claude-powerline.style = "powerline";  # Vim-style (default)
```

## Integration with Development Workflow

### Git Workflow

Claude Powerline enhances your git workflow by providing:

- **Branch visibility**: Always see current branch
- **Change tracking**: Monitor uncommitted changes
- **Remote sync status**: Know when to push/pull

### Budget Management

Use the budget monitoring to:

- **Track API costs**: Stay within spending limits
- **Optimize prompts**: See impact of different approaches
- **Plan work sessions**: Manage 5-hour billing windows

### Context Management

Monitor context usage to:

- **Avoid truncation**: Know when approaching limits
- **Optimize conversations**: Start fresh when needed
- **Model selection**: Choose appropriate model for task

## References

- **Claude Powerline Repository**: <https://github.com/Owloops/claude-powerline>
- **Gruvbox Theme**: <https://github.com/morhetz/gruvbox>
- **NixOS Home Manager**: <https://nix-community.github.io/home-manager/>

## Updates

Claude Powerline auto-updates via `npx`, ensuring you always have the latest features and fixes.

To manually update:

```bash
npx -y @owloops/claude-powerline@latest --style=powerline
```

## Support

For issues or questions:

1. Check this documentation
2. Review the troubleshooting section
3. Check the upstream repository issues
4. Create an issue in this repository

---

**Last Updated**: 2025-01-15
**Version**: 1.0.0
**Status**: Production Ready
