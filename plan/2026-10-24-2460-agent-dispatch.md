---
status: approved
issue: 2460
spec: spec/2026-10-24-2460-agent-dispatch.md
---

# Plan: let Claude dispatch Codex and agy per plan, without being asked each time

## Approved decisions (from intent and spec)

- **Two optional plan frontmatter fields.**
  - `coders:` maps a step number to `coder`, `agy` or `codex`. Unlisted
    steps keep today's default, and the planner's own steps (builds,
    reviews, deploys) can't be assigned.
  - `reviewers:` lists `codex` and/or `agy` as extra read-only reviews. The
    fresh Opus review always runs.
- **Claude may propose both in a draft plan**, with a one-line reason per
  dispatched step. The user's plan approval is the consent. No change after
  approval without re-approval. Only Claude dispatches; Codex and agy never
  start other agents.
- **Policy wording** everywhere: "when the user asks, or when an approved
  `plan/` names it".
- **On a failed handoff**, Claude does the step or gives it to the `coder`,
  and notes the fallback in the PR.
- **`team` is out of scope.** Guards, read-only review modes and the agy
  probe gate don't change.

## Steps

The plan touches five files, so per the model split, steps 1–4 go to a new
`coder` agent. Steps 5–6 are mine.

1. **`home/development/claude-code-skills/artifact-workflow/SKILL.md`.**
   - In the plan template (lines 106–111), add after `spec: spec/<slug>.md`:

     ```yaml
     coders:        # optional: step number -> coder | agy | codex; unlisted steps use the default
       3: agy
     reviewers:     # optional: extra read-only reviews (codex, agy) on top of the Opus review
       - codex
     ```

   - In Rules (after line 42), add one bullet: "A plan may name who
     implements a step (`coders:`) and extra read-only reviewers
     (`reviewers:`), each with a one-line reason in the plan. Only Claude
     proposes and dispatches them. The user's plan approval is the consent,
     and they never change after approval without re-approval."
   - Verify: markdownlint on the file → 0 errors.
   - Traps:
     - This body is inlined into `~/.codex/AGENTS.md` and
       `~/.gemini/AGENTS.md` by `agent-rules.nix`, which asserts the text
       has no `Model split`, `Load it` or `name: artifact-workflow`. Don't
       write any of those phrases.
     - A line starting with `#` plus digits becomes a heading.

2. **`modules/programs/claude-code-managed-claude.md`, Model split section.**
   After the "Review with a fresh agent …" bullet (lines 42–43), add:
   "- An approved `plan/` may name other implementers per step (`coders:`)
   and extra read-only reviewers (`reviewers:`). Follow it with the
   `handoff` and `second-opinion` skills. Steps and reviews it does not name
   follow the rules above."
   - Verify: markdownlint → 0 errors.
   - Traps: don't touch the `## Model split (Claude Code only)` heading,
     because `agent-rules.nix:9` splits on it.

3. **`AGENTS.md`.**
   - Lines 51–52 and 56–57: "or that Claude starts at the user's request"
     becomes "or that Claude starts at the user's request or because an
     approved `plan/` names it in `coders:`". Re-wrap to the file's width.
   - Line 241–242: "Consult other models (Codex, Antigravity) only when the
     user asks, through the `second-opinion` skill. Never on your own
     initiative." becomes "Consult other models (Codex, Antigravity) only
     when the user asks or an approved `plan/` names them in `reviewers:`,
     through the `second-opinion` skill. Never on your own initiative
     otherwise."
   - Verify: markdownlint → 0 errors.
     `grep -c "approved \`plan/\` names" AGENTS.md` → 3.
   - Traps: the bus guard greps shell command text, so make prose edits with
     the Edit tool.

4. **The `handoff` and `second-opinion` skills.**
   - `home/development/claude-code-skills/handoff/SKILL.md`:
     - Frontmatter `description` (lines 3–6): append "…, or when the approved
       `plan/` names agy or codex for the step in `coders:`." in place of
       "Never on your own initiative." (keep that sentence as "Never
       otherwise.").
     - "When", line 16: "Only when the user asks." becomes "When the user
       asks, or when the approved `plan/`'s `coders:` names agy or codex for
       this step."
     - "A handoff failed when", after "Otherwise report the failure to the
       user and do the step yourself.": add "For a step dispatched by
       `coders:`, you may give it to the `coder` instead. Note the fallback
       in the PR."
   - `home/development/claude-code-skills/second-opinion/SKILL.md`:
     - Frontmatter `description`: "Use only when the user explicitly asks …
       or invokes `/second-opinion`" gains "…, or when an approved `plan/`
       lists the provider in `reviewers:`". "Never use it on your own
       initiative" becomes "Never otherwise".
     - "When to use", lines 19–22: the same addition to the first bullet. In
       the second bullet, "Never on your own initiative" becomes "Never
       otherwise". Keep "never as approval for an artifact gate, and never
       ask again or ask another model until one agrees".
   - Verify: markdownlint on both → 0 errors. `grep -n "Only when the user
     asks"` on both → no match. Both frontmatters still parse:
     `nix eval --raw .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.file.".claude/skills/handoff/SKILL.md".source`
     (or the attribute that `claude-code-skills/default.nix` uses) builds.
   - Traps: a skill's `description` decides when it triggers, so keep it one
     YAML folded scalar (`>-`), with no colon-space inside the text.

5. **Mine: build and review.**
   - Run `just check-syntax`, `just test-host p620` and
     `just test-host razer`. The `agent-rules.nix` asserts run here.
   - Then grep the built files:
     - the p620 Home Manager generation's `.codex/AGENTS.md` and
       `.gemini/AGENTS.md` contain `coders:` and not `Model split`
     - the p620 toplevel's `etc/claude-code/CLAUDE.md` contains
       `reviewers:`
   - Then a fresh `opus` reviewer, given only this plan and `git diff`. Check
     especially that no text lets Codex or agy dispatch, or lets Claude
     dispatch without an approved plan.
   - Traps: write commit bodies to a file (`-F`).

6. **Mine: roll out and PR.**
   - Post on the agent bus, then `just quick-deploy p620` and
     `just deploy-via-p620 razer` from the worktree with
     `ALLOW_BRANCH_DEPLOY=1`, after merging main.
   - Check that `/etc/claude-code/CLAUDE.md` on each host has the new
     bullet.
   - **p510 is not deployed.** It picks the text up at its next approved
     deploy.
   - Open the PR linking the three files, saying which steps the coder did,
     and that p510 still has the old text.
   - Traps: p510 is never deployed without asking. Merge main first.

## Tests

```bash
just check-syntax && just test-host p620 && just test-host razer
markdownlint-cli2 --config .markdownlint.json AGENTS.md modules/programs/claude-code-managed-claude.md \
  home/development/claude-code-skills/{artifact-workflow,handoff,second-opinion}/SKILL.md
grep -c 'approved `plan/` names' AGENTS.md   # → 3
```

The first real proof is the next approved plan that sets `coders:` or
`reviewers:`.

## Rollback

Revert the PR's squash commit and redeploy p620 and razer. Every text goes
back to "only when the user asks", and plans that set the fields simply
aren't dispatched.
