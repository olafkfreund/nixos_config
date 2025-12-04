# NixOS Infrastructure Hub - Claude Code Guide

> **Fast, Easy, Reliable NixOS Development with Claude Code**

## 🚀 Quick Start Workflows

### Daily Development Workflow

```bash
# Morning: Check what needs attention
/check_tasks

# Start new work: Create issue + branch
/new_task "Add PostgreSQL monitoring"

# Implementation: Use optimized commands
/nix-module            # Create new module
/nix-deploy            # Deploy changes
/nix-security          # Security audit

# Code review before commit
/review

# Close the loop
git commit && gh pr create
/check_tasks           # Verify issue closed
```

### Emergency Fix Workflow

```bash
/nix-fix               # Auto-fix anti-patterns
/nix-deploy            # Emergency deploy
Emergency deploy to p620
```

## 📋 Powerful Slash Commands

### Module Development

**`/nix-module`** - Create new NixOS module

- ⚡ Automatically follows best practices
- 🔒 Includes security hardening
- ✅ Validates syntax and patterns
- 📚 Provides usage examples
- ⏱️ Complete in ~2 minutes

```
/nix-module
Create monitoring/postgres-exporter module
```

### Code Quality

**`/nix-fix`** - Fix anti-patterns automatically

- Detects mkIf true patterns
- Removes trivial wrappers
- Fixes secret handling
- Hardens service security
- Shows before/after diffs

```
/nix-fix
Fix all files in modules/services/
```

**`/review`** - Comprehensive code review

- Checks against PATTERNS.md
- Detects anti-patterns
- Security analysis
- Performance review
- Actionable fixes with code

```
/review
Review hosts/p620/configuration.nix
```

### Security

**`/nix-security`** - Security audit

- Service isolation check
- Systemd hardening review
- Secret management audit
- Firewall configuration
- SSH hardening
- Generates security score

```
/nix-security
# Returns detailed security report
```

### Deployment

**`/nix-deploy`** - Smart deployment

- Automatic validation
- Change detection
- Security checks
- Smart rollback
- Post-deployment verification

```
/nix-deploy
Deploy to p620

# Fast mode (skip tests)
/nix-deploy
Fast deploy to razer

# Emergency mode
/nix-deploy
Emergency deploy to p510

# All hosts
/nix-deploy
Deploy to all hosts
```

### Optimization

**`/nix-optimize`** - Performance analysis

- Build performance
- Disk usage optimization
- Memory tuning
- Network optimization
- Boot performance
- Generates specific fixes

```
/nix-optimize
# Returns complete optimization report
```

### GitHub Integration

**`/new_task`** - Create GitHub issue

- Guides through issue creation
- Conducts technical research
- Creates formatted issue
- Generates implementation plan
- Provides branch name

```
/new_task
# Walks through issue creation
```

**`/check_tasks`** - Review open issues

- Shows all open tasks
- Categorizes by priority
- Identifies blockers
- Progress tracking
- Recommended actions

```
/check_tasks
# Shows comprehensive task status
```

## 🤖 Proactive Agent Usage

Claude Code will **automatically** use specialized agents for:

### NixOS Development (nixos-pro agent)

- Creating or modifying NixOS modules
- Writing package derivations
- System optimization tasks
- Security hardening implementations
- Complex NixOS patterns

### Example

```
"Create a comprehensive monitoring module with Prometheus and Grafana"
# Automatically uses nixos-pro agent for implementation
```

## 📚 Required Documentation

**ALWAYS read before coding:**

### Essential References

- **docs/PATTERNS.md** - NixOS best practices and patterns
- **docs/NIXOS-ANTI-PATTERNS.md** - Critical anti-patterns to avoid

### When to Read

**Before Creating Modules:**

```
"Read docs/PATTERNS.md Module System Patterns section,
then create a new monitoring module"
```

**Before Writing Packages:**

```
"Check docs/PATTERNS.md Package Writing Patterns,
then create package derivation for myapp"
```

**Before Code Review:**

```
"Review this code against docs/NIXOS-ANTI-PATTERNS.md
and docs/PATTERNS.md"
```

## 🏗️ Project Architecture

### Infrastructure Overview

- **4 Active Hosts**: p620 (workstation), p510 (server), razer/samsung (laptops)
- **141+ Modules**: Feature-based modular architecture
- **Template System**: 95% code deduplication through templates
- **Multi-User**: Per-host user configurations with Home Manager

### Critical Patterns

#### 1. Module Creation (REQUIRED)

```nix
# All services MUST be in modules/ directory
modules/
├── services/
│   └── myservice.nix    # Feature-based module
└── default.nix          # Explicit imports

# Enable via feature flags in host config
features.myservice.enable = true;
```

#### 2. Security Hardening (REQUIRED)

```nix
systemd.services.myservice = {
  serviceConfig = {
    DynamicUser = true;           # REQUIRED
    ProtectSystem = "strict";     # REQUIRED
    NoNewPrivileges = true;       # REQUIRED
    ProtectHome = true;           # REQUIRED
  };
};
```

#### 3. Secret Management (REQUIRED)

```nix
# ❌ WRONG - Evaluation time
password = builtins.readFile "/secrets/pass";

# ✅ CORRECT - Runtime loading
passwordFile = config.age.secrets.password.path;
```

## ⚡ Fast Development Tips

### 1. Use Slash Commands for Everything

- `/nix-module` instead of manually creating modules
- `/nix-deploy` instead of manual deployment
- `/nix-fix` instead of manual anti-pattern fixes
- `/nix-security` for comprehensive security audit

### 2. Leverage Smart Detection

```bash
# Smart deploy only if changed
/nix-deploy
Deploy to p620
# Automatically skips if no changes
```

### 3. Parallel Operations

```bash
# Deploy to all hosts simultaneously
/nix-deploy
Deploy to all hosts
# Completes in ~3 minutes vs 12 minutes sequential
```

### 4. Quick Validation

```bash
# Fast syntax check
just check-syntax

# Quick validation (30s)
just validate-quick

# Smart test (only if changed)
just quick-test
```

## 🔄 Complete Development Cycle

### Feature Development (5-10 minutes)

```bash
# 1. Create issue (2min)
/new_task "Add Redis monitoring"

# 2. Create module (2min)
/nix-module
Create monitoring/redis-exporter

# 3. Deploy (2min)
/nix-deploy
Deploy to p620

# 4. Review (1min)
/review

# 5. Commit & PR (2min)
git commit -m "feat(monitoring): add redis exporter (#45)"
gh pr create --fill

# 6. Verify (30s)
/check_tasks
```

**Total Time**: ~10 minutes for complete feature

### Bug Fix (2-5 minutes)

```bash
# 1. Quick fix (1min)
# Edit file

# 2. Auto-fix patterns (30s)
/nix-fix

# 3. Fast deploy (1min)
/nix-deploy
Fast deploy to p620

# 4. Verify (30s)
systemctl status service
```

**Total Time**: ~3 minutes for bug fix

### Security Audit (3-5 minutes)

```bash
# 1. Run audit (1min)
/nix-security

# 2. Review report (1min)
# Check critical issues

# 3. Apply fixes (2min)
# Implement suggested fixes

# 4. Validate (1min)
/nix-security
# Verify score improved
```

**Total Time**: ~5 minutes for security review

## 🎯 Best Practices

### DO ✅

1. **Use Slash Commands**: Faster and more reliable
2. **Read Documentation**: Before writing code
3. **Security First**: Always use DynamicUser
4. **Test Locally**: Before deploying
5. **Smart Deploy**: Use change detection
6. **Track Issues**: Use GitHub workflow
7. **Review Code**: Always run /review
8. **Optimize**: Run /nix-optimize monthly

### DON'T ❌

1. **Skip Validation**: Always validate before deploy
2. **Commit Directly**: Use issue-driven workflow
3. **Root Services**: Always use DynamicUser
4. **Evaluation Secrets**: Use runtime loading
5. **Manual Anti-pattern Fixes**: Use /nix-fix
6. **Skip Security**: Run /nix-security regularly
7. **Ignore Warnings**: Address all issues

## 📊 Performance Targets

### Build Times

- Syntax check: < 5s
- Quick validation: < 30s
- Host test: < 60s
- Full deployment: < 2.5min
- Parallel all-hosts: < 3min

### Deployment Safety

- Pre-deployment validation: 100%
- Automatic rollback: Enabled
- Service verification: All services
- Network connectivity: Verified

### Code Quality

- Anti-patterns: Zero tolerance
- Security score: > 85/100
- Test coverage: All modules
- Documentation: Required

## 🚨 Emergency Procedures

### Quick Fix

```bash
/nix-fix              # Auto-fix patterns
/nix-deploy           # Emergency deploy
Emergency deploy to HOST
```

### Rollback

```bash
# Automatic rollback on failure
# Or manual:
sudo nixos-rebuild switch --rollback
```

### Debug

```bash
journalctl -u SERVICE -f    # Follow logs
systemctl status SERVICE    # Check status
just validate              # Full validation
```

## 🔗 Integration Points

### GitHub Workflow

- **Issues**: Track all work with /new_task
- **Branches**: Auto-generate from issues
- **PRs**: Link to issues automatically
- **Tracking**: Monitor with /check_tasks

### Just Commands

- **validate**: Full validation
- **test-host**: Build test
- **quick-deploy**: Smart deployment
- **check-syntax**: Syntax validation

### Documentation

- **PATTERNS.md**: Best practices guide
- **NIXOS-ANTI-PATTERNS.md**: What to avoid
- **CLAUDE.md**: This guide (project context)
- **GITHUB-WORKFLOW.md**: Complete workflow guide

## 💡 Pro Tips

1. **Chain Commands**: Use multiple slash commands in sequence
2. **Context Aware**: Slash commands understand your codebase
3. **Automatic Research**: Commands read docs automatically
4. **Smart Defaults**: Commands choose best options
5. **Comprehensive Output**: Detailed reports with actionable fixes

## 📖 Quick Reference

```bash
# Module Development
/nix-module           # Create new module (2min)

# Code Quality
/nix-fix             # Fix anti-patterns (1min)
/review              # Code review (1min)

# Security
/nix-security        # Security audit (1min)

# Deployment
/nix-deploy          # Smart deploy (2.5min)

# Optimization
/nix-optimize        # Performance analysis (2min)

# GitHub
/new_task            # Create issue (2min)
/check_tasks         # Review tasks (30s)

# Validation
just check-syntax    # Syntax (5s)
just validate-quick  # Quick check (30s)
just test-host HOST  # Build test (60s)
```

## 🎓 Learning Resources

- **Interactive**: Use slash commands and learn from output
- **Documentation**: Read docs/PATTERNS.md for deep understanding
- **Examples**: All slash commands provide example code
- **Anti-patterns**: Learn what NOT to do from NIXOS-ANTI-PATTERNS.md

---

**Remember**: Claude Code is optimized for speed, ease, and reliability. Use slash commands for everything - they're faster and more reliable than manual processes!

For complete workflow details, see: **docs/GITHUB-WORKFLOW.md**
