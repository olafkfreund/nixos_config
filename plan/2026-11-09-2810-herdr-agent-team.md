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
  - codex    # independent read of each step's diff against this plan
  - agy      # second provider, reads the same diff; output is advice only
---

# Plan: herdr-native mixed agent team

The approved decisions, carried over from the spec. This plan can be followed without opening the intent or
the spec.

- **Members.** Each member is one process, with one role, bound at start, all in sandboxed herdr panes:
  - `review`: Codex, interactive, read-only, lasting for the task;
  - `implement`: Codex, one per plan step;
  - `agy-implement`: only if step 2 finds agy's turn-end hook.

  No Claude teammates, no mesh, no cross-machine.
- **Answers and completion come from the agent process, not the model.**
  - Codex: `notify=["<notify-sink>"]`. Verified on codex-cli 0.167.0 under `-s read-only`, payload
    `{"type":"agent-turn-complete","turn-id","input-messages","last-assistant-message"}`.
  - agy: its turn-end hook.
  - Both are normalized to `/run/herdr-team/turns/<turn-id>.json` = `{turn_id, input, reply, source}`.
- **Paths inside a member:**
  - `/run/herdr-team/req` is read-only;
  - `/run/herdr-team/turns` is writable only by the outer sandbox;
  - `<work>` itself is never bound.

  `/run/herdr-team` is outside `/tmp` and the worktree, so model tool commands cannot write it. Step 2 proves
  this.
- **Only a fixed pointer is typed into a pane:** `Request <gen>-<n>: read /run/herdr-team/req/<n>.md and answer
  it in your reply.` Prompt content travels as a file. A turn matches a request only when its `input` (Codex
  `input-messages[-1]`) equals that pointer exactly.
- **Launcher:** `pane run "exec bash <ctl>/launch || exit"`. The launcher runs in the host PID namespace. It
  writes `claim`, starts the watchdog, runs the wrapper in the foreground, writes `exit`, and then the pane ends.
- **Watchdog:** checks the lead's pid **and start time**, and the role's maximum (8 h `review`, 3 h `implement`).
  It stops the member's **process group** with TERM, then KILL after 5 s.
- **Lead is the hub.** Members have no herdr socket, no skill and no relay. The lead checks every answer against
  the plan before writing the next prompt. There is no `forward`.
- **Outcomes of an `ask`:** `ok`, `empty`, `provider_error`, `interrupted`, `cancelled`, `agent_gone`,
  `refused`, `timeout`, `busy`.
- **Revision fingerprint:** `HEAD`, `git diff HEAD --binary`, and untracked unignored paths with their contents.
  It is taken at send and at reply, and `changed_during_review` is set when the two differ.
- **`finish`:**
  1. take a finish reservation on the worktree;
  2. `down` the implementer and wait until it exits;
  3. run `agent-run`'s checks: exit 0, `HEAD` unchanged, non-empty diff, nothing staged, last outcome `ok`;
  4. print the verdict JSON.
- **The herdr skill** comes from `herdr --skill` of the pinned binary. It goes to `~/.claude/skills/herdr` and
  `~/.agents/skills/herdr`, on p620 and razer only. The stale clone is removed on activation.
- **Order:** the spec puts the probes before any other code. They have to run through the real interactive
  wrappers, so step 1 builds only those wrappers and the sink. Nothing is deployed, and step 2's gate decides
  whether steps 3–7 happen.
- **Fallback:** outside herdr, `herdr-team` exits 2, and the skills keep today's headless paths. agy stays
  headless if step 2 fails for agy.

## Steps

1. **Sandbox wrappers, interactive mode, and the notify sink** (coder).
   - **`home/development/agent-review.sh`:**
     - accept `agent-review codex <work> --tui`, with no further arguments except `-c model=…` and
       `-c model_reasoning_effort=…`;
     - run `codex` with no subcommand, adding `-c approval_policy="never"` and `-c notify=[…sink…]` next to the
       existing `forced_login_method`, `mcp_servers={}` and `sandbox_mode="read-only"` at `:106`;
     - in `--tui` mode, replace the `<work>` bind at `:103` with `--ro-bind <work>/req /run/herdr-team/req` and
       `--bind <work>/turns /run/herdr-team/turns`;
     - keep every refusal at `:11-60`;
     - make sure `<work>/req` and `<work>/turns` exist and are real directories.
   - **`home/development/agent-implement.sh`:**
     - wrapper options before `--`: `agent-implement codex|agy [--work <dir>] [--tui] -- …`. `--work` binds the
       same two `/run/herdr-team` paths. `--tui` allows Codex args `-p implement` without `exec` (`:44-47`) and
       adds the same two `-c` keys;
     - for agy, `--tui` allows the interactive form without `-p` (`:84-87`);
     - neither option reaches the tool's argv;
     - the binds go in both `sandbox_exec_bwrap` (`:142-147`) and the unshare path (`:150-175`).
   - **`home/development/codex-cli.nix:27-37`:** `codex-implement` passes leading `--work <dir>` and `--tui` to
     `agent-implement` before its `--`. The guard preflight is unchanged.
   - **New `home/development/notify-sink.sh`:**
     - check `type == "agent-turn-complete"` and `turn-id` matching `^[0-9a-f-]{36}$`;
     - write `{turn_id, input: input-messages[-1], reply: last-assistant-message, source:"codex"}` to
       `/run/herdr-team/turns/.<id>.tmp`, then `mv` it to `<id>.json`;
     - refuse an existing target or a symlink, and always exit 0.

     Package it in `agent-run.nix` as `herdr-team-sink`, with a `checkPhase`: shellcheck, plus fixture runs for a
     good payload, a bad type, a bad id and a symlink target.
   - **Tests:** `agent-review.test.sh` and `agent-implement.test.sh` get the new shapes accepted, and refusals
     for:
     - extra args, `--add-dir`, other `-c` keys and a caller-set `notify` or `approval_policy`;
     - `--work` with a symlink or non-owned dir;
     - `--work` after `--`.

   → verify by `bash home/development/agent-review.test.sh && bash home/development/agent-implement.test.sh`,
   then `nix build .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.path`.

   Traps:
   - writeShellApplication's bash has no `compgen`, so use `env -0`;
   - pre-push shellcheck runs at warning level on whole files;
   - never set `HUMANIZE_CODEX_BYPASS_SANDBOX`, and never add `--dangerously-skip-permissions` outside
     `agy-implement`'s own path;
   - the sink must never read stdin (Claude's Bash stdin is a socket).

2. **Gate: live probes through the step 1 wrappers** (lead, with no repo edits except recording the results in
   this plan).
   - Use the binaries from the step 1 `home.path` build, not the installed ones.
   - Run in an isolated herdr session: `env -u HERDR_ENV -u HERDR_SOCKET_PATH herdr --session t2810`, started
     under `script`, deleted afterwards.
   - For `review` (`agent-review … --tui`) and `implement` (`codex-implement --work … --tui`), each must pass:
     1. herdr reports kind `codex` on the pane;
     2. a typed pointer produces exactly one turn file per turn, and its `input` is the pointer;
     3. a second turn yields a second file, and context is kept;
     4. Esc mid-turn shows a stable interrupted marker on `pane read --source visible`. Record its exact text;
     5. a model shell command cannot write `/run/herdr-team/turns`, and in `review` it cannot write anywhere;
     6. inside the member, a socat connect to every `~/.config/herdr/**/herdr.sock` fails, and `herdr status`
        fails;
     7. `ls -l /proc/self/fd` shows nothing above 2;
     8. the caller's token-bearing `NIX_CONFIG` is absent;
     9. when the agent exits, the pane ends with no shell prompt;
     10. `implement`: `git add` fails.
   - Record the provider-error screen strings seen during a deliberate failure (`-c model=nonexistent`).
   - **For agy:** find the turn-end event and its payload, using a throwaway `HOME` copy with its own
     `hooks.json`. Never edit the synced `~/.gemini/config/hooks.json` here. Check that `agy --sandbox` blocks
     the same write.
   - **Gate:** if any Codex check fails, stop and report to the owner. If only agy fails, step 4 is skipped and
     agy stays headless.

3. **`herdr-team`** (coder): a new `home/development/herdr-team.sh` and `home/development/herdr-team-test.sh`,
   packaged in `home/development/agent-run.nix` like `herdr-run`, with `checkPhase` running the test.
   - **Subcommands:** `up <task> review|implement|agy-implement [--step k]`, `ask <task> <member> <prompt-file>
     [--resume n] [--timeout s]`, `status <task>`, `down <task> [member]`, and `finish <task>
     implement|agy-implement`.
   - **State:**
     - `flock $XDG_RUNTIME_DIR/herdr-team/lock`, held only while state changes;
     - the state file `$XDG_RUNTIME_DIR/herdr-team/<task>.json`;
     - per member `<work>=/tmp/herdr-team.<gen>.<member>.XXXXXX` (0700) with `req/ turns/ turns/done/ ans/`;
     - per member `<ctl>=$XDG_RUNTIME_DIR/herdr-team/<gen>/<member>/` holding `launch claim status exit`.
   - **Refusals at `up`**, copied from `agent-run.sh:23-38`: `~/.config/nixos`, branch `main`, and not a git
     worktree. For an implementer, also:
     - a dirty tree;
     - another implementer or finish reservation on the same canonical worktree, in any state file;
     - live members under the same task name.

     A member is live only when its pid **and** `/proc/<pid>/stat` start time still match.
   - **Pane handling:**
     - the first member uses the tab's root pane (`tab create --no-focus` → `.result.root_pane`), and later
       members use `pane split --no-focus`;
     - claim retry as in `herdr-run.sh:260-270`;
     - `agent rename` only after herdr reports the expected kind on the recorded terminal;
     - the `same_pane` and process-group stop come from `herdr-run.sh:19-42`;
     - the watchdog is modelled on `herdr-run.sh:165-202`, but in the launcher and in the host namespace.
   - **`ask`:**
     - match the turn file whose `input` equals the pointer exactly, moving every read file to `turns/done/`;
     - poll `pane read --source visible` for the provider-error and interrupted strings recorded in step 2;
     - print the result JSON (`ok`, `outcome`, `n`, `member`, `answer`, `turn_id`, `revision_at_send`,
       `revision_at_reply`, `changed_during_review`);
     - a timed-out request stays pending until `--resume` or `down`.
   - **`finish`:** as in the decisions above.
   - **Test** (fake herdr in the style of `herdr-run-test.sh`, isolated `XDG_RUNTIME_DIR`):
     - every refusal and every outcome;
     - `busy`, with a late answer filed under its own `n`;
     - consumed turn files never match twice;
     - pid reuse with a different start time is never signalled;
     - `down` closes only matching panes;
     - `finish` downs before it checks, and its reservation blocks a second implementer;
     - outside herdr every command exits 2.

   → verify by `bash home/development/herdr-team-test.sh <built herdr-team>` and the `home.path` build.

   Traps:
   - lock handling: never hold the flock while waiting for a turn;
   - jq for all JSON, and never interpolate prompt text into a command line;
   - herdr IDs are opaque, so parse them from JSON responses;
   - `pane run` admission is not execution, which is why the claim retry exists.

4. **agy member** (codex), only if step 2 passed for agy.
   - **`home/development/antigravity-config.nix:146-198`:**
     - `agy-implement` passes leading `--work <dir>` and `--tui` to `agent-implement` as in step 1;
     - one turn-end entry is added to the managed `hooks.json` merge, in the same way as `agentVoiceAgyHook`
       and #2794's `nixi-working`. It runs `sh -c '[ -d /run/herdr-team/turns ] && command -v herdr-team-sink
       >/dev/null && herdr-team-sink --agy; echo "{}"'`, with timeout 5;
   - **`notify-sink.sh`** gains `--agy`, mapping the payload fields recorded in step 2 onto the same output shape.

   → verify by `bash modules/programs/agy-guard-adapter.test.sh`, the sink fixtures, and a re-run of step 2's
   agy probes with the real wrapper.

   Traps:
   - `~/.gemini` syncs to p620, p510 and razer, and a failing hook blocks every agy call, so the entry must
     always print `{}` and exit 0;
   - merge into `hooks.json`, never replace it.

5. **The herdr skill** (codex).
   - **`home/development/herdr.nix`:**
     - `options.programs.herdrSkill.enable`;
     - when on, `herdrSkill = pkgs.runCommand "herdr-skill" { } ''mkdir -p $out; ${pkgs.herdr}/bin/herdr
       --skill > $out/SKILL.md''`;
     - `home.file.".claude/skills/herdr".source` and `".agents/skills/herdr".source` both point at it;
     - an activation entry `entryBefore [ "linkGeneration" ]` removes `~/.agents/skills/herdr` only when it is
       a real directory containing both `.git` and `Cargo.toml`.
   - **`Users/olafkfreund/profile.nix:204`:** set `programs.herdrSkill.enable = true;` next to `pkgs.herdr`.

   → verify that `nix eval` of `home.file` contains `.claude/skills/herdr` for p620 and razer and not for p510
   (`…p510…home.file` has no such key), and that `nix build` of the p620 `home.path` succeeds.

   Traps:
   - `claude-code-skills/default.nix` is imported on p510 too, so do not add the skill there;
   - `home/syncthing-stignore.nix:49-56` already lists `herdr` as host-local;
   - never `exit` in an activation entry, because entries are concatenated.

6. **Skills and docs** (agy).
   - **`home/development/claude-code-skills/second-opinion/SKILL.md`:** a section "Inside herdr: the team tab"
     placed before the Codex blocks. It covers:
     - `herdr-team up <task> review` once, then `ask` per question;
     - reading `answer`, and quoting `outcome` verbatim on failure;
     - `down` at the end;
     - the existing blocks stay as the fallback outside herdr.
   - **`…/handoff/SKILL.md`:** inside herdr, a Codex step (or an agy step if step 4 landed) is `up … --step k`,
     then `ask`, then `finish`. Its verdict replaces `agent-run`'s. Outside herdr, nothing changes.
   - **`AGENTS.md` ("Delegating to other models"):**
     - team members are sandboxed with no herdr access;
     - an answer is an agent-reported turn;
     - the lead checks every answer against the approved plan;
     - an answer never approves, widens scope or authorizes a commit, deploy or step change;
     - only the lead writes prompts.
   - **`docs/applications/herdr.md`:** a "Team tab" section, and the 0.9.0 mention corrected to 0.9.5.
   - **`modules/programs/claude-code-managed-claude.md`:** name `herdr-team` as the route inside herdr.

   → verify by `npx markdownlint-cli2` on every touched `.md`, which lints whole files at a 120-character line
   limit.

   Traps:
   - a line starting with `#<number>` becomes a heading, so do not start a line with an issue reference;
   - a mkdocs nav change must land in both `mkdocs.yml` and `mkdocs-full.yml` (none expected here).

7. **Build, deploy, live check** (lead).
   - `just check-syntax`, `just test-host p620`, `just test-host razer`, and a p510 eval only.
   - Open the PR linking intent, spec and plan, and saying which steps coder, codex and agy did. Run the
     `@codex review` comment, then the Opus review of the diff against this plan.
   - Merge, then announce on the bus: switch p620, then `just deploy-via-p620 razer`.
   - Live check from a Claude pane in the default session:
     - `up review`, two `ask`s that keep context;
     - `up implement --step 1` on a scratch branch worktree, one `ask` that edits one file, then `finish`
       giving `ok: true`;
     - `down`;
     - the skill is present: `ls -l ~/.claude/skills/herdr/SKILL.md`, which must match `herdr --skill`.

## Tests

- After steps 1, 3 and 5: the package `checkPhase`s, the sandbox tests and `herdr-team-test.sh` pass.
- After step 2: every gate check is recorded as pass, with the exact interrupted and provider-error strings.
- Before merge: `just check-syntax`, `just test-host p620` and `just test-host razer` pass, and the p510 eval
  shows no `herdr` skill.
- After deploy: step 7's live check passes on p620. On razer, `herdr-team status x` exits 2 outside herdr and
  the skill is present.

## Rollback

- **Code:** revert the merge commit and redeploy p620 and razer. The headless paths (`herdr-run`, `agent-run`,
  the `second-opinion` blocks) are never removed, so a revert loses only the team tab.
- **Leftover processes:** `herdr-team down <task>` for any live task. The watchdogs end members within about
  35 s of the lead dying anyway.
- **Skill:** reverting removes the Home Manager links. The deleted July clone is not restored; `herdr --skill`
  regenerates it if wanted.
