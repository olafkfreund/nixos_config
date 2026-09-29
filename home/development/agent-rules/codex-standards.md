# Codex global standards

> Agent OS User Standards
> Adapted from `~/.claude/CLAUDE.md` on 2026-09-16.
> Maintained copy: update this tracked file and rebuild to change Codex instructions.

## Purpose

This file directs Codex to use your personal Agent OS standards for all development work.
These global standards define your preferred way of building software across all projects.

---

## Global Standards

Agent-OS standards and workflow templates (read on demand, not auto-loaded):

- Standards: `~/.agent-os/standards/{tech-stack,code-style,best-practices}.md` —
  note the tech-stack defaults describe a Rails/PostgreSQL/React stack;
  per-project standards override them.
- Claude workflow commands: `/plan-product`, `/create-spec`, `/execute-tasks`,
  `/analyze-product` are Claude commands, not native Codex commands. In Codex,
  follow the included artifact workflow and available task-relevant skills.
- If a referenced standards file is missing, report its absence rather than
  inventing its contents.

NixOS-specific standards live in the installed `nixos` skill and applicable
specialized NixOS skills (load on demand).

## Model by stage

- Intent, spec, plan and revision decisions: `gpt-6-astra` (`/model gpt-6-astra`).
- Implementation of an approved `plan/`: start `codex-implement` (Sol, write
  access, guarded). Do not commit; report changed files and plan deviations.
- `/review` runs on Astra. Luna is only for narrow, read-only lookups.
- At every gate's "stop for review", name the model and command for the next
  stage.
