# NixOS Custom Commands Documentation

Welcome to the NixOS custom commands documentation. This directory contains comprehensive guides for using specialized Claude Code slash commands designed for NixOS infrastructure management.

## Overview

Custom slash commands automate complex NixOS workflows, embedding best practices, safety checks, and GitHub integration into repeatable, documented procedures.

## Available Commands

### Core Maintenance Commands

| Command                | Purpose                            | Frequency | Priority |
| ---------------------- | ---------------------------------- | --------- | -------- |
| `/flake-update`        | Update and deploy flake inputs     | Weekly    | High     |
| `/system-health-check` | Comprehensive infrastructure audit | Weekly    | High     |
| `/deploy-all`          | Deploy to all hosts with testing   | As needed | High     |

### Package Management Commands

| Command               | Purpose                         | Frequency | Priority |
| --------------------- | ------------------------------- | --------- | -------- |
| `/update-package`     | Update specific package         | As needed | Medium   |
| `/update-claude-code` | Update Claude Code specifically | Monthly   | Medium   |

### Quality Assurance Commands

| Command         | Purpose                 | Frequency | Priority |
| --------------- | ----------------------- | --------- | -------- |
| `/config-audit` | Audit for anti-patterns | Monthly   | Medium   |

## Quick Start

```bash
# Start Claude Code
claude

# Use any command
/flake-update
/system-health-check
/update-claude-code
```

## Command Categories

### 1. System Maintenance

- **`/flake-update`** - Safe flake updates with testing and rollback
- **`/system-health-check`** - Comprehensive health monitoring
- **`/deploy-all`** - Coordinated multi-host deployment

### 2. Package Updates

- **`/update-package`** - Generic package update workflow
- **`/update-claude-code`** - Specialized Claude Code updates

### 3. Quality Control

- **`/config-audit`** - Configuration quality and compliance

## Why Use Custom Commands?

### Benefits

 **Consistency**: Same workflow every time, embedding best practices
 **Safety**: Built-in validation, testing, and rollback procedures
 **Documentation**: Commands serve as living documentation
 **Efficiency**: Complex workflows become one-line invocations
 **Quality**: Automatic adherence to patterns and anti-patterns docs
 **Integration**: GitHub issue/PR creation built-in
 **Learning**: New team members see proper workflows

### Productivity Impact

```bash
# Without commands: 15-30 minutes
# 1. Search for package info
# 2. Update files manually
# 3. Calculate hashes
# 4. Test builds
# 5. Create issue
# 6. Create branch
# 7. Commit
# 8. Create PR
# 9. Review
# 10. Deploy

# With commands: 2-5 minutes
/update-claude-code
```

**Result:** 10x faster workflows with better quality and documentation.

## Documentation Structure

```
docs/Nixos/
├── README.md                          # This file
├── Command-System-Overview.md         # Complete command system guide
├── Update-Checker-Guide.md            # NixOS Update Checker (NEW)
├── Flake-Update-Guide.md             # /flake-update documentation
├── System-Health-Check-Guide.md      # /system-health-check documentation
├── Update-Package-Guide.md           # /update-package documentation
├── Update-Claude-Code-Guide.md       # /update-claude-code documentation
├── Deploy-All-Guide.md               # /deploy-all documentation
└── Config-Audit-Guide.md             # /config-audit documentation
```

## Getting Started

### First Time Setup

1. **Verify commands are available:**

   ```bash
   ls -la .claude/commands/
   ```

2. **Test a command:**

   ```bash
   claude
   /system-health-check
   ```

3. **Review command documentation:**

   ```bash
   cat .claude/commands/flake-update.md
   ```

### Recommended Weekly Workflow

```bash
# Monday: System health check
/system-health-check

# Wednesday: Flake updates
/flake-update

# Friday: Review and close completed tasks
/check_tasks
```

### Recommended Monthly Workflow

```bash
# First week: Configuration audit
/config-audit

# Second week: Update Claude Code
/update-claude-code

# Third week: Update other packages
/update-package

# Fourth week: Review improvements
/check_tasks
```

## Integration with Existing Tools

Commands integrate seamlessly with:

- **Just commands**: `just validate`, `just quick-test`, `just quick-deploy`
- **GitHub workflow**: `/new_task`, `/check_tasks`, `/review`
- **Documentation**: `@docs/PATTERNS.md`, `@docs/NIXOS-ANTI-PATTERNS.md`
- **Monitoring**: Grafana, Prometheus, health checking

## Best Practices

### Do's 

-  Use commands for all routine maintenance
-  Read command output carefully
-  Follow recommended schedules
-  Review generated documentation
-  Create GitHub issues for tracking
-  Monitor after deployments
-  Keep commands up-to-date

### Don'ts 

-  Skip testing steps in commands
-  Ignore command warnings
-  Deploy without validation
-  Forget to monitor after changes
-  Skip GitHub workflow integration
-  Ignore rollback procedures

## Common Workflows

### Update and Deploy Workflow

```bash
# 1. Check system health
/system-health-check

# 2. Update flake inputs
/flake-update

# 3. Deploy changes
/deploy-all

# 4. Verify health
/system-health-check
```

### Package Update Workflow

```bash
# 1. Update specific package
/update-package
# Follow prompts for package details

# 2. Review code changes
/review

# 3. Deploy after approval
/deploy-all
```

### Quality Maintenance Workflow

```bash
# 1. Run audit
/config-audit

# 2. Create issues for findings
/new_task
# For each critical/high priority item

# 3. Fix issues
# Work through issues

# 4. Verify improvements
/config-audit
```

## Troubleshooting

### Command Not Found

```bash
# Check if commands exist
ls -la .claude/commands/

# Restart Claude Code
exit
claude
```

### Command Fails

```bash
# Check command file for syntax
cat .claude/commands/COMMAND_NAME.md

# Run command in debug mode
# Add debug output in command execution
```

### Deployment Issues

```bash
# Use rollback procedures from command
# Each command includes rollback instructions

# Check system health
/system-health-check
```

## Documentation References

- **Patterns**: [@docs/PATTERNS.md](../PATTERNS.md)
- **Anti-patterns**: [@docs/NIXOS-ANTI-PATTERNS.md](../NIXOS-ANTI-PATTERNS.md)
- **GitHub Workflow**: [@docs/GITHUB-WORKFLOW.md](../GITHUB-WORKFLOW.md)
- **Roadmap**: [@.agent-os/product/roadmap.md](../../.agent-os/product/roadmap.md)

## Support and Feedback

### Getting Help

1. **Read command documentation** in this directory
2. **Check command file** in `.claude/commands/`
3. **Review execution logs** from Claude Code
4. **Consult pattern documentation**

### Providing Feedback

- **Improve commands**: Edit `.claude/commands/*.md` files
- **Update documentation**: Edit files in `docs/Nixos/`
- **Report issues**: Use `/new_task` to create GitHub issues
- **Share improvements**: Commit and push changes

## Next Steps

1. **Read**: [Command System Overview](./Command-System-Overview.md)
2. **Try**: Run `/system-health-check` to get started
3. **Learn**: Review individual command guides
4. **Practice**: Use commands in daily workflows
5. **Improve**: Customize commands for your needs

## Version History

- **2025-01-29**: Initial command system creation
  - Created 6 core commands
  - Comprehensive documentation
  - Integration with existing infrastructure

## Future Enhancements

Planned command additions:

- `/backup-verify` - Backup status and verification
- `/security-audit` - Security-focused audit
- `/performance-analysis` - Performance optimization
- `/weekly-maintenance` - Automated weekly tasks
- `/emergency-rollback` - Fast rollback all hosts

---

**Remember**: Commands are tools to enhance your workflow, not replace understanding. Always know what the commands are doing and why.
