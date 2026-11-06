---
status: draft
issue: 2748
spec: spec/2026-11-06-2748-agent-delegated-permissions.md
coders:
  2: codex # small but security-critical wrapper logic: argument refusal and mount order
  3: coder # one package entry in an existing pattern
  4: codex # tricky: a new branch in a deny-by-default guard with JSON parsing traps
  5: coder # tests written against the behaviour steps 2 to 4 define
  6: coder # prose edits across four files, needing care more than cleverness
reviewers:
  - codex # independent security read of the wrapper and guard branch
  - agy # second independent read of the same diff
---

# Plan: Let agy and Codex run needed commands under control

Delegated reviews move into a new `agent-review` wrapper that runs the whole tool in
`bwrap` with an allow-only filesystem. This closes a live hole, where Codex's read-only
sandbox can read SSH keys and API keys. It also lets agy run ordinary commands without
`--dangerously-skip-permissions`.

Approved decisions:

- Reviewers may run read-only commands, archive tools, `nix eval` and `nix build`. No
  network for their commands.
- Reviewers write only to a temporary directory for the run, never the repo.
- Codex gains no capability. It only gains the hiding.
- Secrets are not visible at all, by not being mounted.
- `--dangerously-skip-permissions` stays forbidden for reviews.
- `agy-implement`, `codex-implement` and `handoff` are unchanged.

Work in the worktree `/home/olafkfreund/.config/nixos-2748` on branch
`feat/2748-agent-delegated-permissions`. Never check out a branch in `~/.config/nixos`.

## Steps

1. **agy gate, with no repo edits.** In the scratchpad, using the mounts from step 2, find
   the least agy state that gives a usable model. Start from a tmpfs `~/.gemini` with
   read-only binds of `antigravity-cli/antigravity-oauth-token` and `config/`, then add a
   **disposable copy** of `antigravity-cli/settings.json` and read-only `cache/`, one at a
   time. Use `--model gemini-3.1-pro-high`, named for reviews in
   `home/development/agent-rules/agy-standards.md`, then `gemini-4-argon-medium`. Do not
   mount `brain`, `conversations`, `history.jsonl` or `knowledge`.

   Then run `agy --mode plan --sandbox --settings '{"permissions":{"allow":["command(*)"]}}'`
   with a prompt that says the commands are approved and not to plan. Use `test -r` only,
   never printing a value. Record each result on #2748:
   - commands actually run
   - a command can reach no network: `timeout 5 bash -c "echo > /dev/tcp/1.1.1.1/443"`
   - writes to the repo and to any real `~/.gemini` path fail
   - secrets are hidden
   - agy still logs in with its OAuth token read-only. If the token is near expiry, wait
     for it to expire and retest, because a refresh may need to write

   | Result | Action |
   | ------ | ------ |
   | All hold | Continue with agy in the wrapper |
   | Any fails | Skip the agy parts of steps 2 and 4 to 6, ship Codex only, and report to you. agy keeps today's 14 commands until you decide |

   Traps: never pass `--dangerously-skip-permissions`. Never make a real `~/.gemini` path
   writable. Stop after two failed approaches to a single result, and ask.

2. Create `home/development/agent-review.sh`, usage
   `agent-review <agy|codex> <work-dir> -- <tool arguments>`, modelled on
   `home/development/agent-run.sh`.

   Refuse, with a message and exit 2, when:

   - the first argument is not `agy` or `codex`, `<work-dir>` is not an existing directory,
     or the current directory is not a git worktree
   - any argument matches `--dangerously-*`, `--yolo`, `--full-auto`, `--add-dir`,
     `--mode`, `--model` for Codex, `-*gemini_dir*`, `-*gemini-dir*`, `-*config*dir*`,
     `-*config_override*`, or `--sandbox`/`-s` with anything but `read-only`, or a
     `sandbox_mode=` other than `read-only`
   - `HUMANIZE_CODEX_BYPASS_SANDBOX` is set in its environment

   Build `bwrap`, in this order: `--ro-bind` `/nix`, `/etc`, `/usr`, `/bin`, `/lib`, `/lib64`
   and `/run/current-system` where they exist; `--dev /dev`, `--proc /proc`, `--tmpfs /tmp`,
   `--tmpfs /home`; `--unshare-pid`, `--unshare-ipc`, `--die-with-parent`; `--ro-bind` the
   worktree and `git rev-parse --git-common-dir`; `--bind` the work dir; `--chdir` the
   worktree; `--clearenv`, then `--setenv` for `HOME`, `PATH`, `LANG`, `TERM`, `TMPDIR` set to
   the work dir, and `SSL_CERT_FILE`. On a host named `p510`, add `--tmpfs
   /nix/var/nix/daemon-socket`.

   - **codex:** add `--bind "$HOME/.codex" "$HOME/.codex"`, and run the arguments with
     `-c forced_login_method=chatgpt -c 'mcp_servers={}' -c 'sandbox_mode="read-only"'`.
   - **agy:** add step 1's minimal mounts, `--setenv AGY_CODER 1`, `--setenv AGY_REVIEWER 1`,
     `--setenv AGY_WORKTREE <work-dir>` and `--setenv AGY_GUARD_LOG <work-dir>/guard.log`, and
     run with `--mode plan --sandbox --model <step 1's model> --settings <allow rule>`. After
     it exits, print `guard.log`'s deny lines. If `denied_actions` is non-empty and no deny
     line matches, print that agy's own layer refused a command it did not name.

   Exit with the tool's exit code. If `bwrap` cannot start, exit non-zero: never run the tool
   without it.

   → verify with `shellcheck`, and with step 5's test.
   Traps: never read stdin to EOF, because Bash tool stdin is a socket that never closes.
   Codex reads its prompt from stdin, so pass it through untouched. `writeShellApplication`
   uses a minimal bash with no `compgen`. Setting `AGY_CODER=1` is deliberate: the synced
   `hooks.json` entry then needs no change, because changing it would make `agy-implement`
   refuse on hosts not yet deployed.

3. `home/development/agent-run.nix`: add to `home.packages`, in the shape of `agent-run`:

   ```nix
   (pkgs.writeShellApplication {
     name = "agent-review";
     runtimeInputs = with pkgs; [ bubblewrap git jq coreutils gnugrep ];
     text = builtins.readFile ./agent-review.sh;
   })
   ```

   → verify with `git add` of the new files, then `just check-syntax`.
   Traps: flakes ignore untracked files. `bubblewrap` must come from `pkgs`, not the user's
   profile, because the wrapper runs before any mount exists.

4. `modules/programs/agy-guard-adapter.sh`: after the duplicate-key check at line 66 and
   before `case "$name"` at line 68, add a branch for `AGY_REVIEWER=1` that ends in its own
   `allow` or `deny`, so nothing falls through to the coder rules:

   - allow `view_file`, `read_file`, `grep_search`, `list_dir`, `find_by_name`,
     `list_permissions`
   - `run_command`: apply the existing string `CommandLine` and `BypassSandbox` checks, then the
     shared guard, as lines 120 to 139 do. Reuse that code rather than copying it, by moving it
     into a function
   - write tools: allow only under `AGY_WORKTREE`, using the existing path checks at lines 76 to
     116, the same way
   - deny everything else, including MCP tools and `ask_question`, because a headless reviewer
     cannot be answered

   For reviewers, `log_call` also records the flattened command text, so a refusal can be
   named. Add cases to `modules/programs/agy-guard-adapter.test.sh` for each rule, and keep every
   existing case passing.

   → verify with `bash modules/programs/agy-guard-adapter.test.sh`.
   Traps: the adapter is installed at `/etc/antigravity/hooks/coder-guard`, so it needs a system
   deploy, not just Home Manager. An older adapter sees `AGY_CODER=1` and applies coder rules,
   which fail safe. The `.gemini` denial at line 52 stays in force for reviewers.

5. Create `home/development/agent-review.test.sh`, in the style of the other `.test.sh` files and
   needing no login. With a stub tool on `PATH` and a stub `bwrap` for the failure case:
   - each refused argument from step 2 exits 2 and never starts the tool
   - `HUMANIZE_CODEX_BYPASS_SANDBOX` set refuses
   - a `bwrap` that fails means the tool never runs
   - a real `bwrap` run of a small script shows `/run/agenix`, `/mnt`, `/var` and `$HOME/.ssh` absent,
     the worktree not writable, the work dir writable, and the environment cleared

   Wire it into `checkPhase` only if it needs no user namespaces in the Nix sandbox. Otherwise leave
   it run by hand, and say so in its header.

   → verify with `bash home/development/agent-review.test.sh < /dev/null`.

6. Rule text:

   - `AGENTS.md` lines 64 to 70: replace "Read-only modes only" with: delegated reviews run through
     `agent-review`, which allows read-only commands, `nix eval` and `nix build` with no network and
     no secrets mounted. Keep the bans on write modes, `HUMANIZE_CODEX_BYPASS_SANDBOX`,
     `--dangerously-skip-permissions` and API keys.
   - `home/development/claude-code-skills/second-opinion/SKILL.md`: the `herdr-run` blocks at lines 88,
     121, 133 and 164 call `agent-review "$tool" "$work" -- ...` in place of the `env -u` forms, and
     drop flags the wrapper now sets. Update "What this skill will not do" at line 27, keeping the
     rule that nothing here edits the repo, and add that agy's model is pinned by the wrapper.
   - `home/development/agent-rules/agy-standards.md` line 9, and a "Reviewer mode" section in
     `docs/tooling/agy-coder-guard.md`.

   If step 1 stopped agy, only Codex's blocks change, and the text says agy keeps its list.

   → verify with `grep -n 'env -u OPENAI\|env -u GEMINI' home/development/claude-code-skills/second-opinion/SKILL.md`,
   which must print nothing, and `markdownlint` on the changed files.
   Traps: the pre-push markdownlint lints whole files. A line starting with `#` and an issue number
   turns into a heading. No nav change, because no page is added.

7. Commit steps 2 to 6, naming the plan steps. Merge `main` in if it moved. Run `just validate`,
   `just test-host p620` and `just test-host razer`. Push, confirm the remote head matches, open the
   PR linking the intent, spec and plan, and saying which coder did which step. Comment `@codex review`.
   Review with a fresh Opus agent given only this plan path and `git diff`, plus `reviewers:`. Merge
   when clean.
   Traps: `-F` and `--body-file` for all commit and PR text. Codex, once a reviewer, runs through the
   old path until this is deployed.

8. Deploy p620 from `main`: read `#agents:freundcloud.org.uk`, post what and how long, then run
   `AGENT_BUS_ANNOUNCED=1 just p620`. Then run the live probe for each tool through the installed
   `agent-review`, with `test -r` only and never printing a value:
   - hidden: an agenix secret, `~/.ssh/id_ed25519`, `~/.config/gh/hosts.yml`, the other tool's login,
     the session bus, `/mnt`, `/var/lib`, other users' homes, Nix `access-tokens`, and another process's
     `/proc/<pid>/environ`
   - environment: names only, and none holds a credential value
   - listed: readable credential-like files under `/nix`, `/etc` and `/usr`, names only, each explained
   - blocked: writing to the repo and the real `~/.gemini`, also checked after the run, and outbound
     network from a command
   - no MCP server process runs for either tool. If one does, stop and report
   - working: `tar`, `nix eval`, a small `nix build`, `git log`, and login
   - forbidden: `git commit`, `git push` and `ssh p510` fail, and show up in the caller's output
   - repeat the review that failed: a prompt needing `tar` on a `.tar.xz` completes with a non-empty
     response and no `denied_actions`
   - a refused command is named, or reported as unnamed

9. razer: post on the bus, `AGENT_BUS_ANNOUNCED=1 just deploy-via-p620 razer`, and repeat steps 5 and 8's
   checks there. p510 only when you agree: there, confirm a build fails while a review still runs.

10. Open a separate issue for `agy-implement` and `codex-implement`, which may have the same exposure. Do
    not change them here. Close #2748 after step 9.

## Tests

| Check | Expected |
| ----- | -------- |
| `bash modules/programs/agy-guard-adapter.test.sh` | All pass, old and new |
| `bash home/development/agent-review.test.sh < /dev/null` | All pass |
| `shellcheck home/development/agent-review.sh` | Clean |
| `just validate`, `just test-host p620`, `just test-host razer` | Pass |
| Step 8's live probe | Each line as listed |

## Rollback

Revert the merge commit on `main` and deploy. The skill and `AGENTS.md` return to the old commands, and
the old 14-command list was never changed. The wrapper writes nothing lasting: its mounts and `--settings`
exist only for each run. Reverting also reopens the Codex hole, so say so when doing it.
