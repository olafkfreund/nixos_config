---
description: Check open GitHub issues and track task progress
globs:
alwaysApply: false
version: 1.0
encoding: UTF-8
---

# Check Tasks Command

Review open GitHub issues, track progress, and identify priority work items.

## Process

### Step 1: Fetch Open Issues

Use `gh` CLI to retrieve open issues:

```bash
# Get all open issues
gh issue list --state open

# Get issues by label
gh issue list --label "priority:high" --state open
gh issue list --label "type:bug" --state open

# Get assigned issues
gh issue list --assignee "@me" --state open

# Get detailed view of specific issue
gh issue view <issue-number>
```

### Step 2: Categorize and Display Issues

Organize issues into categories and display with formatted output:

```markdown
## 📋 Open Tasks Summary

### 🔴 Critical Priority (Priority: critical)

**Issue #123**: [type] Title

- **Status**: Open | In Progress | Blocked
- **Branch**: feature/123-description (if created)
- **Assignee**: @username
- **Created**: 2 days ago
- **Labels**: priority:critical, type:feature
- **URL**: [Link to issue]

**Progress**:

- [x] Research completed
- [x] Implementation started
- [ ] Testing
- [ ] Documentation

---

### 🟠 High Priority (Priority: high)

[Same format as critical]

---

### 🟡 Medium Priority (Priority: medium)

[Same format]

---

### 🟢 Low Priority (Priority: low)

[Same format]

---

### ⏸️ Blocked Issues

**Issue #456**: [type] Title

- **Blocked By**: Issue #123, Missing dependency
- **Reason**: Waiting for upstream fix
- **Action**: [What needs to happen to unblock]

---

## 📊 Statistics

- **Total Open Issues**: 12
- **Critical**: 2
- **High**: 5
- **Medium**: 3
- **Low**: 2
- **Blocked**: 1
- **In Progress**: 4
- **Needs Research**: 2

## 🎯 Recommended Next Actions

1. **Focus on Critical**: Issue #123 needs immediate attention
2. **Unblock Work**: Issue #456 waiting on dependency
3. **Quick Wins**: Issues #789, #790 are low-effort, high-impact

## 🔄 Recent Activity

- Issue #123 updated 2 hours ago
- Issue #456 blocked 1 day ago
- Issue #789 created 3 days ago
```

### Step 3: Check Branch Status for Issues

For issues with associated branches, check their status:

```bash
# List branches related to issues
gh issue develop --list <issue-number>

# Check if PR exists for branch
gh pr list --head <branch-name>

# Get PR status if exists
gh pr view <pr-number>
```

### Step 4: Identify Stale or Stuck Work

Look for issues that may need attention:

**Criteria for Flagging**:

- Open for > 30 days with no updates
- Marked "in progress" but no commits in > 7 days
- Has open PR with no reviews
- Blocked status with no resolution plan

### Step 5: Generate Action Plan

Based on the review, suggest concrete next steps:

```markdown
## 🎯 Recommended Work Plan

### This Week

1. **Issue #123** (Critical) - Complete testing and deploy
   - Estimated: 4 hours remaining
   - Action: Run full test suite and validation
   - Command: `just validate && just test-host p620`

2. **Issue #456** (High) - Unblock and start implementation
   - Estimated: 8 hours
   - Action: Review dependency status, create workaround if needed
   - Research: Check upstream repository for updates

### This Month

3. **Issue #789** (Medium) - Documentation improvements
   - Estimated: 2 hours
   - Action: Quick wins, low complexity
   - Start: After critical issues resolved

## 🚧 Blockers to Address

- **Issue #456**: Dependency on external library update
  - **Resolution**: Contact maintainer or implement alternative
  - **Timeline**: Waiting 1 week, then implement workaround

## 📈 Progress Tracking

Track overall project health and velocity:

- **Issues Closed This Week**: 3
- **Issues Opened This Week**: 2
- **Average Time to Close**: 5 days
- **Oldest Open Issue**: 45 days (Issue #321)
```

## Advanced Filtering Options

### Filter by Multiple Criteria

```bash
# High priority bugs
gh issue list --label "priority:high" --label "type:bug" --state open

# Features needing research
gh issue list --label "type:feature" --label "needs-research" --state open

# My assigned critical issues
gh issue list --assignee "@me" --label "priority:critical" --state open

# Search by text
gh issue list --search "monitoring" --state open

# Recently updated
gh issue list --state open --json number,title,updatedAt --jq 'sort_by(.updatedAt) | reverse | .[:5]'
```

### Custom JSON Queries

For detailed analysis:

```bash
# Get full issue details in JSON
gh issue list --state open --json number,title,labels,assignees,createdAt,updatedAt,state --limit 100

# Parse with jq for custom reporting
gh issue list --state open --json number,title,labels \
  --jq '.[] | select(.labels[].name | contains("priority:critical")) | {number, title}'
```

## Integration with Development Workflow

### Before Starting Work

```markdown
## Pre-Work Checklist

Run `/check_tasks` to:

1. ✅ Identify highest priority open issues
2. ✅ Check if any issues are blocked
3. ✅ Ensure no critical issues are waiting
4. ✅ Review recent issue activity
5. ✅ Confirm branch naming is correct

## Questions to Answer

- Are there any critical issues that need immediate attention?
- Is the issue I want to work on blocked by anything?
- Has someone else already started a branch for this issue?
- Are there newer, higher-priority issues than what I planned?
```

### During Work

```markdown
## Progress Tracking

Periodically run `/check_tasks` to:

- Monitor if new critical issues were created
- Check if blockers were resolved
- Update issue checklists with progress
- Identify if priorities have changed
```

### End of Day/Week

```markdown
## Review Session

Use `/check_tasks` to:

- Update issue statuses
- Add comments on progress
- Close completed issues (via PR merge)
- Plan next work session
- Update estimates for remaining work
```

## Issue Status Management

### Updating Issue Status

```bash
# Add comment with progress update
gh issue comment <issue-number> --body "Updated progress:
- ✅ Research completed
- ✅ Initial implementation done
- 🔄 Currently testing
- ⏳ Documentation pending
"

# Add label for tracking
gh issue edit <issue-number> --add-label "in-progress"

# Update milestone
gh issue edit <issue-number> --milestone "v1.2.0"
```

### Closing Issues

Issues should typically be closed automatically via PR merge with proper keywords:

```markdown
In PR description use:

- `Fixes #123` - Closes issue when PR merges
- `Closes #123` - Alternative keyword
- `Resolves #123` - Another alternative
- `Relates to #123` - Links but doesn't close
```

## Reporting Options

### Quick Summary (Default)

Just show counts and critical items:

```markdown
## 📋 Quick Task Summary

**Open Issues**: 12 total

- 🔴 Critical: 2 (need immediate attention)
- 🟠 High: 5
- 🟡 Medium: 3
- 🟢 Low: 2

**Action Required**:

- Issue #123 (Critical) - Complete testing
- Issue #124 (Critical) - Fix boot delay
```

### Detailed Report

Full breakdown with all issues listed by category.

### Custom Report

Filter by:

- Specific labels
- Date range
- Assignee
- Milestone
- Search term

## Examples

### Example 1: Daily Standup Check

```
User: "/check_tasks"
```

**Response**:

```markdown
## 📋 Daily Task Status

Good morning! Here's your task overview:

**🔴 Critical (2 issues)**

- #123: [feature] Add PostgreSQL monitoring - In Progress
  - Branch: feature/123-postgres-monitoring
  - Status: Testing phase, 80% complete
  - Action: Run validation and create PR today

- #124: [fix] P510 boot delay - Blocked
  - Status: Waiting for kernel update
  - Action: Check if update available, otherwise implement workaround

**🟠 High Priority (3 issues)**
[List continues...]

**Recommendation**: Focus on completing #123 today, check on #124 blocker.
```

### Example 2: Sprint Planning

```
User: "/check_tasks priority:high"
```

**Response**:

```markdown
## 📋 High Priority Issues for Sprint Planning

Found 5 high-priority issues:

1. **#125**: [enhancement] Improve monitoring dashboards
   - Estimate: M (1 week)
   - Status: Ready to start
   - Dependencies: None

2. **#126**: [feature] Add Loki centralized logging
   - Estimate: L (2 weeks)
   - Status: Needs research
   - Dependencies: Prometheus setup (completed)

[Continues with remaining 3...]

**Sprint Capacity**: Assuming 2-week sprint
**Recommendation**: Take issues #125 and #126 for this sprint
```

### Example 3: Blocker Review

```
User: "/check_tasks show blocked"
```

**Response**:

```markdown
## ⏸️ Blocked Issues Report

**2 Issues Currently Blocked**

1. **#124**: [fix] P510 boot delay
   - **Blocked By**: Kernel update not yet available
   - **Waiting Since**: 5 days
   - **Resolution Options**:
     - Wait for kernel 6.18 (ETA: 2 weeks)
     - Implement systemd workaround
     - Disable problematic service
   - **Recommendation**: Implement workaround today

2. **#127**: [feature] GPU monitoring
   - **Blocked By**: Missing ROCm exporter
   - **Waiting Since**: 2 days
   - **Resolution Options**:
     - Use alternative prometheus_rocm_smi_exporter
     - Write custom exporter
   - **Recommendation**: Start with alternative exporter
```

## Error Handling

### No Open Issues

```markdown
## ✅ All Caught Up!

**No open issues found.**

This means either:

- All work is completed
- No issues have been created yet

**Suggestions**:

- Run `/new_task` to create a new task
- Check closed issues for completed work: `gh issue list --state closed`
- Review roadmap for upcoming features
```

### GitHub CLI Not Authenticated

````markdown
## ⚠️ GitHub CLI Not Authenticated

Please authenticate the GitHub CLI:

```bash
gh auth login
```
````

Follow the prompts to authenticate with your GitHub account.

````

### No Internet Connection

```markdown
## ❌ Cannot Connect to GitHub

Unable to fetch issues. Please check:
- Internet connection
- GitHub status: https://www.githubstatus.com/
- Repository access permissions
````

## Usage Tips

1. **Start Each Day**: Run `/check_tasks` to see what needs attention
2. **Before Committing**: Check if your issue has been updated
3. **Weekly Review**: Run detailed report to plan the week
4. **Blocked Work**: Immediately flag blocked issues with comments
5. **Close Completed**: Use PR keywords to auto-close issues

## Integration with Other Commands

- `/new_task` → Creates issues shown in `/check_tasks`
- `/review` → Reviews code before closing issues via PR
- Justfile commands → Used to validate and test before closing issues
