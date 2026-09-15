---
status: approved
issue: 1818
intent: intent/2026-09-15-1818-artifact-workflow.md
---

# Spec: intent → spec → plan workflow

## Design

1. **Managed policy memory.** `claude-code-managed.nix` renders
   `/etc/claude-code/CLAUDE.md`. It loads in every session in every repo and
   cannot be excluded. It carries the rule only: layout, gates, exemption.
2. **Skill `artifact-workflow`.** Templates and the step-by-step procedure,
   loaded on demand, installed like the `gog` skill.
3. **PARR hook.** When an approved `plan/` file exists, the PLAN phase cites
   the step being executed instead of re-planning; a REVISE that changes the
   approach updates `plan/` in the same commit as the code.
4. **`/create-spec`.** Repointed to the skill's spec mode.

## Layout

Per repo root, one slug `YYYY-MM-DD-<issue>-<slug>` shared across
`intent/`, `spec/`, `plan/`. Frontmatter `status: draft | approved`.
Approval is its own commit. `plan/` is self-contained: it copies the approved
spec decisions and adds steps; the spec is kept, not moved.

## Alternatives rejected

- `~/.claude/CLAUDE.md` only — syncthing-synced, excludable, can drift.
- A PreToolUse gate blocking edits without an approved plan — add only if
  gates are skipped in practice.
- Incident → auto intent loop — no monitoring to trigger it.

## Risks

- Two planning prompts conflict (PARR vs plan.md) — addressed by design 3.
- `/create-spec` lives outside the repo (synced `~/.claude/commands`).

## Verification

- `nix eval` shows the rendered managed CLAUDE.md and hook text
- `just test-host p620` builds
- After deploy: `/context` lists `/etc/claude-code/CLAUDE.md`
