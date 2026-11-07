---
status: approved
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
---

# Plan: Let agy and Codex run needed commands under control

Delegated reviews move into a new `agent-review` wrapper that runs the whole tool in
`bwrap` with an allow-only filesystem. This closes a live hole, where Codex's read-only
sandbox can read SSH keys and API keys. It also lets agy run ordinary commands without
`--dangerously-skip-permissions`.

**Change from the approved spec, needing your approval with this plan.** The spec allowed
reviewers `nix eval` and `nix build`. `modules/nix/nix.nix:29` makes `olafkfreund` a daemon
`trusted-users` member, which Nix's documentation treats as essentially root, and a process
inside `bwrap` connects to the host daemon as that same user. So the daemon socket is hidden
on every host. Tested with it hidden: plain expressions, `nix-instantiate --parse`, `statix`,
`deadnix` and `nixpkgs-fmt` work; `nix build` and flake evaluation do not. When a reviewer
needs a flake evaluated or a build run, Claude runs it and passes the output in. This also
replaces the spec's p510 special case.

Approved decisions:

- Reviewers may run read-only commands, archive tools and Nix evaluation without the
  daemon, as changed above. No network for their commands.
- Reviewers write only to a temporary directory for the run, never the repo.
- Codex gains no capability. It only gains the hiding.
- Secrets are not visible at all, by not being mounted.
- `--dangerously-skip-permissions` stays forbidden for reviews.
- `agy-implement`, `codex-implement` and `handoff` are unchanged.

Work in the worktree `/home/olafkfreund/.config/nixos-2748` on branch
`feat/2748-agent-delegated-permissions`. Never check out a branch in `~/.config/nixos`.

**Owner decision, 2026-11-06:** leave agy out and use Codex only. The gate is not rerun.

**Step 2 review added beyond this plan:** `agent-review` allows only `exec` and `review`, refuses
`-p`/`--profile`, `--enable`, `--disable`, `--oss` and `--sandbox-state*`, and allows `-c` only for
`model`, `model_reasoning_effort` and `review_model`. Callers no longer pass `-c sandbox_mode` or
`-c forced_login_method`, because the wrapper sets them.

**Hardening after the PR review, 2026-11-07:** an Opus attack review and Codex (run through the
wrapper) found bypasses, so `agent-review` now:

- denies by default any option not on its allow-list, which closes attached short forms such as
  `-sdanger-full-access` and `-pimplement`;
- mounts only `~/.codex/auth.json` from `~/.codex`;
- requires the work dir to be under `/tmp`, owned by the user and free of sockets, with no overlap
  with the repo, the git common dir, `~/.codex` or `~/.gemini`;
- requires `-o` to point inside the work dir;
- unsets `GIT_*`, and refuses a repo root or common dir that equals or contains `$HOME`.

The test grew from 54 to 75 checks, by the coder, with mutation checks for each new refusal. Only
the work dir ownership check has no test.

A second Opus review then reproduced a planted `codex`: with an empty or relative PATH entry, a
`codex` file in the reviewed repo ran as the parent, with network and the login. The wrapper now
passes only absolute PATH entries outside the repo and its git common dir into the sandbox. Two
tests cover it (77 checks), and removing either filter fails one of them. `jq` and `gnugrep` left
`runtimeInputs`, unused. Not fixed, as low risk: a process running as the same user could swap the
work dir for a symlink between the checks and the mount. Abstract sockets are left to step 8. The docs now say that Codex can read its
own login, and that command network is blocked by Codex's inner sandbox, not by the wrapper.

**Step 6 as done:** the "Reviewer mode" docs section and the agy-model note are skipped, because
there is no reviewer branch. `agy-standards.md` no longer names a model, since `gemini-3.1-pro-high`
is gone.

**Gate outcome, 2026-11-06 (see #2748).** Step 1 stopped: the Gemini models hit their quota, and
`gpt-oss-120b-medium` only planned. As this plan requires, Codex ships alone. Skip step 4 and every
agy part of steps 2, 5, 6 and 8. For now `agent-review` accepts only `codex`, and agy keeps its 14
commands until the owner decides.

## Steps

1. **agy gate, with no repo edits.** In the scratchpad, write a throwaway script that uses
   the `bwrap` mount list in step 2, including the hidden daemon socket. With it, find the
   least agy state that gives a usable model. Start from a tmpfs `~/.gemini` with
   read-only binds of `antigravity-cli/antigravity-oauth-token` and `config/`, then add a
   **disposable copy** of `antigravity-cli/settings.json` and read-only `cache/`, one at a
   time. Use `--model gemini-3.1-pro-high`, named for reviews in
   `home/development/agent-rules/agy-standards.md`, then `gemini-4-argon-medium`. Do not
   mount `brain`, `conversations`, `history.jsonl` or `knowledge`.

   Then run `agy --mode plan --sandbox --settings '{"permissions":{"allow":["command(*)"]}}'`
   with a prompt that says the commands are approved and not to plan. Use `test -r` only,
   never printing a value. Record each result on #2748:
   - commands actually run
   - a command can reach no network, by each of: TCP to `1.1.1.1:443`, UDP to `1.1.1.1:53`,
     and a DNS lookup. agy itself needs the network, so `bwrap` cannot use `--unshare-net`,
     and this block comes from agy's `--sandbox` alone. The guarantee is what these routes
     show, and is worded that way
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

   - the first argument is not `agy` or `codex`, or the current directory is not a git worktree
   - `<work-dir>` is unsafe. It must be an existing real directory (no symlinks) under `/tmp` or
     `$XDG_RUNTIME_DIR`, compared after `realpath`. It must not contain, or sit inside, the
     worktree, the git common dir, `~/.codex` or `~/.gemini`. Otherwise a later `--bind` would
     turn a protected path writable
   - any argument matches `--dangerously-*`, `--yolo`, `--full-auto`, `--add-dir`, `--settings`,
     `--mode` and `--model` for agy (the wrapper sets these itself), `-*gemini_dir*`,
     `-*gemini-dir*`, `-*config*dir*`, `-*config_override*`, or `--sandbox`/`-s` with anything but
     `read-only`, or a `sandbox_mode=` other than `read-only`
   - `HUMANIZE_CODEX_BYPASS_SANDBOX` is set in its environment
   - for agy: `/etc/antigravity/hooks/coder-guard` is not executable, or `~/.gemini/config/hooks.json`
     does not hold the declared `coder-guard` entry. Use the same check as `agy-implement` in
     `home/development/antigravity-config.nix`. Without the hook, the `command(*)` rule would have
     no guard behind it

   Build `bwrap`, in this order: `--ro-bind` `/nix`, `/etc`, `/usr`, `/bin`, `/lib`, `/lib64`
   `/run/current-system`, `/run/systemd/resolve` and `/run/nscd` where they exist (the last two
   provide DNS, and without them the tool cannot reach its model); `--tmpfs
   /nix/var/nix/daemon-socket` on every host;
   `--dev /dev`, `--proc /proc`, `--tmpfs /tmp`, `--tmpfs /home`; `--unshare-pid`, `--unshare-ipc`,
   `--die-with-parent`; `--ro-bind` the worktree and `git rev-parse --git-common-dir`; `--bind` the
   work dir; `--chdir` the worktree. Then `--clearenv` and exactly these variables: `HOME` set to the
   real home path (the mounts below sit under it), `TMPDIR` set to the work dir, `PATH`, `LANG`,
   `TERM`, `SSL_CERT_FILE`, `NIX_REMOTE='local?read-only=true'`, and
   `NIX_CONFIG='experimental-features = nix-command flakes read-only-local-store'`. Nothing from the
   caller's `NIX_CONFIG` is passed through.

   - **codex:** add `--bind "$HOME/.codex" "$HOME/.codex"`, and run the arguments with
     `-c forced_login_method=chatgpt -c 'mcp_servers={}' -c 'sandbox_mode="read-only"'`. Codex must
     be able to rewrite `auth.json` when its login refreshes, so this bind stays writable for the
     parent process only: its read-only sandbox stops commands writing there, and step 8 proves it.
   - **agy:** add step 1's minimal mounts, `--setenv AGY_CODER 1`, `--setenv AGY_REVIEWER 1`,
     `--setenv AGY_WORKTREE <work-dir>` and `--setenv AGY_GUARD_LOG <work-dir>/guard.log`, and
     run with `--mode plan --sandbox --model <step 1's model> --settings <allow rule>`. After
     it exits, print `guard.log`'s deny lines. If `denied_actions` is non-empty and no deny
     line matches, print that agy's own layer refused a command it did not name. If the response
     shows tools were used but `guard.log` is empty, exit non-zero and say the guard did not fire.
     A reviewer could edit that log, because the hook runs inside the same mounts, so treat it as a
     diagnostic and not as proof. The caller removes the work dir with a `trap`.

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
   - a work dir that is a symlink, outside `/tmp` and `$XDG_RUNTIME_DIR`, equal to or inside the worktree,
     or containing it, refuses
   - for agy, a missing guard or a `hooks.json` without the entry refuses
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
   - blocked for Codex: a command writing to `~/.codex`, and a command doing a DNS lookup
   - hidden: the Nix daemon socket. `nix build` and a flake evaluation both fail
   - working: `tar`, a plain `nix eval --expr`, `nix-instantiate --parse`, `statix`, `git log`, and login
   - forbidden: `git commit`, `git push` and `ssh p510` fail, and show up in the caller's output
   - repeat the review that failed: a prompt needing `tar` on a `.tar.xz` completes with a non-empty
     response and no `denied_actions`
   - a refused command is named, or reported as unnamed
   - local sockets: a command connecting to the abstract sockets `@1PASSWORD_MCP` and
     `@1PASSWORD_SDK_INTERGATIONS` must fail. The wrapper cannot hide abstract sockets, because the
     parent needs the host network, so only Codex's inner sandbox can block them. If a connect
     succeeds, say so in `AGENTS.md` and the second-opinion skill, and open an issue

9. razer: post on the bus, `AGENT_BUS_ANNOUNCED=1 just deploy-via-p620 razer`, and repeat steps 5 and 8's
   checks there. p510 only when you agree.

10. Open two separate issues, and change neither here: `agy-implement` and `codex-implement` may have the
    same exposure, including the daemon socket; and `trusted-users` itself in `modules/nix/nix.nix:29`,
    since any process running as you can reach the daemon. Close #2748 after step 9.

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
