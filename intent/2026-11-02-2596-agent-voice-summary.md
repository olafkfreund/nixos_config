---
status: draft
issue: 2596
author: olafkfreund
---

# Intent: spoken summaries from Claude Code, Codex and agy

## Problem

Claude Code, Codex and agy finish a turn silently. To know what happened you
have to go back to the terminal and read the whole reply, which is often long
and full of paths, diffs and command output.

The desktop already has a voice (`omarchy-voice`: ElevenLabs with Piper as the
offline fallback), but only its own Super+M assistant uses it. The coding agents
never speak.

## Proposed outcome

When Claude Code, Codex or agy finishes a turn, a calm voice says a short
summary of two or three sentences: what was done and anything that needs your
attention. It never reads code, paths, diffs or the full reply.

It then offers more ("want the details?"), and the full explanation is spoken
only if you ask for it.

The same behaviour works for all three agents, and one switch turns it on or
off (for meetings, or for long unattended runs).

## Affected users and systems

- The user, on p620 and razer (the hosts with omarchy-voice and the agents).
- Claude Code, Codex and agy configuration (hooks/notify), managed through
  home-manager in this repo.
- omarchy-voice (reused for speech, not changed).
- Not p510.

## Constraints

- Must reuse the existing speech path (ElevenLabs → Piper). No second TTS
  stack.
- The summary is written by a model. Prefer local Ollama so no extra cloud
  call or key is needed. Subscription login only, never an API key (#1831).
- Must not block or slow the agent: speaking happens after the turn, in the
  background.
- Must not talk over itself: subagents, parallel sessions and Codex/agy runs
  that Claude delegates (handoff, second-opinion) stay quiet or queue.
- No secrets in the Nix store. `~/.claude` and `~/.gemini` are
  syncthing-synced, so do not put nix-store symlinks into them.

## Open questions

1. **Voice:** keep Tarquin (posh RP, what omarchy-voice uses now), or a calmer
   voice just for the narrator, such as Lily (warmer) or Alice (neutral)?
2. **"Want to hear more?"** Options: (a) a desktop notification with a "Tell
   me more" action; (b) a key binding that speaks the full explanation of the
   last turn; (c) a spoken yes/no by microphone. (a) or (b) is cheap; (c) means
   keeping the microphone open after every turn.
3. **When to speak:** after every turn, or only after long turns (for example
   over a minute) and turns that wait on you for input or approval?
4. **Default:** on by default, or off until switched on?
