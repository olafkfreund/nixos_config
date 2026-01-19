# GitHub & Git Integration Skill

> **Comprehensive Git and GitHub CLI Reference for NixOS Infrastructure**
>
> This skill provides deep knowledge of Git version control and GitHub CLI (gh) commands, specifically tailored for NixOS configuration management, issue-driven development, and automated workflows.

## Overview

This skill enables Gemini Code to effectively use Git and GitHub for:

- **Version Control**: Comprehensive git command usage and workflows
- **GitHub Integration**: GitHub CLI (gh) for issues, PRs, releases, and more
- **Issue-Driven Development**: Combining git/gh with /nix-new-task and /nix-check-tasks
- **Automated Workflows**: GitHub Actions integration and automation
- **Repository Management**: Multi-repository coordination and management

## Core Git Commands

### Repository Basics

**Initialize and Clone:**

```bash
# Initialize new repository
git init

# Clone existing repository
git clone https://github.com/user/repo.git
git clone git@github.com:user/repo.git  # SSH

# Clone with specific branch
git clone -b branch-name https://github.com/user/repo.git

# Clone shallow (faster, less history)
git clone --depth 1 https://github.com/user/repo.git

# Clone with submodules
git clone --recurse-submodules https://github.com/user/repo.git
```

**Repository Configuration:**

```bash
# Set user information
git config --global user.name "Your Name"
git config --global user.email "email@example.com"

# Set default branch name
git config --global init.defaultBranch main

# Set default editor
git config --global core.editor "nvim"

# Enable credential caching
git config --global credential.helper cache

# View all configuration
git config --list
git config --global --list

# Repository-specific config (no --global)
git config user.name "Different Name"
```

### Staging and Committing

**Basic Workflow:**

```bash
# Check repository status
git status
git status -s  # Short format

# Add files to staging
git add file.txt
git add *.nix
git add .  # All files
git add -A  # All files including deletions
git add -p  # Interactive staging (patch mode)

# Unstage files
git reset HEAD file.txt
git restore --staged file.txt  # Modern syntax

# Discard changes
git checkout -- file.txt
git restore file.txt  # Modern syntax

# Commit changes
git commit -m "commit message"
git commit -m "title" -m "body"

# Amend last commit
git commit --amend
git commit --amend --no-edit  # Keep message
git commit --amend -m "new message"

# Skip pre-commit hooks (use sparingly)
git commit --no-verify -m "message"
```

**Advanced Staging:**

```bash
# Interactive staging (choose what to stage)
git add -i

# Patch mode (stage parts of files)
git add -p file.txt

# Stage deletions only
git add -u

# Stage new and modified (not deletions)
git add --ignore-removal .

# Show what's staged
git diff --cached
git diff --staged
```

### Branching and Merging

**Branch Management:**

```bash
# List branches
git branch          # Local branches
git branch -r       # Remote branches
git branch -a       # All branches
git branch -v       # With last commit
git branch -vv      # With tracking info

# Create branch
git branch feature-name
git checkout -b feature-name  # Create and switch
git switch -c feature-name    # Modern syntax

# Switch branches
git checkout branch-name
git switch branch-name  # Modern syntax

# Delete branch
git branch -d branch-name      # Safe delete
git branch -D branch-name      # Force delete
git push origin --delete branch-name  # Delete remote

# Rename branch
git branch -m old-name new-name
git branch -m new-name  # Rename current branch

# Track remote branch
git branch --set-upstream-to=origin/branch-name
git branch -u origin/branch-name
```

**Merging Strategies:**

```bash
# Fast-forward merge (default)
git merge feature-branch

# No fast-forward (always create merge commit)
git merge --no-ff feature-branch

# Squash merge (combine all commits)
git merge --squash feature-branch
git commit -m "Squashed feature"

# Abort merge
git merge --abort

# Show merge conflicts
git diff --name-only --diff-filter=U

# Resolve conflicts and continue
git add resolved-file.txt
git commit
```

**Rebasing:**

```bash
# Rebase current branch onto main
git rebase main

# Interactive rebase (last 5 commits)
git rebase -i HEAD~5

# Rebase onto remote
git fetch origin
git rebase origin/main

# Continue after resolving conflicts
git add resolved-file.txt
git rebase --continue

# Skip current commit
git rebase --skip

# Abort rebase
git rebase --abort

# Rebase and autosquash
git rebase -i --autosquash HEAD~5
```

### Remote Operations

**Remote Management:**

```bash
# List remotes
git remote -v

# Add remote
git remote add origin https://github.com/user/repo.git
git remote add upstream https://github.com/original/repo.git

# Change remote URL
git remote set-url origin git@github.com:user/repo.git

# Remove remote
git remote remove origin

# Rename remote
git remote rename origin upstream

# Show remote info
git remote show origin
```

**Fetch, Pull, Push:**

```bash
# Fetch from remote (doesn't merge)
git fetch origin
git fetch --all  # All remotes
git fetch --prune  # Remove deleted remote branches

# Pull (fetch + merge)
git pull origin main
git pull --rebase origin main  # Rebase instead of merge
git pull --ff-only  # Only if fast-forward possible

# Push to remote
git push origin main
git push -u origin feature-branch  # Set upstream
git push --all  # All branches
git push --tags  # Push tags

# Force push (DANGEROUS - use with caution)
git push --force-with-lease  # Safer than --force
git push --force  # Nuclear option

# Delete remote branch
git push origin --delete branch-name
```

### History and Inspection

**Viewing History:**

```bash
# View commit history
git log
git log --oneline  # Compact format
git log --graph --oneline --all  # Visual graph
git log -n 5  # Last 5 commits
git log --since="2 weeks ago"
git log --until="2024-12-01"
git log --author="Name"
git log --grep="keyword"  # Search commit messages

# Show specific commit
git show commit-hash
git show HEAD  # Latest commit
git show HEAD~3  # 3 commits ago

# View file history
git log -- file.txt
git log -p file.txt  # With diffs

# Show who changed each line
git blame file.txt
git blame -L 10,20 file.txt  # Lines 10-20

# Search code history
git log -S "search term" -- file.txt
git log -G "regex pattern"
```

**Comparing Changes:**

```bash
# Show unstaged changes
git diff

# Show staged changes
git diff --cached
git diff --staged

# Compare branches
git diff main..feature-branch
git diff main...feature-branch  # From common ancestor

# Compare commits
git diff commit1 commit2
git diff HEAD~3 HEAD

# Compare with remote
git diff origin/main

# Show statistics
git diff --stat
git diff --shortstat

# Word-level diff
git diff --word-diff
```

### Undoing Changes

**Reverting and Resetting:**

```bash
# Revert commit (creates new commit)
git revert commit-hash
git revert HEAD  # Revert last commit

# Reset to previous state
git reset --soft HEAD~1   # Keep changes staged
git reset --mixed HEAD~1  # Keep changes unstaged (default)
git reset --hard HEAD~1   # DISCARD all changes

# Reset to remote state
git fetch origin
git reset --hard origin/main

# Unstage all files
git reset

# Restore file to last commit
git restore file.txt
git checkout -- file.txt  # Old syntax

# Restore file from specific commit
git restore --source=commit-hash file.txt
```

**Advanced Undo:**

```bash
# Find lost commits
git reflog
git reflog show HEAD

# Recover from reflog
git reset --hard HEAD@{2}

# Cherry-pick specific commit
git cherry-pick commit-hash

# Stash changes
git stash
git stash save "work in progress"
git stash list
git stash pop  # Apply and remove
git stash apply  # Apply but keep
git stash drop stash@{0}
git stash clear  # Remove all stashes

# Stash including untracked files
git stash -u
git stash --include-untracked
```

### Tags and Releases

**Tag Management:**

```bash
# List tags
git tag
git tag -l "v1.*"  # Pattern matching

# Create lightweight tag
git tag v1.0.0

# Create annotated tag
git tag -a v1.0.0 -m "Release version 1.0.0"

# Tag specific commit
git tag -a v1.0.0 commit-hash -m "message"

# Show tag info
git show v1.0.0

# Push tags to remote
git push origin v1.0.0
git push origin --tags  # All tags

# Delete tag
git tag -d v1.0.0  # Local
git push origin --delete v1.0.0  # Remote

# Checkout tag
git checkout v1.0.0
git checkout -b branch-from-tag v1.0.0
```

## GitHub CLI (gh) Commands

### Installation and Authentication

**Install gh:**

```nix
# NixOS configuration
environment.systemPackages = with pkgs; [
  gh  # GitHub CLI
];

# Or in home-manager
home.packages = with pkgs; [
  gh
];
```

**Authentication:**

```bash
# Login to GitHub
gh auth login

# Login with token
gh auth login --with-token < token.txt

# Check authentication status
gh auth status

# Logout
gh auth logout

# Refresh token
gh auth refresh

# Setup git credential helper
gh auth setup-git
```

### Repository Operations

**Repository Management:**

```bash
# View current repository
gh repo view
gh repo view owner/repo

# Clone repository
gh repo clone owner/repo
gh repo clone owner/repo target-directory

# Create repository
gh repo create repo-name
gh repo create repo-name --public
gh repo create repo-name --private
gh repo create owner/repo-name --source=. --remote=upstream

# Fork repository
gh repo fork owner/repo
gh repo fork owner/repo --clone

# List repositories
gh repo list
gh repo list owner
gh repo list --limit 50

# Delete repository
gh repo delete owner/repo

# Rename repository
gh repo rename new-name

# Repository settings
gh repo edit --description "New description"
gh repo edit --homepage "https://example.com"
gh repo edit --enable-issues
gh repo edit --enable-wiki
```

### Issue Management

**Creating Issues:**

```bash
# Create issue interactively
gh issue create

# Create with title and body
gh issue create --title "Bug: Something broke" --body "Description here"

# Create with template
gh issue create --template bug_report.md

# Create with labels
gh issue create --title "Feature" --label enhancement,high-priority

# Create with assignees
gh issue create --title "Task" --assignee username

# Create with milestone
gh issue create --title "Task" --milestone v1.0

# Create with project
gh issue create --title "Task" --project "Project Board"
```

**Listing and Viewing Issues:**

```bash
# List open issues
gh issue list
gh issue list --state open
gh issue list --state closed
gh issue list --state all

# Filter by label
gh issue list --label bug
gh issue list --label "high priority,bug"

# Filter by assignee
gh issue list --assignee @me
gh issue list --assignee username

# Filter by milestone
gh issue list --milestone v1.0

# Filter by author
gh issue list --author username

# Limit results
gh issue list --limit 50

# View specific issue
gh issue view 123
gh issue view 123 --web  # Open in browser

# View with comments
gh issue view 123 --comments
```

**Updating Issues:**

```bash
# Close issue
gh issue close 123
gh issue close 123 --comment "Fixed in #124"

# Reopen issue
gh issue reopen 123

# Edit issue
gh issue edit 123 --title "New title"
gh issue edit 123 --body "New description"
gh issue edit 123 --add-label bug
gh issue edit 123 --remove-label enhancement
gh issue edit 123 --add-assignee username
gh issue edit 123 --remove-assignee username

# Comment on issue
gh issue comment 123 --body "Additional information"

# Pin issue
gh issue pin 123

# Unpin issue
gh issue unpin 123

# Transfer issue
gh issue transfer 123 other-repo
```

**Advanced Issue Operations:**

```bash
# Create issue from template
gh issue create --template .github/ISSUE_TEMPLATE/bug_report.md

# Create issue with file content
gh issue create --title "Bug" --body-file description.txt

# Link to pull request
gh issue develop 123  # Create branch from issue
gh issue develop 123 --checkout

# Search issues
gh issue list --search "is:open is:issue label:bug"
gh issue list --search "is:closed author:username"

# Export issues to JSON
gh issue list --json number,title,state,labels

# Bulk operations
gh issue list --json number | jq -r '.[].number' | xargs -I {} gh issue close {}
```

### Pull Request Operations

**Creating Pull Requests:**

```bash
# Create PR interactively
gh pr create

# Create with title and body
gh pr create --title "Feature: Add support" --body "Description"

# Create from current branch
gh pr create --fill  # Use commit messages
gh pr create --fill-first  # Use first commit message

# Create draft PR
gh pr create --draft

# Create with reviewers
gh pr create --reviewer username1,username2
gh pr create --reviewer @me

# Create with assignees
gh pr create --assignee username

# Create with labels
gh pr create --label enhancement,high-priority

# Create with milestone
gh pr create --milestone v1.0

# Create to specific branch
gh pr create --base develop
gh pr create --head feature-branch

# Create and open in browser
gh pr create --web
```

**Listing and Viewing PRs:**

```bash
# List pull requests
gh pr list
gh pr list --state open
gh pr list --state closed
gh pr list --state merged
gh pr list --state all

# Filter by author
gh pr list --author @me
gh pr list --author username

# Filter by label
gh pr list --label bug

# Filter by assignee
gh pr list --assignee username

# View specific PR
gh pr view 123
gh pr view 123 --web

# View with diff
gh pr diff 123

# View PR checks
gh pr checks 123
gh pr checks 123 --watch  # Watch in real-time

# View PR comments
gh pr view 123 --comments
```

**Updating Pull Requests:**

```bash
# Edit PR
gh pr edit 123 --title "New title"
gh pr edit 123 --body "New description"
gh pr edit 123 --add-reviewer username
gh pr edit 123 --add-label bug

# Comment on PR
gh pr comment 123 --body "LGTM!"

# Review PR
gh pr review 123 --approve
gh pr review 123 --request-changes --body "Please fix X"
gh pr review 123 --comment --body "Some suggestions"

# Close PR
gh pr close 123
gh pr close 123 --comment "Not needed"

# Reopen PR
gh pr reopen 123

# Mark as ready for review
gh pr ready 123

# Convert to draft
gh pr ready 123 --undo
```

**Merging Pull Requests:**

```bash
# Merge PR (creates merge commit)
gh pr merge 123

# Squash merge
gh pr merge 123 --squash

# Rebase merge
gh pr merge 123 --rebase

# Merge and delete branch
gh pr merge 123 --delete-branch

# Auto-merge when checks pass
gh pr merge 123 --auto

# Merge with custom message
gh pr merge 123 --squash --body "Custom merge message"

# Interactive merge
gh pr merge  # Will prompt for PR number and merge strategy
```

**PR Workflow Commands:**

```bash
# Checkout PR locally
gh pr checkout 123

# Create branch from PR
gh pr checkout 123 --branch feature-review

# View PR status
gh pr status

# Watch PR checks
gh pr checks 123 --watch

# Sync PR with upstream
git fetch origin
git merge origin/main
git push

# Request review
gh pr edit 123 --add-reviewer username

# Approve multiple PRs
gh pr list --json number | jq -r '.[].number' | xargs -I {} gh pr review {} --approve
```

### Workflow and Actions

**GitHub Actions:**

```bash
# List workflows
gh workflow list

# View workflow details
gh workflow view workflow-name

# View workflow runs
gh run list
gh run list --workflow=workflow-name

# View specific run
gh run view run-id

# Watch run in real-time
gh run watch run-id

# View run logs
gh run view run-id --log
gh run view run-id --log-failed  # Only failed jobs

# Download artifacts
gh run download run-id

# Rerun workflow
gh run rerun run-id

# Cancel run
gh run cancel run-id

# Trigger workflow
gh workflow run workflow-name

# Trigger with inputs
gh workflow run workflow-name --field key=value

# Enable/disable workflow
gh workflow enable workflow-name
gh workflow disable workflow-name
```

### Release Management

**Creating Releases:**

```bash
# Create release
gh release create v1.0.0

# Create with title and notes
gh release create v1.0.0 --title "Version 1.0.0" --notes "Release notes here"

# Create from notes file
gh release create v1.0.0 --notes-file CHANGELOG.md

# Create with assets
gh release create v1.0.0 dist/*.tar.gz

# Create draft release
gh release create v1.0.0 --draft

# Create prerelease
gh release create v1.0.0-beta --prerelease

# Auto-generate release notes
gh release create v1.0.0 --generate-notes

# Create from specific commit
gh release create v1.0.0 --target commit-hash
```

**Managing Releases:**

```bash
# List releases
gh release list
gh release list --limit 20

# View release
gh release view v1.0.0
gh release view v1.0.0 --web

# Download release assets
gh release download v1.0.0
gh release download v1.0.0 --pattern "*.tar.gz"

# Upload assets to existing release
gh release upload v1.0.0 dist/*.tar.gz

# Delete release
gh release delete v1.0.0
gh release delete v1.0.0 --yes  # Skip confirmation

# Edit release
gh release edit v1.0.0 --title "New title"
gh release edit v1.0.0 --notes "Updated notes"

# View latest release
gh release view --latest
```

### Labels, Milestones, Projects

**Label Management:**

```bash
# List labels
gh label list

# Create label
gh label create "high priority" --color FF0000 --description "Urgent"

# Edit label
gh label edit "bug" --color FF0000
gh label edit "bug" --description "Something isn't working"

# Delete label
gh label delete "wontfix"

# Clone labels from another repo
gh label clone owner/other-repo
```

**Milestone Management:**

```bash
# List milestones
gh milestone list
gh milestone list --state open
gh milestone list --state closed

# Create milestone
gh milestone create "v1.0" --description "First release"
gh milestone create "v1.0" --due-date "2024-12-31"

# Edit milestone
gh milestone edit "v1.0" --title "Version 1.0"
gh milestone edit "v1.0" --due-date "2025-01-15"

# Close milestone
gh milestone close "v1.0"

# Reopen milestone
gh milestone reopen "v1.0"

# Delete milestone
gh milestone delete "v1.0"
```

**Project Management:**

```bash
# List projects
gh project list

# View project
gh project view 1

# Create project (beta)
gh project create --title "Project Name"

# Add item to project
gh project item-add PROJECT_ID --item ISSUE_URL

# List project items
gh project item-list PROJECT_ID
```

### Advanced gh Usage

**Aliases:**

```bash
# Create alias
gh alias set co "pr checkout"
gh alias set issues "issue list --assignee @me"
gh alias set prs "pr list --state open --author @me"

# List aliases
gh alias list

# Delete alias
gh alias delete co
```

**Configuration:**

```bash
# Set default repository
gh repo set-default owner/repo

# Set default editor
gh config set editor nvim

# Set default git protocol
gh config set git_protocol ssh

# View configuration
gh config list

# Set prompt for confirmations
gh config set prompt enabled
```

**API Access:**

```bash
# Make API request
gh api repos/:owner/:repo

# Paginate results
gh api --paginate repos/:owner/:repo/issues

# Send POST request
gh api repos/:owner/:repo/issues -f title="New issue" -f body="Description"

# GraphQL query
gh api graphql -f query='
  query {
    viewer {
      login
    }
  }
'

# Export to JSON
gh api repos/:owner/:repo | jq .
```

## Integration with NixOS Workflow

### Issue-Driven Development Integration

**Combining with /nix-new-task:**

The `/nix-new-task` command internally uses GitHub CLI for issue creation:

```bash
# /nix-new-task workflow uses:
gh issue create \
  --title "Task title" \
  --body "$(cat description.md)" \
  --label "enhancement,nixos" \
  --milestone "v1.0"

# You can verify with:
gh issue list --label enhancement
gh issue view issue-number
```

**Combining with /nix-check-tasks:**

The `/nix-check-tasks` command uses GitHub CLI to query issues:

```bash
# /nix-check-tasks workflow uses:
gh issue list --state open --json number,title,labels,state,assignees

# You can manually check:
gh issue list --assignee @me
gh issue list --label "high-priority"
gh issue list --milestone "current-sprint"
```

**Manual Issue Workflow:**

```bash
# 1. Check current tasks
gh issue list --assignee @me --state open

# 2. Create new task
gh issue create --title "feat: add monitoring" --label enhancement

# 3. Create branch from issue
gh issue develop 45 --checkout
# Creates: feature/45-add-monitoring

# 4. Work on task, then create PR
git push -u origin feature/45-add-monitoring
gh pr create --fill

# 5. Link PR to issue (automatic if branch name includes issue number)
gh pr create --title "feat: add monitoring (#45)"

# 6. After merge, close issue (automatic if PR description has "Closes #45")
gh pr merge 45 --squash --delete-branch
```

### Automated Deployment Integration

**Pre-deployment Issue Check:**

```bash
# Before deploying updates (used in /nix-deploy)
# Check for blocking issues
gh issue list --label "blocking" --state open

# If blocking issues exist, warn user
if [ $(gh issue list --label "blocking" --state open --json number | jq '. | length') -gt 0 ]; then
  echo "⛔ BLOCKING ISSUES EXIST - Review before deploying"
  gh issue list --label "blocking" --state open
fi
```

**Post-deployment Issue Closure:**

```bash
# After successful deployment
# Close issues mentioned in commit messages
git log --oneline origin/main..HEAD | grep -oP 'Closes #\K\d+' | while read issue; do
  gh issue close $issue --comment "Deployed in $(git rev-parse --short HEAD)"
done
```

### Branch Management Integration

**Feature Branch Workflow:**

```bash
# 1. Create issue first
ISSUE=$(gh issue create --title "Add PostgreSQL monitoring" --label enhancement --json number -q .number)

# 2. Create branch from issue
gh issue develop $ISSUE --checkout

# 3. Work on feature
# ... make changes ...

# 4. Commit with issue reference
git commit -m "feat(monitoring): add PostgreSQL exporter (#$ISSUE)"

# 5. Push and create PR
git push -u origin $(git branch --show-current)
gh pr create --fill

# 6. After review, merge
gh pr merge --squash --delete-branch
```

**Hotfix Workflow:**

```bash
# 1. Create urgent issue
ISSUE=$(gh issue create --title "Fix P510 boot delay" --label bug,critical --json number -q .number)

# 2. Create hotfix branch
git checkout -b fix/$ISSUE-p510-boot-delay main

# 3. Fix issue
# ... make changes ...

# 4. Commit and push
git commit -m "fix(p510): resolve boot delay (#$ISSUE)"
git push -u origin fix/$ISSUE-p510-boot-delay

# 5. Create emergency PR
gh pr create --title "fix(p510): resolve boot delay (#$ISSUE)" --body "Emergency fix for 8+ minute boot delays" --label critical

# 6. Fast-track merge
gh pr merge --squash --admin
```

### Release Management Integration

**Creating NixOS Config Releases:**

```bash
# 1. Prepare release
VERSION="v2024.12.1"

# 2. Update version in flake.nix or similar
# ... edit version ...

# 3. Commit version bump
git add flake.nix
git commit -m "chore: bump version to $VERSION"

# 4. Create annotated tag
git tag -a $VERSION -m "Release $VERSION

Major changes:
- Enhanced monitoring with Prometheus/Grafana
- AI provider integration
- MicroVM development environments

See CHANGELOG.md for complete details."

# 5. Push tag
git push origin $VERSION

# 6. Create GitHub release with auto-generated notes
gh release create $VERSION \
  --title "NixOS Config $VERSION" \
  --generate-notes

# 7. Optionally attach build artifacts
nix build .#nixosConfigurations.p620.config.system.build.toplevel
gh release upload $VERSION result
```

### Multi-Repository Coordination

**Working with Upstream and Fork:**

```bash
# 1. Fork nixpkgs
gh repo fork NixOS/nixpkgs --clone

# 2. Add upstream remote
cd nixpkgs
git remote add upstream https://github.com/NixOS/nixpkgs.git

# 3. Create feature branch
git checkout -b add-package upstream/master

# 4. Make changes and commit
# ... edit package ...
git commit -m "package: init at version 1.0"

# 5. Push to your fork
git push -u origin add-package

# 6. Create PR to upstream
gh pr create --repo NixOS/nixpkgs \
  --title "package: init at version 1.0" \
  --body "New package for X. Closes NixOS/nixpkgs#12345"

# 7. Track upstream changes
git fetch upstream
git rebase upstream/master
git push --force-with-lease
```

### GitHub Actions Integration

**Trigger Workflow with Issue:**

```bash
# Create issue that triggers workflow
gh issue create \
  --title "Deploy to staging" \
  --label "deploy,staging"

# Workflow (.github/workflows/deploy-on-issue.yml) can watch for this:
# on:
#   issues:
#     types: [labeled]
#
# jobs:
#   deploy:
#     if: contains(github.event.issue.labels.*.name, 'deploy')
```

**Manual Workflow Trigger:**

```bash
# Trigger deployment workflow manually
gh workflow run deploy.yml \
  --field environment=staging \
  --field host=p620

# Watch workflow run
gh run watch

# View logs if failed
gh run view --log-failed
```

## Advanced Patterns

### Git Worktrees (Multiple Working Directories)

```bash
# Create worktree for parallel work
git worktree add ../nixos-feature feature-branch
git worktree add ../nixos-hotfix -b hotfix/issue-123

# List worktrees
git worktree list

# Remove worktree
git worktree remove ../nixos-feature

# Prune deleted worktrees
git worktree prune
```

### Git Bisect (Finding Bad Commits)

```bash
# Start bisect
git bisect start

# Mark current as bad
git bisect bad

# Mark known good commit
git bisect good v1.0.0

# Git will checkout middle commit - test it
nix build .#nixosConfigurations.p620.config.system.build.toplevel

# Mark as good or bad
git bisect good  # or git bisect bad

# Continue until found
# ...

# Show bad commit
git bisect log

# Reset to HEAD
git bisect reset
```

### Submodules (Managing Dependencies)

```bash
# Add submodule
git submodule add https://github.com/user/repo path/to/submodule

# Initialize submodules after clone
git submodule init
git submodule update

# Clone with submodules
git clone --recurse-submodules repo-url

# Update submodules to latest
git submodule update --remote

# Execute command in all submodules
git submodule foreach 'git pull origin main'

# Remove submodule
git submodule deinit path/to/submodule
git rm path/to/submodule
rm -rf .git/modules/path/to/submodule
```

### Git Hooks (Automation)

**Common Hooks:**

```bash
# Pre-commit hook (.git/hooks/pre-commit)
#!/usr/bin/env bash
# Run validation before commit
nix flake check || {
  echo "Flake check failed!"
  exit 1
}

# Pre-push hook (.git/hooks/pre-push)
#!/usr/bin/env bash
# Run tests before push
just test-all || {
  echo "Tests failed!"
  exit 1
}

# Commit-msg hook (.git/hooks/commit-msg)
#!/usr/bin/env bash
# Validate commit message format
commit_msg=$(cat "$1")
if ! echo "$commit_msg" | grep -qE '^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: .+$'; then
  echo "Invalid commit message format!"
  echo "Use: type(scope): description"
  exit 1
fi

# Make hooks executable
chmod +x .git/hooks/*
```

### GitHub CLI Scripts

**Bulk Issue Management:**

```bash
#!/usr/bin/env bash
# Close all issues with specific label

LABEL="wontfix"

gh issue list --label "$LABEL" --json number --jq '.[].number' | while read issue; do
  echo "Closing issue #$issue"
  gh issue close "$issue" --comment "Closing as $LABEL"
done
```

**PR Review Automation:**

```bash
#!/usr/bin/env bash
# Auto-approve dependabot PRs

gh pr list --author app/dependabot --json number --jq '.[].number' | while read pr; do
  echo "Reviewing PR #$pr"
  gh pr review "$pr" --approve --body "LGTM - Auto-approved dependency update"
  gh pr merge "$pr" --auto --squash
done
```

**Release Changelog Generation:**

```bash
#!/usr/bin/env bash
# Generate changelog from commits since last release

LAST_TAG=$(git describe --tags --abbrev=0)
CURRENT_TAG=$1

echo "# Changelog for $CURRENT_TAG"
echo ""
echo "## Features"
git log $LAST_TAG..HEAD --oneline --grep="^feat" | sed 's/^/- /'
echo ""
echo "## Fixes"
git log $LAST_TAG..HEAD --oneline --grep="^fix" | sed 's/^/- /'
echo ""
echo "## Documentation"
git log $LAST_TAG..HEAD --oneline --grep="^docs" | sed 's/^/- /'
```

## Best Practices

### Commit Message Conventions

**Conventional Commits Format:**

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Formatting changes
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**

```bash
# Feature
git commit -m "feat(monitoring): add Prometheus integration"

# Bug fix
git commit -m "fix(p510): resolve boot delay from fstrim service"

# With body
git commit -m "feat(ai): add multi-provider support

Implement unified AI provider interface with support for:
- Anthropic Gemini
- OpenAI GPT
- Google Gemini
- Local Ollama inference

Includes automatic fallback and cost optimization."

# With issue reference
git commit -m "fix(deployment): add change detection (#45)

Closes #45"

# Breaking change
git commit -m "feat(config)!: migrate to flakes

BREAKING CHANGE: Legacy configuration no longer supported.
All hosts must use flake-based configuration."
```

### Branch Naming Conventions

```bash
# Feature branches
feature/123-add-monitoring
feature/postgres-exporter

# Bug fix branches
fix/456-boot-delay
fix/p510-fstrim-timeout

# Hotfix branches
hotfix/789-critical-security
hotfix/emergency-rollback

# Release branches
release/v1.0.0
release/2024.12

# Experimental branches
experiment/new-architecture
experiment/microvm-testing
```

### Git Workflow Patterns

**Feature Branch Workflow:**

1. Create issue
2. Create branch from issue
3. Implement feature with small commits
4. Push and create PR
5. Review and merge
6. Delete branch

**GitFlow Workflow:**

- `main` - Production-ready code
- `develop` - Integration branch
- `feature/*` - New features
- `release/*` - Release preparation
- `hotfix/*` - Emergency fixes

**GitHub Flow (Recommended for NixOS config):**

1. Create branch from `main`
2. Add commits
3. Open PR
4. Review and discuss
5. Deploy and test
6. Merge to `main`

### Security Best Practices

**SSH Keys:**

```bash
# Generate SSH key for GitHub
ssh-keygen -t ed25519 -C "email@example.com"

# Add to ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Add public key to GitHub
gh ssh-key add ~/.ssh/id_ed25519.pub --title "NixOS P620"

# Test connection
ssh -T git@github.com
```

**GPG Signing:**

```bash
# Generate GPG key
gpg --full-generate-key

# List keys
gpg --list-secret-keys --keyid-format LONG

# Configure git to use GPG
git config --global user.signingkey YOUR_KEY_ID
git config --global commit.gpgsign true

# Add GPG key to GitHub
gpg --armor --export YOUR_KEY_ID | gh gpg-key add

# Sign commits
git commit -S -m "Signed commit"

# Verify signatures
git log --show-signature
```

**Secrets Management:**

```bash
# Never commit secrets!
# Use .gitignore
echo "secrets/" >> .gitignore
echo "*.env" >> .gitignore
echo "*.key" >> .gitignore

# Use environment variables
export GITHUB_TOKEN="your-token"
gh auth login --with-token <<< "$GITHUB_TOKEN"

# Use git-crypt for encrypted secrets
git-crypt init
echo "secrets/** filter=git-crypt diff=git-crypt" >> .gitattributes
git-crypt add-gpg-user YOUR_GPG_KEY
```

## Troubleshooting

### Common Issues and Solutions

**Merge Conflicts:**

```bash
# View conflicted files
git status

# View conflict markers
cat conflicted-file.txt

# Resolve manually, then:
git add conflicted-file.txt
git commit

# Or use merge tool
git mergetool

# Abort merge if needed
git merge --abort
```

**Detached HEAD State:**

```bash
# Create branch from detached HEAD
git checkout -b recovery-branch

# Or return to previous branch
git checkout main
```

**Accidentally Committed to Wrong Branch:**

```bash
# Move commits to new branch
git branch feature-branch
git reset --hard HEAD~3  # Remove last 3 commits from current branch
git checkout feature-branch
```

**Large File Issues:**

```bash
# Remove large file from history
git filter-branch --tree-filter 'rm -f large-file.bin' HEAD

# Or use BFG Repo-Cleaner
bfg --delete-files large-file.bin
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

**GitHub CLI Authentication Issues:**

```bash
# Refresh authentication
gh auth refresh

# Re-login
gh auth logout
gh auth login

# Check token permissions
gh auth status

# Use specific token
export GITHUB_TOKEN="your-token"
gh auth status
```

## Summary

This GitHub skill provides comprehensive knowledge for:

- **Git Fundamentals**: Repository management, branching, merging, rebasing
- **GitHub CLI**: Issues, PRs, releases, workflows, projects
- **Integration**: Combining git/gh with /nix-new-task, /nix-check-tasks, /nix-deploy
- **Automation**: Scripts, hooks, and GitHub Actions integration
- **Best Practices**: Commit conventions, branch naming, security, workflows

Use this skill whenever working with:
- Version control operations
- GitHub issue management
- Pull request workflows
- Release management
- Repository automation
- Multi-repository coordination

The skill seamlessly integrates with existing NixOS infrastructure commands and enables efficient issue-driven development workflows.
