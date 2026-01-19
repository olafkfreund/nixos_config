---
description: Create a new GitHub issue with research and planning
globs:
alwaysApply: false
version: 1.0
encoding: UTF-8
---

# New Task Command

Create a new GitHub issue following best practices with research, planning, and proper workflow setup.

## Process

### Step 1: Gather Task Information

Ask the user for the following information if not provided:

1. **Task Title**: Brief, descriptive title (50-72 characters)
2. **Task Description**: Detailed description of what needs to be done
3. **Task Type**:
   - `feature` - New functionality
   - `bug` - Bug fix
   - `enhancement` - Improvement to existing feature
   - `docs` - Documentation update
   - `refactor` - Code refactoring
   - `chore` - Maintenance tasks
4. **Priority**: `critical`, `high`, `medium`, `low`
5. **Research Required**: Does this task need technical research? (yes/no)

### Step 2: Conduct Technical Research (if required)

If research is needed:

1. **Search for Solutions**: Use WebSearch to find:
   - Best practices for the task
   - Similar implementations
   - Common pitfalls and solutions
   - Relevant documentation

2. **Review Existing Code**: Check if similar patterns exist in the codebase
   - Search for related modules in `modules/`
   - Check for similar configurations in `hosts/`
   - Review documentation in `docs/`

3. **Consult Documentation**:
   - @docs/PATTERNS.md - Best practices
   - @docs/NIXOS-ANTI-PATTERNS.md - Anti-patterns to avoid
   - Official Nix/NixOS documentation

4. **Synthesize Research**: Create a research summary including:
   - Recommended approach
   - Key considerations
   - Potential challenges
   - Required dependencies
   - Example implementations

### Step 3: Create Issue Body

Format the GitHub issue body with the following structure:

```markdown
## Description

[Clear description of what needs to be done and why]

## Context

[Background information and motivation for this task]

## Research Summary

[If research was conducted, include key findings and recommendations]

### Recommended Approach

- [Step 1]
- [Step 2]
- [Step 3]

### Key Considerations

- [Important point 1]
- [Important point 2]

### References

- [Link to documentation 1]
- [Link to similar implementation]
- [Link to best practices guide]

## Acceptance Criteria

- [ ] [Specific, testable criteria 1]
- [ ] [Specific, testable criteria 2]
- [ ] [All tests pass]
- [ ] [Documentation updated]
- [ ] [Follows PATTERNS.md best practices]
- [ ] [No anti-patterns from NIXOS-ANTI-PATTERNS.md]

## Implementation Checklist

- [ ] Create feature branch from issue
- [ ] Implement solution following research
- [ ] Write/update tests
- [ ] Update documentation
- [ ] Run validation: `just validate`
- [ ] Test deployment: `just test-host HOST`
- [ ] Create pull request
- [ ] Code review
- [ ] Merge after approval

## Related Issues

[Link to related issues if any]

## Labels

`[task-type]`, `[priority]`

## Estimated Effort

[XS/S/M/L/XL based on complexity]
```

### Step 4: Create GitHub Issue

Use the `gh` CLI to create the issue:

```bash
gh issue create \
  --title "[TYPE] Title of the task" \
  --body "$(cat <<'EOF'
[Formatted issue body from Step 3]
EOF
)" \
  --label "type:[task-type]" \
  --label "priority:[priority]" \
  --assignee "@me"
```

### Step 5: Provide Next Steps

After creating the issue, inform the user:

````markdown
✅ **GitHub Issue Created**

**Issue Number**: #123
**Title**: [TYPE] Task Title
**URL**: [GitHub Issue URL]

## Next Steps

1. **Create Feature Branch**:
   ```bash
   git checkout main
   git pull
   git checkout -b [type]/123-brief-description
   ```
````

Or use gh CLI:

```bash
gh issue develop 123 --checkout
```

2. **Begin Work**: Start implementing the solution following the research

3. **Track Progress**: Update the issue checklist as you complete tasks

4. **When Complete**:

   ```bash
   just validate
   just test-host HOST
   git add .
   git commit -m "[type]: description (#123)"
   git push -u origin [type]/123-brief-description
   ```

5. **Create Pull Request**:

   ```bash
   gh pr create --fill
   ```

## Branch Naming Convention

- `feature/123-description` - New features
- `fix/123-description` - Bug fixes
- `enhancement/123-description` - Improvements
- `docs/123-description` - Documentation
- `refactor/123-description` - Refactoring
- `chore/123-description` - Maintenance

```

## Important Notes

### Labels to Use

Based on task type and priority:

**Type Labels**:
- `type:feature` - New functionality
- `type:bug` - Bug fixes
- `type:enhancement` - Improvements
- `type:docs` - Documentation
- `type:refactor` - Refactoring
- `type:chore` - Maintenance

**Priority Labels**:
- `priority:critical` - Urgent, blocks other work
- `priority:high` - Important, should be done soon
- `priority:medium` - Normal priority
- `priority:low` - Nice to have

**Additional Labels**:
- `needs-research` - Requires technical research
- `good-first-issue` - Good for beginners
- `help-wanted` - Community help needed

### Commit Message Format

Follow conventional commits:

```

type(scope): description (#issue-number)

Longer description if needed

Relates to #issue-number

```

### Examples

**Feature**:
```

feature(monitoring): add Plex media server monitoring (#45)

Implement comprehensive Plex monitoring with Tautulli integration
including real-time stream tracking and user analytics.

Relates to #45

```

**Bug Fix**:
```

fix(p510): resolve boot delay from fstrim service (#67)

Optimize fstrim service configuration to prevent 8+ minute
boot delays on P510 media server.

Fixes #67

```

## Error Handling

If `gh` CLI is not available or not authenticated:

1. Check if `gh` is installed: `which gh`
2. Authenticate: `gh auth login`
3. Check repo: `gh repo view`

If creating issue fails, provide manual instructions for creating via GitHub web interface.

## Usage Examples

### Simple Feature Request

```

User: "Add support for PostgreSQL monitoring"

```

**Assistant Response**:
1. Ask about priority and if research is needed
2. Conduct research on PostgreSQL exporters
3. Create issue with research findings
4. Provide next steps with branch name

### Bug Report

```

User: "P620 boot is slow after recent changes"

```

**Assistant Response**:
1. Identify as bug fix, ask priority
2. Research systemd boot analysis
3. Create issue with debugging steps
4. Provide investigation checklist

### Research-Heavy Task

```

User: "Implement distributed monitoring with Thanos"

```

**Assistant Response**:
1. Conduct extensive research on Thanos
2. Review compatibility with current Prometheus setup
3. Create detailed issue with implementation plan
4. Include multiple phases if complex
```
