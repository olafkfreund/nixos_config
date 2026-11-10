---
status: draft
issue: 2831
author: olafkfreund
---

# Intent: cut Claude Code's fixed context, in sync on every host

## Problem

Every Claude Code session starts with about 35–40k tokens of instructions, skill descriptions, tool names and
hook text before any work. It is paid again on every `/clear`, every compaction and every subagent. A Fable
review on 2026-11-10 (#2831) measured the sources:

| Source | Size | Tokens per session (est.) |
| ------ | ---- | ------------------------- |
| Skill list | 57 user skills, 16 repo skills, 32 commands, 10 enabled plugins; 55 KB of descriptions | about 14k |
| MCP tool names and server instructions | 30 servers, about 680 names | about 7k |
| `MEMORY.md` index | 150 lines, 20.7 KB, about 40 entries for resolved or removed things | about 5k |
| `AGENTS.md` | 306 lines, 18 KB; Anthropic advises under 200 | about 4.5k |
| Subagent list | 34 agents, 10 on Opus | about 2.5k |
| ponytail at `ultra` | injected at session start and into every subagent | about 1.1k each |
| PARR reminder | a `UserPromptSubmit` hook, so about 200 tokens every turn | grows with the session |

Model use also costs more than it needs to:

- the built-in Explore subagent inherits the session model (Opus or Fable) for read-only searching;
- unnamed subagents inherit it too.

Some of these settings are declared in Nix, and some were changed by hand in `~/.claude/settings.json` (the
plugins). So p620 and razer can drift apart, and a change made for one repo does not reach the others.

## Proposed outcome

The owner's decision (#2831) is every must-do item from the review except moving MCP servers out of user scope.

1. **Plugins:** frontend-design, taste-skill, ui-ux-pro-max, impeccable, jobs-to-be-done and daily.dev are off.
   `humanize`, `ponytail`, `prismantis` and `nix-lsp` stay on.
2. **Skills:**
   - The 32 `nix-*` commands, and skills that duplicate others, are shown by name only or hidden.
   - Our own skills' descriptions are cut to about 250 characters.
   - Third-party skills stay as they are.
3. **MCP:** the Atlassian MCP server is removed from p620 and razer. Microsoft 365 and Spotify are disconnected.
   The others stay.
4. **`AGENTS.md`** is under 200 lines. History and infrastructure notes move to `docs/`, or to path-scoped
   `.claude/rules/`. No rule is lost, and every non-negotiable and every instruction-only rule (#2812) stays.
5. **`MEMORY.md`** keeps only live entries, about 60 lines. Resolved and removed entries are archived, not
   deleted.
6. **Models:**
   - The built-in Explore subagent runs on Haiku.
   - Unnamed subagents default to Sonnet.
   - The `coder` stays on Sonnet.
   - The session (Opus or Fable) and the fresh Opus reviewer stay.
7. **Hooks:**
   - ponytail defaults to `lite`; `/ponytail ultra` stays available.
   - PARR moves from a per-turn hook into the managed `CLAUDE.md`, which is loaded once.
   - PARR's text for Codex and agy (`agent-rules.nix`) is unchanged.

**Observable result:** a fresh session on p620 and on razer shows the same skill list, plugins, MCP servers and
subagent models. Its fixed context (measured with `/context`) is at least 20k tokens smaller than today.

## Affected users and systems

- **Nix:**
  - `modules/programs/claude-code-managed.nix` (managed settings and `CLAUDE.md`, skill overrides, env, hooks);
  - `home/development/claude-code-lsp.nix` (the user settings template), or wherever plugin state is set;
  - `home/development/claude-code-agents.nix` (Explore);
  - `home/development/claude-code-skills/` (our skill descriptions);
  - `hosts/p620/configuration.nix:358` and `hosts/razer/configuration.nix:242` (Atlassian);
  - `AGENTS.md` and `docs/`.
- **Outside the repo:**
  - `~/.claude/projects/-home-olafkfreund--config-nixos/memory/`;
  - the claude.ai connector settings for Microsoft 365 and Spotify. Those are account-level connectors, not in
    any config file, so the owner disconnects them.
- **Hosts:** p620 and razer. p510 is not touched without the owner's OK.

## Constraints

- **Declared once, applied everywhere.** Every change goes through Nix or Home Manager modules that p620 and
  razer both import, so both hosts converge on deploy. Nothing is a per-host hand edit.
  - `~/.claude` is Syncthing-synced between hosts. Hand-edited state there must not fight the declared state.
  - A plugin turned off must stay off after a deploy, a sync or a plugin update.
- **No safety rule is weakened:**
  - the artifact gates;
  - subscription-only login and no API keys (#1831);
  - the agent-bus announce hook;
  - p510 needs the owner's OK;
  - #2812's unrestricted agents with instruction-only rules;
  - the branch and worktree rules.

  These rules may move between files, for example from `AGENTS.md` to the managed `CLAUDE.md`, but not shrink.
- **Codex and agy keep their instructions:** `~/.codex/AGENTS.md` and agy's rules come from `agent-rules.nix`
  and are not cut here.
- **Changes land between sessions.** Changing plugins or MCP servers rebuilds the prompt cache once.
- **Deploy:** p620, then razer through p620.

## Open questions

- **The review's "nice to have" items:**
  - disable 26 more subagents and move 4 from Opus to Sonnet;
  - remove the NixOS section duplicated in `~/.codex/AGENTS.md`;
  - a statix/deadnix hook;
  - make the `coder` run `just check-syntax` before handing back.

  Are they in scope? Default: no, as a follow-up issue, because the owner asked for the must-do list.
- **The Atlassian removal:** remove only the MCP server, or the Jira/Confluence token secrets and the
  `atlassian-mcp` package too? Default: only the Claude Code MCP entry (`mcp-servers.atlassian.enable = false` on
  both hosts). The secrets stay declared but unused, so turning it back on is one line.
