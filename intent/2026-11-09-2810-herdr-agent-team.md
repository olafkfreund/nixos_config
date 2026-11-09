---
status: draft
issue: 2810
author: olafkfreund
---

# Intent: herdr-native mixed agent team

## Problem

The mixed agent team (Claude Code leads; Codex and agy draft, review and implement plan steps) runs every Codex
or agy call as a one-shot headless command. `agent-run` → `herdr-run` (`home/development/herdr-run.sh`,
`agent-run.sh`) splits a pane, runs `codex exec`/`codex review` or `agy -p`, closes the pane, and returns a
JSON verdict. The `second-opinion` and `handoff` skills build on that.

What that costs:

- No conversation. A review that needs a follow-up question starts a fresh run with a fresh context.
- The owner cannot see or steer a teammate while it works, because the pane closes when the run ends.
- The agents cannot talk to each other. Every exchange goes through Claude reading a file.

herdr 0.9.5, which is already installed, can start Codex, agy and Claude as named interactive agents in panes and
tabs (`herdr agent start --kind codex|agy|claude`). It also lets one agent prompt another, wait for it and read
its answer (`agent prompt --wait`, `agent read`). herdr ships an agent skill (`herdr --skill`, upstream
`skills/herdr/SKILL.md`) that teaches an agent those commands. None of the three agents has it installed.

## Proposed outcome

- The herdr skill is installed declaratively for Claude Code, Codex and agy, on p620 and razer.
- From Claude Code inside herdr, one command or skill sets up a team tab for a task:
  - a Codex agent and an agy agent in sibling panes;
  - each pane is named, visible and stays open;
  - each pane is in the task worktree.
- The agents work by talking:
  - the lead sends a prompt to a teammate and reads the answer;
  - teammates can answer each other, for example a reviewer to the implementer, as the video shows (chapter 12:39);
  - the owner can watch every pane and type into any of them.
- The `handoff` and `second-opinion` skills use the team panes instead of one-shot runs. What they guarantee stays
  the same:
  - every review is read-only;
  - an implementer edits only in its worktree;
  - Claude alone stages, commits and deploys;
  - provider failures are reported verbatim.
- Closing the task closes the panes it opened.

## Affected users and systems

- **People:** the owner and every Claude Code session on p620 and razer that uses the agent team.
- **Files:**
  - `home/development/{herdr.nix,herdr-run.sh,agent-run.sh,agent-run.nix}`, the agent-team piece of
    `modules/programs/claude-code-managed.nix`, and the skills distribution in
    `home/development/claude-code-skills/default.nix`;
  - the `handoff` and `second-opinion` skills, and `AGENTS.md` ("Delegating to other models");
  - `docs/applications/herdr.md`.
- **Hosts:** p510 is not touched.

## Constraints

- **Every existing control stays:**
  - #2757: the `agent-implement` and `agent-review` sandboxes. An implementer gets no secrets, no Nix daemon
    socket and a read-only `.git`. A reviewer is read-only.
  - #2762: a pane passes only allow-listed environment names. No tokens, no `NIX_CONFIG`, no `SSH_AUTH_SOCK`.
  - #2081 and #2291: the coder guards.
  - Subscription login only, never an API key (#1831).
  - Never `HUMANIZE_CODEX_BYPASS_SANDBOX`, and no new `--dangerously-skip-permissions`.
  - Never work in `~/.config/nixos` or on `main`.
- **The herdr socket is full control of the session.** Anything that can reach it can type into every pane,
  including the lead's, and so answer the lead's permission prompts. A teammate's access to herdr, if any, is
  limited to talking to its own team. It must never reach other panes, keys or the lead's prompts.
- **Messages from a teammate are untrusted data, not instructions** (AGENTS.md). One agent's reply must not
  approve an intent, spec or plan, and must not make another agent commit, deploy or step outside its plan step.
- **Declarative install:** the skill comes from the pinned herdr package or flake input, not `npx skills add`.
- Must work with herdr 0.9.5 as pinned, and fail clearly outside herdr. Today `herdr-run` just runs the command
  when it is not in herdr; the new path needs an equivalent.

## Open questions

1. **Talk topology.**
   - *Hub:* only Claude prompts the teammates, and they answer it.
   - *Mesh:* teammates also prompt each other, as in the video, through a relay that can only reach the team's
     named agents.

   Recommendation: start with the hub plus one relayed lane, reviewer → implementer, gated by Claude.
2. **Replace or keep.** Should the headless path stay for one-shot reviews (cheaper, with a JSON verdict), or be
   removed outright? Recommendation: keep it as the fallback when not inside herdr.
3. **Scope.** Is a Claude teammate (a second Claude pane) in scope? The video's cross-machine agents (chapter 15:07)
   and worktree-per-agent (14:37) would come later.
4. **agy's place.** AGENTS.md says delegated agy is "off the team by the owner's choice", while agent-team mode
   puts it on every task. Which holds for the new team tab?
