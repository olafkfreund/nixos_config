---
status: approved
issue: 2831
spec: spec/2026-11-10-2831-claude-context-diet.md
coders:
  1: coder   # managed settings: plugins, skillOverrides, env, ponytail, PARR (one Nix file + one md)
  2: agy     # Atlassian removal: mechanical deletions across ~10 files
  3: codex   # MCP reconciler retired-server logic (small, tricky jq + write test)
  4: coder   # Explore agent file via activation
  5: coder   # AGENTS.md split with the section map and checklist
  6: coder   # skill description trims + second-opinion agy flag fix
reviewers:
  - codex    # it found the sync and AGENTS.md reach gaps in review
  - agy      # second read; reruns with --dangerously-skip-permissions per #2812
---

# Plan: cut Claude Code's fixed context, in sync on every host

Self-contained: implementing this needs only this file and the code. Line numbers are from commit 7aa8fedc2.
Every Nix change lands in modules that both p620 and razer import:

- `modules.programs.claude-code-managed`, at hosts/p620:251 and hosts/razer:419;
- the shared Home Manager profile.

## Approved decisions

1. **Plugins.** Managed `enabledPlugins` sets six plugins to `false`:
   - `frontend-design@claude-plugins-official`;
   - `taste-skill@taste-skill`;
   - `ui-ux-pro-max@ui-ux-pro-max-skill`;
   - `impeccable@impeccable`;
   - `jobs-to-be-done@pm-skills`;
   - `daily.dev@daily.dev`.

   They are merged with the existing `fleet-guard` entry from `claude-code-mods.nix`. The header note at
   `claude-code-managed.nix:9–12` is updated. Fallback, only if the live check fails: a `jq` reconcile of
   `~/.claude/settings.json` after `claudeUserSettingsInit`.
2. **Skills.** `baselineSkillOverrides` gains the exact `name-only` and `off` tables from the spec (section 2).
   Our own skills' descriptions over 300 characters are cut to about 250, keeping their trigger words.
3. **Atlassian goes completely:**
   - the host blocks;
   - the option tree and secrets in `modules/ai/mcp-servers.nix`;
   - the `claude-code-mcp.nix` and `claude-desktop/mcp-config.nix` entries;
   - `pkgs/atlassian-mcp` and its line in `pkgs/default.nix`;
   - the four secret declarations in `secrets.nix`, with their `.age` and `.placeholder` files;
   - the Atlassian section of `docs/MCP-GUIDE.md`.

   `intent/`, `spec/` and `plan/` are exempt as history.
4. **The MCP reconciler** gets `retiredMcpServers = [ "atlassian" ]`:
   - deletes those keys from `~/.claude.json` and `~/.claude/settings.local.json` `mcpServers`, and from Claude
     Desktop's config, on every activation;
   - counts a present retired key as a difference in the "already matches" test.
5. **`AGENTS.md`** is split per the spec's section map. Every live rule stays, including:
   - the first sentences of the `codex-implement` and `agy-implement` paragraphs;
   - "advice only";
   - `HUMANIZE_CODEX_BYPASS_SANDBOX`;
   - subscription only.

   Only the "Legacy, unused by default" text moves, to `docs/architecture/agent-delegation.md`. Infrastructure
   notes go to `docs/architecture/infrastructure-notes.md`, with the desktop items also in a path-scoped
   `.claude/rules/desktop.md`. Both docs pages go into `mkdocs.yml` and `mkdocs-full.yml`.
6. **`MEMORY.md`.** The lead archives RESOLVED, FIXED and REMOVED entries, and decommissioned hosts or services,
   to `memory/archive/`. The target is about 60 lines.
7. **Models.**
   - `~/.claude/agents/Explore.md` (Haiku, read-only tools) is written as a real file by activation on every
     switch, never as a `home.file` symlink.
   - The managed env gets `CLAUDE_CODE_SUBAGENT_MODEL = "sonnet"`.
8. **Ponytail and PARR.**
   - `PONYTAIL_DEFAULT_MODE = "lite"`.
   - `parrProtocol.enable = false` on both hosts.
   - The four PARR lines become a "## Working style" section in `claude-code-managed-claude.md`.
   - `parr-protocol.txt` stays for Codex and agy.
9. **The `second-opinion` skill bug.** Its agy commands gain `--dangerously-skip-permissions`, as #2812
   requires. Without it, headless agy auto-denies every command and returns an empty review. That happened
   three times on 2026-11-10.

## Steps

1. **`modules/programs/claude-code-managed.nix` and `claude-code-managed-claude.md`** (decisions 1, 2-overrides,
   7-env, 8).
   - **Plugins:** in the managed settings attrset, near where `skillOverrides` is merged (:750–753), add
     `enabledPlugins` with the six set to `false`. `lib.recursiveUpdate`-merge it so `claude-code-mods.nix:43`'s
     `fleet-guard` entry survives. Update the header comment (:9–12).
   - **Skill overrides:** add the spec's tables to `baselineSkillOverrides` (:197–199). Keep `ask-gemini = "off"`.
   - **Env:** in the `env` block (:722), set `CLAUDE_CODE_SUBAGENT_MODEL = "sonnet"` and change
     `PONYTAIL_DEFAULT_MODE` to `"lite"` (:725).
   - **PARR:** set `parrProtocol.enable = false` at hosts/p620/configuration.nix:253 and
     hosts/razer/configuration.nix:421. Add the PARR text as `## Working style` after the "Model split" section
     in `modules/programs/claude-code-managed-claude.md`.
   - Verify:
     - `just check-syntax`;
     - `nix eval .#nixosConfigurations.p620.config.environment.etc."claude-code/managed-settings.json".text | jq`
       shows the plugins, the overrides and the env, and the same for razer.
   - Traps:
     - do not add plugins to `managed-settings` in any other attr;
     - `skillOverrides` values are only `off`, `user-invocable-only` and `name-only` (#1928);
     - the managed `CLAUDE.md` is generated, so edit only its source `.md`.
2. **Atlassian removal** (decision 3).
   - **Delete:**
     - hosts/p620/configuration.nix:358–(end of the `atlassian` block);
     - hosts/razer/configuration.nix:242–(same);
     - in `modules/ai/mcp-servers.nix`: :99–190 (the options), :270, :296 and :335–357 (the secrets);
     - home/development/claude-code-mcp.nix:22 and :211–(end of the block);
     - home/development/claude-desktop/mcp-config.nix:11 and :125–(end of the block);
     - `pkgs/default.nix:4` and the directory `pkgs/atlassian-mcp/`;
     - in `secrets.nix`, the entries `api-jira-token`, `api-confluence-token`, `api-jira-pat` and
       `api-confluence-pat`;
     - the files `secrets/api-jira-token.age`, `secrets/api-confluence-token.age`, any
       `secrets/api-confluence-pat.age`, and `secrets/api-{jira,confluence}-{token,pat}.placeholder`;
     - the Atlassian section of `docs/MCP-GUIDE.md`.
   - Verify:
     - `grep -rn "atlassian\|api-jira\|api-confluence" --exclude-dir={intent,spec,plan} .` finds nothing;
     - `just check-syntax` passes.
   - Traps:
     - `secrets.nix` is evaluated by agenix, so keep its syntax valid;
     - do not touch other secrets;
     - `git rm` the files; do not leave them untracked.
3. **The retired-server reconcile** in `home/development/claude-code-mcp.nix` (decision 4).
   - Add `retiredMcpServers = [ "atlassian" ];` in the `let`.
   - In `claudeSharedMcpServers` (:317–), extend the jq "already matches" test (:378) so that any retired key
     present is a difference. Write with `del(.mcpServers[$r[]])` alongside the existing `+` merge.
   - Apply the same delete to `~/.claude/settings.local.json` if the file exists, written atomically
     (`mktemp` in the same dir, then `mv`).
   - Apply the same delete to Claude Desktop's generated config path from `claude-desktop/mcp-config.nix`.
   - Verify:
     - build the HM activation: `just test-host p620`;
     - in a temp `HOME`, a test script copies a `~/.claude.json` and a `settings.local.json` that contain
       `atlassian`, runs the activation snippet, and checks the key is gone and the other servers are
       untouched. The script is `home/development/claude-code-mcp-retire-test.sh`, run from the module's check
       if one exists, or by hand.
   - Traps:
     - never print the files' contents; they may hold tokens;
     - `$DRY_RUN_CMD` conventions;
     - the activation must not `exit`.
4. **The Explore agent** (decision 7) in `home/development/claude-code-agents.nix`.
   - Add a store file `exploreAgent` with this frontmatter:

     ```yaml
     name: Explore
     description: <the built-in's one-line purpose>
     model: haiku
     tools: Read, Grep, Glob, Bash
     ```

     The body is a 5–8 line read-only search prompt.
   - Add a `home.activation.claudeExploreAgent` entry after `writeBoundary`:
     `install -D -m 0644 ${exploreAgent} "$HOME/.claude/agents/Explore.md"`.
   - Verify: `just test-host p620`.
   - Traps:
     - never `home.file`; `agents/**` is Syncthing-synced (home/syncthing-stignore.nix:106);
     - the curation step must not move `Explore.md` to `agents-disabled`.
5. **The `AGENTS.md` split** (decision 5).
   - Work section by section, following the spec's map.
   - Produce a checklist in the PR body that maps every bullet of the old file to its new place: kept, moved to
     a doc, or moved to a rule.
   - Create `docs/architecture/agent-delegation.md`, `docs/architecture/infrastructure-notes.md` and
     `.claude/rules/desktop.md` (`paths:` per the spec). Add both docs to the `nav` in `mkdocs.yml` and
     `mkdocs-full.yml`.
   - Verify:
     - `wc -l AGENTS.md` is under 200;
     - `npx --no markdownlint-cli2` passes on all changed Markdown;
     - `grep` that `AGENTS.md` still contains: `Never set`, `Subscription login only`, `p510`,
       `AGENT_BUS_ANNOUNCED`, `instruction-only`, `codex-implement`, `agy-implement`, `herdr-team`,
       `worktree`.
   - Traps:
     - markdownlint lints whole files;
     - the nav must change in both mkdocs files;
     - #2828 later edits the herdr-team bullet, so keep it intact.
6. **Skill text** (decisions 2-trims and 9).
   - **Trims:** for our own skills whose source is in this repo (`home/development/claude-code-skills/*` and
     the skills table's `localSkills`), cut every description over 300 characters to about 250, keeping the
     trigger words. List each with its before and after length in the PR.
   - **`second-opinion`:** in `home/development/claude-code-skills/second-opinion/SKILL.md`, add
     `--dangerously-skip-permissions` to both agy commands, the prose path and `--agent`. Add one line saying
     why: #2812, and the empty reviews.
   - Verify: `npx --no markdownlint-cli2` on the changed files.
   - Traps: third-party skills are untouched; the YAML frontmatter must stay valid.
7. **Lead: `MEMORY.md`** (decision 6). Move the archived files to `memory/archive/` and rewrite the index.
   - Verify: `wc -l MEMORY.md` is about 60, and every remaining link resolves.
   - Traps: outside git; done directly by the lead, not a coder.
8. **Lead: build, review, deploy, verify.**
   - **Before:** record `/context` in a fresh session on p620 at today's main.
   - **Build:** `just check-syntax`, `just test-host p620`, `just test-host razer`.
   - **Review:** a fresh Opus pass, then Codex and agy (with `--dangerously-skip-permissions`) on
     `git diff origin/main`.
   - **Ship:** open a PR with the intent, spec, plan, the checklist and the trim list. Announce on the bus, then
     `just p620` and `just deploy-via-p620 razer`.
   - **After**, in a fresh session on each host, check everything in the spec's Verification:
     - the plugins, the skill list, `claude mcp list`, `/agents` for Explore, the subagent model, no PARR
       reminder, and the ponytail banner;
     - the Syncthing round trip for a plugin set to `true`;
     - `/context` after;
     - the bus, branch and p510 guards;
     - the generated Codex and agy rules still contain the rules.
   - **Owner:** disconnect Microsoft 365 and Spotify at claude.ai, then confirm their tools are gone.

## Tests

| Command | Expected |
| ------- | -------- |
| `just check-syntax` | passes |
| `just test-host p620` and `just test-host razer` | both build |
| the retire-test script | `atlassian` is gone, other servers untouched |
| `grep` for Atlassian outside the history dirs | nothing found |
| `wc -l AGENTS.md` | under 200 |
| `/context` before and after | at least 20k tokens less (target) |
| the post-deploy checks on p620 and razer | identical results |

## Rollback

Revert the merge commit and deploy both hosts. Atlassian's `.age` files stay in git history. Plugins come back
when the managed `false` entries are gone. The `MEMORY.md` archive can be moved back by hand.

## Amendments (2026-11-10, from Codex's plan review; no decision changed)

- **Step 1, plugins:** `fleet-guard` comes in through `cfg.settings.enabledPlugins` (claude-code-mods.nix:38–43).
  Merge as `enabledPlugins = (cfg.settings.enabledPlugins or { }) // { <the six> = false; }`, so the declared
  `false` values win and `fleet-guard = true` survives.
  - Verify by reading the rendered file:

    ```bash
    nix eval --raw .#nixosConfigurations.<host>.config.environment.etc."claude-code/managed-settings.json".source
    ```

    Then `jq` the path, which must show the six `false` and `fleet-guard` `true`, for p620 and razer. `.text`
    is not set; `.source` is.
- **Step 1, skill overrides:** the exact entries.

  **`name-only`:** `check-nixos-issues`, `check-updates`, `nix-check-tasks`, `nix-clean`, `nix-deploy`,
  `nix-fix`, `nix-help`, `nix-info`, `nix-manix-search`, `nix-module`, `nix-network`, `nix-new-task`,
  `nix-optimize`, `nix-precommit`, `nix-review`, `nix-secrets`, `nix-security`, `nix-test`, `nix-validate`,
  `nix-workflow-bugfix`, `nix-workflow-feature`, `nix-workflow-security`, `parr`, `update-antigravity`,
  `update-claude-code`, `update-codex`, `update-warp`, `update-waveterm`, `agent-team`, `analyze-product`,
  `blog`, `create-spec`, `crew`, `demo`, `dns`, `execute-tasks`, `plan-product`, `team`.

  **`off`:**

  | Name | Duplicate it is checked against |
  | ---- | ------------------------------- |
  | `gemini-review` | `second-opinion` |
  | `code-reviewer` | the `code-reviewer` agent and `/code-review` |
  | `security-audit` | `/security-review` and `security-patrol` |
  | `nixos-expert` | the `nixos` skill |
  | `system-doctor` | `nixos-doctor` |
  | `devops-architect` | `deployment-coordinator` and `cloud-architect` |

  Before setting an entry `off`, compare the two descriptions. If the duplicate does not cover the entry's
  purpose, make the entry `name-only` instead, and note it in the PR.
- **Step 2, the true ranges:**
  - `mcp-servers.nix`: the option tree runs :99–201, and the secrets :335–362.
  - The documentation blocks in `claude-code-mcp.nix` (:482–492) and `claude-desktop/mcp-config.nix` (:244–265)
    are also removed.
  - The final `grep` is the completeness check.
- **Step 3, Claude Desktop:** its config is a Home Manager `xdg.configFile` with `force = true`
  (mcp-config.nix:17). Step 2's removal of the declaration is what removes Atlassian there; step 3 never `jq`s
  that store-backed file. The retired-key delete applies only to `~/.claude.json` and
  `~/.claude/settings.local.json`.
- **Step 3, the test:** `home/development/claude-code-mcp-retire-test.sh` builds a fixture `~/.claude.json` in a
  temp `HOME`.
  - Every declared server already matches, and `atlassian` is the only difference, plus one unrelated
    undeclared server.
  - It extracts the reconcile `jq` program as a shared Nix string, used by the activation and the test.
  - It asserts that `atlassian` is gone and that the unrelated server and all declared servers are unchanged.
  - It covers `settings.local.json` the same way.
  - The test runs as a `pkgs.runCommand` check, referenced from the module, so `just test-host` runs it.
- **Step 4, Explore:**
  - `$DRY_RUN_CMD install …`;
  - `entryAfter [ "writeBoundary" "claudeAgentCuration" ]`;
  - `Explore` is never in `disabledAgents`.
- **Step 5:** the old-to-new checklist for `AGENTS.md` is written by the coder, reviewed by the lead, and then
  copied into this plan, in the same commit as the `AGENTS.md` change. Every #2812 rule, every
  `codex-implement`/`agy-implement` limit and every non-negotiable is marked KEEP, with its new line number.
- **Step 6:** the `second-opinion` agy flag was already applied during implementation, which is what Codex saw.
  The step is complete when the diff shows it on both agy commands.

## Step 5 checklist: old AGENTS.md to its new place

### AGENTS.md split checklist (old line ranges from commit 7aa8fedc2)

K = kept in AGENTS.md, D = moved to doc, R = also in .claude/rules/desktop.md

| Old section / bullet | Old lines | Where now |
| --- | --- | --- |
| Read first | 3-12 | K |
| Hosts table + HM note | 14-26 | K |
| Non-negotiable 1-6 | 28-45 | K |
| Delegating: Codex/agy/Ollama read-only | 49-50 | K |
| Owner decision #2812 (incl. agent-review stays, unused) | 51-57 | K |
| Instruction-only rules (6 sub-bullets) | 58-78 | K |
| codex-implement paragraph, live sentences | 79-83 | K |
| codex-implement "Legacy ... #2812" tail | 83-86 | D agent-delegation.md |
| agy-implement paragraph, live sentences | 87-91 | K |
| agy-implement "Legacy ... #2812" tail | 91-95 | D agent-delegation.md |
| Untrusted advice, never approval | 96-97 | K |
| Mixed teams inside herdr (all sub-bullets) | 98-113 | K (verbatim) |
| Legacy agent-review paragraph | 114-128 | D agent-delegation.md; one-line pointer in K |
| Never set HUMANIZE_CODEX_BYPASS_SANDBOX | 129 | K |
| Subscription login only | 130 | K |
| Module shape | 132-146 | K |
| Commands | 148-157 | K |
| Build / test / deploy | 159-173 | K |
| Layout | 175-189 | K |
| Adding a user | 191-195 | K |
| Git (incl. worktree, Justfile branch rule) | 197-208 | K |
| Infra: Hyprland keys | 214-215 | D infrastructure-notes.md + R |
| Infra: no binary cache | 216-219 | D infrastructure-notes.md |
| Infra: monitoring removed | 220-221 | D infrastructure-notes.md |
| Infra: one Wayland session | 222-227 | D + R |
| Infra: programs.hyprland by nixarchy | 228-237 | D + R |
| Infra: Omarchy theme | 238-251 | D + R |
| Infra: p510 Omarchy session | 252-264 | D + R |
| Infra: Sunshine ("rule below" -> "rule in AGENTS.md, Non-negotiable 2") | 265-273 | D + R |
| Infra: nixarchy runners / build-dir | 274-288 | D |
| Infra: NVIDIA bump needs boot | 289-292 | D |
| Infra: DEX5550 / Samsung / HP | 293 | D |
| Infra: MicroVMs per host | 294-295 | D |
| Infra pointer (new, 8 lines) | - | K |
| Claude Code (2 bullets) | 297-306 | K |

Result: AGENTS.md 199 lines (also dropped duplicate Layout rows and two duplicate Build/test lines that Commands and
Read-first already carry).

### KEEP marks (verified present verbatim in new AGENTS.md by grep)

- KEEP: #2812 owner decision (agy --dangerously-skip-permissions, Codex bypass flags, every launch path, agent-review
  stays unused)
- KEEP: instruction-only rules: Secrets, Herdr socket, Git and /etc/nixos, Nix daemon (p510 / unsigned paths), Network
  and host operations, Reviews (git status --porcelain)
- KEEP: codex-implement limits (who may start it, task worktree, no commit/deploy/restart/gc/reboot, guard enforces,
  Issue #2081)
- KEEP: agy-implement limits (same, Issues #2087, #2291)
- KEEP: untrusted advice / never approval; Never set HUMANIZE_CODEX_BYPASS_SANDBOX; Subscription login only
- KEEP: herdr-team block verbatim
- MOVED (history only): the "Legacy, unused by default" tails and agent-review paragraph

## Deviation (step 5, from agy's plan review)

Two live rules sat at the end of a "Legacy, unused by default" bullet, and the split moved them with it:

- delegated agy reviews stay in `--mode plan`;
- never `codex exec` for edits or `agy --mode accept-edits` for reviews.

They are restored to `AGENTS.md`, next to the "untrusted advice" rule. The desktop rule's `paths:` glob
`hosts/*/nixos/*hypr*` matched no files, so it is replaced by `hosts/*/nixos/nixarchy.nix` and
`hosts/*/nixarchy/**`.

## Deviations (step 8 review fixes)

- **Explore gets `tools: Read, Grep, Glob`, without Bash.** With Bash, "read-only" rested only on the prompt
  (Opus review).
- **The `~/.claude.json` reconcile** writes its temp copy in the same directory and removes it on a dry run, so
  no credential-bearing copy is left in `/tmp`. The fault existed before this task (Codex, Opus and agy). The
  retire test gains a dry-run case.
- **Non-negotiable 2 in `AGENTS.md`** names the Sunshine exception, so Codex and agy see it (Opus).
- **p510's `parrProtocol.enable` is set to `false` in config only**, so the three hosts do not drift apart. p510
  is not built or deployed without the owner's OK.
- A leftover Jira example and a long line, both in `docs/MCP-GUIDE.md`, are fixed.
- Two review claims did not hold up on testing:
  - the null-`mcpServers` edge case cannot happen;
  - no skill description is over 300 characters (checked with `yq`).
