# NixOS Commands Help

Quick reference for all available NixOS development commands.

## 🚀 Quick Commands (Most Used)

```bash
/nix-deploy          # Smart deployment with validation
/nix-module          # Create new module with best practices
/nix-fix             # Auto-fix anti-patterns
/nix-security        # Security audit
/review              # Code review
```

## 📋 All Available Commands

### Module Development

**`/nix-module`** - Create new NixOS module
- Automatically follows best practices
- Includes security hardening
- Validates syntax and patterns
- Provides usage examples
- Time: ~2 minutes

### Code Quality & Review

**`/nix-fix`** - Fix anti-patterns automatically
- Detects and fixes mkIf true patterns
- Removes trivial wrappers
- Fixes secret handling issues
- Hardens service security
- Shows before/after diffs
- Time: ~1 minute

**`/review`** - Comprehensive code review
- Checks against PATTERNS.md
- Detects anti-patterns from NIXOS-ANTI-PATTERNS.md
- Security analysis
- Performance review
- Actionable fixes with code examples
- Time: ~1 minute

### Security

**`/nix-security`** - Security audit
- Service isolation check (DynamicUser)
- Systemd hardening review
- Secret management audit
- Firewall configuration review
- SSH hardening check
- Generates security score (0-100)
- Time: ~1 minute

### Deployment

**`/nix-deploy`** - Smart deployment workflow
- Automatic validation
- Change detection (skips if no changes)
- Security checks
- Smart rollback on failure
- Post-deployment verification
- Modes: standard, fast, emergency, all-hosts
- Time: ~2.5 minutes (standard), ~1 minute (fast)

### Optimization

**`/nix-optimize`** - Performance analysis
- Build performance analysis
- Disk usage optimization
- Memory tuning recommendations
- Network optimization
- Boot performance analysis
- Generates specific fixes with impact estimates
- Time: ~2 minutes

### GitHub Integration

**`/new_task`** - Create GitHub issue
- Guides through issue creation
- Conducts technical research
- Creates formatted issue with labels
- Generates implementation plan
- Provides branch name
- Time: ~2 minutes

**`/check_tasks`** - Review open issues
- Shows all open tasks
- Categorizes by priority
- Identifies blocked issues
- Progress tracking
- Recommended next actions
- Time: ~30 seconds

**`/nix-help`** - This help (you are here!)

## ⚡ Common Workflows

### Daily Development
```bash
/check_tasks                          # Morning check
/new_task "Add feature"               # Start work
/nix-module                           # Create module
/nix-deploy                           # Deploy
/review                               # Review
git commit && gh pr create            # Commit
/check_tasks                          # Verify
```
**Total: ~10 minutes**

### Quick Fix
```bash
# Edit file
/nix-fix                              # Fix patterns
/nix-deploy                           # Fast deploy
Fast deploy to p620
```
**Total: ~3 minutes**

### Security Audit
```bash
/nix-security                         # Run audit
# Review and fix issues
/nix-security                         # Verify
```
**Total: ~5 minutes**

### Performance Optimization
```bash
/nix-optimize                         # Analyze
# Apply suggested fixes
/nix-deploy                           # Deploy
Deploy to p620
```
**Total: ~10 minutes**

## 📊 Time Savings

**Traditional Approach:**
- Module creation: 30-60 minutes
- Code review: 15-30 minutes
- Security audit: 30-60 minutes
- Deployment: 10-20 minutes
- **Total: 85-170 minutes**

**With Slash Commands:**
- Module creation: 2 minutes
- Code review: 1 minute
- Security audit: 1 minute
- Deployment: 2.5 minutes
- **Total: 6.5 minutes**

**Time Saved: 92-96% reduction**

## 🎯 Command Selection Guide

**Choose command based on task:**

| Task | Command | Time |
|------|---------|------|
| Create new module | `/nix-module` | 2min |
| Fix code issues | `/nix-fix` | 1min |
| Review code | `/review` | 1min |
| Security check | `/nix-security` | 1min |
| Deploy changes | `/nix-deploy` | 2.5min |
| Optimize performance | `/nix-optimize` | 2min |
| Create issue | `/new_task` | 2min |
| Check tasks | `/check_tasks` | 30s |

## 🔧 Just Commands (Shell)

Complement slash commands with Just commands:

```bash
just check-syntax                     # Syntax validation (5s)
just validate-quick                   # Quick validation (30s)
just test-host HOST                   # Build test (60s)
just quick-deploy HOST                # Smart deploy (varies)
just validate                         # Full validation (2min)
```

## 💡 Pro Tips

1. **Start with /check_tasks** every morning
2. **Use /nix-module** for all new modules
3. **Run /nix-fix** before every commit
4. **Use /review** for all code reviews
5. **Deploy with /nix-deploy** (it's smarter)
6. **Run /nix-security** weekly
7. **Use /nix-optimize** monthly
8. **Track everything with /new_task**

## 📚 Documentation References

All commands automatically reference:
- **docs/PATTERNS.md** - Best practices
- **docs/NIXOS-ANTI-PATTERNS.md** - What to avoid
- **.claude/CLAUDE.md** - Project context
- **docs/GITHUB-WORKFLOW.md** - Complete workflow

## 🚨 Emergency Commands

**Quick fixes:**
```bash
/nix-fix                              # Auto-fix patterns
/nix-deploy                           # Emergency deploy
Emergency deploy to HOST
```

**Rollback:**
```bash
sudo nixos-rebuild switch --rollback
```

## 🎓 Learning Path

1. **Start**: Use `/nix-help` (you are here!)
2. **Daily**: Use `/check_tasks` and `/nix-deploy`
3. **Weekly**: Run `/nix-security`
4. **Monthly**: Run `/nix-optimize`
5. **Master**: Chain commands for complete workflows

## 📖 More Help

- **Full guide**: See .claude/CLAUDE.md
- **Workflows**: See docs/GITHUB-WORKFLOW.md
- **Patterns**: See docs/PATTERNS.md
- **Anti-patterns**: See docs/NIXOS-ANTI-PATTERNS.md

---

**Need specific help?** Just ask!
- "How do I create a new module?"
- "What's the fastest way to deploy?"
- "How do I fix security issues?"
- "Show me the complete workflow"

Claude Code will guide you through any task! 🚀
