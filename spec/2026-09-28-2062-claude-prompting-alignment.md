---
status: approved
issue: 2062
intent: intent/2026-09-28-2062-claude-prompting-alignment.md
---

# Spec: Claude's standing instructions match how Opus 5.5 is meant to be prompted

Decisions on the intent's open questions, 2026-09-28:

| # | Question | Decision |
| --- | --- | --- |
| 1 | PARR delivery | **PARR stays.** Keep the per-prompt hook, rewrite its text calmly |
| 2 | Output style | One outcome-first line in the PARR text; disable `ponytail` |
| 3 | Subagent caps | 4 concurrent, spawn depth 1 |
| 4 | `~/.claude/CLAUDE.md` | Remove its PARR section; the hook carries PARR |
| 5 | Other agents (amendment) | **One PARR text for every agent.** Rewrite `parr-protocol.txt` in place |

Decision 1 is the user's explicit choice ("we still will use PARR right?").
It replaces the intent's recommendation (b), which would have moved PARR
into the managed policy and removed the hook.

**Amendment (decision 5), given by the user when approving this spec:**
"make this change … so the other agents can use this new version as
well". That lifts the intent's Claude-only constraint for the PARR text
alone. Codex and Antigravity already get PARR from their generated global
files (`~/.codex/AGENTS.md`, `~/.gemini/AGENTS.md`), which
`home/development/agent-rules.nix` builds from `parr-protocol.txt`, so the
single source is that file. The repo `AGENTS.md` is not changed:

- PARR is a global working method, not a rule for this repo.
- Claude already reads `AGENTS.md` natively (#2031, `CLAUDE.md` retired),
  so adding PARR there would duplicate the hook.
- It would only apply inside this repo.

The subagent caps, the output-style change and the `~/.claude` edits stay
Claude-only.

## Design

### 1. One calm PARR text for every agent, still injected into Claude on every prompt

`modules/programs/parr-protocol.txt` is rewritten in place (decision 5) to:

```text
Work in PARR: Plan, Act, Reflect, Revise.
- Plan: before acting on a non-trivial task, state the goal and your
  approach in a few lines.
- Act: run independent steps in parallel; sequence only steps that depend
  on each other.
- Reflect: at real checkpoints, check the result against evidence (command
  output, tests) before building on it.
- Revise: when something fails, find the cause before retrying; after two
  failed attempts, stop and ask.
If an approved plan/ exists for the task, cite the plan step you are
executing rather than re-planning. When you report, lead with the outcome;
keep progress notes brief.
```

`claude-code-managed.nix` is unchanged in this respect: `parrReminderScript`
already cats `parr-protocol.txt` inside the `<system-reminder>` wrapper.
The hook, `parrProtocol.enable` and the three hosts' `parrProtocol.enable =
true` stay as they are. The same file keeps feeding
`home/development/agent-rules.nix`, which adds a `## PARR protocol` heading
and has no assertion on the PARR wording, so Codex and Antigravity get the
new text at the next Home Manager activation.

What changes against today's text, and the guidance behind each change:

- **No "MANDATORY / CRITICAL / NEVER", and no emoji section templates.**
  The guides say to dial back aggressive language and to prefer general
  instructions over prescriptive steps.
- **"Execute exactly ONE step … NEVER chain" becomes "parallel where
  independent".** The guides treat parallel tool calls as a strength.
- **"Reflect after EACH step" becomes "at real checkpoints, against
  evidence".** Explicit verification on every step causes
  over-verification on Opus 5+.
- **Kept:** plan first, stop after two failed attempts, cite the approved
  plan step, and PARR itself.


### 2. The managed policy line that names PARR's phase

In `modules/programs/claude-code-managed-claude.md`, "While implementing,
the PARR PLAN phase cites the plan step being executed." becomes "While
implementing, name the plan step you are executing (PARR's Plan phase)." It
means the same thing, and it no longer relies on the old section names.

### 3. Subagent caps

In `mergedSettings`, add managed `env`:

```nix
env = {
  CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS = "4";
  CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH = "1";
} // (cfg.settings.env or { });
```

A host's own `settings.env` still wins. Both variables are present in the
installed Claude Code (2.1.283; the docs require 2.1.217 or later),
confirmed with `strings` on the binary.

### 4. Local edits after deploy (outside the repo)

- **`~/.claude/CLAUDE.md`:** delete the "Expert Reasoning Protocol
  (MANDATORY)" section, from its heading through "Example Cycle" and the
  "COMPLETE" template. Keep the header and "Global Standards". Take a backup
  first. The file is Syncthing-synced, so the edit reaches every host.
- **`~/.claude/settings.json`:** set `"ponytail@ponytail": false` under
  `enabledPlugins`.

## Alternatives rejected

- **Remove the hook and move PARR into the managed policy** (the intent's
  recommendation): the user wants PARR reinforced every turn.
- **A separate Claude-only PARR file** (the spec before decision 5): the
  agents would drift apart, and the user wants one PARR for all of them.
- **Put PARR in the repo `AGENTS.md`:** it would duplicate Claude's hook
  and apply only inside this repo, while PARR is global.
- **Keep `ponytail` and drop output rules from PARR:** its "code first, at
  most three lines" rule clashes with review, report and planning work.

## Risks

- **Less forceful wording makes Claude skip the plan on real work**
  (all Claude sessions): the hook still fires every prompt. Watch the next
  few multi-step tasks, and add one plain sentence if planning drops off.
  Don't bring back capitals.
- **Codex and Antigravity plan less without the forceful wording** (the
  other agents): they get the same calm text as Claude. Check one Codex
  review and one Antigravity plan run after deploy.
- **A subagent cap of 4 slows a genuinely wide fan-out** (Workflow runs):
  hosts can raise it through `settings.env`.
- **Losing `ponytail`'s code-minimalism push** (coding tasks): the repo's
  rules and review still cover over-engineering. Re-enable it if missed.

## Verification

1. **Build:** `just check-syntax`, `just test-host p620` and `just test-host
   razer`. In p620's `managed-settings.json`:
   - `.env.CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS == "4"` and the depth is
     `"1"`;
   - the `UserPromptSubmit` hook script outputs the new text inside
     `<system-reminder>`, with no "MANDATORY", no emoji and no "ONE step".
2. **Codex and Antigravity get the new PARR:** the built `~/.codex/AGENTS.md`
   source (and `~/.gemini/AGENTS.md`, the same store file) contains
   "Work in PARR: Plan, Act, Reflect, Revise." and no "MANDATORY" or
   "ONE step". Apart from the PARR section, the file is unchanged.
3. **Live, after deploy:** a fresh Claude session's reminder shows the new
   PARR text; `~/.claude/CLAUDE.md` no longer has the Expert Reasoning
   Protocol; `claude plugin list` (or the settings file) shows `ponytail`
   disabled.
