---
status: approved
issue: 2812
spec: spec/2026-11-09-2812-skip-permissions.md
coders:
  1: codex   # small, tricky shell/Nix in four files; Codex knows its own flags
  2: agy     # mechanical doc rewrites across four files
reviewers:
  - codex    # fresh session reads the diff against this plan
  - agy      # second provider; output is advice only
---

# Plan: run agy and Codex unrestricted, everywhere

These are the approved decisions, carried over from the spec. This plan stands on its own.

- **Owner decision (2026-11-09):** agy runs with `--dangerously-skip-permissions`, and Codex with
  `--dangerously-bypass-approvals-and-sandbox` (or the config equivalent), on **every** launch path. That covers
  the owner's own sessions, delegated reviews, delegated implementation and, through #2810's Amendment 2, herdr
  team members.
- **No sandbox wrapper on any default path.** `agent-review`, `agent-implement` and `agent-sandbox.sh` stay in
  the repo, unused, so going back is a revert.
- **Kept:**
  - `herdr-run`, for its visible pane and env allow-list;
  - the coder guards and their preflight. `CODEX_CODER=1`, `AGY_CODER=1`, `AGY_WORKTREE` and `AGY_GUARD_LOG`
    must reach the guards;
  - `agent-run`'s checks;
  - subscription login only: `forced_login_method=chatgpt`, plus `env -u` of the API-key list.
- **Instruction-only from now on:** Claude alone commits, deploys and reboots; the bus announcement; p510 needs
  the owner's OK; worktrees, never `main`. Claude checks `git status --porcelain` before and after every review.

## Steps

1. **Launchers, defaults and env** (codex).
   - **`home/development/agent-env.sh`:** add
     `agent_api_keys=(OPENAI_API_KEY OPENAI_API_KEY_FILE GEMINI_API_KEY GEMINI_API_KEY_FILE GOOGLE_API_KEY
     ANTHROPIC_API_KEY)`, with the same SC2034 disable comment as the other arrays. Nothing else in that file
     changes.
   - **`home/development/codex-cli.nix:27-37` (`codex-implement`):** keep the guard preflight unchanged. Replace
     `exec "${bin}/agent-implement" codex -- -p implement "$@"` with:
     - `export CODEX_CODER=1`;
     - `env -u` for each name in that list (inline the names; the script is not concatenated with
       `agent-env.sh`);
     - `exec "${bin}/codex" --dangerously-bypass-approvals-and-sandbox -c forced_login_method=chatgpt
       -p implement "$@"`. Keep the `-p implement` position Codex accepts: root options first, then
       `exec`/args from `"$@"`.
   - **`home/development/codex-cli.nix`**, a new activation entry `codexUnrestricted`, modelled on
     `codexReviewModel` (`:115-123`). It makes sure `~/.codex/config.toml` has `approval_policy = "never"` and
     `sandbox_mode = "danger-full-access"`:
     - a missing key is added at the top;
     - a key with a different value is rewritten in place with `sed`;
     - the file keeps mode 0600;
     - never `exit`.
   - **`home/development/antigravity-config.nix:146-198` (`agy-implement`):** keep every preflight (guard,
     `hooks.json`, the probe on a version change, the argument scan). Replace the final `exec … agent-implement
     agy -- …` (`:197`) with `exec env -u <keys> AGY_CODER=1 AGY_WORKTREE="$(git rev-parse --show-toplevel)"
     agy --mode accept-edits --dangerously-skip-permissions $model "$@"`. `AGY_GUARD_LOG` passes through when
     set. agy's own `--sandbox` flag is dropped too, per the decision.
   - **The `agy` shell function**, for bash `initExtra` and zsh `initContent`, in the file that installs agy for
     the user (`modules/ai/antigravity-cli.nix`, or `antigravity-config.nix` if that is where `home.packages` has
     agy). It runs `command agy` with `env -u` of the keys, and adds `--dangerously-skip-permissions` unless that
     flag is already in `"$@"`. Copy the pattern of `claudeLauncher` in `home/development/herdr.nix:22` and `:36-37`.
   - **`modules/ai/antigravity-cli.nix:81`:** `Exec=${agy}/bin/agy --dangerously-skip-permissions`.

   → verify:
   - `nix-instantiate --parse` on each edited `.nix`;
   - `bash -n` on the shell snippets;
   - `nix build .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.path -o /tmp/hp-2812`;
   - `grep` of the built `bin/codex-implement` and `bin/agy-implement` shows no `agent-implement`, and does show
     `CODEX_CODER=1` / `AGY_CODER=1`.

   Traps:
   - `nix-instantiate --parse` must pass for each edited file;
   - activation entries are concatenated, so never `exit`;
   - `~/.codex/config.toml` is owned by Codex, so edit it, never replace it;
   - `$model` in `agy-implement` is intentionally unquoted (SC2086 disable already present).

   **Done (2026-11-09, codex via agent-run, with lead fixes).** Deviations, from agy's spec and plan reviews and
   the lead's review:
   - `agy-guard-probe` drops action 5 (`BypassSandbox`) and its denied check. Without `--sandbox`, agy's
     `run_command` has no `BypassSandbox` parameter, so the probe would fail and `agy-implement` would refuse on
     the next agy update. The adapter's own check and its unit test stay, for a revert;
   - `implement.config.toml` now says `sandbox_mode = "danger-full-access"` and `approval_policy = "never"`, so a
     plain `codex -p implement` matches the launcher. The `[sandbox_workspace_write]` table is gone;
   - `codex-project` (`codex-cli/module.nix`) wraps both Codex calls in the same `env -u` list;
   - `codexUnrestricted` treats a line as a table header only when it is a real `[table]` or `[[array]]` header
     at column 0. Codex's version also stopped at array-element lines, which could duplicate a root key.
     Sample-file results: a missing file is left alone; profile-only keys are left alone and root keys are added;
     different root values are rewritten and backed up; a root key after an array is found; a second run is a
     no-op;
   - checks: the p620 and razer `home.path` builds pass, and the p510 eval passes. The built `codex-implement`
     and `agy-implement` no longer call `agent-implement` and carry `CODEX_CODER=1` and `AGY_CODER=1`. The `agy`
     function passes `bash -n` and `zsh -n`, and its dry run adds the flag exactly once and strips all six keys.

2. **Docs** (agy).
   - **`AGENTS.md`, "Delegating to other models":**
     - replace the ban at `:84` with the owner decision of 2026-11-09;
     - list the instruction-only rules from the intent's table;
     - mark the `agent-review` and `agent-implement` paragraphs "legacy, unused by default (#2812)".
   - **`home/development/claude-code-skills/second-opinion/SKILL.md`:**
     - Codex commands become `herdr-run codex timeout N env -u <keys> codex
       --dangerously-bypass-approvals-and-sandbox -c forced_login_method=chatgpt review|exec …`, with root options
       before the subcommand;
     - agy commands become `herdr-run agy timeout N env -u <keys> agy --dangerously-skip-permissions --mode plan
       …`;
     - add "check `git status --porcelain` before and after; report any change";
     - put `:120-138` under "Legacy: the sandboxed wrappers (unused by default)";
     - the "Never" list keeps "no API key" and "no `HUMANIZE_CODEX_BYPASS_SANDBOX`" and drops the flag ban.
   - **`…/handoff/SKILL.md`:** rewrite `:53` and `:63` as instructions to the agent: no commit, no deploy, no
     staging. Drop the "Never" item about the flag.
   - **`modules/programs/claude-code-managed-claude.md`:** one line saying that delegated agents run unrestricted
     by owner decision (#2812), and that commit, deploy and p510 are instruction-only.

   → verify by `npx markdownlint-cli2` on every touched `.md` (120-character lines, whole file).

   Traps:
   - never start a line with `#<number>`;
   - keep the existing sections, and edit only what this step names.

3. **Build, PR, deploy, live checks** (lead).
   - `just check-syntax`, `just test-host p620`, `just test-host razer`; a p510 eval only.
   - `bash home/development/agent-run.test.sh`.
   - Open the PR linking intent, spec and plan, and saying which steps codex and agy did. Run `@codex review`, a
     fresh Opus review against this plan, and fresh Codex and agy reviewers.
   - Merge. Follow the bus procedure: `read_new`, post the hosts and about 15 minutes, `AGENT_BUS_ANNOUNCED=1`.
     Switch p620, then `just deploy-via-p620 razer`. p510 only with the owner's OK.
   - Live checks on p620, from this session:
     1. an agy `second-opinion` review that needs a shell command completes, where before it failed with
        `jetski … auto-denied`, and `git status --porcelain` is unchanged;
     2. a Codex `review --base` of a small diff completes, with the root-option form;
     3. dummy `OPENAI_API_KEY` / `GEMINI_API_KEY` set **outside herdr** are absent inside the tool;
     4. `agent-run codex` in a scratch worktree edits a file, and returns `ok: true`;
     5. the Codex guard denies `git commit` from the implementer, proving `CODEX_CODER` reached it;
     6. clear the probe's version cache, then `agy-guard-probe` passes all six actions;
     7. `agent-run agy` in a scratch worktree returns `ok: true`, and the guard log has entries;
     8. plain `codex` reports approval `never` and sandbox `danger-full-access` in its status, and plain `agy`
        runs with the flag.
   - razer: check 1 over SSH.
   - Tell #2810 (step 3b, Amendment 2) to rebase onto main.

## Corrections from Codex's plan review

These override the step text above where they differ.

- **Step 1, `codex-implement`:** one command, `exec env -u OPENAI_API_KEY -u OPENAI_API_KEY_FILE -u GEMINI_API_KEY
  -u GEMINI_API_KEY_FILE -u GOOGLE_API_KEY -u ANTHROPIC_API_KEY CODEX_CODER=1 "${bin}/codex"
  --dangerously-bypass-approvals-and-sandbox -c forced_login_method=chatgpt -p implement "$@"`. `agy-implement`
  follows the same pattern: `exec env -u … AGY_CODER=1 AGY_WORKTREE=… agy …`.
- **Step 1, the profile:** confirm that `codex -p implement` loads `~/.codex/implement.config.toml` without the
  wrapper. Codex 0.167 reads `<profile>.config.toml` from `CODEX_HOME`, which is what `agent-implement` relied on
  when it bound that file. Check it in step 3 (check 9): the implementer's status line shows model `gpt-6-sol`.
- **Step 1, the agy shell function:** it goes in a Home Manager module, `home/development/antigravity-config.nix`,
  next to `agy-implement`. `modules/ai/antigravity-cli.nix` is NixOS and installs agy via
  `environment.systemPackages` (`:67`). Body: `agy() { case " $* " in *" --dangerously-skip-permissions "*) ;; *)
  set -- --dangerously-skip-permissions "$@" ;; esac; command env -u … agy "$@"; }`, assigned to both
  `programs.bash.initExtra` and `programs.zsh.initContent`. That is the pattern at `home/development/herdr.nix:22`
  (function) and `:36-37` (assignments).
- **Step 1, `codexUnrestricted` activation, root keys only:**
  - if the file is missing, do nothing (Codex creates it);
  - edit only the part **before the first `[table]` header**:
    - a root `approval_policy` or `sandbox_mode` line with another value is rewritten in place;
    - a missing one is prepended;
    - keys inside `[profiles.*]` or other tables are never touched;
  - use `awk` that tracks "seen a table header", writing to a temp file and installing it with mode 0600 only
    when the result differs;
  - before the first change, save the old root values to `~/.codex/.pre-2812-root-keys` for rollback;
  - make sure a repeat run is a no-op, honour `$DRY_RUN_CMD`, and never `exit`.

  Verify by running the activation snippet on test fixtures: a missing file, root keys absent, root keys
  different, the same keys only inside `[profiles.x]`, and a second run.
- **Step 2, docs:** also rewrite:
  - `second-opinion/SKILL.md:111`, which says the wrapper is required and direct review forbidden;
  - `handoff/SKILL.md:55`, which says staging and builds are impossible, the daemon hidden and no secrets.

  Both Codex review paths must carry "Do not modify anything": `exec` in its prompt file, and `review` through its
  base instruction. The skill says `review --base` cannot take a prompt, so the lead's `git status` check before
  and after is the guard there.
- **Step 3, extra checks:**
  - **9:** `codex -p implement` shows model `gpt-6-sol`;
  - **10:** with `/etc/codex/hooks/coder-guard` temporarily unreadable to the preflight's check (simulated with
    `PATH`/`yq` stubs, not by touching `/etc`), `codex-implement` refuses. The same goes for `agy-implement`
    with a missing `hooks.json` entry, simulated with a temp `HOME`;
  - **11:** a Codex `exec` review completes and leaves the tree unchanged;
  - **12:** all six key variables, set outside herdr, are absent inside each of `codex-implement`,
    `agy-implement`, the `agy` function and the `second-opinion` commands;
  - **13:** `zsh -n` on the generated zsh init, plus a live `zsh -ic 'type agy'`;
  - builds: `nix build` of both the p620 **and** razer `home.path`, and for p510
    `nix eval .#nixosConfigurations.p510.config.system.build.toplevel.drvPath`.
- **Rollback:** restore the root values from `~/.codex/.pre-2812-root-keys`. Delete a key only when no earlier
  value was recorded, and only at root.

## Tests

- Step 1: the parse, build and `grep` checks above.
- Step 2: markdownlint is clean.
- Step 3: all eight live checks pass on p620, and check 1 passes on razer.

## Rollback

Revert the merge commit and redeploy. That restores the sandboxed launchers and the ban. `~/.codex/config.toml`
keeps the two keys. Remove them by hand, or with `sed -i '/^approval_policy\|^sandbox_mode/d'`.
