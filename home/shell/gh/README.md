# GitHub CLI Configuration

This directory contains configuration for [GitHub CLI](https://cli.github.com/) (gh), a command-line tool for interacting with GitHub repositories.

## Overview

The GitHub CLI is configured in your NixOS setup to provide:

- Command-line access to GitHub repositories and features
- Custom aliases for frequently used operations
- Integration with your local git workflow

## Features

- Authentication with your GitHub account
- Repository management from the terminal
- Issue and PR management without using the web interface
- CI workflow interactions

## Usage

Common GitHub CLI commands:

```bash
# Clone a repository
gh repo clone owner/repo

# View issues
gh issue list

# Create a pull request
gh pr create

# Check status of PRs
gh pr status

# Run custom GitHub CLI extensions
gh extension install owner/extension
```

Your configuration may include custom aliases to simplify frequent operations, authentication settings, and preferences for the default browser or editor used when interacting with GitHub content.
