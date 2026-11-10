---
status: draft
issue: 2828
author: olafkfreund
---

# Intent: agy as a herdr-team member through `agy acp`

## Problem

Mixed agent teams inside herdr (#2810) can only seat Codex. agy is refused as a member while `agyMember = false`
(`home/development/agent-run.nix:4`, `home/development/herdr-team.sh:222`). The reason is that an answer must be
the agent's own end-of-turn reply, and agy's turn-end hook (`Stop`) carries no reply text. #2810 step 4 failed
on exactly that. So agy steps stay on headless `agent-run`, where the owner cannot watch or steer them and agy
cannot take part in `converse`.

`agy acp` (agy 1.5.3) runs agy as an Agent Client Protocol server over stdio:

- turns are sent with `session/prompt`;
- reply text streams as `session/update` `agent_message_chunk` events;
- a turn ends with `stopReason: "end_turn"`;
- `session/load` resumes a conversation.

That is the reply and the end-of-turn signal the hook lacks. Prior art is danielyaa5/orchestrate-agents
`scripts/google_worker.py` (MIT).

## Proposed outcome

- **A spike settles feasibility first.** On p620, with the owner's subscription login, it shows that the
  following work, or reports which one fails:
  - `agy acp` takes a prompt and returns the full reply with `end_turn`;
  - it resumes the same conversation on a second turn, which recalls something given only in the first;
  - it does not stop on permission requests.
- **If the spike passes:**
  - `herdr-team up <task> agy-implement` (and `review`, if useful) opens a visible pane where an agy member runs.
  - Its replies land in `<work>/turns/` in the same shape Codex's `notify` writes. So `ask`, `converse`,
    `finish`, the archive (#2818) and the marker-based stopping work unchanged.
  - `agyMember` becomes true.
- **If the spike fails:** the issue records why, and `agyMember` stays false.

## Affected users and systems

- `home/development/herdr-team.sh`, `home/development/agent-run.nix` (`agyMember`), a new small ACP client
  (script or package), `home/development/herdr-team-test.sh`.
- `docs/applications/herdr.md`, and the `handoff` and `second-opinion` skills' note that agy steps stay on
  `agent-run`.
- p620 and razer through Home Manager.

## Constraints

- agy keeps running unrestricted (#2812): `--dangerously-skip-permissions` or its ACP equivalent. The rules
  stay instruction-only, so ACP permission requests are answered "allow" for the member's worktree, and no new
  sandbox is added.
- Subscription login only. No `GEMINI_API_KEY`/`GOOGLE_API_KEY` (#1831), launched through `agent-env`.
- No change to how Codex members work.
- The pane must show the conversation (the owner asked to watch the agents), not only a spinner.
- It builds on #2818. Nothing lands until #2818 is merged.
- p510 is not touched.

## Open questions

- Should the ACP client be a small Python script (stdlib only, like the prior art) or bash with `jq` and a
  coprocess? Default: Python, because JSON-RPC over a pipe is fragile in bash.
- Does agy enforce its own hooks (the `agy-implement` guard, #2087/#2291) under `acp`? If not, an agy
  implementer through ACP loses the guard preflight. Default: the spike checks this, and an agy implementer
  needs the guard.
