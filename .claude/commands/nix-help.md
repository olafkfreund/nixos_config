# NixOS Commands Help

Quick reference for all available NixOS development commands.

## 🚀 Quick Commands (Most Used)

```bash
/nix-deploy          # Smart deployment with validation
/nix-module          # Create new module with best practices
/nix-fix             # Auto-fix anti-patterns
/nix-security        # Security audit
/nix-review          # Code review
```

## 📋 All Available Commands

### Validation & Testing (NEW!)

**`/nix-validate`** - Validation suite (NEW!)

- Syntax validation (nix flake check)
- Feature dependency validation
- Security configuration checks
- Code quality validation
- Modes: quick (30s), standard (1min), full (2min)
- Replaces: validate, validate-quick, check-syntax, and 7 more recipes
- Time: 30s (quick) to 2min (full)

**`/nix-test`** - Testing suite (NEW!)

- Build testing for single or all hosts
- Home Manager configuration testing
- Secret access verification
- Module structure testing
- Modes: single-host, all-hosts, parallel, ci
- Replaces: test-all, test-all-parallel, and 13 more recipes
- Time: 60s (single) to 2min (parallel)

### Cleanup & Maintenance (NEW!)

**`/nix-clean`** - Cleanup operations (NEW!)

- Garbage collection (standard, aggressive)
- Store optimization (deduplication)
- Dead code removal
- Generation management
- Modes: standard (30s), aggressive (2min), full (5min)
- Replaces: gc, gc-aggressive, optimize, and 3 more recipes
- Time: 30s (standard) to 5min (full)

### System Information (NEW!)

**`/nix-info`** - System information (NEW!)

- System status and health check
- Full infrastructure summary
- Configuration analysis
- Generation history
- Modes: status (5s), summary (15s), analysis (30s)
- Replaces: status, history, info, and 5 more recipes
- Time: 5s (status) to 30s (analysis)

### Specialized Operations (NEW!)

**`/nix-precommit`** - Pre-commit hook management (NEW!)

- Install/update pre-commit hooks
- Run all hooks or staged files only
- Format, lint, and validate code
- Hooks: nixpkgs-fmt, statix, deadnix, shfmt, shellcheck, prettier, markdownlint
- Modes: install, run-all, run-staged, update, clean
- Replaces: pre-commit-install, pre-commit-run, pre-commit-staged, and 3 more recipes
- Time: 5s (install) to 30s (run-all)

**`/nix-live`** - Live USB installer management (NEW!)

- Build host-specific live USB images
- Show USB devices for flashing
- Flash ISO to USB drive
- Clean build artifacts
- Features: Hardware auto-detection, TUI installer, SSH access
- Replaces: build-all-live, show-devices, flash operations, clean-live, live-help
- Time: 10min (build) to 5min (flash)

**`/nix-microvm`** - MicroVM development environments (NEW!)

- Manage 3 VMs: dev-vm, test-vm, playground-vm
- List, start, stop, SSH, restart VMs
- Each VM: 8GB RAM, 4 CPU cores, persistent storage
- SSH ports: 2222 (dev), 2223 (test), 2224 (playground)
- Features: Full dev stack, testing sandbox, experimental tools
- Replaces: list-microvms, stop-all-microvms, clean-microvms, test-all-microvms, microvm-help
- Time: 30s (start) to 5s (list)

**`/nix-secrets`** - Secrets management (NEW!)

- Create, edit, list, rekey encrypted secrets
- Test secret decryption and runtime access
- Check secrets on remote hosts
- Fix agenix issues remotely
- Features: Age encryption, SSH key-based access, runtime loading
- Replaces: secrets, secrets-status, test-secrets, test-all-secrets, secrets-status-host, fix-agenix-remote
- Time: 5s (status) to 1min (rekey)

**`/nix-network`** - Network monitoring and diagnostics (NEW!)

- Monitor network continuously with logging
- Check network stability and DNS
- Ping all infrastructure hosts
- Show comprehensive host status
- Features: Interface monitoring, DNS recovery, auto-stabilization
- Replaces: network-monitor, network-check, ping-hosts, status-all
- Time: instant (ping) to continuous (monitor)

### Module Development

**`/nix-module`** - Create new NixOS module

- Automatically follows best practices
- Includes security hardening
- Validates syntax and patterns
- Provides usage examples
- Time: ~2 minutes

### Code Quality & Review

**`/nix-fix`** - Fix anti-patterns automatically (ENHANCED!)

- Detects and fixes mkIf true patterns
- Removes trivial wrappers
- Fixes secret handling issues
- Hardens service security
- **NEW: Format-only mode** - nixpkgs-fmt, shfmt, prettier (15s)
- **NEW: Lint-only mode** - statix, deadnix, shellcheck, markdownlint (20s)
- **NEW: Format + Lint** - comprehensive code quality (45s)
- Modes: anti-pattern fix, format, lint, format+lint, comprehensive
- Shows before/after diffs
- Time: ~1 minute (anti-patterns), ~15s (format), ~20s (lint), ~45s (comprehensive)

**`/nix-review`** - Comprehensive code review

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

**`/nix-deploy`** - Smart deployment workflow (ENHANCED!)

- Automatic validation
- Change detection (skips if no changes)
- Security checks
- Smart rollback on failure
- Post-deployment verification
- **NEW: Update operations** - system updates, flake updates, preview updates, guided workflows
- Modes: standard, fast, emergency, all-hosts, update, preview
- Time: ~2.5 minutes (standard), ~1 minute (fast), ~3 minutes (update workflow)

### Optimization

**`/nix-optimize`** - Performance analysis (ENHANCED!)

- Build performance analysis
- Disk usage optimization
- Memory tuning recommendations
- Network optimization
- Boot performance analysis
- **NEW: Performance testing** - build times, memory usage, evaluation speed, cache efficiency
- **NEW: Efficiency reports** - code duplication, feature flag usage, configuration metrics
- Modes: full test, build-times, memory, eval, parallel, cache, efficiency report
- Generates specific fixes with impact estimates
- Time: ~2 minutes (quick), ~10 minutes (full performance test)

### GitHub Integration

**`/nix-new-task`** - Create GitHub issue

- Guides through issue creation
- Conducts technical research
- Creates formatted issue with labels
- Generates implementation plan
- Provides branch name
- Time: ~2 minutes

**`/nix-check-tasks`** - Review open issues

- Shows all open tasks
- Categorizes by priority
- Identifies blocked issues
- Progress tracking
- Recommended next actions
- Time: ~30 seconds

**`/nix-help`** - This help (you are here!)

## 🔄 Complete Workflows

Use workflow commands for guided multi-step processes:

**`/nix-workflow-feature`** - Feature development (5-10 minutes)

- Create GitHub issue with research
- Create module following best practices
- Deploy and verify
- Code review and PR creation
- Complete tracking

**`/nix-workflow-bugfix`** - Bug fix (2-5 minutes)

- Identify or create issue
- Auto-fix anti-patterns
- Fast deployment
- Verify fix works
- Commit and PR

**`/nix-workflow-security`** - Security audit (3-5 minutes)

- Run comprehensive security audit
- Review findings and score
- Apply auto-fixes
- Validate improvements
- Deploy hardening changes

**Quick Examples:**

### Daily Development

```bash
/nix-workflow-feature               # Full guided workflow
# Or manual steps:
/nix-check-tasks                    # Morning check
/nix-new-task "Add feature"         # Start work
/nix-module                         # Create module
/nix-deploy                         # Deploy
/nix-review                         # Review
git commit && gh pr create          # Commit
/nix-check-tasks                    # Verify
```

### Total: ~10 minutes

### Quick Fix

```bash
/nix-workflow-bugfix                # Full guided workflow
# Or manual steps:
# Edit file
/nix-fix                            # Fix patterns
/nix-deploy                         # Fast deploy
Fast deploy to p620
```

### Total: ~3 minutes

### Security Audit

```bash
/nix-workflow-security              # Full guided workflow
# Or manual steps:
/nix-security                       # Run audit
# Review and fix issues
/nix-security                       # Verify
```

### Total: ~5 minutes

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

### Time Saved: 92-96% reduction

## 🎯 Command Selection Guide

**Choose command based on task:**

| Task                     | Command            | Time               |
| ------------------------ | ------------------ | ------------------ |
| Validate configuration   | `/nix-validate`    | 30s-2min           |
| Test builds              | `/nix-test`        | 1-2min             |
| Clean up disk            | `/nix-clean`       | 30s-5min           |
| Check system info        | `/nix-info`        | 5-30s              |
| Manage pre-commit hooks  | `/nix-precommit`   | 5-30s              |
| Build live USB installer | `/nix-live`        | 5-10min            |
| Manage MicroVMs          | `/nix-microvm`     | 5-30s              |
| Manage secrets           | `/nix-secrets`     | 5s-1min            |
| Network diagnostics      | `/nix-network`     | instant-continuous |
| Create new module        | `/nix-module`      | 2min               |
| Fix code issues          | `/nix-fix`         | 15s-1min           |
| Review code              | `/nix-review`      | 1min               |
| Security check           | `/nix-security`    | 1min               |
| Deploy changes           | `/nix-deploy`      | 1-3min             |
| Optimize performance     | `/nix-optimize`    | 2-10min            |
| Create issue             | `/nix-new-task`    | 2min               |
| Check tasks              | `/nix-check-tasks` | 30s                |

## 🔧 Just Commands (Shell)

Complement slash commands with Just commands:

```bash
just check-syntax                     # Syntax validation (5s)
just validate-quick                   # Quick validation (30s)
just test-host HOST                   # Build test (60s)
just quick-deploy HOST                # Smart deploy (varies)
just validate                         # Full validation (2min)
```

## 🤖 Available Agents

Claude Code automatically uses specialized agents for specific tasks.

**System Agents** (`.claude/agents/`):

- **issue-checker** - Analyzes GitHub issues and tracks progress
- **local-logs** - Parses system logs for debugging and error analysis
- **nix-check** - Validates NixOS configurations and detects issues
- **update** - Manages system and package updates

**Built-in Agents** (always available):

- **nixos-pro** - NixOS development, modules, packages, optimization, security
- **code-reviewer** - Comprehensive code review against best practices
- **debugger** - Error analysis, debugging, troubleshooting
- **security-auditor** - Security vulnerability detection and hardening

### When Agents Trigger

Agents activate automatically based on your request:

- Module creation → **nixos-pro**
- Code review → **code-reviewer**
- Log analysis → **local-logs**
- Security audit → **security-auditor**
- Issue tracking → **issue-checker**
- Package updates → **update**
- Configuration validation → **nix-check**

### Manual Agent Use

You can explicitly request an agent:

```text
"Use nixos-pro agent to create a monitoring module"
"Have the security-auditor review this configuration"
"Ask the debugger to analyze this error"
```

## 🎯 Available Skills

Skills provide specialized knowledge automatically when you mention the technology.

**NixOS Tools** (`.claude/skills/`):

- **nixcore** - Nix language, derivations, imports, options, module system best practices
- **agenix** - Age-encrypted secret management
- **home-manager** - User environment configuration and dotfiles
- **devenv** - Development environment setup and tooling

**Package Integration**:

- **cargo2nix** - Rust/Cargo package integration
- **node2nix** - Node.js/npm package integration
- **uv2nix** - Python uv package manager integration

**Desktop Environments**:

- **gnome** - GNOME desktop configuration patterns
- **cosmic-de** - System76 COSMIC desktop setup
- **stylix** - Unified theming and styling framework

**Development Tools**:

- **github** - Git and GitHub CLI (gh) integration, issue-driven development, PR workflows

### Using Skills

Skills activate automatically when you mention the technology:

```text
"Create NixOS module with proper options" → Uses nixcore skill
"Write package derivation for myapp"     → Uses nixcore skill
"Debug NixOS module evaluation error"    → Uses nixcore skill
"Configure agenix for API keys"          → Uses agenix skill
"Set up home-manager for new user"       → Uses home-manager skill
"Create cargo2nix derivation for myapp"  → Uses cargo2nix skill
"Apply stylix theme to all applications" → Uses stylix skill
"Create GitHub issue with gh CLI"        → Uses github skill
"Set up git hooks for NixOS validation"  → Uses github skill
```

## 💡 Pro Tips

1. **Chain Commands** - Use multiple slash commands in sequence for complete workflows
2. **Context Aware** - Slash commands automatically understand your codebase structure
3. **Automatic Research** - Commands read docs/PATTERNS.md and docs/NIXOS-ANTI-PATTERNS.md automatically
4. **Smart Defaults** - Commands choose best options based on context
5. **Start with /nix-check-tasks** - Every morning to see what needs attention
6. **Use /nix-module** - For all new modules (ensures best practices)
7. **Run /nix-fix** - Before every commit to catch anti-patterns
8. **Use /nix-review** - For all code reviews (automated quality checks)
9. **Deploy with /nix-deploy** - It's smarter than manual deployment
10. **Run /nix-security** - Weekly for security audits
11. **Use /nix-optimize** - Monthly for performance optimization
12. **Track everything with /nix-new-task** - GitHub-driven development
13. **Use workflow commands** - `/nix-workflow-*` for complete guided processes
14. **Learn from output** - Commands provide educational examples and explanations

## 📚 Documentation References

All commands automatically reference:

- **docs/PATTERNS.md** - Best practices
- **docs/NIXOS-ANTI-PATTERNS.md** - What to avoid
- **.claude/CLAUDE.md** - Project context
- **docs/GITHUB-WORKFLOW.md** - Complete workflow

## 🚨 Emergency Procedures

### Quick Fix

```bash
/nix-fix                              # Auto-fix anti-patterns
/nix-deploy                           # Emergency deploy
Emergency deploy to HOST
```

### Rollback Failed Deployment

```bash
# Automatic rollback (happens on failure)
# Or manual rollback:
sudo nixos-rebuild switch --rollback
```

### Debug Service Failures

```bash
# Check service status
systemctl status SERVICE

# Follow logs in real-time
journalctl -u SERVICE -f

# Recent error logs
journalctl -u SERVICE --since "10 minutes ago" -p err

# Full validation
just validate
```

### Fix Broken Configuration

```bash
# 1. Check syntax errors
just check-syntax

# 2. Validate configuration
just validate-quick

# 3. Test specific host
just test-host HOST

# 4. If all else fails, rollback
sudo nixos-rebuild switch --rollback
```

### Recover from Boot Failure

```bash
# Boot into previous generation from GRUB menu
# Then investigate:
journalctl -xb                        # Boot logs
systemd-analyze blame                 # Boot time analysis

# Fix and test
just test-host HOST
/nix-deploy
Deploy to HOST
```

### Emergency Contacts

- **Documentation**: docs/PATTERNS.md, docs/NIXOS-ANTI-PATTERNS.md
- **Validation**: `just validate`
- **Help**: `/nix-help`
- **Rollback**: Always available via GRUB or `nixos-rebuild`

## 🎓 Learning Path

1. **Start**: Use `/nix-help` (you are here!)
2. **Daily**: Use `/nix-check-tasks` and `/nix-deploy`
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
