# Agent Skills Management

Manage AI agent skills using the Skills CLI (vercel-labs/skills).

## When to Use

When the user asks to:
- Install, update, remove, or list agent skills
- Search for available skills
- Create a new custom skill
- Check for skill updates

## Commands Reference

### List installed skills
```bash
skills list
```

### Install skills from a repository
```bash
# Interactive - choose skills and agents
skills add owner/repo

# Install specific skills globally for Claude Code
skills add owner/repo --skill skill-name -g -a claude-code

# Install all skills from a repo
skills add owner/repo --all -g -a claude-code

# List available skills without installing
skills add owner/repo --list
```

### Search for skills
```bash
skills find "search query"
```

### Update all installed skills
```bash
skills update
```

### Check for available updates
```bash
skills check
```

### Remove skills
```bash
# Interactive removal
skills remove

# Remove specific skill
skills remove skill-name

# Remove from global scope
skills remove --global skill-name
```

### Create a new skill
```bash
# Create SKILL.md template in current directory
skills init

# Create in subdirectory
skills init my-new-skill
```

## Known Skill Repositories

- **AbsolutelySkilled/AbsolutelySkilled** - 200+ production skills (brainstorm, coding, DevOps, security)
- **vercel-labs/agent-skills** - Vercel's curated skill collection

## Skill File Format (SKILL.md)

```markdown
---
name: my-skill
description: What this skill does
---

# My Skill

Instructions for the agent.

## When to Use
Describe activation scenarios.

## Steps
1. Step one
2. Step two
```

## Installation Locations

- **Global**: `~/.claude/skills/skill-name/SKILL.md` (available in all projects)
- **Project**: `.claude/skills/skill-name/SKILL.md` (project-specific)

## Workflow

1. Run the appropriate `skills` command
2. Show output to the user
3. If installing, recommend relevant skills for the user's NixOS/DevOps workflow
4. After installation, verify with `skills list`
