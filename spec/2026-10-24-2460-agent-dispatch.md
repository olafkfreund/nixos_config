---
status: approved
issue: 2460
intent: intent/2026-10-24-2460-agent-dispatch.md
---

# Spec: let Claude dispatch Codex and agy per plan, without being asked each time

## Design

### 1. Two optional plan frontmatter fields

These are documented in the plan template in
`home/development/claude-code-skills/artifact-workflow/SKILL.md`:

```yaml
---
status: draft
issue: <n>
spec: spec/<slug>.md
coders:        # optional: who implements a step; unlisted steps follow the model split
  3: agy
  4: codex
reviewers:     # optional: read-only reviewers added to the fresh Opus review
  - codex
---
```

- **`coders:`** maps a step number to `coder`, `agy` or `codex`.
  - A step that isn't listed follows the model split as today: the Sonnet
    `coder` at three or more editing steps or files, otherwise Claude itself.
  - Naming `agy` or `codex` overrides the threshold for that step.
  - The steps marked "Mine" in a plan, such as builds, reviews and deploys,
    can't be assigned.
- **`reviewers:`** lists `codex` and/or `agy`.
  - The fresh Opus reviewer *always* runs, because the policy requires it
    (decision 3). These are extra reviews on top of it.
  - They run through the `second-opinion` paths, which stay read-only:
    `codex review` and `agy --mode plan`.
  - With the field absent, only Opus reviews, as today.
- **Claude may propose both fields in a draft plan** (decision 2). The plan
  must say why, in one line per dispatched step: for example "agy: large
  mechanical edit, frees the coder", or "codex: second view on the guard
  logic". The user's plan approval is the consent. Claude never adds or
  changes either field after approval without the user re-approving.
- **Template text** goes into the plan template block and one rule line in
  the skill's Rules list. That `SKILL.md` body is inlined into
  `~/.codex/AGENTS.md` and `~/.gemini/AGENTS.md` by
  `home/development/agent-rules.nix`, so Codex and agy also see what the
  fields mean. That is wanted, because they read the plans.

### 2. Policy texts: "when the user asks, or when an approved `plan/` names it"

- **Managed CLAUDE.md** (`modules/programs/claude-code-managed-claude.md`,
  "Model split" section, line 32 on): add one bullet after the review bullet.
  An approved `plan/` may name other implementers per step (`coders:`) and
  extra read-only reviewers (`reviewers:`). Follow it with the `handoff` and
  `second-opinion` skills. Steps and reviews it doesn't name follow the
  rules above. Keep the heading text exactly as it is, because
  `agent-rules.nix` splits on `"\n## Model split (Claude Code only)"`.
- **`AGENTS.md:51-59`:** in the Codex and agy bullets, "that the user starts,
  or that Claude starts at the user's request" becomes "that the user starts,
  or that Claude starts at the user's request or because an approved `plan/`
  names it in `coders:`".
- **`AGENTS.md:241`:** "Consult other models … only when the user asks …
  Never on your own initiative" becomes "only when the user asks or an
  approved `plan/` names them in `reviewers:` … Never on your own
  initiative otherwise".
- **`handoff` skill** (`home/development/claude-code-skills/handoff/SKILL.md`):
  - In the frontmatter `description`, and under "When": "Only when the user
    asks" becomes "when the user asks, or when the approved `plan/`'s
    `coders:` names agy or codex for the step".
  - Add: "If a dispatched step fails (the existing failure list), do the
    step yourself or give it to the `coder`, and note the fallback in the
    PR."
- **`second-opinion` skill:** the same change to `description` and "When to
  use", for `reviewers:`. Everything under "What this skill will not do"
  stays: read-only, never an approval, and never ask again until one agrees.

### 3. Out of scope (decision 1)

The `team` command keeps Claude-only workers. A follow-up issue can be
opened if it's wanted.

## Alternatives rejected

- **Dispatch through a field in the intent or spec.** Approval of the *how*
  belongs in the plan, which is the artifact that names steps. Earlier
  stages don't have step numbers.
- **`reviewers:` replacing the Opus review.** The managed policy requires the
  fresh Opus review, and decision 3 keeps it as the default. Other providers
  only add to it.
- **A free-form "dispatch" section in the plan body.** Frontmatter is
  machine-checkable and sits next to `status:`, so it's visibly part of what
  was approved.
- **Letting Claude choose the tool per step at run time.** That is exactly
  the "own initiative" the policy forbids. The approved plan is the consent.

## Risks

- **Quota.** Each dispatched step or extra reviewer spends subscription
  quota. That is bounded, because only an approved plan can ask for it.
- **The policy text is read by several agents.** A wording slip could let
  Codex or agy read the new fields as permission to dispatch each other. The
  `SKILL.md` rule says only Claude dispatches. Codex and agy run under their
  coder guards and never start other agents.
- **`agent-rules.nix` assertions.** The managed policy is split on the
  "Model split" heading, and three asserts guard the output. Changing the
  heading, or leaking the section, fails evaluation loudly. That's a build
  error, not silent drift.
- **Hosts.** The managed CLAUDE.md reaches every host that runs Claude Code,
  p510 included. p620 and razer pick it up at their next deploy. **p510 only
  when you approve its deploy**, as always. Until then p510 keeps the old,
  stricter text, which is safe.

## Verification

- `just check-syntax`, then `just test-host p620` and `just test-host razer`.
  The `agent-rules.nix` asserts run during evaluation.
- In the built Home Manager generation:
  - `~/.codex/AGENTS.md` and `~/.gemini/AGENTS.md` contain the new `coders:`
    and `reviewers:` template text, and no "Model split".
  - `/etc/claude-code/CLAUDE.md` in the p620 toplevel contains the new
    model-split bullet.
- markdownlint passes on every edited `.md` file.
- `grep -n "at the user's request" AGENTS.md` shows the new wording in both
  bullets, and `grep -n "Only when the user asks"` finds nothing in the two
  skills.
- **The first real use** is the proof: the next approved plan that sets
  `coders:` or `reviewers:` dispatches without a chat request, and its PR
  says which tool did which step.
