---
status: approved
issue: TBD
author: olafkfreund
---

# Intent: Declare every local skill once, install it for each agent

## Problem

#1958 installs the external nix-skills collection for Claude, Codex and
Antigravity. The skills written for this setup do not get the same treatment.
Measured on p620 on 2026-09-22:

- **13 skills are managed by nothing.** They are plain files in
  `~/.claude/skills/`: not in this repo, not built by Nix, and reaching other
  hosts only through Syncthing. Codex, Antigravity and Pi never see them.
  - Written here: `nixos-standards`, `parr-run`, `fides`,
    `backstage-patterns`, `run-aws-demo`, `linkedin-post`, `reddit-post`,
    `super-brainstorm`, `cosmic-ui-design-skill`
  - Apparently installed by the `skills` CLI (`home/development/skills-cli.nix`):
    `clean-code`, `ci-cd-pipelines`, `frontend-design`, `skill-forge`
- **10 skills are declared in `home/development/claude-code-skills/default.nix`,
  but one file at a time**, so reaching another agent means adding another
  `home.file` line for each file and each agent. Only `gog` and `notebooklm`
  have those lines (about 13 of them). `1password`, `agent-bus`,
  `artifact-workflow`, `dns`, `obsidian` and `nixi` are Claude-only, and
  nothing records whether that is on purpose. `second-opinion` and
  `ask-ollama-cloud` are Claude-only on purpose (#1831, #1928).
- **Agent directories disagree.** `gog` and `notebooklm` are installed into
  `~/.codex/skills` and `~/.gemini/skills`. #1958 chose `~/.agents/skills`
  (Codex) and `~/.gemini/config/skills` (Antigravity). #1832 wants every agent
  to follow the same process, yet `artifact-workflow` (the process itself)
  exists only for Claude.

Prior art: crertel/nix-agency and nix-skills' `nix/agent-directories.nix`
both declare a skill once and derive each agent's copy from one table of
agent directories.

## Proposed outcome

- Each local skill is declared once in this repo, with the list of agents it
  goes to. The default is all agents; a Claude-only skill says so, and says why.
- One table of agent directories is the only place agent paths are written,
  and it agrees with #1958.
- The 13 unmanaged skills are either brought into the repo, left to the
  `skills` CLI deliberately, or deleted. None stay unaccounted for.
- On p620, razer and p510, `ls` of each agent's skill directory shows the
  declared set, and a rebuild reproduces it without Syncthing.

## Affected users and systems

- `home/development/claude-code-skills/default.nix` and the local skill
  directories next to it
- `home/syncthing-stignore.nix`, since skills that become Nix-managed should
  stop syncing
- Hosts p620, razer and p510; agents Claude Code, Codex, Antigravity, possibly Pi
- nixarchy's per-activation skill relinking (`nixarchy/modules/home.nix:973`),
  which owns sibling links in the same directories and must not be fought

## Constraints

- **This repo is public.** Every skill brought in must be checked for
  secrets, private hostnames, account details and client material before it is
  committed. Anything that fails that check stays out of this repo.
- Must not break the per-file approach in the shared directories: nixarchy and
  nix-skills own sibling entries there.
- Must keep `second-opinion` and `ask-ollama-cloud` Claude-only (#1831, #1928).
- No new flake input or tool. Reuse the pattern nix-skills already uses.

## Open questions

1. Which of the 13 unmanaged skills belong in this public repo, which in a
   private place, and which should be deleted?
2. Should `artifact-workflow` go to every agent? #1832 suggests yes.
3. Codex: `~/.agents/skills`, `~/.codex/skills`, or both? Gemini:
   `~/.gemini/config/skills` (Antigravity), `~/.gemini/skills` (Gemini CLI),
   or both?
4. Should Pi (`~/.pi/agent/skills`, already seeded by nixarchy) be a target?
5. Do the `skills`-CLI catalogue skills stay under that CLI's control?
