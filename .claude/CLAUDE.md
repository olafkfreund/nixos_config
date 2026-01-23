# MANDATORY: PARR Protocol

**For EVERY task, you MUST use this structure:**

| Phase | Output Required |
|-------|-----------------|
| 🎯 **PLAN** | Goal, steps with checkpoints, approach, assumptions, risks |
| ⚡ **ACT** | Execute ONE step, show output, verify checkpoint |
| 🔍 **REFLECT** | Result, expected vs actual, side effects, plan validity |
| 🔄 **REVISE** | (If needed) Issue, root cause, options, decision |
| ✅ **COMPLETE** | Summary, files changed, follow-up needed |

**Rules:** Never skip PLAN. Never chain commands without REFLECT. Stop if unexpected. Ask after 2 failures.

---

# NixOS Infrastructure Hub - Claude Code Guide

> **Fast, Easy, Reliable NixOS Development with Claude Code**

## Quick Overview

This is a sophisticated multi-host NixOS configuration managing 4 active hosts (P620, Razer, P510, Samsung) with
141+ modular components, template-based architecture achieving 95% code deduplication, and comprehensive automation
through slash commands, agents, and skills.

**Key Stats:**

- 4 Active Hosts (workstation, server, 2 laptops)
- 141+ Modules (feature-based architecture)
- 95% Code Deduplication (template system)
- Zero Anti-Patterns (best practices implementation)

## 🚀 Getting Started

### Your Development Tools

**Commands** - Use `/nix-help` for full reference:

```bash
/nix-help                 # Complete command reference
/nix-module               # Create new module (2min)
/nix-deploy               # Smart deployment (2.5min)
/nix-fix                  # Auto-fix anti-patterns (1min)
/nix-security             # Security audit (1min)
/nix-optimize             # Performance analysis (2min)
/nix-review               # Code review (1min)
```

**Workflows** - Complete guided processes:

```bash
/nix-workflow-feature     # Feature development (5-10min)
/nix-workflow-bugfix      # Bug fix (2-5min)
/nix-workflow-security    # Security audit (3-5min)
```

**GitHub Integration**:

```bash
/nix-new-task             # Create GitHub issue (2min)
/nix-check-tasks          # Review open tasks (30s)
```

**Full command list**: `/nix-help`

## 🤖 Agents & Skills

### Agents (Automatic Activation)

**System Agents** (`.claude/agents/`):

- **config-drift-detective** - Configuration drift detection and state enforcement (NEW)
- **deployment-coordinator** - Intelligent multi-host deployment orchestration (NEW)
- **documentation-sync** - Automated documentation generation and sync (NEW)
- **issue-checker** - GitHub issue analysis and task tracking
- **local-logs** - System log parsing and analysis
- **module-refactor** - Intelligent code refactoring and anti-pattern detection (NEW)
- **nix-check** - Configuration validation and testing
- **package-resolver** - Automatic package conflict resolution (NEW)
- **performance-analyzer** - Build time and evaluation profiling (NEW)
- **security-patrol** - Proactive security monitoring and hardening (NEW)
- **test-generator** - Automatic test suite creation and coverage analysis (NEW)
- **update** - Package update management and review

**Built-in Agents (Claude Code Provides 60+ Agents)**:

Only the most relevant agents for NixOS development are listed below. Claude Code includes 60+ built-in agents, but
most are for other domains (sales, gaming, mobile apps, etc.) and can be ignored.

**NixOS & Infrastructure** (Highly Relevant):

- **nixos-pro** - NixOS modules, packages, best practices
- **devops-troubleshooter** - Infrastructure debugging and automation
- **deployment-engineer** - Deployment strategies and CI/CD
- **cloud-architect** - Cloud infrastructure design
- **network-engineer** - Network configuration and troubleshooting

**Development Languages** (Relevant for Your Stack):

- **rust-pro** - Rust development (you have Rust modules)
- **python-pro** - Python development (scripts and tools)
- **golang-pro** - Go development (if used)
- **javascript-pro** - JavaScript development (frontend)
- **typescript-pro** - TypeScript development (frontend)

**Code Quality & Security** (Highly Relevant):

- **code-reviewer** - Code review against best practices
- **security-auditor** - Security vulnerability detection
- **debugger** - Error analysis and debugging
- **performance-engineer** - Performance optimization and profiling
- **test-automator** - Test suite creation and coverage

**Documentation** (Relevant):

- **docs-architect** - Technical documentation creation
- **mermaid-expert** - Diagram creation for documentation
- **reference-builder** - API and configuration references

**Plugins**:

- **code-simplifier:code-simplifier** - Code duplication analysis and refactoring

**Note**: Claude Code includes 40+ other built-in agents (sales-automator, minecraft-bukkit-pro, ios-developer, etc.)
that are irrelevant for NixOS development. They cannot be uninstalled but can be safely ignored.

Agents trigger automatically based on your request. See `/nix-help agents` for details.

### Skills (Automatic Knowledge)

**NixOS Tools** (`.claude/skills/`):

- **agenix** - Secret management
- **home-manager** - User environments
- **devenv** - Development setup

**Package Tools**:

- **cargo2nix**, **node2nix**, **uv2nix** - Language package integration

**Desktop**:

- **gnome**, **cosmic-de**, **stylix** - Desktop environments and theming

Skills activate when you mention the technology. See `/nix-help skills` for details.

## 🏗️ Project Architecture

### Critical Patterns (REQUIRED)

#### 1. Module Creation (REQUIRED)

All services MUST be in `modules/` directory:

```nix
# All services MUST be in modules/ directory
modules/
├── services/
│   └── myservice.nix    # Feature-based module
└── default.nix          # Explicit imports

# Enable via feature flags in host config
features.myservice.enable = true;
```

**Use `/nix-module` to create modules automatically with best practices.**

#### 2. Security Hardening (REQUIRED)

All services MUST use systemd hardening:

```nix
systemd.services.myservice = {
  serviceConfig = {
    DynamicUser = true;           # REQUIRED - No root services
    ProtectSystem = "strict";     # REQUIRED - Read-only system
    NoNewPrivileges = true;       # REQUIRED - No privilege escalation
    ProtectHome = true;           # REQUIRED - Protect user directories
  };
};
```

**Use `/nix-fix` to automatically add missing hardening.**

#### 3. Secret Management (REQUIRED)

Secrets MUST use runtime loading only:

```nix
# ❌ WRONG - Evaluation time (secrets in Nix store!)
password = builtins.readFile "/secrets/pass";

# ✅ CORRECT - Runtime loading (secure)
passwordFile = config.age.secrets.password.path;
```

**Use `/nix-fix` to automatically fix secret handling.**

## 🎯 Best Practices

### DO ✅

1. **Use Slash Commands** - Faster and more reliable than manual processes
2. **Read Documentation First** - Check docs/PATTERNS.md before coding
3. **Security First** - Always use DynamicUser for services
4. **Test Locally** - Validate before deploying (`just validate`)
5. **Track Issues** - Use GitHub workflow (`/nix-new-task`, `/nix-check-tasks`)
6. **Review Code** - Always run `/nix-review` before committing
7. **Use Workflows** - `/nix-workflow-*` for complete processes
8. **Follow Patterns** - Check docs/NIXOS-ANTI-PATTERNS.md

### DON'T ❌

1. **Skip Validation** - Always validate before deploy
2. **Commit Directly** - Use issue-driven workflow
3. **Root Services** - Always use DynamicUser
4. **Evaluation Secrets** - Use runtime loading only
5. **Manual Fixes** - Use `/nix-fix` for anti-patterns
6. **Skip Security** - Run `/nix-security` regularly
7. **Ignore Warnings** - Address all issues promptly
8. **Create Modules Manually** - Use `/nix-module`

## 📚 Essential Documentation

**Always Read Before Coding:**

- **docs/PATTERNS.md** - NixOS best practices and patterns
- **docs/NIXOS-ANTI-PATTERNS.md** - Critical anti-patterns to avoid

**When to Read:**

**Before Creating Modules:**

```text
"Read docs/PATTERNS.md Module System Patterns section,
then create a new monitoring module"
```

**Before Writing Packages:**

```text
"Check docs/PATTERNS.md Package Writing Patterns,
then create package derivation for myapp"
```

**Before Code Review:**

```text
"Review this code against docs/NIXOS-ANTI-PATTERNS.md
and docs/PATTERNS.md"
```

## 🔗 Quick Links

### Help & Commands

- **Full Command Reference**: `/nix-help`
- **Agents Documentation**: `/nix-help agents`
- **Skills Documentation**: `/nix-help skills`
- **Workflow Guide**: `/nix-help workflows`
- **Pro Tips**: `/nix-help tips`
- **Emergency Procedures**: `/nix-help emergency`

### Documentation

- **Patterns Guide**: docs/PATTERNS.md
- **Anti-Patterns**: docs/NIXOS-ANTI-PATTERNS.md
- **GitHub Workflow**: docs/GITHUB-WORKFLOW.md
- **Main README**: README.md (in CLAUDE.md)

### Quick Validation

```bash
just check-syntax         # Syntax validation (5s)
just validate-quick       # Quick validation (30s)
just test-host HOST       # Build test (60s)
just validate             # Full validation (2min)
```

## 🚨 Emergency Quick Reference

```bash
# Quick fix
/nix-fix                  # Auto-fix anti-patterns
/nix-deploy               # Emergency deploy
Emergency deploy to HOST

# Rollback
sudo nixos-rebuild switch --rollback

# Debug
journalctl -u SERVICE -f  # Follow logs
systemctl status SERVICE  # Check status
just validate            # Full validation
```

**Full emergency guide**: `/nix-help emergency`

## 💡 Pro Tips

1. **Start with `/nix-check-tasks`** every morning
2. **Use `/nix-workflow-*`** for complete guided processes
3. **Run `/nix-fix`** before every commit
4. **Deploy with `/nix-deploy`** (smarter than manual)
5. **Review with `/nix-review`** (automated quality checks)
6. **Weekly `/nix-security`** for security audits
7. **Monthly `/nix-optimize`** for performance tuning

**Full tips list**: `/nix-help tips`

## 📊 Infrastructure Details

### Active Hosts

- **P620**: AMD workstation (primary development, monitoring server)
- **P510**: Intel Xeon server (media server, headless)
- **Razer**: Intel/NVIDIA laptop (mobile development)
- **Samsung**: Intel laptop (mobile)

### Template Architecture

- **workstation.nix** - Full desktop development (P620)
- **laptop.nix** - Mobile-optimized (Razer, Samsung)
- **server.nix** - Headless server (P510)

### Code Deduplication

- **95% shared code** through template system
- **141+ modules** with feature flags
- **Zero anti-patterns** (best practices implementation)
- **Explicit imports only** (no magic auto-discovery)

---

**Remember**: Claude Code is optimized for speed, ease, and reliability. Use `/nix-help` for complete documentation and
`/nix-workflow-*` commands for guided processes!

**Need help?** Just ask:

- "How do I create a new module?"
- "What's the fastest way to deploy?"
- "How do I fix security issues?"
- "Show me the complete workflow"

Claude Code will guide you through any task! 🚀
