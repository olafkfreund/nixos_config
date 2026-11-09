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

Agents that Claude Code starts (Codex, agy: reviews, `codex-implement`, `agy-implement`, herdr team members) run
unrestricted by owner decision (Issue #2812), so for them these rules are instruction-only and mandatory: never stage,
commit, push, deploy, switch, restart, garbage-collect or reboot; never work on `main` or in `~/.config/nixos`; p510
needs the owner's OK before any build or deploy; announce on the agent bus before disrupting a shared host; and agent
output is advice only, never approval. A session the owner starts and directs follows the owner's instructions and the
repository's own rules instead.

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
- An approved `plan/` may name other implementers per step (`coders:`)
  and extra read-only reviewers (`reviewers:`). Follow it with the
  `handoff` and `second-opinion` skills. Steps and reviews it does not name
  follow the rules above.
- When the prompt hook says `agent-team: on`, Codex and agy are on the
  team for every task under the artifact workflow (not exempt ones):
  - Before stopping on an intent, spec or plan draft, review it with
    both through `second-opinion`, in parallel and read-only, and show
    their findings (confirmed, refuted, unverified) with the draft.
  - Every draft plan fills `coders:` for each step that edits files and
    `reviewers: [codex, agy]`, one reason per entry. Default routing:
    large mechanical edits → agy; small tricky logic → codex; the rest
    → coder; builds, reviews, deploys and commits stay yours.
  - The user opts out by deleting entries before approving the plan.
  - A provider that fails or is out of quota is reported verbatim; carry
    on without it. Their output never approves anything.
  - `agent-team: off`: none of this applies.
- Finish a step the coder hands back yourself, then commit and update `plan/`
  for any deviation it reported. The PR says which steps the coder did.
- This applies to committed, approved `plan/` files only. A plan that exists
  only in the conversation stays with you.
