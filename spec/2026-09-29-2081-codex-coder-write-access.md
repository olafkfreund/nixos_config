---
status: draft
issue: 2081
intent: intent/2026-09-29-2081-codex-coder-write-access.md
---

# Spec: Codex may write code for approved plans

## Design

Codex has no subagent like Claude's `coder`. Instead, **one Codex session
changes model by stage**, and the implementation stage runs in a dedicated
profile that carries the write access and the limits.

### 1. `codex-implement`: the only way Codex gets write access

A `codex-implement` command on `PATH` (home-manager, `home.packages`)
runs `CODEX_CODER=1 exec codex -p implement "$@"`. The `implement` profile
is a whole file that we own, so home-manager writes it:
`home.file.".codex/implement.config.toml"`. `~/.codex` is not synced by
Syncthing (`home/syncthing-stignore.nix` excludes it), so a Nix store
symlink there is safe. This is the same way `~/.codex/AGENTS.md` is already
installed.

```toml
# ~/.codex/implement.config.toml
model = "gpt-6-sol"
model_reasoning_effort = "medium"
sandbox_mode = "workspace-write"
approval_policy = "on-request"

[sandbox_workspace_write]
network_access = false
```

A plain `codex` session keeps whatever `~/.codex/config.toml` sets today.
The session model stays `gpt-6-sol`, as the intent decided. Only the
implementation stage is formally handed write access, and that hand-off
always goes through `codex-implement`.

### 2. The guard: the same script as Claude's coder

Codex's `PreToolUse` hook input matches Claude's: `tool_name` is `"Bash"`,
the command is in `tool_input.command`, and exit code 2 denies. So
`modules/programs/claude-coder-guard.sh` from #2079 works unchanged. It
blocks deploy and activation, store GC, power, service state and git
history, and it is covered by 88 test cases.

- **Scoping.** Codex hooks are not profile-scoped: they load from every
  config layer. A global guard would block `git commit` in your other
  repos, where Codex commits today. So the hook is a small wrapper that
  exits 0 unless `CODEX_CODER=1`, and otherwise runs the shared guard.
  `codex-implement` sets the variable, and plain `codex` does not.
- **Stable path.** The wrapper is installed at `~/.local/bin/codex-coder-guard`.
  Codex requires you to trust a non-managed hook once (`/hooks`). The trust
  is tied to the hook definition, so a stable path keeps it across
  rebuilds. `codex-nix-format` does the same (`codex-cli.nix`).
- **Registration.** The existing activation entry `codexNixFormatHook`
  already merges into `~/.codex/hooks.json` with `jq`. A second, identical
  entry, `codexCoderGuardHook`, adds a `PreToolUse` hook with matcher
  `Bash` if it is missing, and never rewrites what is there.
- **Guard message.** The guard's message becomes neutral. It currently
  says "Hand this step back to the main session", which only makes sense
  for Claude. It will say "Hand this step back", and name #2079/#2081.

### 3. Review on Astra

A top-level `review_model = "gpt-6-astra"` goes into `~/.codex/config.toml`.
Codex writes that file itself, so a new activation entry, `codexReviewModel`,
inserts the line only if no `review_model` line exists. It goes at the top,
because top-level keys must come before the first table. Your own later
edits win.

### 4. The rules, in the same words everywhere

- **`AGENTS.md`, "Delegating to other models".** Split it into two cases:
  - When another agent calls them, Codex, agy and Ollama draft and review,
    read-only, as today.
  - A Codex session *you* start with `codex-implement` may write code for
    an approved `plan/` in a task worktree. It does not commit, deploy,
    restart, garbage-collect or reboot. The guard enforces that.

  The `HUMANIZE_CODEX_BYPASS_SANDBOX` ban stays.
- **`second-opinion/SKILL.md`, lines 30–32.** The write modes stay unused
  *for second opinions*. Implementation goes through `codex-implement`.
- **`home/development/agent-rules/codex-standards.md`** (Codex only, not
  Antigravity) gains a short "Model by stage" section:
  - Intent, spec, plan and revision decisions run on `gpt-6-astra`
    (`/model gpt-6-astra`).
  - Implementation runs under `codex-implement` (Sol).
  - `/review` runs on Astra.
  - Luna is only for narrow, read-only lookups.
  - At every gate's "stop for review", name the model and command for the
    next stage. This answers the intent's question 4.

### Decisions on the intent's open questions

| # | Question | Decision |
|---|----------|----------|
| 1 | Scope | Codex only. Antigravity is a follow-up issue once Codex has run a few real tasks. Ollama stays draft-only. |
| 2 | Commits | Codex does not commit. It reports changed files and plan deviations, and you (or a Claude session) commit, the same as Claude's coder. The guard blocks `git commit`. |
| 3 | Sandbox and approval | A dedicated `implement` profile: `workspace-write`, network off, `on-request` approvals, launched only through `codex-implement`. |
| 4 | Reminder to switch | `codex-standards.md` tells Codex to name the next stage's model and command at every gate. |

## Alternatives rejected

- **A global guard for every Codex session.** It would block `git commit`
  in other repos, where you use Codex today.
- **Scoping the guard per repo with `.codex/hooks.json`.** It covers only
  this repo, but the rule is meant to be central.
- **Managed hooks in `requirements.toml`.** They would avoid the one-time
  trust step, but the docs do not give their location on Linux, and they
  would apply to every session, with the same problem as a global guard.
- **`prefix_rule(... decision="forbidden")` in `~/.codex/rules/`.** Those
  rules are global, and Codex rewrites that file with the approvals you
  grant.
- **Spawned `worker` agents on Sol with Astra as the session model.** The
  intent already rejected this: Astra would still run every main-session
  turn.
- **A second copy of the guard for Codex.** It would drift from Claude's.
  One file with one test serves both.

## Risks

- **Environment inheritance is not documented.** Whether the hook process
  inherits `CODEX_CODER` from `codex` is not stated in the docs. If it does
  not, the wrapper sees nothing and never guards, and nothing reports it.
  Verification step 3 proves it with a live probe before any real task. If
  it fails, the fallback is to make the wrapper check the hook input's
  `cwd` for a path under a task worktree (`*/nixos-[0-9]*`). That is a
  deviation, recorded in `plan/`.
- **Trust.** Until you trust the hook with `/hooks` on each host, Codex does
  not run it. The probe runs after trusting, and the plan names the step.
- **Network off may break builds.** With network access off, the sandbox
  may block the nix daemon socket, which would make `just test-host` fail
  inside it. Codex then asks to escalate (`on-request`). If that happens on
  every build, set `network_access = true` in the profile. The guard, not
  the network setting, is what stops deploys.
- **Hosts.** p620 and razer. p510 only if you ask.

## Verification

1. **Build.** `just check-syntax`, `just test-host p620` and
   `just test-host razer` pass, and
   `bash modules/programs/claude-coder-guard.test.sh` passes with the
   neutral message.
2. **Files.** After deploying p620:
   - `~/.codex/implement.config.toml` exists;
   - `~/.codex/hooks.json` has exactly one `PreToolUse` entry pointing at
     `~/.local/bin/codex-coder-guard`;
   - `~/.codex/config.toml` has exactly one `review_model` line;
   - `~/.codex/AGENTS.md` contains "Model by stage" and still no `coder`;
   - `~/.gemini/AGENTS.md` does not contain "Model by stage".
3. **Live probe**, in a throwaway git repo, after `/hooks` trust:
   - `codex-implement exec` runs `git commit --allow-empty -m probe`, which
     is blocked, and `git status`, which runs;
   - the repo keeps only its first commit;
   - a plain `codex exec` in the same repo can still commit, which shows
     the guard is scoped.
4. **Model.** `codex-implement` reports `gpt-6-sol` (`/status`), and
   `/review` reports `gpt-6-astra`.
