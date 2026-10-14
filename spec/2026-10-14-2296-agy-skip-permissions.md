---
status: approved
issue: 2296
intent: intent/2026-10-14-2296-agy-skip-permissions.md
---

# Spec: agy-implement runs with --dangerously-skip-permissions under the guard

## Design

### 1. The wrapper: the flag replaces the shadow home

This is the `agyImplement` wrapper in
`home/development/antigravity-config.nix` (line 126 to its closing `'';`).

- **Keep** the two fail-closed checks: the guard file exists and is
  executable, and `hooks.json` registers it.
- **Keep** the `--model gemini-4-argon-medium` default. It is still skipped
  when the caller passes `--model` or `--effort`.
- **Delete:**
  - the shadow-home block: `mktemp`, the `trap`, `link_except`, the three
    link calls and the generated `settings.json`;
  - the two comment lines that describe it.
- **Run agy as:**
  `AGY_CODER=1 exec agy --mode accept-edits --sandbox --dangerously-skip-permissions $model "$@"`.
  It can `exec` again, because there is no cleanup to run.

The adapter (`modules/programs/agy-guard-adapter.sh`) is unchanged. It
still:

- denies every tool outside its allow-list;
- denies any argument that mentions `.gemini`;
- passes `run_command` to the shared coder guard.

Under the flag, it is the only barrier.

### 2. Rules

- **`AGENTS.md:66-67`.** The ban is scoped: never set
  `HUMANIZE_CODEX_BYPASS_SANDBOX`, and never pass
  `--dangerously-skip-permissions` to plain `agy`, `--mode plan` or Codex.
  The one exception is `agy-implement`, which passes the flag itself, only
  after confirming the guard (Issue #2296).
- **`handoff/SKILL.md`, the "Never" list.** Change the entry to "pass
  `--dangerously-skip-permissions` yourself; `agy-implement` already does,
  under the guard". Claude does not add the flag to any other command.
- **`handoff/SKILL.md:31-32`, the razer note.** Keep it until razer's agy is
  signed in with the Ultra account. The intent's open question was not
  answered, so verification step 3 decides whether the note goes.
- **`agy-standards.md`.** No change. It does not mention the flag.

## Alternatives rejected

- **Keep the shadow home.** It works, but it is about 30 lines with known
  edge cases: MCP children recreating caches, and state lost when agy
  rewrites a file by rename. The flag gives the same result, proven by
  probe, with the hooks still firing.
- **The flag plus the shadow home.** That adds no protection, because the
  flag already skips every permission prompt.
- **Allowing the flag in general.** It is outside the user's request. Plain
  agy has no guard.

## Risks

- **A future agy release could skip hooks under the flag.** The guard would
  then be gone silently. To mitigate this, the verification probe (commit
  blocked, `.gemini` write blocked) becomes a required re-check after every
  agy bump, written into the skill. This is the main risk.
- **The flag may also skip prompts we have not seen,** such as browser,
  MCP, or file access outside the workspace. The adapter's deny-by-default
  list covers every tool that is not explicitly allowed. `--sandbox` stays
  on for terminal commands.
- **razer** keeps failing without `--model` until it is signed in again. It
  fails visibly (`status: ERROR`).
- **Hosts:** p620 and razer. p510 is not deployed.

## Verification

1. `just check-syntax`, and a p620 toplevel build with `pipefail`.
2. Deploy p620. In a scratch repo, `agy-implement` must:
   - make the edit;
   - have `git commit` blocked, with `HEAD` unchanged;
   - have `touch ~/.gemini/...` blocked;
   - show no `denied_actions`.

   `pgrep -af` during the run must show the flag and a single `--model`.
   Plain `agy -p` must still be auto-denied (`denied_actions: command`).
3. Deploy razer and run the same probe. If razer is signed in with the
   Ultra account by then, run it without `--model` and drop the razer note.
   Otherwise run it with `--model gemini-3.8-flash-medium` and keep the note.
