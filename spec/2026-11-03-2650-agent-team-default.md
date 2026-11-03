---
status: approved
issue: 2650
intent: intent/2026-11-03-2650-agent-team-default.md
---

# Spec: Codex and agy as permanent team members, with Claude as manager

## Decisions (from the intent's open questions)

1. The switch is **per user and host**, persistent until flipped.
2. When a provider fails or runs out of quota, Claude **reports it and carries
   on**; the switch is not touched.

## Design

### 1. The switch: `agent-team on|off|status`

- A `writeShellScriptBin "agent-team"` in
  `modules/programs/claude-code-managed.nix`, added to
  `environment.systemPackages` behind a new option
  `modules.programs.claude-code-managed.agentTeam.enable`
  (default `true`, so all three hosts get it without host edits).
- State lives in `${XDG_STATE_HOME:-$HOME/.local/state}/agent-team/mode`,
  holding `on` or `off`. **No file means on** (the user asked for "always").
  Not under `~/.claude`: that directory is syncthing-synced, so the switch
  would flip every host at once, against decision 1.
- `/agent-team` slash command in
  `home/development/claude-code-commands/default.nix`, next to `/team`:
  `!agent-team $ARGUMENTS`, so the user can flip it without leaving the
  session.

### 2. Telling Claude the mode: a one-line prompt hook

- A `UserPromptSubmit` hook, added to the `hooks` merge in
  `claude-code-managed.nix` next to `parrHooks`, prints
  `<system-reminder>agent-team: on</system-reminder>` (or `off`).
- `UserPromptSubmit`, not `SessionStart`, so a flip takes effect on the next
  prompt of a running session, with no restart. Cost: one short line per
  prompt.

### 3. Policy: what "on" means

One new bullet in the **Model split** section of
`modules/programs/claude-code-managed-claude.md`. That section is
Claude-only (`home/development/agent-rules.nix` cuts the text at
`"\n## Model split (Claude Code only)"`), which is right: Codex and agy do not
dispatch each other. Keep the heading text exactly as it is.

When the prompt hook says `agent-team: on`, for any task under the artifact
workflow (exempt tasks are untouched):

- **Planning.** Before stopping on an intent, spec or plan draft, run the
  `second-opinion` skill on it with Codex and agy, read-only, and show their
  findings (verified, refuted or unverified) next to the draft. Revise the
  draft first if a finding is right. Their agreement is never an approval.
- **Coding.** Every draft plan carries `coders:` for each step that edits
  files and `reviewers: [codex, agy]`, each with a one-line reason. Default
  routing, which Claude may override with a reason:
  - large or mechanical edits across many files → `agy`
  - small, tricky logic (guards, parsers, shell with quoting) → `codex`
  - everything else → `coder` (Sonnet)
  - builds, reviews, deploys and commits → Claude ("Mine")
- **Review.** The fresh Opus reviewer still always runs; Codex and agy add
  read-only reviews of the final diff.
- **Opt-out.** The user deletes a `coders:` entry or a reviewer from the
  draft plan before approving it. What the approved plan says is what runs.
- **Failure.** A provider that fails, times out or hits quota is reported
  verbatim; Claude carries on without it (decision 2). A failed coder step
  goes to the `coder` or Claude, as `handoff` already says.

When it says `agent-team: off`, the bullet does not apply and today's rules
stand: opt-in by user request or by an approved `plan/`.

Matching text changes, each one phrase:

- `AGENTS.md:51-59`: "… or because an approved `plan/` names it in
  `coders:`" stays; nothing to add, since agent-team mode acts only through
  `coders:` in an approved plan.
- `AGENTS.md:242-244`: "only when the user asks or an approved `plan/` names
  them in `reviewers:`" gains "or Claude Code's agent-team mode is on (see
  the managed CLAUDE.md)". "Never otherwise" stays.
- `second-opinion` skill: the same addition to `description` and "When to
  use". Everything under "What this skill will not do" stays.
- `handoff` skill: unchanged triggers (it still acts only on an approved
  plan's `coders:`), but its "Commands" and "A handoff failed when" sections
  are replaced by one call to `agent-run` (section 4).
- `artifact-workflow` skill: one rule line, "When agent-team mode is on,
  every draft plan fills `coders:` and `reviewers:` (see the managed
  CLAUDE.md); the user opts out by deleting entries before approval."

### 4. `agent-run`: one handoff, one verdict

A `writeShellApplication "agent-run"` in a new file
`home/development/agent-run.nix`, imported explicitly next to
`codex-cli.nix` and `antigravity-config.nix`, with its logic in
`home/development/agent-run.sh` so it can be tested.

```bash
agent-run <agy|codex> <prompt-file>     # run in the task worktree
```

- Refuses to run in `~/.config/nixos` (the shared checkout) or on `main`.
- Records `git rev-parse HEAD`, runs `agy-implement --output-format json
  --print-timeout 20m -p "$(cat prompt)"` or `codex-implement exec - <
  prompt`, then applies the six checks `handoff` lists today: exit code,
  agy `status == SUCCESS`, empty `denied_actions`, non-empty response,
  non-empty worktree diff, unmoved `HEAD`.
- Retries once on `connecting to sandbox server`, as today.
- Prints one JSON object on stdout:
  `{"ok":bool,"tool":"agy","reason":"…","changed":["file",…],"head_moved":bool,"log":"/path"}`
  and exits 0 when `ok`, 1 otherwise. Full tool output goes to the log file,
  not to Claude's context.
- An assert-based self-test, `home/development/agent-run.test.sh`, runs the
  script against stub `agy-implement` / `codex-implement` binaries in a
  temp git repo and covers each failure case.

The Sonnet `coder` stays a Claude agent driven by `Agent`/`SendMessage`;
`agent-run` covers only agy and Codex.

### 5. Parallel reviews

`second-opinion` currently says "Run the calls one at a time, never in
parallel"; no spec records why. Replace it with: run the Codex and agy calls
in parallel as two background Bash commands, each with its own output file
and timeout, and wait for both. If a parallel run turns out to fail where a
sequential one did not, the rule goes back and the reason is written down.

### 6. `/team` becomes the manager

Rewrite `teamCommand` in `home/development/claude-code-commands/default.nix`:

- Argument: the path of an approved `plan/`. No approved plan → stop and say
  so (no more ad-hoc decomposition, which bypassed the plan gate).
- Read `coders:`. For each step, in plan order:
  - `coder` → one Sonnet `coder` agent per task, later steps via
    `SendMessage` (as the model split says);
  - `agy` / `codex` → `agent-run` in the background;
  - unlisted → model-split default.
- **Parallel only when safe.** Steps run in parallel only if the plan marks
  them independent and their named files are disjoint; each parallel agy or
  Codex step gets its own worktree off the task branch
  (`git worktree add ../nixos-<issue>-s<n> HEAD`), and Claude applies its
  diff back to the task worktree (`git -C … diff | git apply`), then removes
  that worktree. Otherwise steps run sequentially in the task worktree.
- After each step: Claude runs the step's check, commits, and records which
  worker did it. At the end: fresh Opus review plus the plan's `reviewers:`.
- No Opus agent-team teammates any more: that broke the model split.

### Out of scope

- Changing what Codex or agy may write, or the guards (#2081, #2087, #2296).
- Ollama: unchanged.
- A docs page: `AGENTS.md`, the managed CLAUDE.md and the skills are where
  agents read this, and they are the documentation.

## Alternatives rejected

- **Environment variable or Nix option as the switch.** An env var needs a
  session restart; a Nix option needs a rebuild. The user asked for "at will".
- **State under `~/.claude`.** Syncthing-synced, so one flip changes every
  host (decision 1 says per host).
- **`SessionStart` hook.** A flip would be ignored by running sessions.
- **Wrapping agy and Codex as Claude agents** so `SendMessage` reaches them.
  It puts a Claude model between Claude and the tool: more tokens, one more
  place to fail, and no warm cache on the agy/Codex side anyway.
- **Auto-off on quota exhaustion.** Rejected by decision 2.
- **A new `parallel:` plan field.** The plan step text already names files;
  "independent of step N" in the step is enough, and Claude checks the file
  sets are disjoint.

## Risks

- **Quota and latency.** Two reviews per draft adds minutes per gate and
  uses ChatGPT and Antigravity quota; heavy days may hit limits. Mitigated by
  parallel runs, timeouts, and the off switch.
- **Parallel Codex + agy** may fail for a reason the old sequential rule
  guarded against. Watched for in verification; reverted if so.
- **Prompt hook cost.** One line per prompt in every session on every host.
- **`/team` behaviour change.** Anyone (or any doc) using `/team` for ad-hoc
  decomposition loses that; it now needs an approved plan.
- **Merge conflicts** when a parallel step's diff no longer applies. Then
  Claude reruns that step sequentially.
- **Text drift.** The "on" rule lives in the managed CLAUDE.md; the skills
  and `AGENTS.md` only point to it, so it is stated once.
- Hosts: all three get the hook and the command (system and HM). p620 and
  razer are deployed; p510 is built only after asking.

## Verification

- `just check-syntax`, `just validate`.
- `bash home/development/agent-run.test.sh` passes (all six failure cases
  and the success case).
- `just test-host p620` and `just test-host razer` build; p510 eval only.
- After deploying p620: `agent-team status` → `on` with no state file;
  `agent-team off` → the next prompt in a running session shows
  `agent-team: off`; `agent-team on` restores it. On razer the state is
  independent.
- Dry run on a throwaway task: Claude's draft plan carries `coders:` and
  `reviewers:`, and the Codex and agy reviews run in parallel and both
  return.
- `/team` with no plan path refuses; with an approved plan it dispatches per
  `coders:`.
