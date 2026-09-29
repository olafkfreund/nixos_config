---
status: approved
issue: 2081
spec: spec/2026-09-29-2081-codex-coder-write-access.md
---

# Plan: Codex may write code for approved plans

## Approved decisions

These are copied from the approved spec, so this plan can be implemented
without opening the intent or the spec.

- **One Codex session changes model by stage.** Intent, spec, plan and
  revision decisions run on `gpt-6-astra`. Implementation runs on
  `gpt-6-sol`, under `codex-implement` only. `/review` runs on Astra. Luna
  is only for narrow, read-only lookups.
- **`codex-implement`** runs `CODEX_CODER=1 exec codex -p implement "$@"`.
  The profile file, `~/.codex/implement.config.toml`, is installed by
  home-manager with `home.file`. `~/.codex` is not synced by Syncthing, so
  a Nix store symlink there is safe. Its contents:
  - `model = "gpt-6-sol"`, `model_reasoning_effort = "medium"`;
  - `sandbox_mode = "workspace-write"`, `approval_policy = "on-request"`;
  - `[sandbox_workspace_write] network_access = false`.
- **The guard is the shared file** `modules/programs/claude-coder-guard.sh`
  from #2079. Codex's `PreToolUse` input matches Claude's, and exit code 2
  denies. A wrapper runs it only when `CODEX_CODER=1`, because Codex hooks
  are not profile-scoped and plain Codex still commits in other repos. The
  wrapper has a stable path, `~/.local/bin/codex-coder-guard`, so the
  one-time `/hooks` trust survives rebuilds. It is registered in
  `~/.codex/hooks.json` by a jq merge that only adds, never rewrites.
- **The guard's message is neutral:** "Hand this step back", naming #2079
  and #2081.
- **Review model.** `review_model = "gpt-6-astra"` is inserted at the top of
  `~/.codex/config.toml` only if no `review_model` line exists.
- **Commits.** Codex does not commit. It reports changed files and plan
  deviations.
- **The rules say the same thing everywhere.**
  - `AGENTS.md` separates delegated use (read-only) from a Codex session
    you start with `codex-implement` (it may write code for an approved
    `plan/`).
  - `second-opinion` keeps its write modes unused for second opinions.
  - `codex-standards.md` gains a "Model by stage" section that tells Codex
    to name the next stage's model and command at every gate.
- **Scope.** Codex only; Antigravity is a follow-up. p620 and razer; p510
  only if you ask.
- **Fallbacks.**
  - If the live probe shows the hook does not inherit `CODEX_CODER`, the
    wrapper instead checks the hook input's `cwd` against `*/nixos-[0-9]*`.
  - If network-off breaks nix builds inside the sandbox, set
    `network_access = true`.
  - Either one is a deviation, recorded here.

## Handoff

Steps 1–6 edit five files, which is above the model-split threshold. They go
to the `coder` agent: one agent for the whole task, each later step sent
with `SendMessage`. Opus does steps 7–9 and the review, because the coder
cannot commit or deploy.

## Steps

1. `modules/programs/claude-coder-guard.sh`, lines 2 and 16–17: make the
   messages neutral.
   - Line 2's comment starts "PreToolUse guard for coding agents (#2079,
     #2081)".
   - Line 16 says `BLOCKED by the coder guard (#2079, #2081): $1`.
   - Line 17 says "This session edits files and runs checks only. Hand this
     step back."
   → verify by `bash modules/programs/claude-coder-guard.test.sh`, which
   prints "coder guard: all cases pass".
   Traps: line 1 must stay `# shellcheck shell=bash`, or the pre-push
   shellcheck fails. Do not change any matching logic.

2. `home/development/codex-cli.nix`, `let` block (lines 2–21): add three
   bindings after `codexNixFormat`:
   - `guardCmd = "${config.home.homeDirectory}/.local/bin/codex-coder-guard";`
   - `codexCoderGuard = pkgs.writeShellScript "codex-coder-guard"`. Its
     body is the line `[ "''${CODEX_CODER:-}" = 1 ] || exit 0`, followed by
     the shared guard's text. Get that text with:

     ```nix
     builtins.replaceStrings [ "@jq@" ] [ "${pkgs.jq}/bin/jq" ]
       (builtins.readFile ../../modules/programs/claude-coder-guard.sh)
     ```

     Put a comment above it naming #2081 and saying why it checks
     `CODEX_CODER`: Codex hooks are not profile-scoped.
   - `codexImplement = pkgs.writeShellScriptBin "codex-implement"` with the
     body `CODEX_CODER=1 exec "${bin}/codex" -p implement "$@"`.

   → verify by `just check-syntax`.
   Traps:
   - Inside a Nix `''` string, a shell `${VAR}` must be written `''${VAR}`.
   - The shared guard starts with `# shellcheck shell=bash`. Once it comes
     after the wrapper's first line, that line is a harmless comment.
   - Do not copy the guard's logic into this file; read the shared file.

3. `home/development/codex-cli.nix`, the attribute set after `in`: install
   the new pieces.
   - Add `codexImplement` to `home.packages` (line 47).
   - Add `home.file.".local/bin/codex-coder-guard".source = codexCoderGuard;`
     next to the `codex-nix-format` line (line 56).
   - Add `home.file.".codex/implement.config.toml".text`, holding the six
     keys listed in the approved decisions, with a one-line TOML comment
     naming #2081.

   → verify by this printing the six keys:

   ```bash
   hm='.#nixosConfigurations.p620.config.home-manager.users.olafkfreund'
   nix eval --raw "$hm.home.file.\".codex/implement.config.toml\".text"
   ```

   Traps: the profile file is read by Codex as TOML. Keep
   `[sandbox_workspace_write]` last, after the top-level keys.

4. `home/development/codex-cli.nix`, `home.activation` (lines 59–86): add
   two entries after `codexNixFormatHook`, in the same shape.
   - **`codexCoderGuardHook`.** Merge `.hooks.PreToolUse += [{ hooks:
     [{ type: "command", command: $cmd, timeout: 10 }] }]` into
     `~/.codex/hooks.json`, unless an entry with that command already
     exists. Pass `$cmd` as `--arg cmd "${guardCmd}"`. Leave out `matcher`,
     so it runs for every tool; the guard exits 0 when there is no
     `tool_input.command`. Use the same temp file, `cmp` and `install`
     dance as `codexNixFormatHook`.
   - **`codexReviewModel`.** If `$HOME/.codex/config.toml` exists and
     `grep -q '^review_model'` finds nothing, write
     `review_model = "gpt-6-astra"` followed by the old contents to a temp
     file, then `$DRY_RUN_CMD install -m 0600` it back.

   → verify by `just check-syntax`.
   Traps:
   - Never `exit` in an activation entry, because they are concatenated
     into one script (see the comment at line 58).
   - Keep `config.toml` at mode 0600: it sits next to `auth.json`.
   - Every write goes through `$DRY_RUN_CMD`.

5. `home/development/agent-rules/codex-standards.md`, at the end (after
   line 28): append `## Model by stage`, with at most 10 lines.
   - Intent, spec, plan and revision decisions: `gpt-6-astra`
     (`/model gpt-6-astra`).
   - Implementation of an approved `plan/`: start `codex-implement`
     (Sol, write access, guarded). Do not commit; report changed files and
     plan deviations.
   - `/review` runs on Astra. Luna is only for narrow, read-only lookups.
   - At every gate's "stop for review", name the model and command for the
     next stage.

   → verify by `just check-syntax`, then build
   `home.file.".codex/AGENTS.md".source` for p620 (same `nix build` form as
   step 3). `grep -c "Model by stage"` on it prints `1`, and the same on
   the `.gemini/AGENTS.md` build prints `0`.
   Traps:
   - Do not use the word "coder" or the heading "Model split". The assert
     in `agent-rules.nix` fails evaluation on "Model split".
   - Keep lines at or under 120 characters (markdownlint MD013).

6. `AGENTS.md`, lines 47–57 ("Delegating to other models"), and
   `home/development/claude-code-skills/second-opinion/SKILL.md`, lines
   29–32.
   - **AGENTS.md:** replace line 49 with two cases:
     - When another agent calls them, Codex, agy and Ollama draft and
       review, read-only, and never write a commit.
     - A Codex session the user starts with `codex-implement` may write
       code for an approved `plan/` in a task worktree. It does not commit,
       deploy, restart, garbage-collect or reboot, and the guard enforces
       that (#2081).

     Change the "Read-only modes only" bullet to say it applies to
     delegated use. Keep the `HUMANIZE_CODEX_BYPASS_SANDBOX` line and the
     subscription line unchanged.
   - **SKILL.md:** change "both exist and are deliberately unused" to say
     they stay unused for second opinions. Implementing an approved plan is
     `codex-implement`'s job, and not this skill's.

   → verify by `grep -n codex-implement AGENTS.md home/development/claude-code-skills/second-opinion/SKILL.md`
   showing both files, and markdownlint passing on both.
   Traps:
   - Do not start a line with `#<number>`; write "Issue #2081".
   - The pre-push markdownlint lints the whole file, so leave other lines
     alone.

7. Opus: `just check-syntax`, `just test-host p620`, `just test-host razer`,
   and the guard test. Then review the diff with a fresh `model: "opus"`
   agent, given only this plan and `git diff`.
   → verify by all four passing and no blocking review finding.
   Traps: p510 is not built.

8. Opus: commit steps 1–6 on `feat/2081-codex-coder-write-access`, push,
   and open the PR. The PR links all three files and says the coder did
   steps 1–6.
   → verify by CI passing on the PR.
   Traps: write the message with `-F` from a file, because the bus guard
   matches words like "deploy" in command text.

9. Opus, after merge: announce on `#agents`, run `just quick-deploy p620`,
   and ask the user to trust the new hook with `/hooks` in a Codex session.
   Then run the Tests below. razer follows the same way
   (`just deploy-via-p620 razer`) once p620 passes.
   → verify by every item in Tests.
   Traps: check that no `nhs` or `nh os` is running first. The trust step
   is the user's, because Codex asks interactively.

## Tests

- **Build.** `just check-syntax` passes; `just test-host p620` and
  `just test-host razer` build; `bash modules/programs/claude-coder-guard.test.sh`
  prints "all cases pass".
- **Files on p620.**
  - `~/.codex/implement.config.toml` has the six keys.
  - This prints `1`:

    ```bash
    jq '[.hooks.PreToolUse[]?.hooks[]?.command]
        | map(select(endswith("codex-coder-guard"))) | length' ~/.codex/hooks.json
    ```

  - `grep -c '^review_model' ~/.codex/config.toml` prints `1`, and a second
    activation leaves it at `1`.
  - `~/.codex/AGENTS.md` has "Model by stage", and `~/.gemini/AGENTS.md`
    does not.
- **Probe, after trust.** In a throwaway git repo with one commit:
  - `codex-implement exec` is asked to run
    `git commit --allow-empty -m probe`, then `git status`. The commit is
    blocked with the guard's message, `git status` runs, and `git log`
    still shows one commit.
  - Plain `codex exec` with write access, in the same repo, can commit.
    This shows the guard is scoped. It is the only time `codex exec` gets
    write access, and it is in a throwaway repo, not this tree.
- **Model.** The `codex-implement exec` output header names `gpt-6-sol`.

## Rollback

`git revert` the implementation commit and deploy p620 (and razer, if it
was deployed). That removes `codex-implement`, the guard wrapper and the
profile file.

The activation steps only ever add, so after the revert remove two things
by hand on each host:

- the `PreToolUse` entry whose command ends in `codex-coder-guard`, from
  `~/.codex/hooks.json`;
- the `review_model` line in `~/.codex/config.toml`, if you want Codex's
  default back.

The guard's message change in step 1 is reverted with the rest.
