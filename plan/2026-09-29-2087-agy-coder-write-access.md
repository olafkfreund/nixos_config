---
status: approved
issue: 2087
spec: spec/2026-09-29-2087-agy-coder-write-access.md
---

# Plan: Antigravity may write code for approved plans

## Approved decisions

These are copied from the approved spec, so this plan can be implemented
without opening the intent or the spec.

- **Facts probed on `agy` 1.2.12:**
  - hooks load from `~/.gemini/config/hooks.json` only (workspace hooks are
    ignored, #1036) and run with no trust step;
  - the shell tool is `run_command`, with the command at
    `toolCall.args.CommandLine` (there is no `tool_input.command`);
  - `{"decision":"deny","reason":…}` on stdout denies a call cleanly;
  - hooks inherit env vars from `agy`, and run with cwd `~/.gemini/config`;
  - a hook that fails blocks the tool call.
- **The adapter** `modules/programs/agy-guard-adapter.sh` goes at
  `/etc/antigravity/hooks/coder-guard` on every host, from
  `claude-code-managed.nix`. It allows unless `AGY_CODER=1`. It hands
  `CommandLine` to the shared guard as `{"tool_input":{"command":…}}`, and
  turns exit 2 into a deny with the guard's message. The shared guard does
  not change.
- **Registration.** `antigravityCoderGuardHook` in `antigravity-config.nix`
  merges `{"coder-guard":{"PreToolUse":[{"matcher":"*","hooks":[{"type":"command","command":"/etc/antigravity/hooks/coder-guard","timeout":10}]}]}}`
  into `~/.gemini/config/hooks.json` as a real file, add-only, and leaves
  invalid JSON alone. The path is synced by Syncthing, so the command is an
  absolute `/etc` path, never a store path.
- **`agy-implement`** fails closed: it exits 1 unless the guard file is
  executable and `hooks.json` has the `coder-guard` entry. Then it runs
  `AGY_CODER=1 exec agy --mode accept-edits --model gemini-3.8-flash-medium --sandbox "$@"`,
  with the prompt last. `--sandbox` is dropped if the probe shows it stops
  checks from running.
- **Models.** `gemini-3.1-pro-high` for intent, spec, plan, revisions and
  review; `gemini-3.8-flash-medium` implements. agy does not commit.
- **Rules.**
  - `AGENTS.md` gets an `agy-implement` twin of the `codex-implement`
    bullet, and its `accept-edits` ban is scoped to delegated use.
  - `second-opinion` keeps agy in `--mode plan`.
  - A new `agent-rules/agy-standards.md` holds "Model by stage" and goes
    into the `.gemini/AGENTS.md` build only.
- **Prerequisite, approved with the spec.** Run
  `agy plugin disable googlecloudtools.datacloud_telemetry` once on p620
  and razer. Its `{"continue":true}` reply makes every `agy` terminal
  command fail.
- **Hosts.** p620 and razer. p510 only if you ask.

## Handoff

Steps 1–5 edit seven files, which is above the model-split threshold. They go
to the `coder` agent: one agent for the whole task, each later step sent
with `SendMessage`. Opus does steps 6–9, the review and all host actions.

## Steps

1. `modules/programs/agy-guard-adapter.sh` (new) and
   `modules/programs/agy-guard-adapter.test.sh` (new).
   - **Adapter**, a bash script whose first line is
     `# shellcheck shell=bash`, with placeholders `@jq@` and `@guard@`:
     - read stdin into `payload`;
     - if `AGY_CODER` is not `1`, print `{"decision":"allow"}` and exit 0;
     - if the payload has no `toolCall` (check with `@jq@ -e .toolCall`),
       print a deny with the reason "unreadable hook payload" and exit 0.
       This fails closed;
     - read `cmd` from `.toolCall.args.CommandLine // empty`, and if it is
       empty, print allow;
     - otherwise run
       `msg=$(@jq@ -n --arg c "$cmd" '{tool_input:{command:$c}}' | @guard@ 2>&1 >/dev/null)`
       and keep its exit code;
     - on exit code 2, print `@jq@ -n --arg r "$msg" '{decision:"deny",reason:$r}'`,
       and otherwise print allow;
     - always exit 0.
   - **Test**, in the style of `claude-coder-guard.test.sh`:
     - make temporary copies with `@jq@` replaced by `jq`, and `@guard@`
       replaced by a temporary copy of `claude-coder-guard.sh`;
     - feed it payloads of the shape
       `{"toolCall":{"name":"run_command","args":{"CommandLine":…,"Cwd":"/tmp"}},"conversationId":"t"}`;
     - these must give a deny: `git commit -m x`, `sudo reboot`,
       `just quick-deploy p620`, and `not json` as the whole payload;
     - these must give an allow: `git status`, `just check-syntax`, and a
       payload with no `CommandLine`;
     - all of the above with `AGY_CODER=1`, plus `git commit -m x` without
       `AGY_CODER`, which must be allowed;
     - check the decision with `jq -r .decision`, and check that the deny
       reason contains "BLOCKED by the coder guard".

   → verify by `bash modules/programs/agy-guard-adapter.test.sh`, which
   prints "agy guard adapter: all cases pass", and
   `shellcheck -s bash` on both files.
   Traps:
   - Do not touch `claude-coder-guard.sh`.
   - The adapter must print exactly one JSON object on every path. agy
     rejects replies it can't parse, which is the telemetry plugin's bug.

   Deviation: only exit 0 allows; any other guard exit denies, so a crashed
   or missing guard fails closed.

   Deviation (review, #2087): the shared guard only understands shell
   commands, but agy's real tool set is wider than `run_command` (view_file,
   grep_search, replace_file_content, write_to_file, call_mcp_tool,
   send_command_input, subagent/schedule tools, and more). Judging by tool
   name closes that gap: a fixed allow-list of safe read/edit tools
   (view_file, grep_search, list_dir, find_by_name, replace_file_content,
   multi_replace_file_content, write_to_file, ask_question,
   list_permissions) passes without the guard; `run_command` requires
   `.toolCall.args.CommandLine` to actually be a string (`jq -e … | strings`)
   before it reaches the guard, denying a missing, wrong-case or non-string
   `CommandLine`; every other tool name, including agy's own
   `send_command_input` and `call_mcp_tool`, denies outright. Added matching
   test cases to `agy-guard-adapter.test.sh`.

2. `modules/programs/claude-code-managed.nix`: next to `codexGuardScript`
   (line 312), add `agyGuardScript = pkgs.writeShellScript "agy-coder-guard"`,
   built from `builtins.readFile ./agy-guard-adapter.sh` with `@jq@`
   replaced by `${pkgs.jq}/bin/jq` and `@guard@` by `${coderGuardScript}`.
   `coderGuardScript` is already the shared guard with jq filled in.
   Add a two-line comment naming #2087. It should say that agy's payload
   differs, and that the path is absolute because `hooks.json` syncs. Then,
   below the codex `environment.etc` lines (around 980–993), add
   `environment.etc."antigravity/hooks/coder-guard".source = agyGuardScript;`.

   → verify by building
   `.#nixosConfigurations.p620.config.environment.etc."antigravity/hooks/coder-guard".source`
   and piping a `git commit` payload into the result with `AGY_CODER=1`.
   It must print a deny.
   Traps:
   - Use `builtins.replaceStrings` with two-element lists. Do not use a
     Nix `''` string for the adapter body; keep it in the `.sh` file.

3. `home/development/antigravity-config.nix`: in the `let` block (lines
   25–93), add `agyImplement = pkgs.writeShellScriptBin "agy-implement"`.
   - Its body: if `/etc/antigravity/hooks/coder-guard` is not executable,
     or `${pkgs.jq}/bin/jq -e '."coder-guard"' "${geminiDir}/config/hooks.json"`
     fails, print the reason to stderr and exit 1.
   - Otherwise it runs
     `AGY_CODER=1 exec agy --mode accept-edits --model gemini-3.8-flash-medium --sandbox "$@"`.
   - Inside `config = lib.mkIf cfg.enable {`, add
     `home.packages = [ agyImplement ];`.
   - Also add `home.activation.antigravityCoderGuardHook`, in the shape of
     `antigravityMcpSync`:
     - `mkdir -p "${geminiDir}/config"`;
     - if `hooks.json` is missing, write the entry with `$DRY_RUN_CMD`;
     - if it is valid JSON without a `coder-guard` key, `jq` merge the
       entry in;
     - if it already has one, do nothing;
     - if it is invalid JSON, echo a notice and leave it alone.

     Write a real file with `printf > file`, never a symlink.

   → verify by `just check-syntax`, and by running the activation snippet
   twice against a temporary `HOME` holding a copy of a `hooks.json`. That
   must leave exactly one `coder-guard` key, keep the other keys, and leave
   invalid JSON alone.
   Traps:
   - Never `exit` in an activation entry, because entries are concatenated
     into one script.
   - Shell `${…}` inside Nix `''` strings must be written `''${…}`.
   - `-p` must stay last: the wrapper passes `"$@"` after every flag.

   Deviation (review, #2087): two defects found in review, both fixed here
   instead of in a later step since they touch the same file:
   - The registered `hooks.json` `command` is no longer the bare
     `/etc/antigravity/hooks/coder-guard` path. It is a shell gate,
     `/bin/sh -c '[ "${AGY_CODER:-}" = 1 ] || { echo "{\"decision\":\"allow\"}"; exit 0; }; exec /etc/antigravity/hooks/coder-guard'`,
     generated via `pkgs.formats.json` so the escaping is correct. Without
     it, a host whose hooks.json has synced ahead of its own
     `/etc/antigravity/hooks/coder-guard` (p510, or razer in the window
     before `just deploy-via-p620 razer` finishes, since Syncthing carries
     the merged hooks.json first) would deny *every* agy tool call with
     "command not found", not just fail open on a plain (non-`agy-implement`)
     session. The gate now decides allow/exec entirely from `AGY_CODER`
     before ever referencing the `/etc` file. `agy-implement`'s second
     pre-check now matches on
     `."coder-guard".PreToolUse[]?.hooks[]?.command` containing the real
     `/etc` path, not just the presence of the `coder-guard` key, so a stale
     or hand-edited entry with the wrong command still fails closed.
   - The activation script's writes used `$DRY_RUN_CMD printf … > "$hooksfile"`;
     `$DRY_RUN_CMD` becomes `echo` on a dry run, but the `> "$hooksfile"`
     redirection is set up by the shell regardless of which command runs, so
     a dry run still truncated and wrote to `hooks.json`. Fixed by writing to
     a `mktemp` file unconditionally and publishing with
     `$DRY_RUN_CMD mv "$tmp" "$hooksfile"`, the same pattern
     `claude-code-mcp.nix` already uses for its own JSON merge. The existing
     `antigravityMcpSync` activation (untouched by this plan) has the same
     bug; out of scope here.

4. `home/development/agent-rules/agy-standards.md` (new) and
   `home/development/agent-rules.nix` (lines 44–47).
   - Write `# Antigravity global standards`, followed by `## Model by stage`
     in at most 10 lines:
     - intent, spec, plan and revisions use `agy --model gemini-3.1-pro-high`;
     - implementation of an approved `plan/` uses `agy-implement` (Gemini
       3.8 Flash, write access, guarded). Do not commit; report changed
       files and plan deviations;
     - review uses `agy --mode plan --model gemini-3.1-pro-high`;
     - at every gate's "stop for review", name the next stage's model and
       command.
   - In `agent-rules.nix`, pass `(builtins.readFile ./agent-rules/agy-standards.md)`
     as the first item of the `.gemini/AGENTS.md` list, the way
     `codex-standards.md` is passed for Codex.

   → verify by building both AGENTS.md sources for p620 (as in #2081 plan
   step 5). "Model by stage" and `agy-implement` must appear in `.gemini`
   and not in `.codex`, and `grep -c coder` on the `.gemini` build must
   print `0`.
   Traps:
   - Do not use the words "coder" or "Model split". The assert in
     `agent-rules.nix` fails evaluation on "Model split".
   - Keep lines at or under 120 characters.

5. `AGENTS.md` ("Delegating to other models", lines 47–62) and
   `home/development/claude-code-skills/second-opinion/SKILL.md` (lines
   29–33).
   - **AGENTS.md:** after the `codex-implement` bullet, add the twin
     bullet: an agy session the user starts with `agy-implement` may write
     code for an approved `plan/` in a task worktree. It does not commit,
     deploy, restart, garbage-collect or reboot, and the guard enforces
     that (Issue #2087).
   - **AGENTS.md:** add `--dangerously-skip-permissions` to the line that
     bans bypass flags, next to `HUMANIZE_CODEX_BYPASS_SANDBOX`.
   - **SKILL.md:** extend line 33 so that implementing an approved plan is
     `codex-implement`'s or `agy-implement`'s job.

   → verify by `grep -n agy-implement` on both files, and
   `npx --no-install markdownlint-cli2` on both. Then git add everything.
   Traps:
   - Never start a line with `#<number>`; write "Issue #2087".
   - Leave other lines alone.

6. Opus, before any deploy: find out whether `~/.gemini` syncs to p510.
   Read the folder's device list from the Syncthing REST API or
   `config.xml` on p620.
   → verify by recording the answer in the PR. If it does sync, confirm the
   p510 build includes `/etc/antigravity/hooks/coder-guard`.
   `claude-code-managed.nix` is on p510, so this is an eval check, not a
   p510 build.
   Traps: never build or deploy p510 without asking.

7. Opus: run `just check-syntax`, `just test-host p620`,
   `just test-host razer`, both guard tests, and a fresh `model: "opus"`
   review of `git diff` against this plan.
   → verify by all of them passing, with no blocking finding.
   Traps: none.

8. Opus: commit the work and open the PR. The PR records which steps the
   coder did, and the Syncthing answer from step 6.
   → verify by CI passing.
   Traps: write the commit message with `-F` from a file.

9. Opus, after merge: announce on `#agents`. Then, on p620:
   - disable the telemetry plugin
     (`agy plugin disable googlecloudtools.datacloud_telemetry`);
   - run `just quick-deploy p620`;
   - run the Tests.

   Then razer: `just deploy-via-p620 razer`, then disable the plugin over
   ssh.
   → verify by every item in Tests.
   Traps:
   - Check first that no `nhs` or `nh os` is running.
   - The p620 deploy writes `hooks.json`, and Syncthing carries it to razer
     within seconds, before razer has `/etc/antigravity/hooks/coder-guard`.
     Until razer is deployed, every agy call on razer is blocked. So deploy
     razer straight after p620, and tell the user about the gap. It fails
     closed, so nothing unsafe runs.

## Deviation from the second review

`manage_task` came off the allowlist, because its behaviour is unknown and
the adapter fails closed. The hooks.json activation now requires a JSON
object; anything else, such as an array, is left untouched instead of
aborting the whole activation under `set -e`.

## Tests

- **Build.** `just check-syntax` passes; `just test-host p620` and
  `just test-host razer` build; both guard tests pass.
- **Files on p620.**
  - `/etc/antigravity/hooks/coder-guard` is executable;
  - `jq 'has("coder-guard")' ~/.gemini/config/hooks.json` prints `true`;
  - `~/.gemini/AGENTS.md` has "Model by stage".
- **Probe** in a throwaway git repo, prompt last, with the plugin disabled:
  - `agy-implement -p "…"` is asked to run
    `git commit --allow-empty -m probe`, then `git status`. The transcript
    shows "tool call denied by pre-tool hook: BLOCKED by the coder guard"
    for the commit, `git status` runs, and `git log` shows one commit.
  - Plain `agy --mode accept-edits -p "…"` in the same repo shows no guard
    message.
  - The run used `gemini-3.8-flash-medium`, shown in the transcript's
    `modelName`.
  - If `--sandbox` stopped `git status`, drop the flag and record it here.
- **Fail closed.** With the `coder-guard` key temporarily removed from
  `hooks.json`, `agy-implement` exits 1 with its reason. Restore the key
  afterwards.

## Rollback

`git revert` the implementation commit and deploy p620 and razer. That
removes `agy-implement`, `/etc/antigravity/hooks/coder-guard` and the rule
text.

Two things are left to undo by hand:

- **The `coder-guard` key.** Delete it from `~/.gemini/config/hooks.json`,
  on one host is enough because Syncthing carries the change. Do this
  **before** the revert deploy, or the missing `/etc` file blocks every agy
  call.
- **The telemetry plugin.** Re-enable it with `agy plugin enable …` only if
  you want its telemetry back, while it still breaks the CLI.
