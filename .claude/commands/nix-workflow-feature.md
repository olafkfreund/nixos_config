# Feature Development Workflow

Complete feature development cycle optimized for speed and quality.

**Estimated Time:** 5-10 minutes total

## Workflow Steps

### 1. Create GitHub Issue (2 minutes)

```bash
/new_task "Add Redis monitoring"
```

**What happens:**

- Guides through issue creation
- Conducts technical research
- Reviews PATTERNS.md and NIXOS-ANTI-PATTERNS.md
- Creates formatted GitHub issue with labels
- Generates implementation plan with acceptance criteria
- Provides branch name (e.g., `feature/45-redis-monitoring`)

### 2. Create Module (2 minutes)

```bash
/nix-module
Create monitoring/redis-exporter module
```

**What happens:**

- Creates module in correct location (`modules/services/` or `modules/monitoring/`)
- Follows NixOS best practices automatically
- Includes security hardening (DynamicUser, ProtectSystem)
- Validates syntax and patterns
- Provides usage examples

**Result:** Production-ready module following all best practices

### 3. Deploy Changes (2 minutes)

```bash
/nix-deploy
Deploy to p620
```

**What happens:**

- Validates configuration syntax
- Detects if configuration actually changed
- Runs security checks
- Deploys to specified host
- Verifies services started correctly
- Automatic rollback on failure

**Modes:**

- Standard: Full validation (2.5 min)
- Fast: Skip some checks (1 min)
- Emergency: Minimal checks (30s)

### 4. Code Review (1 minute)

```bash
/review
```

**What happens:**

- Checks against PATTERNS.md best practices
- Detects anti-patterns from NIXOS-ANTI-PATTERNS.md
- Security analysis (DynamicUser, secrets handling)
- Performance review
- Provides actionable fixes with code examples

**Result:** Quality score and specific improvements

### 5. Commit & Create PR (2 minutes)

```bash
git add .
git commit -m "feat(monitoring): add redis exporter (#45)

Implement comprehensive Redis monitoring with:
- prometheus_redis_exporter integration
- Custom Grafana dashboard
- Query performance tracking

Closes #45"

git push -u origin feature/45-redis-monitoring
gh pr create --fill
```

**Commit format:** Follow Conventional Commits

- `feat(scope):` for new features
- Link to issue number: `(#45)`
- Detailed body with bullet points
- Footer: `Closes #45`

### 6. Verify Completion (30 seconds)

```bash
/check_tasks
```

**What happens:**

- Shows all open tasks
- Confirms issue #45 is linked to PR
- Displays task progress
- Recommends next actions

## Time Breakdown

| Step          | Time        | Command                      |
| ------------- | ----------- | ---------------------------- |
| Create issue  | 2 min       | `/new_task`                  |
| Create module | 2 min       | `/nix-module`                |
| Deploy        | 2 min       | `/nix-deploy`                |
| Review        | 1 min       | `/review`                    |
| Commit & PR   | 2 min       | `git commit && gh pr create` |
| Verify        | 30 sec      | `/check_tasks`               |
| **TOTAL**     | **~10 min** | **Complete feature**         |

## Traditional Approach Comparison

**Without slash commands:**

- Module creation: 30-60 minutes (manual research, pattern following)
- Code review: 15-30 minutes (manual checklist)
- Deployment: 10-20 minutes (manual validation, testing)
- **Total: 55-110 minutes**

**With slash commands:**

- Module creation: 2 minutes (automated)
- Code review: 1 minute (automated)
- Deployment: 2 minutes (automated)
- **Total: ~10 minutes**

**Time saved: 82-91% reduction**

## Best Practices

### DO ✅

- Create issue before starting work (`/new_task`)
- Use `/nix-module` for module creation (ensures best practices)
- Run `/review` before committing
- Link PR to issue (`Closes #45`)
- Verify with `/check_tasks` after PR creation

### DON'T ❌

- Skip issue creation (tracking is important)
- Create modules manually (miss best practices)
- Skip code review (quality matters)
- Commit without testing deployment first
- Forget to link PR to issue

## Troubleshooting

### Module Creation Fails

```bash
# Check syntax first
just check-syntax

# Try with more specific path
/nix-module
Create module in modules/services/redis-exporter.nix
```

### Deployment Fails

```bash
# Validate configuration
just validate-quick

# Check specific host
just test-host p620

# Review error logs
journalctl -xe
```

### Code Review Finds Issues

```bash
# Auto-fix common anti-patterns
/nix-fix

# Review again
/review
```

## Next Steps

After PR is merged:

1. Deploy to production hosts
2. Monitor service status
3. Update documentation if needed
4. Close issue (auto-closes with PR merge)

## Related Workflows

- `/nix-workflow-bugfix` - Quick bug fixes (2-5 minutes)
- `/nix-workflow-security` - Security audits (3-5 minutes)
- `/nix-help workflows` - All available workflows

---

**Pro Tip:** Run this workflow 3-5 times to build muscle memory. After that, the entire process becomes automatic and completes in ~10 minutes for any feature.
