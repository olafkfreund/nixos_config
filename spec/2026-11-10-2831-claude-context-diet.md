---
status: draft
issue: 2831
intent: intent/2026-11-10-2831-claude-context-diet.md
---

# Spec: cut Claude Code's fixed context, in sync on every host

## Design

Everything below is declared in modules that p620 and razer both import:

- `modules.programs.claude-code-managed` (hosts/p620:251, hosts/razer:419);
- `modules.programs.claude-code-mods`;
- the shared Home Manager profile.

Where a value lives in a file Claude Code writes itself, an activation step reconciles it on every switch.

### 1. Plugins: managed `enabledPlugins`

- `managed-settings.json` gains `enabledPlugins` entries set to `false` for:
  - `frontend-design@claude-plugins-official`;
  - `taste-skill@taste-skill`;
  - `ui-ux-pro-max@ui-ux-pro-max-skill`;
  - `impeccable@impeccable`;
  - `jobs-to-be-done@pm-skills`;
  - `daily.dev@daily.dev`.
- Managed settings are the highest-precedence layer and are read-only. A user-scope `true`, whether Syncthing
  brings it back or `/plugin` sets it, cannot override them. They render from Nix on both hosts, so no
  reconciliation of `~/.claude/settings.json` is needed.
- This is a deliberate exception to the module's header note (`claude-code-managed.nix:9–12`), which reserves
  managed `enabledPlugins` for the organization mod. The note is updated to say a declared *off* also belongs
  there.
- **Fallback, only if verification shows the managed `false` does not win:** an activation step after
  `claudeUserSettingsInit` (`claude-code-lsp.nix:146`) sets the same keys to `false` with
  `jq '.enabledPlugins += {...}'`, written atomically, leaving every other key alone.
- `humanize`, `ponytail`, `prismantis`, `nix-lsp` and `fleet-guard` are unchanged.

### 2. Skills: `skillOverrides` and shorter descriptions

`baselineSkillOverrides` (`claude-code-managed.nix:197`) gains:

- **`name-only`:** the repo's 32 `.claude/commands` (`nix-*`, `update-*`, `check-*`, `gemini-review`, `parr`).
  They stay invocable with `/`, and only their names reach the prompt.
- **`off`:** the user commands that duplicate a skill or a built-in: `code-reviewer`, `security-audit`,
  `nixos-expert`, `system-doctor`, `devops-architect`, `crew`, `demo`. Each one is checked against its
  duplicate in the plan before it is turned off.

Our own skills' descriptions over 300 characters are cut to about 250. Those are skills whose source is in this
repo or in `home/development/claude-code-skills` (`localSkills`), such as `craftapps`, `obsidian`, `ripsaw`,
`run-aws-demo` and `meetingai`. Third-party skills, for example `stageshow` and the nixarchy skills, are left
alone; they can go `name-only` later if wanted.

### 3. Atlassian: removed completely

This is the owner's decision. Removed on both hosts:

- the host blocks at `hosts/p620/configuration.nix:358` and `hosts/razer/configuration.nix:242`;
- the `atlassian` option tree and its secrets in `modules/ai/mcp-servers.nix` (:99–190, :270, :296, :335–355);
- the entries in `home/development/claude-code-mcp.nix` (:22, :211–) and
  `home/development/claude-desktop/mcp-config.nix`;
- `pkgs/atlassian-mcp/` and its line in `pkgs/default.nix`;
- the `api-jira-*` and `api-confluence-*` entries in `secrets.nix`, and the files
  `secrets/api-jira-token.age`, `secrets/api-confluence-token.age` and the four `.placeholder` files.

Old intents, specs and plans that mention Atlassian are history and stay.

The MCP reconciler in `claude-code-mcp.nix` (:370–393) only adds or replaces entries. It gains a declared
`retiredMcpServers = [ "atlassian" ]` list. On every activation it deletes those keys from `~/.claude.json`'s
`mcpServers`, and from Claude Desktop's config. So a synced or stale entry cannot come back.

### 4. `AGENTS.md` under 200 lines, with nothing lost

| Section (current lines) | Goes to | Why it is safe |
| ----------------------- | ------- | -------------- |
| Read first, Hosts, Non-negotiable, Module shape, Commands, Build/test/deploy, Layout, Adding a user, Git (1–209) | stays, tightened | Codex and agy read `AGENTS.md`; these are cross-agent rules |
| Delegating to other models (47–131) | the owner decision, the instruction-only rules list (#2812) and the herdr-team paragraph stay. The three "Legacy, unused by default" paragraphs (agent-review, agent-implement, the old sandbox) move to `docs/architecture/agent-delegation.md`, with a one-line pointer | the rules agents must follow stay in the file every agent reads; only history moves |
| Infrastructure notes (210–296) | `docs/architecture/infrastructure-notes.md`, with a two-line pointer. The desktop and Hyprland items also go to `.claude/rules/desktop.md` with `paths: ["hosts/common/nixos/omarchy-*.nix", "modules/desktop/**", "hosts/*/nixos/*hypr*"]` | facts about the tree, not behaviour rules. Codex and agy reach them through the pointer |
| Claude Code (297–306) | stays | short |

The plan includes a checklist: every bullet of the old file maps to a line in the new file, in the docs, or in
the rule file.

The new `docs/` pages are added to both `mkdocs.yml` and `mkdocs-full.yml`, which are hand-synced.

### 5. `MEMORY.md`

The lead (Claude) does this directly. The memory dir is outside git.

- An entry is archived when its index line or file says RESOLVED, FIXED or REMOVED, or names a decommissioned
  host or service (DEX5550, k3d on p510, Samsung/HP and similar).
- Its file moves to `memory/archive/`, and its index line is deleted.
- The target is about 60 index lines.
- Live entries are untouched.

### 6. Models

- **`~/.claude/agents/Explore.md`** is declared through `home.file`, so the Syncthing ignore list picks it up,
  as with the skills (`home/syncthing-stignore.nix`). The file has `name: Explore`, `model: haiku`, tools
  `Read, Grep, Glob, Bash`, and a short read-only search prompt. A user agent with a built-in's name replaces
  the built-in. The verification checks that `/agents` shows Explore on Haiku.
- **Managed `env`** (`claude-code-managed.nix:722`) gains `CLAUDE_CODE_SUBAGENT_MODEL = "sonnet"`, the default
  for subagents that have no `model:` frontmatter.
- `coder` (`model: sonnet`), the named agents with their own `model:`, and the Opus reviewer are unchanged.

### 7. ponytail and PARR

- `PONYTAIL_DEFAULT_MODE = "lite"` (`claude-code-managed.nix:725`). `/ponytail ultra` stays available per
  session.
- `parrProtocol.enable` goes `false` on both hosts, so the per-turn `UserPromptSubmit` hook is gone. The four
  PARR lines are added as a "## Working style" section in the managed `CLAUDE.md`
  (`claude-code-managed-claude.md`), loaded once and cached.
- `parr-protocol.txt` stays, because `agent-rules.nix` still feeds it to Codex and agy.
- The `agent-team` prompt hook stays. It is tiny and its text depends on state.

## Alternatives rejected

- **Uninstalling the plugins:** a later `/plugin install` or a synced `installed_plugins.json` would bring them
  back. A managed `false` holds.
- **Rewriting `~/.claude/settings.json` from Nix:** it is a runtime-writable file (#398). Managed settings or a
  key-level reconcile avoid clobbering the user's other choices.
- **Moving every MCP server to project scope:** declined by the owner.
- **`opusplan`:** switching models rebuilds the prompt cache. The artifact gates already separate planning from
  coding.
- **Haiku for `coder`:** too weak for the repo's code, and its long-prompt pricing is worse.
- **Cutting `~/.codex/AGENTS.md`:** out of scope (intent constraint). It is a follow-up.

## Risks

- **The managed `enabledPlugins: false` may not override the user's `true`** if Claude Code merges that key
  differently. Checked live, with the activation fallback ready.
- **A user agent named `Explore` may not replace the built-in** in this Claude Code version (2.1.322). Checked
  with `/agents`; if not, the Explore override is dropped and the PR notes it.
- **Shortened skill descriptions can make a skill trigger less often.** The trigger words are kept in each
  shortened text.
- **Removing Atlassian removes Jira and Confluence access from agents.** That is the owner's choice. The `.age`
  files stay in git history if they are ever needed again.
- **The prompt cache rebuilds once** after the deploy.
- **Hosts:** p620 and razer. p510 is not touched (it does not import these Claude modules).

## Verification

- **Eval and build:** `just check-syntax`, `just test-host p620`, `just test-host razer`.
- **`grep`:** no `atlassian`, `api-jira` or `api-confluence` outside `intent/`, `spec/` and `plan/`.
- **After deploying to p620 and razer**, in a fresh session on each host:
  - `jq .enabledPlugins /etc/claude-code/managed-settings.json` shows the six as `false`, and `/plugin` lists
    them disabled;
  - the skill list shows the `name-only` and `off` states from section 2;
  - `claude mcp list` has no `atlassian`;
  - `/agents` shows Explore on Haiku;
  - one unnamed subagent's transcript records `claude-sonnet-*`;
  - no PARR `system-reminder` appears on a turn, and the managed `CLAUDE.md` has the Working style section;
  - the session-start ponytail banner says `lite`.
- **Sync:** set one of the six plugins to `true` in `~/.claude/settings.json` on razer, let Syncthing carry it
  to p620, and start a fresh session there. It is still disabled.
- **Size:** `/context` in a fresh session in this repo on p620, before (on today's main) and after. The PR
  records both. Target: at least 20k tokens less.
- **Safety:**
  - `AGENTS.md` keeps every non-negotiable and the #2812 rules, per the plan's checklist;
  - the bus guard still blocks a deploy-word command without `AGENT_BUS_ANNOUNCED`;
  - the branch guard still blocks a checkout in `~/.config/nixos`.
- **Owner:** Microsoft 365 and Spotify are disconnected at claude.ai, and their `mcp__claude_ai_*` tools are
  gone from a fresh session.
