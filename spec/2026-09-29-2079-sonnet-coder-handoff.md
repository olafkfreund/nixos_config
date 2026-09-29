---
status: draft
issue: 2079
intent: intent/2026-09-29-2079-sonnet-coder-handoff.md
---

# Spec: Opus plans and reviews, a Sonnet 5.5 coder implements approved plans

## Design

The rule and the agent ship through the managed layer
(`modules/programs/claude-code-managed.nix`). That module is already
imported by p620, razer and p510, and Claude Code applies what it installs
above user and project settings. This makes the rule global without writing
into `~/.claude`, which Syncthing syncs.

### 1. The `coder` agent, installed as a managed agent

A new file, `modules/programs/claude-code-coder-agent.md`, is installed
with `environment.etc` at `/etc/claude-code/.claude/agents/coder.md`.
Claude Code loads subagents from the managed settings directory first, and
managed skills already sit in `/etc/claude-code/.claude/skills/` (Claude
Code docs: *Subagents* and *Skills*). No other file on this machine defines
an agent named `coder`.

Its frontmatter:

```yaml
name: coder
description: Implements the steps of an approved plan/ file. Start it only
  after plan/ is status: approved, and keep using the same agent for the
  whole task.
model: sonnet
tools: Read, Edit, Write, Grep, Glob, Bash
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: <store path of coder-guard.sh>
```

- **Model alias.** `model: sonnet` is an alias. It resolves to Sonnet 5.5
  today and follows later releases.
- **No agent spawning.** The coder has no Agent tool.
  `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` already stops nesting, so this is
  a second guard.

The body gives the coder its standing instructions:

1. Work from the approved `plan/` file only.
2. Do one step per message. After each step, run the check command the plan
   names for it, and report the result as evidence.
3. Do not commit. Report changed files and any deviation from the plan.
   The main session commits after review, so the rule that "a deviation
   updates `plan/` in the same commit" stays with the session that owns the
   plan.
4. After two failed attempts at the same step, stop and return the step to
   the main session with the evidence.

### 2. The coder guard (enforced limits)

`coder-guard.sh` is written with `pkgs.writeShellScript` in
`claude-code-managed.nix`. It is a frontmatter hook, so it runs only while
the coder is active. It blocks, outright, any Bash command that:

- deploys or activates a system: `nixos-rebuild`, `nh os`,
  `switch-to-configuration`, the `just` deploy recipes
  (`quick-deploy`, `deploy-*`, `p620`, `p510`, `razer`), or `nhs`;
- garbage-collects or optimises the store, reboots, or powers off;
- restarts a service with `systemctl … restart|stop|start`;
- writes to git history or remotes: `git commit`, `git push`,
  `git checkout`, `git switch`, `git reset --hard`, `git stash`.

A blocked call returns the reason, and the coder hands the step back.

The existing agent-bus guard is not enough on its own. It only makes the
agent announce first, and a coder could satisfy that by setting
`AGENT_BUS_ANNOUNCED=1`. The coder guard has no bypass.

### 3. The rule, in the managed CLAUDE.md

A new closing section, `## Model split (Claude Code only)`, goes at the end
of `modules/programs/claude-code-managed-claude.md`:

- **Roles.** The session model (Opus) writes intent, spec and plan, and
  reviews. The `coder` agent writes the code.
- **When to hand off.** Hand off when an approved `plan/` has three or more
  steps that edit files, or touches three or more files. Below that, Opus
  implements, because a handoff costs a cache write and a re-read that a
  small task does not earn back.
- **How to hand off.** Start one `coder` per task with the plan path and
  step 1. Continue the same agent with `SendMessage` for each later step,
  so its prompt cache stays warm. The cache belongs to one model, so the
  coder builds its own cache once, and after that only reads it.
- **Review.** Start a fresh agent with `model: opus`. Give it only the plan
  path and `git diff`, and have it check the diff against `plan/`. It is
  kept separate from the coder so that it does not share the coder's blind
  spots.
- **Failure.** When the coder returns a step, the main session fixes it,
  and does not start a second coder.
- **PR.** The PR notes which steps the coder implemented.
- **Applies to committed plans only.** A plan that only exists in a
  conversation stays with Opus. This keeps the handoff behind the approval
  gate in every repo, including repos without `intent/`, `spec/` and
  `plan/` folders.

### 4. Keep the rule out of Codex and Antigravity

`home/development/agent-rules.nix` inlines the whole managed CLAUDE.md into
`~/.codex/AGENTS.md` and `~/.gemini/AGENTS.md`. The new section is
Claude-specific, so `agent-rules.nix` cuts the policy at
`\n## Model split (Claude Code only)`. A new assert makes the evaluation
fail if the word `coder` survives into the generated text. This follows
the existing assert pattern in that file.

### 5. Make plans self-contained

The plan template in the `artifact-workflow` skill
(`home/development/claude-code-skills/artifact-workflow/SKILL.md`) changes
its step line to include everything a fresh implementer needs:

```text
1. <file>:<lines>: <change> → verify by <command>
   Traps: <repo rules that apply, or "none">
```

This is model-neutral, so it stays shared with Codex and Antigravity.

### Decisions on the intent's open questions

| # | Question | Decision |
|---|----------|----------|
| 1 | Threshold | 3 or more file-editing steps, or 3 or more files. Otherwise Opus implements. |
| 2 | Where `coder` lives | `/etc/claude-code/.claude/agents/`, the managed location. If the deploy check below shows Claude Code does not load it, the fallback is a copy seeded into `~/.claude/agents/` by a home-manager activation step, only when the file is missing. |
| 3 | Enforcing the limits | A tool list plus the frontmatter PreToolUse guard. |
| 4 | Repos without artifacts | The handoff applies only to committed, approved `plan/` files. |
| 5 | `/parr`, `parr-run`, Codex | Out of scope. Codex is a separate issue, because `AGENTS.md` currently allows Codex read-only use only. |
| 6 | Measuring it | Record `/usage` before and after in the PRs of the first five tasks that hand off, then decide whether to keep the threshold. |

## Alternatives rejected

- **`opusplan` (switching model in the same session).** Sonnet inherits all
  the planning noise, and the handoff pays for the full context once. It
  also does not survive a plan that was approved in another session.
- **A new coder per step.** Each new agent loses its cache and has to read
  its files again.
- **Putting the rule in `parr-protocol.txt`.** That text is injected into
  every prompt, and it is also inlined into the Codex and Antigravity
  rules.
- **Installing `coder.md` into `~/.claude/agents/` from the Nix store.**
  Syncthing syncs `~/.claude`, and store symlinks break that sync.
- **Relying only on the agent-bus guard.** It can be bypassed by setting
  `AGENT_BUS_ANNOUNCED=1`.
- **A dedicated `reviewer` agent file.** The Agent tool's `model: "opus"`
  parameter is enough, so there is one less file to maintain.

## Risks

- **Claude Code might not load managed agents.** This is not proven on this
  machine yet: the docs list the managed location, but give the path only
  for skills. The verification below catches it, and the fallback is in
  decision 2.
- **The guard can block legitimate commands.** A too-broad pattern can
  block harmless ones, for example the word `restart` inside a `grep`. The
  guard matches on command words, not on prose. Because the coder hands a
  blocked step back instead of looping, a false positive costs one
  handback.
- **The coder can miss something the plan leaves out.** Opus review catches
  it in the diff. It cannot catch a side effect, and the guard is what
  prevents those.
- **Rollout.** p620 first. razer builds via p620. p510 is built and
  deployed only with your approval.

## Verification

1. **Build.** `just check-syntax`, then `just test-host p620` and
   `just test-host razer`. p510 is built only on request.
2. **Codex and Antigravity rules.** The generated files do not contain the
   section:
   `grep -c "Model split\|coder" ~/.codex/AGENTS.md ~/.gemini/AGENTS.md`
   gives `0` after the home-manager switch. The new assert also fails the
   evaluation if it would.
3. **Agent loads.** After deploying p620, a new `claude` session lists
   `coder` among its agents with model `sonnet`. The fallback in decision 2
   is used if it does not.
4. **Guard works.** In a coder session, `git commit --allow-empty -m test`
   and `nixos-rebuild --help` are both blocked, while `just check-syntax`
   runs.
5. **End to end.** The first real task above the threshold runs through
   plan → coder → Opus review. Its PR records which steps the coder did,
   and `/usage` before and after.
