---
status: draft
issue: 2810
spec: spec/2026-11-09-2810-herdr-agent-team.md
coders:
  1: coder   # the sandbox wrappers: security-critical shell, and Codex should not write its own cage
  3: coder   # herdr-team.sh plus its test: the largest piece, stateful logic
  4: codex   # small and self-contained: agy passthrough and one hook entry, gated on step 2
  5: codex   # small Nix: skill derivation, HM option, activation cleanup
  6: agy     # large mechanical doc edits across five files
reviewers:
  - codex    # independent read of each step's diff against this plan; a fresh session, never the one that coded the step
  - agy      # second provider, reads the same diff; a fresh session; output is advice only
---

# Plan: herdr-native mixed agent team

This plan can be followed without opening the intent or the spec. The decisions below carry the approved spec.
Three of them make the spec's wording more precise; those are marked *(clarifies spec)*, and approving this plan
approves them.

## Decisions

- **Members.** Each member is one process, with one role, bound at start, all in sandboxed herdr panes:
  - `review`: Codex, interactive, read-only, lasting for the task;
  - `implement`: Codex, one per plan step;
  - `agy-implement`: only if step 2 finds agy's turn-end hook and step 4 lands.

  No Claude teammates, no mesh, no cross-machine.
- **Answers and completion come from the agent process, not the model.**
  - Codex: `notify=["<sink>"]`. Verified on codex-cli 0.167.0 under `-s read-only`, payload
    `{"type":"agent-turn-complete","turn-id","input-messages","last-assistant-message"}`.
  - agy: its turn-end hook.
  - The sink validates the raw payload and writes the normalized file `/run/herdr-team/turns/<turn-id>.json`, as
    `{turn_id, input, reply, source}`.
  - `ask` validates the normalized file again: `turn_id` matches `^[0-9a-f-]{36}$`, `source` is `codex` or
    `agy`, and `input` and `reply` are strings. Anything else is ignored and logged to `<ctl>/status`.
- **Paths inside a member:**
  - `/run/herdr-team/req`, bound read-only from `<work>/req`;
  - `/run/herdr-team/turns`, bound writable from `<work>/turns`, written only by the agent's own process;
  - `<work>` itself, never bound.

  `/run/herdr-team` is outside `/tmp` and the worktree, so model tool commands cannot write it. Step 2 proves
  this.
- **Only a fixed pointer is typed into a pane:** `Request <gen>-<n>: read /run/herdr-team/req/<n>.md and answer
  it in your reply.` A turn matches a request only when its `input` equals that pointer exactly. `--resume`
  never types.
- **Launcher.** `up` writes `<ctl>/launch` and sends `pane run "exec bash <ctl>/launch || exit"`, retrying until
  `<ctl>/claim` appears. The launcher, in the host PID namespace:
  1. records its pid, start time and pgid in `<ctl>/claim`;
  2. starts the watchdog;
  3. runs the wrapper in the foreground, through `agent-env`:
     - `agent-env agent-review codex <work> --tui`;
     - `agent-env codex-implement --work <work> --tui`;
     - `agent-env agy-implement --work <work> --tui`;
  4. writes the exit code to `<ctl>/exit` and exits, so the pane ends.
- **Watchdog.** Every 30 s it checks the lead's pid **and start time**, and the role's maximum (8 h `review`,
  3 h `implement`). When either fails, it sends TERM to the member's process group, then KILL after 5 s.
- **A graceful exit decides `finish`** *(clarifies spec)*:
  - `finish` first asks the member to quit with logical keys only, `agent send-keys <name> ctrl+c ctrl+c`, the
    sequence step 2 records. It waits up to 15 s for `<ctl>/exit`.
  - Only the exit code step 2 records for that graceful quit counts as success. `down`'s TERM or KILL is never
    reinterpreted as success.
  - If the member does not exit in time, `finish` downs it and reports `ok: false`, `reason: not_exited`.
- **Task and members** *(clarifies spec)*:
  - A task has one generation at a time. `up` adds members to the task's current generation and its tab.
  - "Live members under the same task name" refuses only a **new generation** while the old one has live
    members, that is, a reused task name.
  - One implementer per canonical worktree, across all tasks. `review → implement → finish → implement` in one
    task is the normal flow.
- **agy routing** *(clarifies spec)*:
  - `herdr-team` refuses `agy-implement` with `refused: agy member not enabled` unless it was built with agy
    support. That is a Nix argument, set to `true` only by step 4.
  - The skills route agy steps through the team only when that is on. Otherwise agy steps stay on `agent-run`,
    as the spec's skills section says.
- **Lead is the hub.** Members have no herdr socket, no skill and no relay. The lead checks every answer against
  the plan before writing the next prompt. There is no `forward`.
- **Revision fingerprint:** `HEAD`, `git diff HEAD --binary`, and untracked unignored paths with their contents.
  It is taken at send and at reply, and `changed_during_review` is set when the two differ.
- **The herdr skill** comes from `herdr --skill` of the pinned binary. It goes to `~/.claude/skills/herdr` and
  `~/.agents/skills/herdr`, on p620 and razer only. The stale clone is removed on activation.
- **Fallback:** outside herdr, `herdr-team` exits 2 and the skills keep today's headless paths.
- **Order:** the spec puts the probes before any other code. They need the real interactive wrappers, so step 1
  builds only the wrappers and the sink, nothing is deployed, and step 2's gate decides steps 3–7.

## Steps

1. **Sandbox wrappers, interactive mode, and the sink** (coder).
   - **`home/development/agent-sandbox.sh`:** the unshare helper binds only same-path dirs (`--rw|--ro DIR`
     at `:117`, moved back at `:242`).
     - Add `--rw-to SRC DST` and `--ro-to SRC DST` to the helper's policy and to `sandbox_exec_unshare`.
     - SRC must be a real directory owned by the caller, with no symlinks, and DST must lie under
       `/run/herdr-team/`.
     - The bwrap path uses `--bind` and `--ro-bind` with distinct DST, under the same validation.
   - **`home/development/agent-review.sh`:**
     - accept `agent-review codex <work> --tui`, with no further arguments except `-c model=…` and
       `-c model_reasoning_effort=…`;
     - run `codex` with no subcommand. The wrapper itself adds `-c approval_policy="never"` and
       `-c notify=[…sink…]` next to `forced_login_method`, `mcp_servers={}` and `sandbox_mode="read-only"`
       (`:106`). A caller-supplied `notify` or `approval_policy` is refused;
     - in `--tui` mode, the `<work>` bind at `:104` becomes `<work>/req` → `/run/herdr-team/req` (read-only) and
       `<work>/turns` → `/run/herdr-team/turns` (writable). Both are created if missing and must be real dirs;
     - every refusal at `:11-60` is kept.
   - **`home/development/agent-implement.sh`:**
     - options before `--`: `agent-implement codex|agy [--work <dir>] [--tui] -- …`. Neither reaches the tool's
       argv;
     - `--work` binds the same two paths, through bwrap (`:142-147`) and unshare (`:150-175`);
     - `--tui` allows Codex `-p implement` without `exec` (`:44-47`) and adds the same two wrapper-set `-c`
       keys;
     - for agy, `--tui` allows the interactive form without `-p` (`:84-87`).
   - **`home/development/codex-cli.nix:27-37` and `home/development/antigravity-config.nix:197`:**
     - `codex-implement` and `agy-implement` pass leading `--work <dir>` and `--tui` to `agent-implement`
       before its `--`;
     - each calls `agent-implement` by **its store path** (a `let` binding to the package), not
       `${config.home.profileDirectory}/bin`, so an undeployed build tests its own chain;
     - the guard preflights are unchanged.
   - **New `home/development/notify-sink.sh`** (`herdr-team-sink`, packaged in `agent-run.nix` with a
     `checkPhase`):
     - read the payload from argv, never stdin;
     - require `type == "agent-turn-complete"` and a `turn-id` that matches `^[0-9a-f-]{36}$`;
     - write `{turn_id, input: input-messages[-1], reply: last-assistant-message, source:"codex"}` to
       `/run/herdr-team/turns/.<id>.tmp`, then `mv -n` it to `<id>.json`;
     - refuse an existing target, a symlink, or a missing `/run/herdr-team/turns`;
     - always exit 0.
   - **Tests:** `agent-review.test.sh` and `agent-implement.test.sh` accept the new shapes, and refuse:
     - extra args, `--add-dir`, other `-c` keys and a caller-set `notify` or `approval_policy`;
     - `--work` with a symlink, a non-owned dir or a DST outside `/run/herdr-team/`;
     - `--work` after `--`.

     The sink's `checkPhase` covers a good payload, a bad `type`, a bad id, a symlink target and an existing
     target.

   → verify by `bash home/development/agent-review.test.sh && bash home/development/agent-implement.test.sh`,
   then `nix build .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.path -o /tmp/hp-2810`,
   then `readlink -f` on its `bin/codex-implement` and the `agent-implement` it calls. Both must be the new
   store paths.

   Traps:
   - writeShellApplication's bash has no `compgen`, so use `env -0`;
   - pre-push shellcheck runs at warning level on whole files;
   - never set `HUMANIZE_CODEX_BYPASS_SANDBOX`, and never add `--dangerously-skip-permissions` outside
     `agy-implement`'s own path;
   - Claude's Bash stdin is a socket, so the sink never reads stdin.

2. **Gate: live probes through the step 1 build** (lead, with no repo edits except recording the results in this
   plan).
   - Put `/tmp/hp-2810/bin` first on `PATH`, and check with `command -v` that every wrapper resolves there.
   - Run in an isolated herdr session: `env -u HERDR_ENV -u HERDR_SOCKET_PATH herdr --session t2810` under
     `script`, deleted afterwards.
   - For `review` and `implement`, each must pass:
     1. herdr reports kind `codex` on the pane;
     2. a typed pointer produces exactly one turn file per turn, and its `input` is the pointer;
     3. a second turn yields a second file, and context is kept;
     4. Esc mid-turn shows a stable interrupted marker on `pane read --source visible`. Record its exact text;
     5. a model shell command cannot write `/run/herdr-team/turns`, and in `review` it cannot write anywhere;
     6. no member process holds a unix socket to herdr. `ss -xp` shows no `herdr.sock` peer for any pid in the
        member's process group. A socat connect to every `~/.config/herdr/**/herdr.sock` and `herdr status`
        both fail from inside;
     7. the caller's token-bearing `NIX_CONFIG` is absent, and the sandbox's own value is exactly
        `experimental-features = nix-command flakes read-only-local-store`;
     8. `ctrl+c ctrl+c` via `agent send-keys` quits the agent. Record the sequence and the exit code in
        `<ctl>/exit`;
     9. the pane then ends, with no shell prompt;
     10. for `implement`, `git add` fails.
   - **Provider errors:**
     - reproduce an auth error by running `review` with a throwaway `HOME` that has no `~/.codex/auth.json`;
     - record its screen string;
     - take the quota, rate-limit and capacity strings from codex-cli 0.167.0's own error text with
       `strings` on the binary, and record them as "taken from the binary, not reproduced".
   - **For agy:** find the turn-end event and its payload, using a throwaway `HOME` copy with its own
     `hooks.json`. Never edit the synced `~/.gemini/config/hooks.json`. Check that `agy --sandbox` blocks the
     same write as check 5.
   - **Gate:** if any Codex check fails, stop and report to the owner. If only agy fails, step 4 is skipped and
     agy support stays off.

3. **`herdr-team`** (coder): a new `home/development/herdr-team.sh` and `home/development/herdr-team-test.sh`,
   packaged in `home/development/agent-run.nix` like `herdr-run`, with `checkPhase` running the test. A Nix
   argument `agyMember ? false` is baked in as a constant.
   - **State file** `$XDG_RUNTIME_DIR/herdr-team/<task>.json`:
     - `gen` (random) and `tab`;
     - `worktree` (canonical), and `lead` (`{pid, start}`);
     - `members.<name>`: `{role, pane, terminal, pid, start, pgid, step, fingerprint, pending, work, ctl}`;
     - `reservation`: the finish reservation, or `null`.

     All state changes run under `flock $XDG_RUNTIME_DIR/herdr-team/lock`, held only while state changes,
     never while waiting.
   - **Dirs:** `<work>=/tmp/herdr-team.<gen>.<member>.XXXXXX` (0700, with `req/ turns/ turns/done/ ans/`) and
     `<ctl>=$XDG_RUNTIME_DIR/herdr-team/<gen>/<member>/` (with `launch claim status exit`).
   - **`up <task> review|implement|agy-implement [--step k]`:**
     - refuses, as in `agent-run.sh:23-38`: `~/.config/nixos`, branch `main`, or not a git worktree;
     - refuses `agy-implement` unless `agyMember`;
     - refuses a new generation when the task's old one has live members;
     - for an implementer, refuses a dirty tree, or another implementer or reservation on the same canonical
       worktree in any state file;
     - creates the tab if the task has none (`tab create --no-focus` → `.result.root_pane`, used by the first
       member), and otherwise runs `pane split --no-focus`;
     - writes the launcher and runs the claim retry as in `herdr-run.sh:260-270`;
     - runs `agent rename <pane> <task>-<member>` after herdr reports the expected kind on the recorded
       terminal, waiting up to 60 s;
     - records the start fingerprint;
     - on **any** failure, downs everything this call started and removes its dirs.

     Stale state files, where no member is live, are reported and removed at the start of every `up`. A member
     is live only when its pid **and** `/proc/<pid>/stat` start time match.
   - **`ask <task> <member> <prompt-file> [--resume n] [--timeout s]`** (default 900 s):
     - refuses `busy` while a request is pending;
     - takes `n`, copies the prompt to `<work>/req/<n>.md`, and takes `revision_at_send`;
     - checks the pane, terminal, kind, pid and start time, giving `agent_gone` on a mismatch;
     - types only the pointer, with `agent prompt` and no `--wait`;
     - then polls every 2 s until the timeout, in this order:
       1. a provider-error string on `pane read --source visible`. That gives `provider_error`, with the
          matching lines saved verbatim to `<work>/ans/<n>.screen`, even when a turn also arrived;
       2. a turn file whose `input` equals the pointer. It is moved to `turns/done/`, the reply is written to
          `<work>/ans/<n>.md`, and the outcome is `ok`, or `empty` for an empty reply;
       3. `<ctl>/exit` exists. That gives `agent_gone` with the exit code, or `refused` with the
          `<ctl>/status` line when the code is 2;
       4. the interrupted marker with no matching turn, giving `interrupted`.
     - Every non-matching turn file read along the way is moved to `turns/done/`.
     - The result is one JSON line: `ok`, `outcome`, `n`, `member`, `answer`, `turn_id`, `revision_at_send`,
       `revision_at_reply`, `changed_during_review`, and `exit` when known. A timeout leaves the request
       pending.
   - **`status <task>`:** prints the state file plus liveness, as JSON.
   - **`down <task> [member]`:**
     - marks any pending request `cancelled`;
     - checks pid and start time, then sends TERM and after 5 s KILL to the pgid;
     - waits until no process in that pgid remains (`pgrep -g`);
     - then closes the pane if its terminal id matches (`same_pane`, `herdr-run.sh:19-24`), and updates the
       state file.
   - **`finish <task> implement|agy-implement`:**
     1. takes the reservation;
     2. runs the graceful quit from the decisions;
     3. then `down`;
     4. then the checks: exit code equals step 2's recorded graceful code, `HEAD` unchanged, non-empty diff
        against the start fingerprint, nothing staged, last outcome `ok`;
     5. prints `{ok, reason, changed, head_moved, exit}`;
     6. releases the reservation.
   - **Tests** (fake herdr in the style of `herdr-run-test.sh`, isolated `XDG_RUNTIME_DIR`, fake pids):
     - every refusal, and every `ask` outcome in its precedence order, including `provider_error` beating a
       completed turn;
     - `--resume` types nothing, and a late answer is filed under its own `n`;
     - consumed or malformed turn files never match;
     - two concurrent `up`s for one worktree, where exactly one wins;
     - failure injection at every `up` stage, where nothing stays behind;
     - a stale state file is removed;
     - the watchdog fires when the lead pid dies, and when its start time changes;
     - pid reuse with a different start time is never signalled;
     - `down` waits for the whole group, and closes only matching panes;
     - the flow `review → implement → finish → implement` in one task;
     - `finish` with no graceful exit gives `not_exited`;
     - `agy-implement` is refused while `agyMember` is false;
     - outside herdr every command exits 2.

   → verify by `bash home/development/herdr-team-test.sh <built herdr-team>` and the `home.path` build.

   Traps:
   - never hold the flock while waiting;
   - use jq for all JSON, and never interpolate prompt text into a command line;
   - herdr IDs are opaque, so parse them from JSON;
   - `pane run` admission is not execution, which is why the claim retry exists.

4. **agy member** (codex), only if step 2 passed for agy.
   - **`home/development/antigravity-config.nix`:** add one turn-end entry to the managed `hooks.json` merge,
     in the same way as `agentVoiceAgyHook` (`modules/programs/agent-voice.nix:133`) and #2794's `nixi-working`
     (`modules/programs/nixi-agent-hooks.nix:57`). It runs `sh -c '[ -d /run/herdr-team/turns ] && command -v
     herdr-team-sink >/dev/null && herdr-team-sink --agy "<payload>"; echo "{}"'`, with timeout 5.
   - **`notify-sink.sh`:** add `--agy`, mapping the payload fields recorded in step 2 onto the same output
     shape.
   - **`agent-run.nix`:** build `herdr-team` with `agyMember = true`.

   → verify by `bash modules/programs/agy-guard-adapter.test.sh`, the sink fixtures, and a re-run of step 2's
   agy probes through the real wrapper.

   Traps:
   - `~/.gemini` syncs to p620, p510 and razer, and a failing hook blocks every agy call, so the entry always
     prints `{}` and exits 0;
   - merge into `hooks.json`, never replace it;
   - review this step for guard preservation and argument parsing specifically.

5. **The herdr skill** (codex).
   - **`home/development/herdr.nix`:**
     - `options.programs.herdrSkill.enable`;
     - when on, `herdrSkill = pkgs.runCommand "herdr-skill" { } ''mkdir -p $out; ${pkgs.herdr}/bin/herdr
       --skill > $out/SKILL.md''`;
     - `home.file.".claude/skills/herdr".source` and `".agents/skills/herdr".source` both point at it;
     - an activation entry `entryBefore [ "linkGeneration" ]` removes `~/.agents/skills/herdr` only when it is
       a real directory containing both `.git` and `Cargo.toml`.
   - **`Users/olafkfreund/profile.nix:204`:** set `programs.herdrSkill.enable = true;` next to `pkgs.herdr`.

   → verify that `home.file` has both keys for p620 and razer and neither for p510 (`nix eval … --apply
   'f: builtins.hasAttr ".claude/skills/herdr" f'`), and that the p620 `home.path` builds.

   Traps:
   - `claude-code-skills/default.nix` is imported on p510 too, so do not add the skill there;
   - `home/syncthing-stignore.nix:49-56` already lists `herdr` as host-local;
   - never `exit` in an activation entry.

6. **Skills and docs** (agy).
   - **`home/development/claude-code-skills/second-opinion/SKILL.md`:** a section "Inside herdr: the team tab",
     placed before the Codex blocks:
     - `herdr-team up <task> review` once, then `ask` per question;
     - read `answer`, and quote `outcome` and the `.screen` file verbatim on failure;
     - `down` at the end;
     - the existing blocks stay as the fallback outside herdr.
   - **`…/handoff/SKILL.md`:** inside herdr, a Codex step is `up … implement --step k`, then `ask`, then
     `finish`, and the verdict replaces `agent-run`'s. An agy step goes through the team only if step 4
     landed. Outside herdr, nothing changes.
   - **`AGENTS.md` ("Delegating to other models"):**
     - members are sandboxed with no herdr access;
     - an answer is an agent-reported turn;
     - the lead checks every answer against the approved plan;
     - an answer never approves, widens scope or authorizes a commit, deploy or step change;
     - only the lead writes prompts.
   - **`docs/applications/herdr.md`:** a "Team tab" section, and the 0.9.0 mention corrected to 0.9.5.
   - **`modules/programs/claude-code-managed-claude.md`:** name `herdr-team` as the route inside herdr.

   → verify by `npx markdownlint-cli2` on every touched `.md`, which lints whole files at a 120-character line
   limit.

   Traps:
   - a line starting with `#<number>` becomes a heading;
   - a mkdocs nav change must land in both `mkdocs.yml` and `mkdocs-full.yml` (none expected).

7. **Build, deploy, live check** (lead).
   - `just check-syntax`, `just validate`, `just test-host p620`, `just test-host razer`, and a p510 eval only.
   - Open the PR linking intent, spec and plan, and saying which steps coder, codex and agy did. Run the
     `@codex review` comment, a fresh Opus review of the diff against this plan, and fresh Codex and agy
     sessions as reviewers.
   - Merge. Then follow the bus procedure: `read_new("#agents:freundcloud.org.uk")` for in-flight work, post
     the hosts and roughly 15 minutes, and run with `AGENT_BUS_ANNOUNCED=1`. Switch p620, then
     `just deploy-via-p620 razer`.
   - Live check from a Claude pane in the default session on p620:
     - `up review` with two `ask`s that keep context;
     - `up implement --step 1` in a scratch worktree, one `ask` that edits one file, then `finish` giving
       `ok: true`;
     - `down`.
   - Skill check on both hosts: `cmp <(herdr --skill)` against both `~/.claude/skills/herdr/SKILL.md` and
     `~/.agents/skills/herdr/SKILL.md`.

## Tests

- After step 1: the sandbox tests and the sink `checkPhase` pass, and the `readlink` chain shows the new store
  paths.
- After step 2: every gate check is recorded as pass, with the exact interrupted, graceful-quit and
  provider-error strings.
- After step 3: `herdr-team-test.sh` passes in `checkPhase`.
- Before merge: `just check-syntax`, `just validate`, `just test-host p620` and `just test-host razer` pass, and
  the p510 eval shows no `herdr` skill.
- After deploy: step 7's live check passes on p620. On razer, `herdr-team status x` exits 2 outside herdr and
  the skill matches `herdr --skill`.

## Rollback

- **Code:** revert the merge commit and redeploy p620 and razer. The headless paths (`herdr-run`, `agent-run`,
  the `second-opinion` blocks) are never removed, so a revert loses only the team tab.
- **Leftover processes:** `herdr-team down <task>` for any live task. The watchdogs end members within about
  35 s of the lead dying anyway.
- **Skill:** reverting removes the Home Manager links. The deleted July clone is not restored; `herdr --skill`
  regenerates it if wanted.
