---
status: draft
issue: 2081
author: olafkfreund
---

# Intent: Codex may write code for approved plans

## Problem

Issue #1831 set up delegation to other providers as read-only, and said
coding workers would come in "a separately approved phase". This issue is
that phase. The rule is written down in three places:

- **`AGENTS.md` ("Delegating to other models").** It says "Codex, agy and
  Ollama draft and review; they never write a commit", allows only
  read-only modes, and bans `codex exec` with write access and
  `agy --mode accept-edits` against this tree.
- **The `second-opinion` skill.** It calls those write modes "deliberately
  unused".
- **The Codex and Antigravity global rules.** They repeat it, because
  `home/development/agent-rules.nix` copies it into them.

That section was written about Codex being *called by another agent* as a
drafter or reviewer. Codex's own global rules carry the same text, though,
so a Codex session you start yourself reads it as a ban on writing any
code. The wording does not separate the two cases.

Issue #2079 splits Claude's work by model: Opus plans and reviews, and a
Sonnet coder writes the code. Codex can do the same with OpenAI's three
current models, and the saving is bigger than Claude's. On OpenAI's
standard rates, Astra costs 5 times as much as Sol:

| Model         | Input / cached / output per MTok | Codex credits per MTok (output) |
| ------------- | -------------------------------- | ------------------------------- |
| `gpt-6-astra` | $10 / $1 / $50                   | 1,250 |
| `gpt-6-sol`   | $2 / $0.20 / $10                 | 250 |
| `gpt-6-luna`  | $0.10 / $0.01 / $0.50            | 12.5 |

On the ChatGPT subscription, every model draws on one shared allowance at
these different rates.

## Proposed outcome

- **A Codex session you start may write code** for an approved `plan/`,
  in a task worktree. `AGENTS.md`, the `second-opinion` skill and the
  generated Codex/Antigravity rules all say so in the same words.
- **Codex called by another agent stays read-only.** Second opinions
  through `second-opinion` are unchanged, and Claude keeps its own Sonnet
  coder (#2079).
- **Codex switches model by stage, not by spawning agents.**
  - The session default stays `gpt-6-sol`, and Sol writes the code once
    the plan is approved.
  - Astra (`/model gpt-6-astra`, or `codex -m gpt-6-astra`) writes intent,
    spec and plan, and decides any major revision.
  - `/review` runs on Astra through a top-level
    `review_model = "gpt-6-astra"`.
  - Luna is only for narrow searches and mechanical, well-scoped edits.
    It is never the default for Nix work.

  The approval gates are where the session pauses anyway, so they are the
  natural points to switch. No extra agent is spawned just to change
  model; OpenAI's docs note that multi-agent runs use more tokens than a
  single agent doing the same work.
- **The same limits as Claude's coder.** No deploys, service restarts,
  garbage collection or reboots. No commits to `main`, and no branch
  checkouts in the shared `~/.config/nixos` checkout.
- **The sandbox stays on.** `HUMANIZE_CODEX_BYPASS_SANDBOX` and any sandbox
  bypass stay banned.
- **Approval stays with you.** Codex output never approves an intent,
  spec or plan, and never merges its own PR.
- **Savings are measured, not assumed.** Codex's `/status` and the usage
  dashboard are recorded over a few real issues, including the review and
  rework each one needed.

## Affected users and systems

- **Rules.** `AGENTS.md` (the "Delegating to other models" section) and
  the `second-opinion` skill
  (`home/development/claude-code-skills/second-opinion/SKILL.md`).
- **Generated agent rules.** `home/development/agent-rules.nix` and
  `home/development/agent-rules/codex-standards.md`, which become
  `~/.codex/AGENTS.md` and `~/.gemini/AGENTS.md`.
- **Codex configuration.** `~/.codex/config.toml` gets the top-level
  `review_model`. Codex writes that file itself, and Nix writes nothing
  declarative there (`home/development/codex-cli.nix`), so the setting
  goes in through the existing activation step, not a managed file.
- **Hosts.** p620 and razer, where Codex is used. p510 only with your
  approval, as always.

## Constraints

- **Enforced, not remembered.** Codex has no agent-scoped hook like
  Claude's coder guard, so the limits have to come from its sandbox and
  approval policy, not from the model remembering them.
- **Subscription login only.** Never an API key (#1831).
- **Shared working tree.** Codex's spawned agents share one working tree
  ("edits made by one agent are immediately visible to all other agents"),
  which is one more reason to switch models instead of spawning.
- **Depends on #2079.** It uses #2079's self-contained plan template and
  its list of forbidden actions, so it lands after #2079.

## Open questions

1. **Scope.** Is it Codex only? The same reasoning covers Antigravity
   (`agy --mode accept-edits`), but Ollama's cloud models have no
   filesystem access through their MCP tool and stay draft-only. The
   proposal is Codex now, and Antigravity as a follow-up.
2. **Commits.** Does Codex commit on the task branch, or leave commits to
   you?
3. **Sandbox and approval.** Is `workspace-write` with network off and an
   approval policy of `on-request` enough? Or should the settings be
   pinned in a Codex profile used only for implementation (for example
   `codex -p implement`)?
4. **Remembering to switch.** Does anything remind you to switch model at
   each gate? One option is to state the model in the gate's "stop for
   review" message. Otherwise it is left to the person running the
   session.
