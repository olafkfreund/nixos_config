# Managed instructions

## Artifact workflow: intent → spec → plan

Applies to any task tracked as an issue or touching more than one file.
Exempt: typos, a flake lock bump, a one-line config change. When unsure, ask.

The procedure and templates are in the `artifact-workflow` skill. Load it
before writing any of these files.

Layout at the repo root, one slug `YYYY-MM-DD-<issue>-<slug>` per task:

- `intent/<slug>.md` — the why: problem, outcome, affected, constraints, open questions
- `spec/<slug>.md` — the what: design, alternatives rejected, risks, verification
- `plan/<slug>.md` — the how, self-contained: decisions, ordered steps, tests, rollback

Each file has frontmatter `status: draft | approved` and links its predecessor.

Gates — never skip one, never self-approve:

1. New task: write `intent/`, commit as draft on the task branch, stop for review.
2. Only after the user approves the intent: write `spec/`, stop for review.
3. Only after the user approves the spec: write `plan/`, carrying every
   approved spec decision over. Keep the spec; do not move it. Stop.
4. No implementation edits until `plan/` is `status: approved`.

Record each approval as its own commit, e.g. `docs(intent): approve <slug> (#123)`.
While implementing, name the plan step you are executing (PARR's Plan phase).
If implementation must deviate, update `plan/` in the same commit as the code.
The PR description links all three; review checks the diff against `plan/`.

## Model split (Claude Code only)

The session model (Opus) writes intent, spec and plan, and reviews. The
`coder` agent (Sonnet) writes the code for an approved `plan/`.

- Hand off when an approved `plan/` has three or more steps that edit files,
  or touches three or more files. Below that, implement it yourself: a
  handoff costs a fresh cache and a re-read that a small task does not repay.
- Start one `coder` per task with the plan path and step 1, and send each
  later step to the same agent with `SendMessage` so its cache stays warm.
- Review with a fresh agent on `model: "opus"`, given only the plan path and
  `git diff`, so it does not share the coder's blind spots.
- Finish a step the coder hands back yourself, then commit and update `plan/`
  for any deviation it reported. The PR says which steps the coder did.
- This applies to committed, approved `plan/` files only. A plan that exists
  only in the conversation stays with you.
