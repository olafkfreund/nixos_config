---
status: approved
issue: 2810
author: olafkfreund
---

# Intent: herdr-native mixed agent team

## Problem

The mixed agent team (Claude Code leads; Codex and agy draft, review and implement plan steps) runs every Codex
or agy call as a one-shot headless command. `herdr-run` (`home/development/herdr-run.sh:241`) opens a
background tab, runs `codex exec`/`codex review` or `agy -p` in it, then closes it. `second-opinion` calls
`herdr-run` directly. `handoff` goes through `agent-run` (`agent-run.sh`), which adds six checks and a JSON
verdict. Claude-only teams already run in herdr tabs through `pkgs/herdr-claude-teams` (a tmux shim) and
`claude-swarm-reaper`. Codex and agy have no equivalent.

What that costs:

- No conversation. A review that needs a follow-up question starts a fresh run with a fresh context.
- Nothing to come back to. The pane is visible while it runs but closes when the run ends, and a headless run
  cannot be steered mid-turn.
- The agents cannot talk to each other. Every exchange goes through Claude reading a file.

herdr 0.9.5, which is already installed, can start Codex, agy and Claude as named interactive agents in panes and
tabs (`herdr agent start --kind codex|agy|claude`). It also lets one agent prompt another, wait for it and read
its answer (`agent prompt --wait`, `agent read`). herdr ships an agent skill (`herdr --skill`, upstream
`skills/herdr/SKILL.md`) that teaches an agent those commands. Claude does not have it.
`~/.agents/skills/herdr`, which Codex and agy read, is a hand-made clone of the whole herdr repo dated
2026-07-25. Its SKILL.md is older than the 0.9.5 one, and it is not managed by Nix.

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
  - `docs/applications/herdr.md` (it still says 0.9.0), `home/syncthing-stignore.nix` (`hostLocalSkillIgnores`
    already lists `herdr`), and `modules/programs/claude-code-managed-claude.md` (the agent-team rules).
- **Hosts:** p510 is not touched. `claude-code-skills` is on for p510 too, and `pkgs.herdr` is installed only on
  p620 and razer (`Users/olafkfreund/profile.nix`). So the herdr skill has to be gated to those two hosts.

## Constraints

- **Every existing control stays:**
  - #2757: the `agent-implement` and `agent-review` sandboxes. An implementer gets no secrets, no Nix daemon
    socket and a read-only `.git`. A reviewer is read-only.
  - #2762: a pane passes only allow-listed environment names. No tokens, no `NIX_CONFIG`, no `SSH_AUTH_SOCK`.
  - #2081 and #2291: the coder guards.
  - Subscription login only, never an API key (#1831).
  - Never `HUMANIZE_CODEX_BYPASS_SANDBOX`, and no new `--dangerously-skip-permissions`.
  - Never work in `~/.config/nixos` or on `main`.
- **The interactive agents keep the same sandbox as the headless ones, or they do not start.** Today
  `agent-review` accepts only `codex exec|review` and refuses agy (`agent-review.sh:11,37`). `agent-implement`
  accepts only headless argument shapes (`agent-implement.sh:46,86`). So a plain `herdr agent start --kind codex`
  in the worktree is not enough. The agent runs inside wrappers that keep:
  - credentials, config and MCP access as restricted as today;
  - the env allow-list;
  - the coder guards.

  Any combination that cannot be launched that way is refused (fail closed).
- **The herdr socket is full control of the session.** Anything that can reach it can type into every pane,
  including the lead's, and so answer the lead's permission prompts. A teammate never reaches the real socket by
  any route, whether env, a discoverable path or an inherited descriptor. Teaching a model which commands are
  allowed is not a boundary. If a teammate can message anyone, that goes through an endpoint the model cannot
  bypass. The endpoint knows who is calling, allows only that task's agents as destinations, and allows only
  sending text. It never offers keys, closing panes or starting agents. If that cannot be built on herdr 0.9.5,
  teammates get no herdr access.
- **Messages from a teammate are untrusted data, not instructions** (AGENTS.md), and that includes messages the
  lead forwards. A teammate's claim never stands in for owner approval, changes scope or authorizes a commit,
  deploy or step change. Claude checks each recommendation against the approved plan and the evidence before
  acting on it. Each message keeps its sender and task. Message text never becomes a shell command, relay option
  or keystroke, so it cannot land in a shell or a permission prompt after an agent exits.
- **Authority is bound to one task, one role and one plan step.** A reviewer cannot become an implementer by being
  prompted. An implementer's authority ends with its step. A role change starts a fresh, correctly sandboxed
  process. Conversation history never extends authority.
- **Tasks stay separate.** Several Claude sessions run at once, so names and panes belong to one task. Messages
  cannot cross tasks, and a stale name cannot be reused. Cleanup touches only that task's panes, and it stops
  their processes and revokes their messaging, including after a partial start or a lead crash. One worktree has
  one writer at a time, and a review names the revision it reviewed.
- **Results are as checkable as today's verdict.** Success, refusal, timeout, cancellation, provider failure and an
  incomplete answer stay distinguishable, and each is tied to the request it answers. `agent-run` checks today
  carry over: exit status, empty output, agy `status` and `denied_actions`, a moved `HEAD`, an empty diff. A
  returned `--wait` or an open pane is not proof of a finished answer.
- **Declarative install:** the skill comes from the pinned herdr package or flake input, not `npx skills add`.
- Must work with herdr 0.9.5 as pinned. Setting up a team outside herdr reports that herdr is unavailable.
  Whether a one-shot call outside herdr keeps the sandboxed headless path is open question 2.

## Open questions

0. **Feasibility, before anything else.** Can herdr 0.9.5 recognize and drive an agent that was launched
   through our sandbox wrappers rather than as its canonical executable? Can a relay give a teammate "send text
   to my team" without the socket? If either answer is no, the spec says so and narrows the outcome. One
   possibility: only Claude talks, through herdr, to sandboxed panes it starts itself.
1. **Talk topology.**
   - *Hub:* only Claude prompts the teammates, and they answer it.
   - *Mesh:* teammates also prompt each other, as in the video, through a relay that can only reach the team's
     named agents.

   Recommendation: start with the hub plus one relayed lane, reviewer → implementer, gated by Claude.
2. **Replace or keep.** Should the headless path stay for one-shot reviews (cheaper, with a JSON verdict), or be
   removed outright? Recommendation: keep it as the fallback when not inside herdr.
3. **Scope.** Is a Claude teammate (a second Claude pane) in scope? The video's cross-machine agents (chapter 15:07)
   and worktree-per-agent (14:37) would come later.
4. **agy's place.** AGENTS.md and `second-opinion` say agy is out of use by the owner's choice (#2748), and
   `agent-review` refuses agy, so it has no read-only review sandbox. Agent-team mode puts it on every task. Does
   the team tab include agy? If it does, is agy support in `agent-review` (#2748) a prerequisite?
5. **Who gets the herdr skill.** The upstream skill teaches the raw socket commands a sandboxed teammate must
   never have. It helps Codex or agy only when you run them yourself as the lead, outside the sandbox. Install it
   for all three for that use, with sandboxed teammates getting none of it and only the relay's own
   instructions?
6. **One pane per role, or respawn?** A sandbox's mounts are fixed at start: `agent-review` mounts the worktree
   read-only and `agent-implement` mounts it writable. Does a team tab open separate reviewer and implementer
   panes, or restart the pane's process when a task moves from review to implementation?
7. **Turn completion inside the sandbox.** herdr's lifecycle state comes partly from integration hooks, which
   reach the socket. The sandbox hides both the socket and `~/.codex/hooks.json`. Does `agent prompt --wait`
   still work by reading the screen alone? Or are answers read from a file, as `docs/applications/herdr.md`
   already advises for alternate-screen agents?
8. **Teardown trigger.** "Closing the task" has no command today. Is teardown a command, Claude's `SessionEnd`
   hook, or an idle reaper like `claude-swarm-reaper`?
