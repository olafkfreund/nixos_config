---
status: approved
issue: 2062
author: olafkfreund
---

# Intent: Claude's standing instructions match how Opus 5.5 is meant to be prompted

## Problem

Claude Code here runs Claude Opus 5.5 at effort `medium`. Anthropic's
prompting guides for Opus 5.5, Opus 5 and current models in general say
several things our standing instructions contradict:

- **Aggressive language over-triggers.** "Dial back any aggressive language.
  Where you might have said 'CRITICAL: You MUST use this tool when...', you
  can use more normal prompting."
- **General beats prescriptive.** "Prefer general instructions over
  prescriptive steps … Claude's reasoning frequently exceeds what a human
  would prescribe."
- **No explicit verification on Opus 5 and later.** It "verifies its own
  work without being told to"; instructions like "include a final
  verification step" or "double-check your answer" "cause over-verification
  … remove them".
- **Parallel tool calls are a strength.** Independent calls should run
  together, and dependent ones in order.
- **Delegation needs a cap.** The model "delegates to subagents more
  readily than prior models". Claude Code offers
  `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` and
  `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` as deterministic caps.

What we run instead:

1. **The PARR protocol, twice.**
   - `modules/programs/parr-protocol.txt` is injected by a
     `UserPromptSubmit` hook (`claude-code-managed.nix`) on every prompt.
   - `~/.claude/CLAUDE.md` (a local, Syncthing-synced file, not in this
     repo) carries a longer version.
   - Both use "MANDATORY / CRITICAL / NEVER" and mandatory per-phase output
     templates.
   - Both say "execute exactly ONE step … NEVER chain commands", which works
     against parallel tool calls.
   - Both require a REFLECT block after every step, plus final quality
     gates.
2. **Three output-style sources that disagree.** PARR's templates, the
   `ponytail` plugin's SessionStart hook ("at most three short lines";
   enabled in `~/.claude/settings.json`), and Claude Code's own guidance.
3. **No subagent caps** anywhere.

`parr-protocol.txt` also feeds the global rules for Codex and Antigravity
(`home/development/agent-rules.nix`), so it isn't Claude-only today.

## Proposed outcome

- Claude's standing instructions are short and calm, and give their
  reasons. They keep what matters and drop the rest:
  - keep: brief intent before work, and outcome-first reports;
  - keep: evidence before claiming success;
  - keep: stop and ask after two failed attempts;
  - keep: the destructive-action and host rules;
  - drop: per-step templates, capitals, and forced per-step reflection.
- Independent steps run in parallel. Only dependent steps are sequenced.
- One source decides output style.
- Subagent concurrency and depth have hard caps.
- The intent → spec → plan gates, the hook-enforced guards (p510, the bus,
  the shared checkout) and `AGENTS.md` are unchanged. They already follow
  the guidance.

## Affected users and systems

- **Claude Code on p620, razer and p510,** through
  `modules/programs/claude-code-managed.nix` (the hook, and managed `env`).
- **The PARR text.** The Claude hook would read its own new file.
  `parr-protocol.txt` stays for Codex and Antigravity unless decided
  otherwise.
- **Local files outside the repo, edited by hand after approval:**
  `~/.claude/CLAUDE.md` (the PARR section) and `~/.claude/settings.json`
  (`ponytail`, depending on decision 2).
- Deploy: p620 and razer; p510 only on request.

## Constraints

- Claude-only. Codex and Antigravity keep their current global rules.
- No weakening of safety: the p510, bus and shared-checkout hooks, the
  destructive-action rules and the artifact gates stay as they are.
- `~/.claude` is Syncthing-synced, so no store symlinks inside it (see the
  memory note on syncthing-managed dirs).

## Open questions

1. **Replace or remove the PARR hook?**
   - (a) Replace its text with a short, calm instruction of four or five
     lines on every prompt.
   - (b) Remove the hook and keep one short section in the managed
     `CLAUDE.md` policy file, which is read once per session, not injected
     each turn.

   I recommend (b). A standing instruction doesn't need re-injecting every
   turn, and it's cheaper.
2. **Which source owns output style?**
   - (a) A short outcome-first instruction from the guide, and disable
     `ponytail`.
   - (b) Keep `ponytail` and drop output rules from PARR.

   I recommend (a): `ponytail` is a code-minimalism plugin whose output
   rules ("code first, at most three lines") clash with review and report
   work.
3. **Cap values:** `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=4` and
   `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`? These are proposed starting
   values.
4. **`~/.claude/CLAUDE.md`:** trim its PARR section to match, or delete that
   section, since the managed policy would carry it?
