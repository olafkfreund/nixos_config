---
status: approved
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

- **A spike settles feasibility first.** On p620, with the owner's subscription login, inside a real herdr
  pane, it reports pass or fail for each of these:
  1. `agy acp` takes a prompt and returns the full reply with `end_turn`.
  2. A second turn resumes the same conversation and recalls something given only in the first.
  3. It runs without stopping on permission requests.
  4. agy's own hooks still fire under `acp`, so the `agy-implement` guard (#2087/#2291) holds. This one is
     required for an implementer.
  5. herdr-team's pane contracts can be met. Today `up`, `ask` and `finish` depend on:
     - herdr reporting the pane's agent as `agy` (`same_pane`, herdr-team.sh:159);
     - `h agent prompt` delivering the pointer to the pane (:495);
     - an interrupt marker on screen (:409, Codex's `■ Conversation interrupted`);
     - a clean exit 0 after `ctrl+c` in `finish` (:803–821).

     The spike says which of these an ACP client in the pane can meet and which need herdr-team changes.
- **If the spike passes:**
  - `herdr-team up <task> agy-implement` opens a visible pane, where the owner watches an agy implementer's
    conversation.
  - Its replies land in `<work>/turns/` in the shape `herdr-team-sink` writes for Codex.
  - `ask`, `converse`, `finish`, the archive and the marker-based stopping (#2818) all work for it. Any
    herdr-team changes they need are part of this task.
  - `agyMember` becomes true.
- **If the spike fails:** the issue records why, and `agyMember` stays false.

## Affected users and systems

- `home/development/herdr-team.sh`, `home/development/agent-run.nix` (`agyMember`), a new small ACP client
  (script or package), `home/development/herdr-team-test.sh`.
- `docs/applications/herdr.md`, and the `handoff` and `second-opinion` skills' note that agy steps stay on
  `agent-run`.
- p620 and razer through Home Manager.

## Constraints

- agy keeps running unrestricted (#2812): `--dangerously-skip-permissions` or its ACP equivalent. Every ACP
  permission request is answered "allow", with no path scoping. The member reads its request files in `/tmp`
  and git metadata outside the worktree, and the rules stay instruction-only. No new sandbox is added.
- Subscription login only (#1831). The launch goes through `agent-env`, and the member's argv unsets
  `GEMINI_API_KEY`, `GEMINI_API_KEY_FILE`, `GOOGLE_API_KEY` and the other key variables, as the `review` member
  does today (herdr-team.sh:280).
- No change to how Codex members work.
- The pane must show the conversation (the owner asked to watch the agents), not only a spinner.
- It builds on #2818. Nothing lands until #2818 is merged.
- p510 is not touched.

## Open questions

- Should agy also be offered as a reviewer (an `agy-review` role)? Today a task has one member per role, and
  `review` is always Codex (herdr-team.sh:8, :221). Default: no, `agy-implement` only. A reviewer can follow
  once this works.
- If spike item 4 fails, so agy's hooks do not fire under `acp`: is there any acceptable implementer path, for
  example the guard run by the ACP client itself, or does the task stop? Default: stop and report.
