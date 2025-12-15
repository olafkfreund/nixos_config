# GitHub Workflow Best Practices

> Version: 1.0.0
> Last Updated: 2025-01-29
> Status: Active

## Overview

This document defines the complete GitHub-based development workflow for the NixOS Infrastructure Hub project. It follows **GitHub Flow** principles optimized for continuous delivery and rapid iteration while maintaining code quality and stability.

## Table of Contents

1. [Workflow Strategy](#workflow-strategy)
2. [Issue-Driven Development](#issue-driven-development)
3. [Branch Management](#branch-management)
4. [Pull Request Process](#pull-request-process)
5. [Code Review Standards](#code-review-standards)
6. [Testing and Validation](#testing-and-validation)
7. [Deployment Strategy](#deployment-strategy)
8. [Automation and Tools](#automation-and-tools)

---

## Workflow Strategy

### Why GitHub Flow?

**GitHub Flow** is chosen for this project because:

- ✅ **Simplicity**: Single main branch with feature branches
- ✅ **Continuous Delivery**: Deploy from main at any time
- ✅ **Fast Iteration**: Quick feedback loops
- ✅ **Collaboration**: Easy code review and discussion
- ✅ **NixOS Compatibility**: Atomic deployments align with NixOS generations

### Core Principles

1. **Main Branch is Always Deployable**
   - All code in `main` must pass all tests
   - All code in `main` must be production-ready
   - Deploy from `main` at any time with confidence

2. **Feature Branches for All Changes**
   - Every change starts with a GitHub issue
   - Every change happens in a dedicated branch
   - Branch names reference the issue number

3. **Pull Requests for Code Review**
   - All changes go through PR review
   - PRs must pass automated checks
   - PRs require approval before merge

4. **Automated Testing**
   - Every commit triggers validation
   - PRs must pass all checks
   - Deployment happens only after tests pass

5. **Issue Tracking**
   - All work starts with an issue
   - Issues provide context and discussion
   - PRs automatically close issues when merged

---

## Issue-Driven Development

### Philosophy

**"No code without an issue, no issue without a plan"**

Every code change, bug fix, or improvement must:

1. Start with a GitHub issue
2. Include research and planning
3. Have clear acceptance criteria
4. Follow the implementation checklist

### Creating Issues with `/nix-new-task`

Use the `/nix-new-task` Claude command to create well-structured issues:

```
User: "/nix-new-task"
```

The command will:

1. ✅ Guide you through issue creation
2. ✅ Conduct technical research if needed
3. ✅ Create formatted GitHub issue
4. ✅ Assign appropriate labels and priority
5. ✅ Provide next steps for implementation

### Issue Structure

Every issue should include:

```markdown
## Description

[What needs to be done and why]

## Research Summary

[Technical research findings and recommendations]

### Recommended Approach

- Step-by-step implementation plan

### Key Considerations

- Important points to remember

### References

- Links to documentation and examples

## Acceptance Criteria

- [ ] Testable criteria 1
- [ ] Testable criteria 2
- [ ] All tests pass
- [ ] Documentation updated

## Implementation Checklist

- [ ] Create feature branch
- [ ] Implement solution
- [ ] Write tests
- [ ] Update documentation
- [ ] Run validation
- [ ] Create PR
- [ ] Code review
- [ ] Merge

## Labels

type:feature, priority:high

## Estimated Effort

M (1 week)
```

### Issue Labels

#### Type Labels (Required)

- `type:feature` - New functionality
- `type:bug` - Bug fixes
- `type:enhancement` - Improvements to existing features
- `type:docs` - Documentation updates
- `type:refactor` - Code refactoring
- `type:chore` - Maintenance tasks

#### Priority Labels (Required)

- `priority:critical` - Urgent, blocks other work
- `priority:high` - Important, should be done soon
- `priority:medium` - Normal priority
- `priority:low` - Nice to have

#### Status Labels (Optional)

- `status:blocked` - Blocked by dependencies
- `status:in-progress` - Currently being worked on
- `status:needs-review` - Awaiting code review
- `needs-research` - Requires technical research
- `good-first-issue` - Good for beginners

### Checking Issues with `/nix-check-tasks`

Use the `/nix-check-tasks` Claude command to review open issues:

```
User: "/nix-check-tasks"
```

The command provides:

1. 📋 Summary of all open issues by priority
2. 🎯 Recommended next actions
3. ⏸️ Blocked issues requiring attention
4. 📊 Statistics and progress tracking

---

## Branch Management

### Branch Naming Convention

**Format**: `<type>/<issue-number>-<brief-description>`

#### Examples

```bash
# Feature branches
feature/123-postgres-monitoring
feature/145-loki-logging

# Bug fix branches
fix/67-p510-boot-delay
fix/89-grafana-dashboard-error

# Enhancement branches
enhancement/156-monitoring-dashboards
enhancement/178-ai-provider-fallback

# Documentation branches
docs/134-workflow-documentation
docs/201-api-documentation

# Refactoring branches
refactor/167-module-deduplication
refactor/189-secrets-management

# Maintenance branches
chore/199-dependency-updates
chore/203-cleanup-old-configs
```

### Creating Branches

#### Method 1: GitHub CLI (Recommended)

```bash
# Automatically create branch linked to issue
gh issue develop 123 --checkout

# This creates: feature/123-issue-title (based on issue type)
```

#### Method 2: Manual Creation

```bash
# Ensure you're on main and up to date
git checkout main
git pull origin main

# Create new branch
git checkout -b feature/123-postgres-monitoring
```

### Branch Lifecycle

```
main
 │
 ├─→ feature/123-description    [Create from issue]
 │    │
 │    ├─→ [Development work]    [Multiple commits]
 │    │
 │    ├─→ [Create PR]            [When ready]
 │    │
 │    ├─→ [Code review]          [Review and iterate]
 │    │
 │    └─→ [Merge to main]        [After approval]
 │
 └─→ [Delete branch]             [After merge]
```

### Branch Protection Rules

**Main Branch Protection**:

- ✅ Require pull request reviews before merging
- ✅ Require status checks to pass before merging
- ✅ Require branches to be up to date before merging
- ✅ Require conversation resolution before merging
- ❌ Do not allow force pushes
- ❌ Do not allow deletions

---

## Pull Request Process

### Creating Pull Requests

#### Step 1: Prepare for PR

```bash
# Ensure all changes are committed
git status

# Run local validation
just validate

# Test on relevant hosts
just test-host p620

# Push branch to remote
git push -u origin feature/123-postgres-monitoring
```

#### Step 2: Create PR with GitHub CLI

```bash
# Create PR with auto-filled title and body from commits
gh pr create --fill

# Or create with custom title and body
gh pr create \
  --title "feat(monitoring): add PostgreSQL monitoring (#123)" \
  --body "$(cat <<'EOF'
## Summary
Implements comprehensive PostgreSQL monitoring with prometheus_postgres_exporter.

## Changes
- Add PostgreSQL exporter module
- Create Grafana dashboard for PostgreSQL metrics
- Update monitoring configuration
- Add documentation

## Testing
- ✅ Validated with `just validate`
- ✅ Tested on p620 and dex5550
- ✅ All tests pass
- ✅ Grafana dashboard loads correctly

## Screenshots
[Dashboard screenshot]

## Documentation
- Updated docs/MONITORING.md
- Added PostgreSQL monitoring guide

Closes #123
EOF
)"
```

### PR Structure

Every PR should include:

```markdown
## Summary

Brief description of the changes and their purpose.

## Changes

- Bullet list of specific changes made
- Organized by category if needed

## Testing

- ✅ Validation checks passed
- ✅ Tested on specific hosts
- ✅ All tests pass
- ✅ Manual testing completed

## Screenshots (if applicable)

[Visual proof of changes]

## Documentation

- List of documentation updates
- Links to updated docs

## Related Issues

Closes #123
Relates to #45

## Checklist

- [ ] Code follows PATTERNS.md best practices
- [ ] No anti-patterns from NIXOS-ANTI-PATTERNS.md
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Validation passed
- [ ] Tested on affected hosts
```

### PR Title Format

Follow **Conventional Commits** specification:

```
<type>(<scope>): <description> (#issue)

Examples:
feat(monitoring): add PostgreSQL monitoring (#123)
fix(p510): resolve boot delay from fstrim service (#67)
docs(workflow): add GitHub workflow documentation (#145)
refactor(modules): eliminate code duplication (#167)
chore(deps): update flake inputs (#199)
```

**Types**:

- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation only
- `style` - Formatting, missing semicolons, etc.
- `refactor` - Code restructuring
- `perf` - Performance improvements
- `test` - Adding tests
- `chore` - Maintenance tasks

**Scopes** (examples):

- `monitoring` - Monitoring related changes
- `p620`, `p510`, etc. - Host-specific changes
- `modules` - Module system changes
- `docs` - Documentation changes
- `ci` - CI/CD changes

### PR Review Process

#### 1. Automated Checks

PRs must pass:

- ✅ Nix syntax validation
- ✅ Build tests for all affected hosts
- ✅ Code review checklist from NIXOS-ANTI-PATTERNS.md
- ✅ No breaking changes detected

#### 2. Human Review

All PRs require:

- ✅ At least one approval (can be self-reviewed for personal repo)
- ✅ All conversations resolved
- ✅ No requested changes outstanding

#### 3. Final Validation

Before merge:

- ✅ Branch is up to date with main
- ✅ All checks pass
- ✅ Documentation is updated
- ✅ Changelog is updated (if applicable)

### Merging Pull Requests

#### Merge Strategy

Use **Squash and Merge** for cleaner history:

```bash
# Via GitHub CLI
gh pr merge 45 --squash --delete-branch

# This will:
# 1. Squash all commits into one
# 2. Merge to main
# 3. Delete the feature branch
# 4. Close linked issues
```

#### Merge Commit Message

```
feat(monitoring): add PostgreSQL monitoring (#123)

Implements comprehensive PostgreSQL monitoring with:
- prometheus_postgres_exporter integration
- Custom Grafana dashboard with 15 panels
- Query performance tracking
- Connection pool monitoring
- Database size metrics

Testing:
- Validated on p620 and dex5550
- All dashboards loading correctly
- Metrics collection verified

Documentation:
- Updated docs/MONITORING.md
- Added PostgreSQL monitoring guide

Closes #123

Co-authored-by: Claude <noreply@anthropic.com>
```

---

## Code Review Standards

### Review Checklist

Use the `/nix-review` command for automated code review:

```
User: "/nix-review"
```

#### Manual Review Checklist

**Code Quality**:

- [ ] Follows PATTERNS.md best practices
- [ ] No anti-patterns from NIXOS-ANTI-PATTERNS.md
- [ ] Code is readable and well-structured
- [ ] No unnecessary complexity
- [ ] Proper error handling

**NixOS Specific**:

- [ ] No `mkIf condition true` patterns
- [ ] Explicit imports (no auto-discovery)
- [ ] Proper secret handling (runtime loading)
- [ ] Service hardening (DynamicUser, ProtectSystem)
- [ ] Correct dependency categorization

**Testing**:

- [ ] Validation passes (`just validate`)
- [ ] Host tests pass (`just test-host HOST`)
- [ ] Manual testing completed
- [ ] No regressions introduced

**Documentation**:

- [ ] Code is documented
- [ ] README/docs updated if needed
- [ ] Commit messages are clear
- [ ] PR description is comprehensive

**Security**:

- [ ] No secrets in code
- [ ] Proper access controls
- [ ] Services run with minimal privileges
- [ ] Firewall rules updated if needed

### Review Workflow

```
1. Author creates PR
   ↓
2. Automated checks run
   ↓
3. Reviewer assigned (or self-review)
   ↓
4. Review conducted
   ↓
5. Feedback provided
   ↓
6. Author addresses feedback
   ↓
7. Re-review if needed
   ↓
8. Approval granted
   ↓
9. PR merged
   ↓
10. Branch deleted
   ↓
11. Issue automatically closed
```

### Review Comments

Use GitHub's review features:

- **Comment**: Ask questions or request clarification
- **Request Changes**: Require modifications before merge
- **Approve**: Allow merge when ready
- **Suggest Changes**: Provide specific code suggestions

---

## Testing and Validation

### Pre-Commit Testing

Before committing:

```bash
# Check syntax
just check-syntax

# Validate configuration
just validate-quick

# Format code
just format
```

### Pre-PR Testing

Before creating PR:

```bash
# Full validation
just validate

# Test specific host
just test-host p620

# Test all hosts (parallel)
just test-all-parallel

# Performance test
just perf-test
```

### Automated CI/CD

GitHub Actions run on every PR:

```yaml
# Conceptual workflow
on: [pull_request]

jobs:
  validate:
    - Check Nix syntax
    - Run validation suite
    - Build all affected hosts
    - Run code review checks

  test:
    - Test each host configuration
    - Verify no regressions
    - Check for anti-patterns

  security:
    - Scan for secrets
    - Check service hardening
    - Verify firewall rules
```

### Testing Strategy

**Levels of Testing**:

1. **Syntax Level**: Nix expression syntax
2. **Build Level**: Configuration builds successfully
3. **Deploy Level**: Configuration deploys without errors
4. **Runtime Level**: Services start and function correctly
5. **Integration Level**: Services interact correctly

**Test Coverage**:

- ✅ All new features have tests
- ✅ Bug fixes include regression tests
- ✅ Configuration changes tested on affected hosts
- ✅ Documentation includes testing procedures

---

## Deployment Strategy

### Deployment Workflow

```
1. PR Merged to Main
   ↓
2. Automated build triggered
   ↓
3. Validation passes
   ↓
4. Deploy to target host(s)
   ↓
5. Verify deployment
   ↓
6. Monitor for issues
   ↓
7. Rollback if needed (NixOS generations)
```

### Deployment Commands

```bash
# Deploy to specific host (recommended)
just quick-deploy p620

# Deploy only if configuration changed
just quick-deploy p620  # Skips if no changes

# Deploy to all hosts in parallel
just deploy-all-parallel

# Emergency deployment (skip tests)
just emergency-deploy p620

# Rollback to previous generation
sudo nixos-rebuild switch --rollback
```

### Deployment Best Practices

1. **Test First**: Always test before deploying to production
2. **Incremental**: Deploy to one host first, verify, then others
3. **Monitor**: Watch logs and metrics after deployment
4. **Rollback Plan**: Know how to rollback quickly
5. **Communication**: Update issue with deployment status

### Post-Deployment Verification

```bash
# Check system status
systemctl status

# Verify critical services
systemctl status prometheus grafana

# Check for errors
journalctl -p err -b

# Verify monitoring
grafana-status
prometheus-status

# Test functionality
just validate
```

---

## Automation and Tools

### GitHub CLI Setup

Install and authenticate:

```bash
# Check if installed
which gh

# Authenticate (if needed)
gh auth login

# Verify authentication
gh auth status

# Check repository access
gh repo view
```

### Claude Commands

Use Claude's `/nix-new-task` and `/nix-check-tasks` commands:

```bash
# Create new task
"/nix-new-task"
# Guides through issue creation with research

# Check tasks
"/nix-check-tasks"
# Shows all open issues with priorities

# Review code
"/nix-review"
# Comprehensive code review based on PATTERNS.md
```

### Justfile Integration

The `Justfile` provides automation for common tasks:

```bash
# Validation
just validate          # Full validation
just validate-quick    # Quick validation
just check-syntax      # Syntax only

# Testing
just test-host HOST    # Test specific host
just test-all-parallel # Test all hosts in parallel

# Deployment
just quick-deploy HOST # Smart deployment
just deploy-all        # Deploy all hosts

# Maintenance
just format            # Format all Nix files
just clean             # Clean build artifacts
```

### Git Hooks

Pre-commit hooks ensure code quality:

```bash
# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files

# Bypass hooks (use sparingly)
git commit --no-verify
```

---

## Workflow Examples

### Example 1: Adding a New Feature

```bash
# 1. Create issue with research
/nix-new-task
# Type: feature
# Priority: high
# Description: Add PostgreSQL monitoring
# Research: yes

# 2. Issue created: #123

# 3. Create branch
gh issue develop 123 --checkout
# Branch: feature/123-postgres-monitoring

# 4. Implement feature
# ... make changes ...

# 5. Test locally
just validate
just test-host p620

# 6. Commit changes
git add .
git commit -m "feat(monitoring): add PostgreSQL monitoring (#123)"

# 7. Push and create PR
git push -u origin feature/123-postgres-monitoring
gh pr create --fill

# 8. Wait for review and approval

# 9. Merge PR
gh pr merge 123 --squash --delete-branch

# 10. Deploy
just quick-deploy p620

# 11. Verify
grafana-status
# Issue #123 automatically closed
```

### Example 2: Fixing a Bug

```bash
# 1. Check for existing issue
/nix-check-tasks
# Issue #67 exists: P510 boot delay

# 2. Create branch
gh issue develop 67 --checkout
# Branch: fix/67-p510-boot-delay

# 3. Debug and fix
# ... investigate and fix ...

# 4. Test fix
just test-host p510

# 5. Commit
git commit -m "fix(p510): resolve boot delay from fstrim service (#67)

Optimize fstrim service configuration to prevent 8+ minute
boot delays on P510 media server.

Fixes #67"

# 6. Push and create PR
git push -u origin fix/67-p510-boot-delay
gh pr create --fill

# 7. Self-review (if personal repo)
/nix-review

# 8. Merge
gh pr merge 67 --squash --delete-branch

# 9. Deploy and verify
just quick-deploy p510
# Reboot and verify boot time improved
```

### Example 3: Documentation Update

```bash
# 1. Create quick task
/nix-new-task
# Type: docs
# Priority: medium
# Description: Document GitHub workflow
# Research: yes (for best practices)

# 2. Create branch
git checkout -b docs/145-github-workflow

# 3. Write documentation
# ... create GITHUB-WORKFLOW.md ...

# 4. Commit
git commit -m "docs(workflow): add comprehensive GitHub workflow guide (#145)"

# 5. PR and merge
git push -u origin docs/145-github-workflow
gh pr create --fill
gh pr merge 145 --squash --delete-branch
```

---

## Best Practices Summary

### Do's ✅

- ✅ Create an issue for every change
- ✅ Use descriptive branch names with issue numbers
- ✅ Write clear commit messages following Conventional Commits
- ✅ Test locally before creating PR
- ✅ Include comprehensive PR descriptions
- ✅ Request reviews (or self-review thoroughly)
- ✅ Update documentation with code changes
- ✅ Use `/nix-new-task` and `/nix-check-tasks` commands
- ✅ Follow PATTERNS.md best practices
- ✅ Avoid anti-patterns from NIXOS-ANTI-PATTERNS.md
- ✅ Delete branches after merging
- ✅ Monitor deployments after merge

### Don'ts ❌

- ❌ Commit directly to main
- ❌ Create PRs without linked issues
- ❌ Merge without testing
- ❌ Leave PRs open for extended periods
- ❌ Force push to main
- ❌ Skip code review
- ❌ Deploy without validation
- ❌ Ignore automated check failures
- ❌ Leave branches undeleted after merge
- ❌ Forget to update documentation

---

## Troubleshooting

### Common Issues

**Issue**: GitHub CLI not authenticated

```bash
Solution:
gh auth login
# Follow prompts
```

**Issue**: PR checks failing

```bash
Solution:
just validate          # Check what's failing
just format            # Fix formatting
just check-syntax      # Fix syntax errors
```

**Issue**: Merge conflicts

```bash
Solution:
git checkout main
git pull
git checkout feature/123-description
git merge main         # Resolve conflicts
git push
```

**Issue**: Can't create branch from issue

```bash
Solution:
# Manual creation
git checkout -b feature/123-description
```

**Issue**: Issue not closing automatically

```bash
Solution:
# Ensure PR body includes:
Closes #123
# Or manually close:
gh issue close 123
```

---

## Resources

### Documentation

- [PATTERNS.md](./PATTERNS.md) - NixOS best practices
- [NIXOS-ANTI-PATTERNS.md](./NIXOS-ANTI-PATTERNS.md) - Anti-patterns to avoid
- [CLAUDE.md](../CLAUDE.md) - Project configuration

### External Resources

- [GitHub Flow Guide](https://docs.github.com/en/get-started/quickstart/github-flow)
- [GitHub CLI Manual](https://cli.github.com/manual/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)

### Commands Reference

```bash
# Issue Management
gh issue create                    # Create issue
gh issue list                      # List issues
gh issue view <number>             # View issue
gh issue develop <number>          # Create branch from issue

# PR Management
gh pr create                       # Create PR
gh pr list                         # List PRs
gh pr view <number>                # View PR
gh pr merge <number>               # Merge PR

# Claude Commands
/nix-new-task                          # Create new task
/nix-check-tasks                       # Check open tasks
/nix-review                            # Code review

# Justfile Commands
just validate                      # Validate configuration
just test-host HOST                # Test host
just quick-deploy HOST             # Smart deploy
just format                        # Format code
```

---

## Changelog

### Version 1.0.0 (2025-01-29)

- Initial GitHub workflow documentation
- Defined GitHub Flow strategy
- Created `/nix-new-task` and `/nix-check-tasks` commands
- Integrated with existing NixOS patterns
- Added comprehensive examples and troubleshooting

---

**Remember**: Good workflow practices make development faster, safer, and more enjoyable. When in doubt, create an issue, make a branch, and submit a PR! 🚀
