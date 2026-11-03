---
status: approved
issue: 2650
spec: spec/2026-11-03-2650-agent-team-default.md
coders:
  1: coder   # Nix option + hook wiring in a 1000-line module: needs the repo's patterns, Sonnet knows them
  2: codex   # small, tricky shell (JSON verdict, exit codes, git state): Codex's strength, and dogfoods the handoff
  3: coder   # two-file Nix glue, depends on step 2's script name
  4: coder   # policy text pasted verbatim from this plan
  5: coder   # skill text edits pasted verbatim from this plan
  6: agy     # large prose rewrite of the /team command body: mechanical, frees the coder
reviewers:
  - codex   # `codex review --base origin/main` on the final diff: second view on the guard-adjacent shell
  - agy     # `--agent nix-check --mode plan` on the final diff: Nix lint view from a second provider
---

# Plan: Codex and agy as permanent team members, with Claude as manager

Worktree: `~/.config/nixos-2650`, branch `feat/2650-agent-team-default`.
Never edit `~/.config/nixos` (it is `/etc/nixos`).

## Approved decisions (from the spec)

- **Switch**: `agent-team on|off|status`, per user and host, persistent.
  State in `${XDG_STATE_HOME:-$HOME/.local/state}/agent-team/mode`; no file
  means **on**. Never under `~/.claude` (syncthing-synced across hosts).
  Also a `/agent-team` slash command.
- **Mode signal**: a `UserPromptSubmit` hook prints
  `<system-reminder>agent-team: on</system-reminder>` (or `off`) each prompt,
  so a flip works on the next prompt with no restart.
- **"On" rule** lives once, in the Model split section of the managed
  CLAUDE.md. Skills and `AGENTS.md` only point to it.
- **On** = for artifact-workflow tasks (not exempt ones): Codex + agy review
  every intent/spec/plan draft read-only before Claude stops; every draft
  plan fills `coders:` (per editing step) and `reviewers: [codex, agy]` with
  reasons; the fresh Opus review always runs too. Routing default: large
  mechanical → agy, small tricky logic → codex, rest → coder, builds /
  reviews / deploys / commits → Claude.
- **Opt-out**: the user deletes entries from the draft plan before approval.
- **Failure**: report verbatim, carry on; the switch is never auto-flipped.
- **`agent-run <agy|codex> <prompt-file>`** runs one handoff, applies the six
  checks, prints one JSON verdict, logs full output to a file.
- **Parallel reviews**: Codex and agy run concurrently in `second-opinion`.
- **`/team`** requires an approved plan path and dispatches per `coders:`;
  parallel only for steps the plan marks independent with disjoint files,
  each in its own worktree; no Opus teammates.
- Out of scope: guards and write access (#2081/#2087/#2296), Ollama, a docs
  page.
- Agy/Codex output is advice; nothing they say approves a gate.

## Steps

1. **`modules/programs/claude-code-managed.nix`** — switch and hook.
   - In the `let` block, after `parrHooks` (~line 41), add:

     ```nix
     agentTeamScript = pkgs.writeShellScriptBin "agent-team" ''
       f="''${XDG_STATE_HOME:-$HOME/.local/state}/agent-team/mode"
       mode=$(cat "$f" 2>/dev/null || echo on)
       case "''${1:-status}" in
         on|off) mkdir -p "''${f%/*}" && echo "$1" > "$f" && echo "agent-team: $1" ;;
         status) echo "agent-team: $mode" ;;
         hook)   printf '<system-reminder>agent-team: %s</system-reminder>\n' "$mode" ;;
         *) echo "usage: agent-team on|off|status" >&2; exit 2 ;;
       esac
     '';
     agentTeamHooks = lib.optionalAttrs cfg.agentTeam.enable {
       UserPromptSubmit = [{
         hooks = [{ type = "command"; command = "${agentTeamScript}/bin/agent-team hook"; timeout = 5; }];
       }];
     };
     ```

   - Add `agentTeamHooks` to the `hooks = lib.zipAttrsWith …` list
     (~line 715), right after `parrHooks`.
   - Add the option after `parrProtocol.enable` (~line 760):
     `agentTeam.enable`: `lib.mkOption`, `types.bool`, `default = true`,
     description "Codex/agy agent-team switch and its per-prompt mode hook
     (issue 2650)."
   - In `config` (~line 989), add
     `environment.systemPackages = lib.optional cfg.agentTeam.enable agentTeamScript;`
     (check first that `config` sets no `environment.systemPackages` already;
     if it does, append to that list instead).

   → verify: `just check-syntax` and

   ```bash
   # the module sets .source, not .text (deviation found in step 1)
   grep -o 'agent-team hook' "$(nix build --no-link --print-out-paths \
     '.#nixosConfigurations.p620.config.environment.etc."claude-code/managed-settings.json".source')"
   ```

   Traps: comment only the why, one line (memory: minimal comments). The
   module is a NixOS module; `cfg` is `config.modules.programs.claude-code-managed`.

2. **`home/development/agent-run.sh`** (new) and
   **`home/development/agent-run.test.sh`** (new) — *independent of steps 1, 4, 5, 6.*
   - `agent-run.sh <agy|codex> <prompt-file>`, bash, `set -euo pipefail`:
     - refuse (exit 2, JSON `ok:false`) when `git rev-parse --show-toplevel`
       is `$HOME/.config/nixos`, or the branch is `main`;
     - `head=$(git rev-parse HEAD)`; `log=$(mktemp -t agent-run.XXXXXX.log)`;
     - agy: `agy-implement --output-format json --print-timeout 20m -p "$(cat "$prompt")" > "$log.json" 2>> "$log"`;
       codex: `codex-implement exec -o "$log.msg" - < "$prompt" >> "$log" 2>&1`;
     - one retry when the log contains `connecting to sandbox server`;
     - fail with a `reason` on the first hit of: non-zero exit;
       agy `.status != "SUCCESS"`; agy `.denied_actions | length > 0`;
       empty or whitespace response (agy `.response`, codex `$log.msg`);
       empty `git status --porcelain`; `git rev-parse HEAD != $head`;
     - print exactly one JSON line via `jq -cn`:
       `{ok, tool, reason, changed: [files from git status --porcelain], head_moved, log}`;
       exit 0 if ok, else 1.
   - `agent-run.test.sh`: assert-based; makes a temp git repo on a branch
     `t`, puts stub `agy-implement` / `codex-implement` first on `PATH`
     (env vars pick the stub's behaviour), and checks each case: success
     (edits a file), non-zero exit, agy status FAILED, denied_actions,
     empty response, empty diff, HEAD moved (stub commits), refusal on
     `main`, sandbox-retry succeeds second time. Prints `ok N/N`.
   → verify: `bash home/development/agent-run.test.sh` → all pass;
   `shellcheck home/development/agent-run.sh home/development/agent-run.test.sh` clean.
   Traps: Codex runs with no network and must not commit; tools needed at
   runtime are `git jq coreutils gnugrep` (step 3 supplies them).

3. **`home/development/agent-run.nix`** (new) and
   **`home/development/default.nix:16`** — package and import.
   - `agent-run.nix`:

     ```nix
     { pkgs, ... }: {
       home.packages = [
         (pkgs.writeShellApplication {
           name = "agent-run";
           runtimeInputs = with pkgs; [ git jq coreutils gnugrep ];
           text = builtins.readFile ./agent-run.sh;
         })
       ];
     }
     ```

     (`agy-implement` / `codex-implement` come from the user's PATH; do not
     add them as runtimeInputs).
   - Import `./agent-run.nix` on the line after `./codex-cli.nix`.
   → verify: `just test-host p620` builds; `writeShellApplication`'s
   shellcheck passes.
   Traps: explicit imports only; the script's shebang/`set` lines are
   supplied by `writeShellApplication`, so strip them from the read text
   if shellcheck complains (or keep the file free of them and have the test
   run it with `bash`).

4. **Policy text** — three files, text verbatim.
   - `modules/programs/claude-code-managed-claude.md`, Model split section,
     new bullet after the `coders:`/`reviewers:` bullet. Keep the heading
     `## Model split (Claude Code only)` byte-identical:

     ```markdown
     - When the prompt hook says `agent-team: on`, Codex and agy are on the
       team for every task under the artifact workflow (not exempt ones):
       - Before stopping on an intent, spec or plan draft, review it with
         both through `second-opinion`, in parallel and read-only, and show
         their findings (confirmed, refuted, unverified) with the draft.
       - Every draft plan fills `coders:` for each step that edits files and
         `reviewers: [codex, agy]`, one reason per entry. Default routing:
         large mechanical edits → agy; small tricky logic → codex; the rest
         → coder; builds, reviews, deploys and commits stay yours.
       - The user opts out by deleting entries before approving the plan.
       - A provider that fails or is out of quota is reported verbatim; carry
         on without it. Their output never approves anything.
       `agent-team: off` means this bullet does not apply.
     ```

   - `AGENTS.md:242-244`: replace with
     "Consult other models (Codex, Antigravity) only when the user asks, an
     approved `plan/` names them in `reviewers:`, or Claude Code's
     agent-team mode is on (managed CLAUDE.md, Model split), through the
     `second-opinion` skill. Never otherwise."
   - `home/development/claude-code-skills/artifact-workflow/SKILL.md`, Rules
     list after the `coders:` rule (~line 46): add
     "- When agent-team mode is on (managed CLAUDE.md), every draft plan
       fills `coders:` and `reviewers:`; the user opts out by deleting
       entries before approval."
   → verify: `nix eval` of `home/development/agent-rules.nix`'s output still
   excludes the Model split section:
   `just test-host p620` (agent-rules asserts `!hasInfix "Model split"`);
   `markdownlint` passes on all three (pre-commit lints whole files).
   Traps: a line starting with `#2650` becomes an H1 (memory); markdownlint
   lints the whole file.

5. **Skills** — text edits.
   - `second-opinion/SKILL.md`:
     - description (lines 3-9): after "lists the provider in reviewers" add
       ", or when Claude Code's agent-team mode is on (managed CLAUDE.md)".
     - "When to use" (lines 17-23): first bullet gains the same clause.
     - line 147: replace with "Run the Codex and agy calls **in parallel**:
       two background Bash commands, each with its own output file and
       `timeout`, then wait for both. (Was sequential with no recorded
       reason; if parallel runs fail where sequential ones did not, put the
       rule back and write the reason here, #2650.)"
     - line 182: "one at a time" → "in parallel".
   - `handoff/SKILL.md`: replace sections "Commands" (line 23) and
     "A handoff failed when" (line 44) with one "Run it" section:

     ````markdown
     ## Run it

     Write the prompt (template below) to a file in the scratchpad, then, in
     the task worktree, with the Bash tool's `run_in_background`:

     ```bash
     agent-run agy "$prompt_file"     # or: agent-run codex "$prompt_file"
     ```

     It refuses `~/.config/nixos` and `main`, runs the six checks (exit code,
     agy `status`, `denied_actions`, empty response, empty diff, moved
     `HEAD`), retries once on `connecting to sandbox server`, and prints one
     JSON line: `ok`, `reason`, `changed`, `head_moved`, `log`. `ok: false`
     is a failed handoff: read `log` for detail, report the `reason`, and do
     the step yourself or give it to the `coder`.

     ````

     Keep "Prompt template", "After", "After an agy update" and "Never".
     The `--model` note moves under "Run it" as: `agent-run` uses agy's
     default model; for another one, run `agy-implement --model <name>`
     directly and do the six checks by hand.

   → verify: `markdownlint` passes; `just test-host p620` builds (skills are
   HM files).
   Traps: nested code fences in the handoff edit — use a 4-backtick outer
   fence when writing it if needed; all fenced blocks need a language tag
   (MD040).

6. **`home/development/claude-code-commands/default.nix`** — `/team` and
   `/agent-team`. *Independent of steps 2-5.*
   - Replace the `teamCommand` body (line 17 to its closing `'';`) and the
     comment above it with a manager command:
     - frontmatter: `description: Run an approved plan/ as manager — dispatch each step to coder, agy or codex per coders:`,
       `argument-hint: <path to approved plan/>`;
     - body, in order: refuse unless `$ARGUMENTS` is a `plan/` file with
       `status: approved`; read `coders:`; per step in plan order —
       `coder` → one Sonnet `coder` agent per task, later steps via
       `SendMessage`; `agy`/`codex` → `handoff` skill (`agent-run`) in the
       background; unlisted → the model-split default; after each step run
       its check, commit, note the worker; parallel only for steps the plan
       marks independent whose files are disjoint, each agy/codex step in
       `git worktree add ../<repo>-<issue>-s<n> HEAD`, diff applied back with
       `git -C <wt> add -A && git -C <wt> diff --cached --binary | git apply`
       (deviation: plain `git diff` drops new files), worktree removed; on a
       failed apply,
       rerun that step sequentially; at the end, fresh Opus review plus the
       plan's `reviewers:`; report which worker did each step. State: no
       Opus teammates; Claude never approves the plan.
   - Add `agentTeamCommand`:

     ```text
     ---
     description: Turn the Codex/agy agent team on or off for this host (#2650)
     argument-hint: on | off | status
     allowed-tools: Bash(agent-team:*)
     ---
     !agent-team $ARGUMENTS
     ```

     and `home.file.".claude/commands/agent-team.md".text = agentTeamCommand;`
     next to line 212.
   → verify: `just test-host p620` builds;
   `grep -c 'approved' result-hm/.claude/commands/team.md` style check via
   `nix eval` of the HM file text, or read the built file after step 7's build.
   Traps: inside the Nix `''` string, `${` must be written `''${`; `$ARGUMENTS`
   is fine as is.

7. **Mine: build, review, deploy.**
   - `just check-syntax`, `just validate`, `bash home/development/agent-run.test.sh`.
   - `just test-host p620`, `just test-host razer`; p510 eval only:
     `nix eval .#nixosConfigurations.p510.config.system.build.toplevel.drvPath`.
   - Reviews: fresh Opus agent with this plan path + `git diff origin/main`;
     `codex review --base origin/main` (read-only); agy
     `--agent nix-check --mode plan` on the diff. Codex and agy in parallel.
   - Open the PR linking intent, spec, plan; say which steps each worker did.
   - After merge: bus announce, `just quick-deploy p620`; razer via
     `just deploy-via-p620 razer`. p510: ask first.
   - Runtime: see Tests.

## Tests

- `bash home/development/agent-run.test.sh` → every case passes.
- `just validate` → clean; p620 and razer build; p510 evaluates.
- On p620 after deploy:
  - `agent-team status` → `agent-team: on` (no state file yet).
  - `agent-team off`, then send any prompt in a running Claude session →
    the hook line reads `agent-team: off`. `agent-team on` → `on`.
  - `/agent-team status` in a session prints the mode.
  - razer's `agent-team status` is independent of p620's.
- Dry run: a throwaway draft plan from Claude carries `coders:` and
  `reviewers:`, and both reviews come back from one parallel run.
- `/team` with no argument refuses; with this plan path it lists the
  dispatch per step.

## Rollback

- Instant, no rebuild: `agent-team off` restores today's opt-in behaviour.
- Full: `git revert` the merge commit and redeploy p620 / razer. The state
  file is harmless when nothing reads it; delete
  `~/.local/state/agent-team` if wanted.

## Deviations during implementation

Recorded per the managed policy; each landed with its code.

- Step 1: the check builds `managed-settings.json`'s `.source`; `.text` is null.
- Step 2 (review fixes from Codex, agy and Opus): `agent-run` refuses a
  dirty worktree (exit 2) so pre-existing edits can't pass as the worker's;
  the HEAD-moved check runs before empty-diff; the returned `log` holds the
  tool's own output too (`$log.json` / `$log.msg` appended); the
  shared-checkout test compares `realpath`s; `changed` uses
  `git status --porcelain -uall`. Tests: 16 cases.
- Step 5: `handoff` keeps two caveats from the old failure list (fallback
  noted in the PR; a guard block shows only in the response).
- Step 6: `/team`'s merge-back stages new files (`add -A` +
  `diff --cached --binary`), commits each applied diff before the next,
  and removes worktrees with `--force`; its YAML description is quoted;
  unlisted steps follow the model-split default only, never agy or Codex
  (agy's draft had routed them by complexity, which defeated the opt-out).
- Step 4: the "`agent-team: off`" line is a sub-bullet so it renders.
