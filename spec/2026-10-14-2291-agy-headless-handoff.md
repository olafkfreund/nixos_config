---
status: draft
issue: 2291
intent: intent/2026-10-14-2291-agy-headless-handoff.md
---

# Spec: Claude can hand implementation work to agy

## Findings that shape the design

Probes run on p620 on 2026-10-14, in scratch repos under the session
scratchpad, with agy 1.3.4 and codex 0.162.1:

| Probe | Result |
| --- | --- |
| agy headless, `permissions.allow` in `<workspace>/.gemini/antigravity-cli/settings.json` | Ignored. The command was auto-denied. |
| agy headless, `HOME` pointed at a shadow home whose `settings.json` adds `permissions.allow = ["command(*)"]` | The command ran. OAuth login still worked. |
| The same, with `AGY_CODER=1` and a `git commit` step | The edit ran. The commit was refused with "BLOCKED by the coder guard (#2079, #2081)". |
| `codex-implement exec` with an edit and a `git commit` step | The edit ran. The commit was blocked by the managed guard. No change needed. |
| agy `--output-format json` on a denial | Reports `status: SUCCESS`, an empty `response`, and `denied_actions: [{"action":"command"}]`. |

agy has no `--settings` flag and no workspace settings layer. It reads
`~/.gemini/antigravity-cli/settings.json` relative to `$HOME`, and
`/etc/antigravity/admin_settings.json`. The admin file applies to every agy
session.

One probe also hit a transient `connecting to sandbox server: ... connection
reset by peer` error. It passed on retry.

## Design

### 1. agy-implement runs agy in a shadow home

The file is `home/development/antigravity-config.nix`, in the `agyImplement`
wrapper.

After the two existing fail-closed checks, the wrapper:

1. Creates a fresh `$(mktemp -d "$XDG_RUNTIME_DIR/agy-implement.XXXXXX")`
   and removes it on exit with `trap`. The directory is on tmpfs, private to
   the user, and never synced.
2. Symlinks every top-level entry of the real `$HOME` into it except
   `.gemini`. That way `git`, `nix`, `just` and `~/.cache` behave the same
   for the commands agy runs.
3. Creates `.gemini/` in the shadow home with a symlink to every real
   `~/.gemini` entry except `antigravity-cli`. `config/hooks.json`, and so the
   guard, is reached through its symlink.
4. Creates `.gemini/antigravity-cli/` with a symlink to every real entry
   except `settings.json`. Conversations, brain and logs are still written to
   the real directories.
5. Writes `settings.json` as the real file with `jq` setting
   `.permissions.allow = ["command(*)"]`.
6. Runs agy with `HOME=<shadow> AGY_CODER=1 agy --mode accept-edits --sandbox`.
   It adds `--model gemini-4-argon-medium` only when the caller passed no
   `--model`.

The real `settings.json` and the synced `~/.gemini` are never written.
Plain `agy` and `agy --mode plan` keep today's permissions, which meets the
intent's scoping constraint. The guard stays the backstop for commit,
deploy, restart, GC and reboot. The guard denies every tool outside its
allow-list, so `command(*)` only matters for shell commands.

The wrapper runs agy as a child process rather than `exec`, so the `trap`
cleanup runs, and it passes agy's exit code through.

### 2. A `handoff` skill for Claude

The new skill lives in `home/development/claude-code-skills/handoff/SKILL.md`
and is wired up the same way as `second-opinion` in that directory's
`default.nix`.

It covers both implementers. Claude uses it only when the user asks
("give this to agy" or "to codex"), and only for a step of a `plan/` with
`status: approved`, in that task's worktree.

- **agy:** `cd <worktree> && agy-implement --output-format json --print-timeout 20m -p "<step>"`
- **codex:** `cd <worktree> && codex-implement exec "<step>"`
- **Prompt content:** the plan path, the step number, "do not commit", and
  the step's check command.
- **The step counts as failed if any of these happens:**
  - the exit code is not 0
  - `status` is not `SUCCESS`
  - `denied_actions` is not empty
  - `response` is empty
  - `git diff` in the worktree is empty when the step should edit files
- **Retry:** once, only on the sandbox-server connection error.
- **Afterwards:** Claude reviews the diff against the plan step, runs the
  step's check, and commits. The PR says which steps agy or codex did.

### 3. Rules updated

- **`AGENTS.md`, "Delegating to other models":** the two implementer bullets
  read "the user or Claude, on the user's request, starts ... for an approved
  `plan/`". The rest stays the same.
- **`home/development/agent-rules/agy-standards.md`:** the model name
  changes to Gemini 4 Argon (Medium), and the section notes headless use
  under a guard.
- **`second-opinion/SKILL.md`, line 33:** points to the `handoff` skill.

## Alternatives rejected

- **`/etc/antigravity/admin_settings.json` with `command(*)`.** It is
  global, so plain `agy` and `--mode plan` sessions would also run every
  command unprompted. That breaks the intent's scoping constraint.
- **`permissions.allow` in the real `~/.gemini/antigravity-cli/settings.json`.**
  This file is global and Syncthing-synced to every host.
- **A workspace settings file.** agy ignores it (see the probe).
- **`--dangerously-skip-permissions`.** It is banned by `AGENTS.md` and the
  intent.
- **Extending `second-opinion` instead of adding a skill.** That skill is
  read-only by contract. Mixing in write access makes it easier to trigger
  write access by accident.

## Risks

- **A new agy release could resolve settings without `$HOME`.** The handoff
  would then fall back to auto-denial and fail visibly through
  `denied_actions`. It would not fail silently. Re-probe after every agy
  bump.
- **Symlinked dotfiles.** A tool that replaces a file atomically
  (write-temp-then-rename) inside a symlinked top-level directory works. A
  tool that renames a top-level dotfile itself would replace the symlink in
  the shadow home only, and the change is lost when the shadow home is
  removed. This is acceptable for a session that only edits files in a
  worktree.
- **The guard is the only barrier for shell commands.** That was the user's
  decision (intent decision 3). The guard is deny-by-default for unknown
  tools and was proven to fire headless.
- **Model availability.** `gemini-4-argon-medium` is in `agy models` on this
  account today. If it disappears, agy errors out, which is visible.
- **Hosts:** p620 and razer. p510 gets the wrapper through home-manager, but
  it is not deployed without approval.

## Verification

1. `just check-syntax`, then `just test-host p620` and `just test-host razer`.
2. After the p620 deploy, in a scratch git repo:
   - `agy-implement --output-format json -p "<append a line, then git commit>"`
     edits the file, `denied_actions` is absent, and the response quotes the
     guard's BLOCKED message.
   - Plain `agy -p "<run date>"` is still auto-denied (proves the scoping).
   - The real `~/.gemini/antigravity-cli/settings.json` is unchanged:
     `jq .permissions` gives `null`.
   - No `agy-implement.*` directory is left in `$XDG_RUNTIME_DIR`.
   - `agy-implement --model gemini-4-argon-high -p ...` uses that model, and
     only one `--model` reaches agy (`ps` during the run).
3. The same agy-implement probe on razer after its deploy.
4. `codex-implement exec` probe (edit allowed, commit blocked) on p620. It
   already passes today.
