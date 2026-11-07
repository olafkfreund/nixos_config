---
status: draft
issue: 2757
spec: spec/2026-11-07-2757-implementer-sandbox.md
coders:
  2: coder # extract the policy from agent-review.sh; codex-implement is not sandboxed until this ships
  3: coder # small edit to agent-review.sh and its test; agy-implement still reads secrets today
  4: coder # the new launcher; until it ships, neither codex-implement nor agy-implement may run
  5: coder # one guard check in codex-cli.nix; same reason as step 4
  6: coder # one line in antigravity-config.nix; same reason as step 4
  7: coder # the new test, written against steps 2 to 6
  8: coder # prose in the handoff skill, AGENTS.md and the agy guard doc
reviewers:
  - codex # independent security read of the mount order, the path checks and the argument allow-lists
  - agy # second read from a different model, in --mode plan with a cleared environment
---

# Plan: Sandbox codex-implement and agy-implement

`codex-implement` and `agy-implement` can read the secrets that #2748 hid from reviewers. This plan
runs both inside a new `agent-implement` wrapper. It shares its policy with `agent-review` through
a new library, `home/development/agent-sandbox.sh`. Codex runs in `bwrap`. agy runs in two nested
user namespaces built with `unshare` and `mount`, because `bwrap` forces `nosuid` and that breaks
agy's own `--sandbox` (#2298).

Work in the worktree `/home/olafkfreund/.config/nixos-2757` on branch
`security/2757-implementer-sandbox`. Never check out a branch in `~/.config/nixos`.

**Why every step goes to `coder`.** Until this issue ships, `codex-implement` and `agy-implement`
are the very thing that can read secrets, so neither may write code for it. Steps 1 and 9 to 11
are Claude's: the gate, builds, the deploy and the live probes.

## Approved decisions (from the spec and the owner, 2026-11-07)

- One library, two launchers, two backends. `agent-sandbox.sh` holds the `GIT_*` unset, the
  worktree and home checks, the read-only host paths, the hidden daemon socket, the safe `PATH`
  filter, the environment allow-list, and two exec functions, `sandbox_exec_bwrap` and
  `sandbox_exec_unshare`. It has no `exec` of its own.
- Sharing is by concatenation in Nix: `text = builtins.readFile ./agent-sandbox.sh +
  builtins.readFile ./agent-review.sh;`. Nothing is sourced at run time.
- `agent-review` keeps its argument allow-list and its behaviour. Only its test changes, to
  assemble the two files into a temporary script.
- `agent-implement <codex|agy> -- <tool arguments>` is a new package next to `agent-review`.
  `codex-implement` and `agy-implement` end in `exec agent-implement …`.
- `agent-run` judges the result from outside, as now.
- Visible and writable, for both tools unless noted:

  | Path | Inside |
  | ---- | ------ |
  | `/nix /etc /usr /lib /lib64 /run/current-system /run/systemd/resolve /run/nscd` | read-only |
  | `/bin` | read-only. bwrap binds it; unshare leaves the host mount, already `ro`, untouched |
  | `/nix/var/nix/daemon-socket` | empty tmpfs, `NIX_REMOTE=local?read-only=true` |
  | every other top-level directory, `/run` (rest), `/tmp`, `/home`, `/sys` | tmpfs (unshare) or absent (bwrap) |
  | `/proc` | new, in a new PID namespace |
  | `/dev` | `null zero full random urandom tty`, a new `pts` and `shm` |
  | the worktree (`git rev-parse --show-toplevel`) | **read-write** |
  | the git common dir | **read-only** |
  | `$TMPDIR`, a new `mktemp -d` under `/tmp`, removed on exit | read-write |
  | codex: `~/.codex/auth.json` | read-write |
  | codex: `~/.codex/implement.config.toml` | read-only bind of the resolved file |
  | agy: `~/.gemini` | read-write, with its configuration read-only or hidden (step 1) |
  | `AGY_GUARD_LOG`'s file, Codex's `-o` file | read-write bind of that one file, after all other mounts |

- **Neither implementer stages.** Claude reviews the diff, runs `git add` and commits (owner
  decision 1, which changes the approved intent).
- The daemon is hidden for both. `nix build`, flake evaluation and `just test-host` fail inside;
  Claude runs them after each step that changes Nix (#2758 tracks `trusted-users`).
- agy's MCP config is masked by a read-only store file `{"mcpServers":{}}`. If that breaks agy's
  start, drop the mask and rely on the adapter's deny (`agy-guard-adapter.sh:141`).
- Codex always gets `-c 'mcp_servers={}'`, keeps `approval_policy = "on-request"`, and
  `codex-implement` refuses to start unless `/etc/codex/requirements.toml` registers
  `/etc/codex/hooks/coder-guard` and that file is executable.
- Arguments: see step 4. Environment: `env -i` (`--clearenv` for bwrap), then `PATH` (filtered),
  `HOME`, `LANG`, `TERM`, `TMPDIR`, `SSL_CERT_FILE`, `NIX_REMOTE`, `NIX_CONFIG`; codex adds
  `CODEX_CODER=1`; agy adds `AGY_CODER=1`, `AGY_WORKTREE` and `AGY_GUARD_LOG` when set.
- If agy's commands can reach an abstract socket such as `@1PASSWORD_MCP`, stop and ask the owner
  (owner decision 2). `herdr-run` writing the environment to a file is #2762 (owner decision 3).

## Changes from the spec, needing your approval with this plan

1. **agy's real config lives in `~/.gemini/antigravity-cli/` too.** The spec's read-only list
   names `settings.json` at the top of `~/.gemini`. The permission allow-list that
   `antigravity-config.nix:365` merges is `~/.gemini/antigravity-cli/settings.json`, and that
   directory also holds `bin/`, `lib/`, `plugins/`, `mcp/` and `builtin/`. Under the spec's own rule
   ("everything that configures agy or runs code"), step 4 binds these read-only as well, and step 1
   confirms the list. Other top-level files seen on p620 (`settings.nix`, `settings.json.orig`,
   `antigravity/user_settings.pb`, `antigravity/skills/`, `antigravity/bin/`) are bound read-only too.
2. **`agent-run.sh:41` changes by two lines.** The spec keeps `agent-run` unchanged, but it also
   requires the `-o` file's parent to be a directory owned by the caller. `log=$(mktemp -t …)`
   puts `"$log.msg"` straight in `/tmp`, which root owns, so every Codex handoff would be refused.
   The fix creates a private directory: `logdir=$(mktemp -d -t agent-run.XXXXXX)` and
   `log=$logdir/log`. The printed `log` path keeps working. The alternative, accepting a sticky
   root-owned parent, weakens the check for every caller, so it is not chosen. Its retry loop
   (`agent-run.sh:42-58`) reuses `"$log.msg"`, which the wrapper's no-clobber create would refuse
   on attempt 2, so each attempt first runs `rm -f -- "$log.msg"`.

## Steps

1. **agy gate, no repo edits (Claude).** In the scratchpad, write a throwaway script that does what
   step 2's `sandbox_exec_unshare` will do, then run `agy-implement`'s exact command line through it
   against a throwaway repo under `/tmp`. Record each row on #2757:

   | Probe result | What happens |
   | ------------ | ------------ |
   | Login, model, file edits and a sandboxed `git status` work, secrets hidden | Continue |
   | agy's `--sandbox` fails inside the namespace | Stop and ask. Do not drop `--sandbox` |
   | agy's commands have outbound network | Continue; step 8 records it as an open exposure |
   | A command reaches `@1PASSWORD_MCP` or another abstract socket | Stop and ask the owner |
   | agy needs to write a protected `~/.gemini` path | Stop and ask |
   | An MCP server runs despite the mask | Drop the mask, record it; the probe checks it runs inside and is denied |

   Also settle, and write into this plan as a deviation note:
   - which of `~/.gemini/config/mcp_config.json` and `~/.gemini/antigravity/mcp_config.json` agy
     reads (mask the one it reads; mask both if unclear);
   - the final read-only list for `~/.gemini` (change 1 above), on p620. Only paths that exist get a
     bind; a listed directory that is missing is created empty by the wrapper first, because agy
     could otherwise create it writable. A listed **file** that is missing makes the wrapper refuse
     to start (fail closed), so the final list holds only files present on p620 and razer;
   - whether agy runs with `/sys` as an empty tmpfs;
   - a forced OAuth refresh works, by waiting for expiry or moving the token's expiry back in a copy.

   → verify: the table rows above, recorded on the issue. `test -r` only; never print a value.
   Traps: never pass `--dangerously-skip-permissions` outside `agy-implement`'s own line. Stop after
   two failed approaches to one row, and ask. Run commands with `</dev/null`.

2. **Create `home/development/agent-sandbox.sh`** (library, no shebang, `# shellcheck shell=bash`
   on line 1). Move, not copy, from `home/development/agent-review.sh`:
   - lines 9-12, the `GIT_*` unset, at top level;
   - lines 19-25 as `sandbox_repo_checks`, which sets `root`, `common` and `home`;
   - lines 111-114 as `sandbox_ro_paths`, an array of the host paths that exist;
   - lines 116-131 as `sandbox_safe_path`, which sets `safe_path`;
   - lines 133-146 as `sandbox_exec_bwrap <extra bwrap args…> -- <command…>`. The fixed part (ro
     paths, daemon tmpfs, `--dev`, `--proc`, `--tmpfs /tmp /home`, `--unshare-pid --unshare-ipc
     --die-with-parent`, `--clearenv` and the shared variables) stays in the function; each caller
     passes its repo binds, `--chdir`, tool-specific `--setenv`s and the command.

   Add:
   - `sandbox_check_out_file <path>`: refuse unless the path is absolute, its parent is an existing
     real directory owned by the caller, `realpath -m -s` equals `realpath -m` for it (no symlink in
     any component), and it is not inside `$root`, `$common`, `$home/.codex`, `$home/.gemini`, `/etc`
     or `/nix`. Then `( set -o noclobber; umask 077; : >"$path" )`, so an existing file is refused,
     and check `[[ -f $path && ! -L $path ]]` and `stat -c %h` is `1`.
   - `sandbox_exec_unshare <policy…> -- <command…>`, the agy backend:
     - Outer: `unshare --user --map-current-user --mount --pid --fork --mount-proc --kill-child --
       bash -c "$(declare -f sandbox_setup); sandbox_setup \"\$@\"" sandbox <args>`, with `bash` as
       an absolute store path from `runtimeInputs`.
     - `sandbox_setup`, with `set -euo pipefail` so any failed mount aborts before agy starts:
       1. `mount --make-rprivate /`.
       2. Staging: `mount -t tmpfs tmpfs /mnt` (refuse if `/mnt` is missing), and bind into it the
          worktree, the common dir, `$TMPDIR`, `~/.gemini`, the guard-log file, `/dev` and, for
          `/run`, the `resolve` and `nscd` directories. Save `cs=$(readlink /run/current-system)`
          now, before `/run` is covered.
       3. `mount --bind X X` then `mount -o remount,bind,ro X` for `/nix`, `/etc`, `/usr`, `/lib*`.
          Never touch `/bin`.
       4. tmpfs over `/nix/var/nix/daemon-socket`, `/home`, `/root`, `/tmp`, `/var`, `/run`, `/sys`,
          `/boot`, `/srv`, `/opt`, `/media`, and every other top-level directory not in the list
          (read `/` with a glob, compare against the keep list, hide the rest). `/mnt` is exempt
          here: it holds the staging until sub-step 9.
       5. `/dev`: tmpfs, then bind `null zero full random urandom tty` from the host (taken from
          the staged bind of `/dev`), then `umount` that staged bind; `devpts` with
          `newinstance,ptmxmode=0666` at `/dev/pts`, `/dev/ptmx` as a symlink to `pts/ptmx`, tmpfs at `/dev/shm`.
       6. In the new `/run`: `ln -s "$cs" /run/current-system` (it is a
          symlink, so a bind would resolve it), and move `resolve`/`nscd` back.
       7. `mkdir -p` each mount point in the new tmpfs, then `mount --move` the staged binds back,
          parents before children. Then `mount -o remount,bind,ro` the common dir. A worktree under
          `/tmp` (agy-guard-probe's) works because `/tmp` is covered before it is moved in.
       8. `~/.gemini`: read-only binds over each protected path from step 1, the MCP mask, tmpfs
          over `antigravity-browser-profile/` and `antigravity-backup/`.
       9. Last, the guard-log file bind. Then `umount /mnt`, which must find no staged mount left
          (fail closed if busy), and cover `/mnt` with a fresh tmpfs.
       10. Close every descriptor above 2 (`for fd in /proc/self/fd/*`), `cd` to the worktree.
       11. `exec unshare --user --map-user="$uid" --map-group="$gid" -- env -i <allow-list> <command>`,
           with `uid`/`gid` from `id -u`/`id -g` on the host before the outer `unshare`.

   → verify: `shellcheck -S info home/development/agent-sandbox.sh` clean.
   Traps: the library is shell-checked alone by pre-push and inside each package; functions only
   its callers use may need a scoped `# shellcheck disable=SC2329` with a one-line reason.
   `writeShellApplication` runs a minimal bash, no `compgen`. Never read stdin: Codex reads its
   prompt from it, so pass it through. Never print `env` values, only names.

3. **`home/development/agent-review.sh` and its test.** Delete the moved lines and call the library
   functions in the same order; the bwrap call becomes `sandbox_exec_bwrap --ro-bind "$root" "$root"
   --ro-bind "$common" "$common" --bind "$work_dir" "$work_dir" --chdir "$root" --setenv TMPDIR
   "$work_dir" --dir "$home/.codex" --bind "$home/.codex/auth.json" "$home/.codex/auth.json" --
   codex -c forced_login_method=chatgpt -c 'mcp_servers={}' -c 'sandbox_mode="read-only"' "$@"`.
   The argument checks at lines 14-109 do not change.
   `home/development/agent-run.nix:28`: `text = builtins.readFile ./agent-sandbox.sh +
   builtins.readFile ./agent-review.sh;`.
   `home/development/agent-review.test.sh:7`: when `AGENT_REVIEW` is unset, `cat
   "$here/agent-sandbox.sh" "$here/agent-review.sh" >"$w/agent-review"` after `$w` exists, and set
   `script` to that. Move the `mktemp`/`trap` (lines 10-11) above it. No check changes.

   → verify: `bash home/development/agent-review.test.sh </dev/null` reports the same 78 checks
   passing as on `origin/main` (run it there first and keep the count); `git add -A`, then
   `just check-syntax`.
   Traps: flakes ignore untracked files. A commit hook may reformat; `git add` and commit again.

4. **Create `home/development/agent-implement.sh`** and package it.
   - Usage `agent-implement <codex|agy> -- <tool arguments>`; `refuse` prints `agent-implement:` and
     exits 2. Refuse `HUMANIZE_CODEX_BYPASS_SANDBOX`, call `sandbox_repo_checks` and
     `sandbox_safe_path`, create `$TMPDIR` with `mktemp -d /tmp/agent-implement.XXXXXX` and remove it
     with a `trap` on exit. Because the trap must run, the backends are not `exec`ed: run them, then
     `exit` with their status.
   - Codex allow-list, default-deny as in `agent-review.sh:62-109`: `exec` as the only subcommand;
     `-p implement`, accepted once and only as the launcher's first two arguments; `-o <file>` and
     `--output-last-message[=]<file>` through `sandbox_check_out_file`; `-`, `--`, `--ephemeral`,
     `--json`, `--color`; `-c`/`--config` with `model` or `model_reasoning_effort` only. Refused:
     `--dangerously-*`, `--yolo`, `--full-auto`, `--add-dir`, `-s`/`--sandbox`, any other `-p` or
     `--profile`, `--enable`, `--disable`, `--oss`, every other option and `-c` key.
   - Codex backend: `sandbox_exec_bwrap` with `--bind "$root" "$root"`, then `--ro-bind "$common"
     "$common"` (after, so a plain repo's `.git` inside the worktree ends read-only), `--bind
     "$tmp" "$tmp"`, `--chdir "$root"`, `--setenv TMPDIR "$tmp" --setenv CODEX_CODER 1`, `--dir
     "$home/.codex"`, the `auth.json` bind, `--ro-bind "$(realpath -e
     "$home/.codex/implement.config.toml")" "$home/.codex/implement.config.toml"`, and last the `-o`
     file bind. Command: `codex -c forced_login_method=chatgpt -c 'mcp_servers={}' "$@"`.
   - agy allow-list: `--mode accept-edits --sandbox --dangerously-skip-permissions` must be the first
     four words exactly as `agy-implement` passes them; then `--model`, `--effort`, `-p`,
     `--output-format`, `--print-timeout` (separate or `=` forms). Refused: `--mode` again, `--add-dir`,
     `-*gemini_dir*`, `-*gemini-dir*`, `-*config*dir*`, `-*config_override*`, and anything else.
     `AGY_GUARD_LOG`, when set in the caller's environment, goes through `sandbox_check_out_file`.
   - agy backend: `sandbox_exec_unshare` with `AGY_CODER=1`, `AGY_WORKTREE=$root` and the log path.
   - `home/development/agent-run.nix`: add after `agent-review`:

     ```nix
     (pkgs.writeShellApplication {
       name = "agent-implement";
       runtimeInputs = with pkgs; [ bubblewrap git coreutils util-linux bash ];
       text = builtins.readFile ./agent-sandbox.sh + builtins.readFile ./agent-implement.sh;
     })
     ```

   - `home/development/agent-run.sh:41`: `logdir=$(mktemp -d -t agent-run.XXXXXX)`, `log=$logdir/log`
     (change 2 above), and `rm -f -- "$log.msg"` at the top of the retry loop at line 42.

   → verify: `shellcheck -S info` on the new file and on `cat agent-sandbox.sh agent-implement.sh`;
   `git add -A`; `just check-syntax`.
   Traps: `util-linux` from `pkgs`, not the profile: the wrapper runs before any mount exists. Codex
   may write `-o` by temp file and rename, which a single-file bind breaks with `EBUSY`/`EXDEV`; the
   live probe in step 10 checks it. If so, stop and ask: the fallback, a dedicated empty
   `$logdir/out/` bound read-write with `-o` inside it, is wider than the spec's one file and needs
   the owner's approval. A process running as the same user could swap the checked file or its
   parent between the check and the bind; this limit is inherited from `agent-review` (#2748) and
   from spec section 6, and `docs/tooling/agy-coder-guard.md` records it (step 8). `$root` and `$common` coincide in
   `.git` only for a plain repo; mount order handles it.

5. **`home/development/codex-cli.nix:27-29`**: `codexImplement` checks the guard, then hands over
   to the wrapper. `CODEX_CODER=1` moves into the wrapper, which sets it inside:

   ```nix
   codexImplement = pkgs.writeShellScriptBin "codex-implement" ''
     req=/etc/codex/requirements.toml
     guard=/etc/codex/hooks/coder-guard
     q='[.hooks.PreToolUse[].hooks[] | select(.command == "/etc/codex/hooks/coder-guard")] | length'
     n=$(${pkgs.yq-go}/bin/yq -p toml -o json "$q" "$req" 2>/dev/null)
     if [ ! -x "$guard" ] || ! [ "$n" -ge 1 ] 2>/dev/null; then
       echo "codex-implement: $req does not register $guard -- refusing to run (#2757)." >&2
       exit 1
     fi
     exec "${bin}/agent-implement" codex -- -p implement "$@"
   '';
   ```

   `yq` parses the TOML, so a `coder-guard` command under another table does not count (checked
   on p620: the live file gives `1`). An empty or non-numeric `n` (an unparsable or missing file)
   makes `[` fail, and the `!` turns that into a refusal. The test plants a `requirements.toml`
   without the hook, one with it under `SubagentStop` only, and an unparsable one.
   Also confirm, and note in the commit body, that the managed `SubagentStart`/`SubagentStop`
   hooks write nothing inside: `subagentScript` exits 0 without `HERDR_ENV=1`
   (`claude-code-managed.nix:609`), which the allow-list never passes.
   → verify: `git add -A`; `just check-syntax`.
   Traps: the `requirements.toml` path is fixed; never make it an environment variable. Inside a
   Nix `''` string, a shell `${…}` would be written `''${…}`; the snippet avoids one.

6. **`home/development/antigravity-config.nix:197`**: replace the `exec agy …` line with
   `exec ${config.home.profileDirectory}/bin/agent-implement agy -- --mode accept-edits --sandbox
   --dangerously-skip-permissions $model "$@"`, and drop `HOME=… AGY_CODER=1 AGY_WORKTREE="$PWD"`
   from it. Keep lines 150-195 as they are, and keep `unset CASCADE_GLOBAL_CONFIG_OVERRIDE` and the
   `SC2086` directive.
   → verify: `git add -A`; `just check-syntax`.
   Traps: `--dangerously-skip-permissions` appears only on this line (#2296). agy-guard-probe calls
   `agy-implement` through `AGY_IMPLEMENT`, so it goes through the wrapper unchanged.

7. **Create `home/development/agent-implement.test.sh`**, in the shape of `agent-review.test.sh`:
   assemble `agent-sandbox.sh` + `agent-implement.sh` unless `AGENT_IMPLEMENT=<path>` is set; plant a
   fake `codex` and fake `agy` that record arguments, environment variable names and a probe. Cover
   every item of spec Verification 3:
   - hidden paths, `/sys` and host `/dev` nodes absent; worktree and `$TMPDIR` writable, common dir
     read-only; only the tool's own login visible; agy's protected `~/.gemini` paths read-only;
     daemon socket absent; `*_CODER` and `AGY_WORKTREE` present and no other caller variable, also
     from a `bash -lc` child; only descriptors 0-2; `umount` of a hidden tree fails, also from a new
     `unshare -Urm`, with the tree still hidden;
   - rejected `-o` and `AGY_GUARD_LOG`: a symlink, a symlinked parent, a hard-linked file, an existing
     file, a root-owned parent, and paths inside the worktree, `~/.gemini` and `/etc`;
   - a worktree under `/tmp`; one refused argument from each column of step 4; a failing fake
     `bwrap` and a failing fake `unshare` exit non-zero without running the tool;
   - `codex-implement`'s check refuses with a planted `requirements.toml` lacking the hook (test the
     extracted check, not the installed file);
   - SKIP, not a pass, without user namespaces;
   - mutation copies, each turning one check red: no `--clearenv`/`env -i`; common dir read-write; no
     daemon tmpfs; `AGY_CODER` dropped; agy on `bwrap` (nested remount fails); no second namespace
     (`umount` uncovers `/home`); no `~/.gemini/config` read-only bind.

   `~/.gemini` in the test is a fake under the test's own `HOME`, never the real one.
   → verify: `bash home/development/agent-implement.test.sh </dev/null` passes; each mutation copy
   fails; `shellcheck -S info` clean.
   Traps: Bash tool stdin never closes, so `</dev/null` on every run. Never print environment values.

8. **Docs.**
   - `home/development/claude-code-skills/handoff/SKILL.md`: under "Prompt template", the
     implementer cannot stage, commit, run `nix build`, flake evaluation or `just test-host`, and
     sees no secret; under "After", Claude reruns the step's checks and builds after every handoff,
     does not trust the implementer's report (`agent-run`'s verdict does not see check results),
     then stages and commits.
   - `docs/tooling/agy-coder-guard.md`: a "Sandbox" section: the unshare backend, the `~/.gemini`
     layout, what is visible by design (each tool's login, `~/.gemini`, the repo with its encrypted
     `.age` files, world-readable `/nix`, `/etc`, `/usr`), and step 1's network result.
   - `AGENTS.md` "Delegating to other models": `codex-implement` and `agy-implement` run in
     `agent-implement` with no secrets, no daemon socket, a read-only `.git`, and Claude stages.
     Record agy's command network as an open exposure if step 1 found it.

   → verify: `markdownlint` on the three files (pre-push lints whole files at MD013 120);
   `mkdocs.yml`/`mkdocs-full.yml` need no change (no new page).
   Traps: a line that starts with an issue number becomes a heading. This edits a description in
   `AGENTS.md`, not its rules.

9. **Build (Claude).** `just check-syntax`, `just validate`, `just test-host p620`, and
   `just deploy-via-p620 razer`'s build half, or `just test-host razer` built on p620.
   → verify: all succeed. Never build p510.

10. **Live probe on p620 (Claude), after the owner approves the deploy.** Announce on
    `#agents:freundcloud.org.uk` first. Run spec Verification 5 for both implementers with `test -r`
    only: hidden secrets list, environment names, daemon and `nix build` failing, forbidden git and
    `ssh p510`, network and `@1PASSWORD_MCP`, MCP processes, `~/.gemini` protected files
    byte-identical (`sha256sum` before and after, compared, not printed), one edit lands and nothing
    lands in the common `.git`, login with a forced refresh, a real `agent-run codex` and
    `agent-run agy` on a one-line throwaway step returning `ok: true`, and agy-guard-probe from a
    cleared `probed` cache.
    → verify: each item recorded on #2757.

11. **The same probe on razer** after `just deploy-via-p620 razer`, announced on the bus. Check the
    `envfs-bin-suid` unit is active and user namespaces are allowed there first.

## Tests

| Command | Expected |
| ------- | -------- |
| `bash modules/programs/agy-guard-adapter.test.sh </dev/null` | passes unchanged |
| `bash home/development/agent-review.test.sh </dev/null` | same check count as `origin/main`, all pass |
| `bash home/development/agent-implement.test.sh </dev/null` | all pass; no SKIP on p620 |
| each `AGENT_IMPLEMENT=<mutant>` copy | at least one FAIL |
| `just check-syntax`, `just validate`, `just test-host p620`, `just test-host razer` | succeed |
| step 10 and 11 probes | every item recorded as expected on #2757 |

## Rollback

- Before deploy: drop the branch commits.
- After deploy: `git revert` the implementation commits on `main` and redeploy p620 and razer;
  `codex-implement` and `agy-implement` go back to running unsandboxed, which is today's state.
- Fast stop without a rebuild: the handoff skill's fallback already applies; give steps to `coder`
  and do not run `codex-implement` or `agy-implement` until fixed.
- Nothing migrates state: `~/.gemini`, `~/.codex` and the repo are only bound, never rewritten.
