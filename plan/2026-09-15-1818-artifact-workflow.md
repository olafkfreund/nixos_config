---
status: approved
issue: 1818
spec: spec/2026-09-15-1818-artifact-workflow.md
---

# Plan: intent → spec → plan workflow

Self-contained. Decisions: managed `/etc/claude-code/CLAUDE.md` carries the
rule; skill `artifact-workflow` carries templates; PARR hook defers to an
approved plan; `/create-spec` points at the skill; small tasks exempt.

## Steps

1. `modules/programs/claude-code-managed.nix`: add
   `environment.etc."claude-code/CLAUDE.md"` from a new
   `modules/programs/claude-code-managed-claude.md`.
2. Same file: append the plan-deferral lines to the PARR reminder script.
3. `home/development/claude-code-skills/artifact-workflow/SKILL.md` + one
   `home.file` line in `default.nix`.
4. `~/.claude/commands/create-spec.md` (synced, outside repo): point at the
   skill's spec mode.
5. `~/.claude/CLAUDE.md` (synced): one line under Phase 1 deferring to an
   approved plan, so it does not contradict the managed rule.

## Tests

- `nix eval .#nixosConfigurations.p620.config.environment.etc."claude-code/CLAUDE.md".text`
- `just test-host p620`

## Rollback

Revert the PR and redeploy; the synced files revert by hand.
