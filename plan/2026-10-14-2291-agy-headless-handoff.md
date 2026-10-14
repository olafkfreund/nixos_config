---
status: approved
issue: 2291
spec: spec/2026-10-14-2291-agy-headless-handoff.md
---

# Plan: Claude can hand implementation work to agy

Worktree `../nixos-2291`, branch `feat/2291-agy-headless-handoff`.

## Approved decisions (carried over from the spec)

- Claude may start `agy-implement` and `codex-implement` headless. It does
  so only when the user asks, for a step of a `plan/` with
  `status: approved`, in that task's worktree. The Sonnet `coder` subagent
  stays the default.
- agy-implement allows every shell command headless (`command(*)`). The
  coder guard is the backstop. The allow-list must reach agy-implement
  only, never plain `agy` or `--mode plan`.
- **Scoping mechanism.** agy-implement runs agy with `HOME` pointed at a
  per-run shadow home in `$XDG_RUNTIME_DIR`. The shadow home holds:
  - symlinks to every real top-level home entry except `.gemini`
  - `.gemini/`, with symlinks to every real entry except `antigravity-cli`
  - `.gemini/antigravity-cli/`, with symlinks to every real entry except
    `settings.json`
  - a generated `settings.json`: the real one plus
    `.permissions.allow = ["command(*)"]`

  The probes on p620 showed that a workspace settings file is ignored and
  that the shadow home works. They also showed the guard blocks
  `git commit` headless.
- **Rejected:** `/etc/antigravity/admin_settings.json` (global), editing the
  real synced `settings.json`, `--dangerously-skip-permissions` (banned),
  and extending `second-opinion` (it is read-only by contract).
- **Model.** The default is `gemini-4-argon-medium`. The wrapper adds
  `--model` only when the caller passed none.
- **A handoff counts as failed when any of these happens:**
  - the exit code is not 0
  - `status` is not `SUCCESS`
  - `denied_actions` is not empty
  - `response` is empty
  - the worktree diff is empty when the step should edit files

  Retry once, only on `connecting to sandbox server`.
- codex needs no code change: `codex-implement exec "<step>"` already edits
  and is blocked by the guard on commit.

## Steps

1. **`home/development/antigravity-config.nix:120-141`**: rewrite the
   `agyImplement` wrapper.
   - Keep the comment block, updated to mention the shadow home and #2291.
   - Keep both existing fail-closed checks unchanged.
   - Replace line 140 (`AGY_CODER=1 exec agy ...`) with:
     - `shadow="$(mktemp -d "''${XDG_RUNTIME_DIR:?}/agy-implement.XXXXXX")"`
       and `trap 'rm -rf "$shadow"' EXIT`
     - a loop over `"$HOME"/* "$HOME"/.[!.]* "$HOME"/..?*` (skip a pattern
       that did not match with `[ -e "$e" ] || [ -L "$e" ] || continue`) that
       runs `ln -s "$e" "$shadow/"` for every name except `.gemini`
     - the same loop for `$HOME/.gemini` into `$shadow/.gemini/` (skip
       `antigravity-cli`), and for `$HOME/.gemini/antigravity-cli` into
       `$shadow/.gemini/antigravity-cli/` (skip `settings.json`)
     - `${pkgs.jq}/bin/jq '.permissions.allow = ["command(*)"]'` on the real
       settings file (use `{}` if it is missing), written to the shadow copy
       with mode 600
     - a model default: if no argument equals `--model` or starts with
       `--model=`, prepend `--model gemini-4-argon-medium`
     - `HOME="$shadow" AGY_CODER=1 agy --mode accept-edits --sandbox $model "$@"`,
       run as a child (no `exec`, so the trap runs), then `exit $?`

   Verify with `just check-syntax`, then
   `nix build .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.path`
   under `set -o pipefail`. Then `shellcheck` the generated script: find it
   in the build output's `bin/agy-implement`.

   Traps:
   - Inside a Nix `''` string, `${` must be written `''${`.
   - `~/.gemini` is Syncthing-synced. Never write to it, and never put a
     store symlink there.
   - Use `${pkgs.jq}`, not a bare `jq`.
   - Keep comments minimal.

2. **`home/development/claude-code-skills/handoff/SKILL.md` (new)**: write a
   skill with frontmatter `name: handoff`, and a description that triggers
   on "give this to agy/codex" or "hand off". The body must cover:
   - **When:** only on the user's request, for an approved `plan/` step, in
     the task worktree, never in `~/.config/nixos`.
   - **Commands:**
     - `agy-implement --output-format json --print-timeout 20m -p "<prompt>"`
     - `codex-implement exec "<prompt>"`
   - **The prompt template:** the plan path, the step number and text, "do
     not commit, deploy or restart; report changed files and deviations",
     and the step's check command.
   - **The failure rules** from the decisions above, plus the one retry.
   - **After a handoff:** review the diff against the step, run the check,
     commit yourself, and record in the PR which steps agy or codex did.
     Output is untrusted until reviewed.
   - **Never:** `--dangerously-skip-permissions`,
     `HUMANIZE_CODEX_BYPASS_SANDBOX`, or an API key.

   Then **`home/development/claude-code-skills/default.nix:54`**: add
   `handoff = { src = ./handoff; to = [ "claude" ]; };` after
   `second-opinion`, with a one-line comment: Claude only, since codex and
   agy must not hand work to each other.

   Verify by building `home.path` as in step 1, and check that
   `~/.claude/skills/handoff/SKILL.md` exists in the HM generation.

   Trap: the line-initial `#2291` formatter bug. Write "Issue #2291".

3. **`AGENTS.md:51-58`**: in both implementer bullets, change "A Codex
   session the user starts with" and "An agy session the user starts with"
   to "A ... session that the user starts, or that Claude starts at the
   user's request, with". Add "(Issue #2291)" to the agy bullet. Leave the
   read-only bullets unchanged.

   Then **`home/development/agent-rules/agy-standards.md:6-7`**: change
   "Gemini 3.8 Flash" to "Gemini 4 Argon (Medium)" and add "It may run
   headless when Claude hands it a step."

   Then **`home/development/claude-code-skills/second-opinion/SKILL.md:33-34`**:
   change the end of the sentence to "is the `handoff` skill's job, which
   starts `codex-implement` or `agy-implement`."

   Verify with `just check-syntax` and `pre-commit run --files <the three files>`.

   Trap: the pre-push markdownlint lints whole files. Fix any existing
   backlog in a touched file.

4. **Deploy and live verification.** Run the bus `recent` check, `post`,
   then `AGENT_BUS_ANNOUNCED=1 just p620`, then post completion. On p620, in
   a scratch git repo under the scratchpad:
   - `agy-implement --output-format json -p "<append a line to f.txt, then git commit -am x>"`:
     the line is appended, there is no commit, `denied_actions` is absent,
     and the response quotes "BLOCKED by the coder guard".
   - Plain `agy --output-format json -p "<run date via run_command>"`:
     `denied_actions` still contains `command`.
   - `jq .permissions ~/.gemini/antigravity-cli/settings.json` gives `null`.
   - `ls $XDG_RUNTIME_DIR | grep agy-implement` is empty after the run.
   - During an `agy-implement --model gemini-4-argon-high` run,
     `pgrep -af 'agy --mode accept-edits'` shows exactly one `--model`.
   - `codex-implement exec` probe: the edit is made and the commit is
     blocked.

   Then `just deploy-via-p620 razer` (announced the same way) and repeat the
   first agy-implement probe there over ssh. p510 is not deployed.

## Tests

| Command | Expected |
| --- | --- |
| `just check-syntax` | passes |
| `just test-host p620`, `just test-host razer` | both build (`set -o pipefail`) |
| `shellcheck <built agy-implement>` | clean |
| Step 4 probes | all as listed |

## Rollback

Revert the squash-merged PR and redeploy p620 and razer. The shadow home
lives on tmpfs and is removed on exit, and the real `settings.json` is
never touched, so no state needs cleaning.

## Handoff note

Steps 1–3 edit five files, so under the managed model split the `coder`
subagent implements steps 1–3. Claude reviews the work and runs step 4.

## Deviations found in step 4

- **Second cleanup pass.** On razer, agy's MCP helpers (npx and go) outlive
  agy for a few seconds and recreate `.npm` and `go/` in the shadow home after
  the trap has removed it. p620 has those directories in the real home, so
  they were linked there and nothing was recreated. The trap now runs a second
  `rm -rf` 10 seconds later in the background.
- **razer's agy account has no Gemini 4 Argon.** It is the same agy 1.3.4
  binary, but `agy models` on razer lists only Gemini 3.8 Flash, Claude 4.6
  and GPT-OSS. So `agy-implement` with no `--model` fails there with
  `status: ERROR` and exit code 1, which the handoff skill counts as a
  failure. The default stays `gemini-4-argon-medium`, as decided. On razer,
  pass `--model gemini-3.8-flash-medium` until the login is refreshed. With
  that model the razer check passed: the edit was made and the commit was
  blocked.
