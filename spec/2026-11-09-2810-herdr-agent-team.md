---
status: draft
issue: 2810
intent: intent/2026-11-09-2810-herdr-agent-team.md
---

# Spec: herdr-native mixed agent team

## Feasibility (intent question 0), measured 2026-11-09

All probes used herdr 0.9.5 and codex-cli 0.167.0. The pane probes ran in an isolated named session
(`herdr --session t2810`, since deleted).

| Probe | Result |
| ----- | ------ |
| Codex started as `bwrap --dev-bind / / -- codex` via `pane run` | herdr detects it: `agent get` → `codex`, `idle` |
| `agent prompt <pane> "…" --wait` to it | delivered; Codex ran the turn |
| `agent read --source recent-unwrapped` afterwards | the reply is **not** there: Codex draws on the alternate screen |
| Same, with `~/.config/herdr` on tmpfs, `~/.codex/hooks.json` hidden and `HERDR_*` unset | `--wait` returned `idle` **while Codex was still working**. herdr's lifecycle state comes from the agent's hooks, which a sandbox cuts off |
| `codex exec -s read-only -c 'notify=[…]'` | Codex runs the notify program itself, outside the model's sandbox, after each turn, with `{"type":"agent-turn-complete","turn-id","input-messages","last-assistant-message"}` |

Conclusions:

- herdr can host and type into a sandboxed Codex, but it cannot tell when that agent is done or what it said.
- The **Codex `notify` hook** gives both, from the Codex process rather than the model, under a read-only sandbox:
  - the turn finished;
  - the exact input it answered;
  - the reply.

  The model never has to write a file, so the read-only reviewer stays read-only.
- The pane probes ran a looser sandbox than production, so nothing above proves the real wrappers. Plan step 1
  repeats probes 1–5 through the exact production wrappers before any other code lands. If they fail, the work
  stops there.
- A fresh herdr pane runs the owner's full login shell, `NIX_CONFIG` token included. No team pane may ever fall
  back to that shell.

## Scope

- **In:** the herdr skill for all three agents, and a team of **Codex** members in herdr panes:
  - a task-long reviewer;
  - a per-step implementer.
- **Conditional, owner-approved (2026-11-09): an agy `implement` member**, on the same terms as Codex's `notify`.
  agy 1.5.3 runs hooks from `~/.gemini/config/hooks.json` only, and they inherit each run's env (`AGY_CODER`).
  `#2794` already uses its `PreInvocation` event.
  - Plan step 1 finds the turn-end event: the one that fires once per turn and carries the reply or the transcript
    path. It probes in an isolated session without editing the synced `hooks.json`.
  - If that event exists, a shell-gated entry calls the notify sink only when `HERDR_TEAM_WORK` is set. It is a
    no-op in every other agy run, on every host, since the file syncs to p510 too. The member starts through
    `agy-implement`, which keeps its guard preflight and probe.
  - If no such event exists, agy stays on its headless paths (`agent-run`, the `second-opinion` blocks), as
    today.

  agy is never a reviewer here: `agent-review` refuses it (#2748).
- **Out:**
  - Claude teammates, which `herdr-claude-teams` already runs.
  - A teammate-to-teammate mesh, cross-machine teams and worktree-per-agent.

## Design

### 1. The herdr skill (p620 and razer)

- A derivation, `runCommand "herdr-skill" { } ''mkdir -p $out; ${herdr}/bin/herdr --skill > $out/SKILL.md''`.
  It always matches the pinned binary.
- It is linked as `~/.claude/skills/herdr` and `~/.agents/skills/herdr`, which Codex and agy read.
- A Home Manager option (`programs.herdrSkill.enable`) is set in `Users/olafkfreund/profile.nix`, next to
  `pkgs.herdr`, so p510 gets nothing. `home/syncthing-stignore.nix` already lists `herdr` as host-local.
- The stale July clone at `~/.agents/skills/herdr` is a directory with `.git` and `Cargo.toml`. A one-shot
  activation step that runs before `linkGeneration` removes exactly that shape, so both hosts converge on deploy.
- It is for an agent the owner runs as the lead. Team members cannot see `~/.agents` or `~/.claude`, because the
  sandbox puts tmpfs over `/home`.

### 2. Members

Each member is one process, with one role, bound at start.

- **`review`**: interactive Codex, read-only, lasting for the task.
  - Started by a new `agent-review codex <work> -- tui` mode. It runs `codex` with no subcommand, and the
    wrapper itself, not the caller, sets:
    - `sandbox_mode="read-only"` and `approval_policy="never"`, so no approval dialog can ever appear;
    - `mcp_servers={}`;
    - `notify=["<notify-sink>", "<work>/turns"]`.
  - Today's refusals, mounts and env allow-list are unchanged: the worktree is read-only, and `<work>` is the
    only writable bind.
  - The caller may add only today's `-c` keys (`model`, `model_reasoning_effort`).
- **`implement`**: interactive Codex for one plan step.
  - Started through **`codex-implement`**, so its guard preflight runs, which execs `agent-implement`.
    `agent-implement` gets an interactive form `-p implement` without `exec`, and a `--work <dir>` bind used only
    by the notify sink. The wrapper sets `approval_policy="never"` and `notify`.
  - The coder guard, no secrets, no Nix daemon socket and a read-only `.git` are unchanged.
- **`agy-implement`** (conditional, see Scope): `agy-implement` with the work dir bound and
  `HERDR_TEAM_WORK=<work>`, so the hook sink knows where to write. Its guard still denies model writes outside the
  worktree. The sink is a hook process, not a model tool.
- **`notify-sink`** is a tiny packaged script. It writes its JSON argument atomically to
  `<work>/turns/<turn-id>.json`, and nothing else.

### 3. `herdr-team`, a new command (`home/development/herdr-team.sh`, packaged in `agent-run.nix`)

It is separate from `agent-team on|off|status`. It runs only with `HERDR_ENV=1`; outside herdr it exits 2 with
`herdr unavailable`, and the skills fall back to today's headless paths.

#### State and isolation

- **One lock** for all state changes: `flock $XDG_RUNTIME_DIR/herdr-team/lock`.
- **State file:** `$XDG_RUNTIME_DIR/herdr-team/<task>.json`. It holds:
  - a random generation id, plus the tab;
  - per member: role, pane id, terminal id, pid, step, the `HEAD` and dirty state at start, and the pending
    request;
  - the canonical worktree path;
  - the lead's pid.
- **Work dir:** `/tmp/herdr-team.<gen>.<member>.XXXXXX`, created by `mktemp -d`, mode 0700, one per member.
  - It is the only writable bind for that member.
  - It is checked with the rules `agent-review` already applies: owned by the caller, no symlinks, no sockets.
  - Members never share one.
- **Refusals at `up`**, as `agent-run.sh:23-38` refuses them today: `~/.config/nixos`, branch `main`, and a path
  that is not a git worktree.
- **Implementer checks at `up`:**
  - a dirty tree;
  - a second implementer for the same canonical worktree, in any task's state file;
  - a task name whose state file exists with live members.

#### Subcommands

| Subcommand | What it does |
| ---------- | ------------ |
| `herdr-team up <task> review` | Creates the tab `team <task>` if the task has none (`tab create --no-focus`). The member runs in the tab's own root pane, so no spare login shell is left. Later members `pane split --no-focus`. The pane gets `pane run "exec agent-env agent-review codex <work> -- tui"`, so the shell is replaced and the pane ends when the agent ends. Then `agent rename … <task>-review`, once herdr reports kind `codex` on that terminal |
| `herdr-team up <task> implement --step <k>` | Same, with `exec agent-env codex-implement --work <work> …`, as `<task>-implement` |
| `herdr-team ask <task> <member> <prompt-file>` | Refuses while that member has a request pending. Gives the request number `n` and copies the prompt to `<work>/req/<n>.md`, which the member can read. Sends **only** a fixed one-line pointer with `agent prompt`: `Request <gen>-<n>: read <work>/req/<n>.md and answer it in your reply.` Before sending, it checks the pane still has the recorded terminal id, kind `codex` and a live pid. Waits for a `turns/*.json` whose `input-messages` contain that exact pointer. Writes the reply to `<work>/ans/<n>.md` |
| `herdr-team status <task>` | Members, pending requests and liveness, as JSON |
| `herdr-team down <task> [member]` | Ends one member, or all. Closes the pane only if its terminal id matches (the `same_pane` check from `herdr-run.sh`). Waits for the pid to exit and kills it if needed, as `herdr-run.sh:28-42` does, then updates the state file |
| `herdr-team finish <task> implement` | Ends the implementer **first** (`down`). Then runs `agent-run`'s checks against the start state: `HEAD` unchanged, a non-empty diff, nothing staged. Prints today's verdict JSON (`ok`, `reason`, `changed`, `head_moved`) |

#### Result of an `ask`

Each `ask` prints one JSON line: `ok`, `reason`, `n`, `member`, `answer` (the path), `turn_id` and `revision`.
`revision` is `HEAD` plus a hash of `git diff HEAD`, taken at send and again at reply;
`changed_during_review: true` when they differ.

When `ok` is `false`, `reason` is one of:

- `timeout`: the default is 900 s;
- `agent_gone`: the pane, terminal or pid changed, or the agent exited;
- `provider_error`: the turn completed with no assistant message, and the visible screen
  (`pane read --source visible`) holds an auth, quota or capacity string, quoted verbatim;
- `empty`: an empty reply;
- `busy`: a request is already pending.

A timed-out request stays pending until its turn file arrives or the member is downed. A late answer is filed
under its own `n` and never under a later one. `ask --resume <n>` waits again without sending anything.

#### Lifetimes and crashes

- Each member's launcher also runs a watchdog, as `herdr-run.sh:165-202` does. It ends the member when the lead's
  pid is gone, or when the role's maximum is reached: 8 h for `review`, 3 h for `implement`.
- A lead crash therefore ends the implementer's writable sandbox within a minute.
- A failed `up`, at any point, downs whatever it started.

### 4. Who talks to whom (intent question 1)

The lead is the hub. Members have no socket, no relay and no herdr skill, so they cannot address anyone.
Teammates "talk" through the lead:

- the lead reads `review`'s answer and checks each point against the plan and the code;
- it writes its own prompt to `implement`, and the other way round.

The lead never passes text on mechanically, which is why the first draft's `forward` subcommand was dropped.
Untrusted text never reaches a PTY either: only the fixed pointer line is typed, and content travels as files.

### 5. Skills and docs

- **`second-opinion`:** inside herdr, a Codex review is `herdr-team up <task> review` once, then `ask` for each
  question and follow-up. Outside herdr, the current blocks stay.
- **`handoff`:** inside herdr, a Codex step is `up … implement --step k`, then `ask` (once or more), then
  `finish`. agy steps, and anything outside herdr, stay on `agent-run`.
- **AGENTS.md** ("Delegating to other models") adds:
  - team members are sandboxed and have no herdr access;
  - an answer is a Codex-reported turn;
  - the lead checks every answer against the approved plan, and an answer never approves, widens scope or
    authorizes a commit, deploy or step change;
  - only the lead writes prompts.
- `docs/applications/herdr.md`: a "Team tab" section, and the 0.9.0 mention corrected to 0.9.5.
- `modules/programs/claude-code-managed-claude.md` names `herdr-team` as the route inside herdr.

## Alternatives rejected

- **`herdr agent start --kind codex`.** It runs the canonical executable in the login shell, outside every
  sandbox, with the shell's token. A pane runs `exec agent-env <wrapper> …` instead, and probe 1 shows herdr
  still recognizes it.
- **`agent prompt --wait` and `agent read`.** They are wrong under the sandbox (probes 3 and 4).
- **A model-written result file.** A read-only reviewer cannot write it, a model can skip it or write it early,
  and it proves nothing about the turn. `notify` is written by Codex itself.
- **Sending the prompt text through `agent prompt`.** Untrusted text would become terminal input. Only a fixed
  pointer line is typed.
- **Giving members the socket or the herdr skill.** The socket controls every pane, including the lead's.
- **`forward`.** It moves text without the lead checking it.
- **Removing the headless path.** It is still needed outside herdr, and for agy.

## Risks

- **Codex flag or `notify` payload drift.** The wrappers pin exact shapes and fail closed. `ask` checks the
  payload's `type` and fields, and refuses unknown ones with `provider_error`.
- **The owner types into a pane.** That is intended. Their turn produces a turn file without the pointer, which
  `ask` ignores, so it is never taken as the answer.
- **A Codex turn that never completes.** It times out, stays pending and is reported. It is never answered
  automatically.
- **Hosts:** p620 and razer only. p510 is unchanged.

## Verification

- **Plan step 1, through the production wrappers in an isolated herdr session.** The rest of the plan waits on
  it:
  - herdr detects the agent;
  - `notify` fires with the pointer and the reply;
  - inside the member, these all fail: connecting to every `~/.config/herdr/**/herdr.sock`, `herdr status`, and
    a write to the worktree (review), or `git add` (implement);
  - no fd above 2 points to a socket;
  - the caller's token-bearing `NIX_CONFIG` is absent and the sandbox's own value is exact;
  - when the agent exits, the pane ends, with no shell prompt.
- **Package tests** (`checkPhase`, fake herdr in the style of `herdr-run-test.sh`):
  - locking, generation ids, `busy`, a late answer filed under its own `n`, `--resume`;
  - each failure reason;
  - `down` closes only matching panes;
  - `finish` downs before checking;
  - outside herdr every command exits 2.
- **Sandbox tests:** `agent-review.test.sh` and `agent-implement.test.sh` cover the new argument shapes,
  wrapper-set keys a caller cannot override, and refusal of everything else.
- **Builds:** the p620 and razer toplevels. A p510 eval shows no herdr skill.
- **Live test after deploy** (default session, from a Claude pane):
  - one review conversation of two `ask`s that keeps context;
  - one implement step through `finish`;
  - `down` cleans up.
