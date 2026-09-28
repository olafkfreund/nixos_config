---
status: approved
issue: 2062
spec: spec/2026-09-28-2062-claude-prompting-alignment.md
---

# Plan: Claude's standing instructions match how Opus 5.5 is meant to be prompted

Branch `docs/2062-claude-prompting-alignment`, in a worktree. The shared
checkout is not touched.

## Approved decisions

These are carried over from the spec, including its two amendments.

**D1. One calm PARR for every agent.** `modules/programs/parr-protocol.txt`
is rewritten in place to exactly:

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
keep progress notes brief. For code, follow ponytail (the smallest correct
change); for reports, reviews and plans this reporting rule comes first.
```

- The Claude hook (`parrReminderScript`, which cats this file inside
  `<system-reminder>`) and `parrProtocol.enable` on the three hosts are
  unchanged.
- `agent-rules.nix` keeps prepending `## PARR protocol` for Codex and
  Antigravity.
- The repo `AGENTS.md` is not changed.

**D2. Managed policy wording.** In `claude-code-managed-claude.md:28`,
"While implementing, the PARR PLAN phase cites the plan step being
executed." becomes "While implementing, name the plan step you are executing
(PARR's Plan phase)."

**D3. Managed `env`.** In `mergedSettings` (`claude-code-managed.nix`, from
about line 664), add:

```nix
env = {
  CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS = "4";
  CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH = "1";
  PONYTAIL_DEFAULT_MODE = "ultra";
} // (cfg.settings.env or { });
```

**D4. Ponytail for Codex and Antigravity.**
`home/development/agent-rules/global.md` (28 lines) gets the spec's
"Writing code (ponytail, ultra)" section appended after `## Git`, verbatim.

**D5. Local edits, not in the repo.** These happen after deploy, with a
backup first:

- `~/.claude/CLAUDE.md`: delete the "Expert Reasoning Protocol (MANDATORY)"
  section, from its heading through the "COMPLETE" template. Keep the
  header and "Global Standards".
- `~/.claude/settings.json`: leave `"ponytail@ponytail": true` as it is.

## Steps

1. **Baselines** → verify:
   - capture today's hook output, the built `~/.codex/AGENTS.md` source and
     `managed-settings.json` for p620 into the scratchpad;
   - the old hook output contains "MANDATORY".
2. **D1–D4 edits,** made with scripted replacements, not the Edit tool (its
   formatter rewrites whole files) → verify: `just check-syntax`, and
   markdownlint on `global.md`.
3. **Built artefacts** → verify, for p620:
   - `managed-settings.json` `.env` has all three keys;
   - the hook output is the D1 text inside `<system-reminder>`, with no
     "MANDATORY", no emoji and no "ONE step";
   - the new `~/.codex/AGENTS.md` source has the D1 PARR, the ponytail
     section and no "MANDATORY";
   - apart from those two sections, the diff against the step-1 baseline is
     empty.
4. **Build:** `just test-host p620` and `just test-host razer`. p510 is
   evaluated only.
5. **Commit, push, PR** linking the intent, spec and plan. **Merge** on
   green CI (squash, pinned to the head commit).
6. **Deploy p620 and razer:** bus-announced, after checking that the runner
   and `nix-daemon` units are unchanged → verify:
   - 0 failed units;
   - the bars have content at +2 min;
   - a fresh `claude -p` session receives the new reminder;
   - ponytail's default mode resolves to `ultra`;
   - `~/.codex/AGENTS.md` shows the ponytail section.
7. **D5 local edits** → verify: `~/.claude/CLAUDE.md` no longer contains
   "Expert Reasoning Protocol", and the backup exists.

## Deviations

- **Codex had its own PARR copy.** D1 assumed `agent-rules.nix` feeds
  `parr-protocol.txt` to both Codex and Antigravity. It only fed
  Antigravity. Codex's file was built from
  `home/development/agent-rules/codex-standards.md`, which carried a 211-line
  copy of the old "Expert Reasoning Protocol (MANDATORY)" (#1861). To meet
  decision 5 (one PARR for every agent):
  - that section is removed from `codex-standards.md` (Purpose and Global
    Standards stay);
  - Codex's `agentsMd` list gets the same `## PARR protocol` block and
    `parr-protocol.txt` that Antigravity gets.

  Result: both files have the new PARR and the ponytail section, and no
  "MANDATORY" or "ONE step". The Codex file went from 429 lines to 234.
- **Baselines** were built through the flake attribute
  (`home.file.".codex/AGENTS.md".source`), because `nix build` on a bare
  output path does not build it.

## Tests

| # | Check | Expected |
| --- | --- | --- |
| T1 | Hook output (step 3) | D1 text; no MANDATORY, emoji or ONE step |
| T2 | `managed-settings.json` `.env` | the 3 keys with the D3 values |
| T3 | Codex global file | new PARR and the ponytail section; nothing else changed |
| T4 | Builds (step 4) | pass |
| T5 | Live checks (step 6) | as listed there |

## Rollback

- **Before merge:** close the PR.
- **After merge:** `git revert` the step-5 commit and redeploy. PARR,
  `env` and the global rules all return to their previous state.
- **Local edits:** restore `~/.claude/CLAUDE.md` from its backup.
- **Ponytail only:** set `PONYTAIL_DEFAULT_MODE` to `full` in a host's
  `settings.env`.
