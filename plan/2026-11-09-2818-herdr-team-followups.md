---
status: approved
issue: 2818
spec: spec/2026-11-09-2818-herdr-team-followups.md
coders:
  1: codex   # small, tricky process-identity logic in one function family
  2: codex   # small, tricky locking and archive logic
  3: coder   # test edits that depend on the fake-herdr details below
  4: agy     # mechanical one-token edits across seven files
  5: coder   # one short docs paragraph
reviewers:
  - codex    # it found the pgid-reuse hole in the spec; checks the code closes it
  - agy      # independent second read of the locking and test waits
---

# Plan: herdr-team follow-ups

Branch `fix/2818-herdr-team-followups`, worktree `~/.config/nixos-2818`. All paths are relative to the repo root.
Line numbers are from commit 9085652e2.

## Approved decisions

1. **Member identity is a marker, not the pgid.**
   - The launcher execs the member with `HERDR_TEAM_MEMBER=<ctl>` in its environment, and `agent-env` keeps the
     name.
   - A process counts as the member's only when its pgrp equals the recorded pgid and its
     `/proc/<pid>/environ` holds `HERDR_TEAM_MEMBER=<ctl>` as a whole NUL-separated entry.
2. **`stop_member` no longer requires a live launcher.**
   - Leader alive with the recorded start time: group signals, as today.
   - Otherwise: verified `pid start` pairs only. TERM them, wait up to 5 s, then KILL the same pairs that `alive`
     still matches. Pids that appear later are never signalled.
3. **`sweep` stops each stale member** (`stop_member`) and archives its answers before `rm_dirs`.
4. **The archive** lives under `$rt/archive/<gen>/`, with every directory made `mkdir -m 700`.
   - `keep_answers` copies `<work>/ans/` to the first free name of `<member>`, `<member>.2`, … and appends a
     `<work>/ans/<TAB><dir>/` line to `archive/<gen>/paths`.
   - `rm_gen` copies `conversation.jsonl`, rewriting `answer` paths with that map in one `jq` pass.
   - The live log is never rewritten.
   - Copy failures warn on stderr and never block teardown.
   - There is no pruning.
5. **`emit` appends under the lock.** If `$rt/<gen>` is gone, it appends to `archive/<gen>/conversation.jsonl`.
6. **Test sleeps become waits:**
   - :345 removed;
   - :354 waits for the pointer in `$TEST_STATE/prompts`;
   - :412 does `wait_for …/req/1.md`, and the unused lines :414–415 are dropped;
   - :485 does `wait "$owner"`;
   - :609 polls `pgrep -g "$pgid" -fx 'sleep 61.7'`.
7. **`ANTHROPIC_API_KEY_FILE`** is stripped wherever `ANTHROPIC_API_KEY` is.

## Steps

1. **`home/development/herdr-team.sh`: identity and stopping.**
   - Launcher (:357): put the marker into the member's environment before the `exec`, for example
     `export HERDR_TEAM_MEMBER="$0"` inside the `bash -c` before `exec "$@"`. `$0` there is `$ctl`.
   - New `member_pids <pgid> <ctl>`, next to `stop_member`:
     - For each pid from `pgrep -g <pgid>`, read `/proc/<pid>/stat` once, take pgrp (field 3) and start (field 20)
       after the closing parenthesis, and require pgrp == pgid.
     - Then check `tr '\0' '\n' </proc/<pid>/environ | grep -qxF "HERDR_TEAM_MEMBER=<ctl>"`.
     - Print `pid start`.
   - `stop_member` (:166–182): drop line 168 (`alive "$2" "$3" || return 0`), and change the signature to
     `stop_member ctl`.
   - Update its caller in `teardown` (:195). Drop the now-unused `pid` and `start` locals and their `mget` lines
     (:184, :187–188), because shellcheck flags them with SC2034.
     - If `alive "$pgid" "$pstart"`, send the group TERM and wait as today.
     - Before the group KILL, check `alive "$pgid" "$pstart"` again. If the leader is gone by then, the group may
       have emptied and its id been reused, so KILL through the per-pid path below instead (Codex).
     - Otherwise collect `member_pids` into an array, TERM each pair still matched by `alive`, poll up to 10 × 0.5 s
       until none of the pairs is `alive`, then KILL the remaining pairs and poll again.
   - `sweep` (:146–158): before `rm_dirs`, call `stop_member "$ctl"` for each member, then `keep_answers`
     (step 2).
   - Verify: `shellcheck home/development/herdr-team.sh`, then `bash home/development/herdr-team-test.sh`. The
     existing cases still pass.
   - Traps:
     - Compare starts with `[[ == ]]` (as `alive` does) or arithmetically, never `>`/`<` on strings.
     - `/proc/<pid>/environ` can be unreadable or vanish: treat that as not ours.
     - `sweep` runs under the lock, so `stop_member` must not call `lock`.
2. **`home/development/herdr-team.sh`: archive and log.**
   - New `keep_answers <gen> <member> <work>`. The caller holds the lock.
     - Return 0 if `<work>` is empty or `<work>/ans` is missing, or `<gen>` fails `^[A-Za-z0-9]+$`.
     - Otherwise `mkdir -m 700 -p "$rt/archive" "$rt/archive/$gen"`, pick a free `<member>[.k]` and
       `mkdir -m 700` it, `cp -r -- "$work/ans/." dest/` (not `-a`, which would copy the source dir's mode onto
       dest), and append `"$work/ans/"$'\t'"$dest/"` to
       `$rt/archive/$gen/paths`.
     - On any failure, print `herdr-team: archive failed for <member>` to stderr and return 0.
   - `teardown` (:183–202): call `keep_answers` under `lock … unlock` before `rm_dirs`. The `gen` comes from
     `jq -r .gen "$f"`.
   - `rm_gen` (:125): before `rm_retry`, if `$rt/$1/conversation.jsonl` exists, write
     `$rt/archive/$1/conversation.jsonl`. Map each line's `.answer` through `paths` with a `jq` prefix replace in
     one pass, fall back to a plain `cp` if `paths` is absent, and use `mkdir -m 700 -p` first. Warn on failure,
     never abort.
   - `emit` (:667–671): wrap the append in `lock`/`unlock`. Under the lock, append to `$rt/$gen/conversation.jsonl`
     if `$rt/$gen` exists, else to `$rt/archive/$gen/conversation.jsonl` if `$rt/archive/$gen` exists. Keep
     printing the line to stdout.
   - Verify: shellcheck and the test suite.
   - Traps:
     - Confirm that no caller of `emit` (:675, :681, :711) holds the lock, because `lock` reopens fd 9 and a nested
       `unlock` would release the outer hold.
     - `jl` (:664) must be computed per call or kept, as today.
3. **`home/development/herdr-team-test.sh`: waits and new cases.**
   - Add `wait_until() { for _ in {1..100}; do "$@" && return 0; sleep 0.05; done; return 1; }` next to
     `wait_for` (:184).
   - :345: delete the `sleep 0.2`.
   - :354: replace `sleep 0.5` with ``wait_until grep -qxsF "$(pointer t1 1)" "$TEST_STATE/prompts"``. The file
     does not exist before the first prompt, and `-s` keeps grep quiet about that.
   - :412: replace `sleep 0.4` with `wait_for "$(field t1 review work)/req/1.md"`, and delete :414–415.
   - :485: replace `sleep 0.2` with `wait "$owner" 2>/dev/null || :`.
   - :609: replace `sleep 0.3` with `wait_until pgrep -g "$pgid" -fx 'sleep 61.7'`. `-x sleep` would match the
     fake Codex's own `sleep 0.05` loop, and plain `-f` the parent `bash -c` before its trap is set.
   - The fake `codex` (:91–100) writes `printenv HERDR_TEAM_MEMBER` to `$TEST_STATE/marker`. This is a separate
     file: the `env-dump` must stay empty (:278, :281).
     - Inside its wait loop it checks for a new switch file, `$TEST_STATE/orphan`. When the file appears, it starts
       `sleep 62.3 &` and exits 0.
     - The switch is set only after a successful `up`, because `up` needs the agent visible (herdr-team.sh:385).
     - The member then exits, the launcher writes `exit` and leaves, and the orphan keeps the marker.
   - `cleanup` (:9–15) and `reset` (:142–145) also `pkill -f 'sleep 62.3'` and `'sleep 63.1'`, so a failed case
     leaks nothing.
   - New cases:
     - **orphan-after-exit:** `down` and `finish implement`. The member exits and the launcher writes `exit`. After
       `down`, no `sleep 62.3` remains.
     - **sweep:** do the orphan setup, wait for `ctl/exit`, then run `up` on another task. With no live member
       left, `sweep` removes the task, prints "removed stale task", and the orphan is gone.
     - **marker guard:** start a decoy with `setsid sleep 63.1 &`, so its pgid is its own pid, with no marker.
       Write the member's `pgid` file by hand as `<decoy pid> 1`, a wrong start time, as the pid-reuse case
       does at :580–600. This forces the per-pid path, and the decoy survives `down`. Add the decoy to
       `sleepers` and kill it at the end of the case.
     - **archive:** run this sequence:
       1. `up review` and `up implement --step 1`, then arm both.
       2. A `converse` from implement whose reply hands off `TO: review`, so both members get an `ans/1.md`.
          Reuse the existing converse fixtures (:780–800).
       3. `finish t1 implement`, then `up implement --step 2` and one `ask`, then `down t1`.

       Then check:
       - `archive/<gen>/review/1.md` exists;
       - `conversation.jsonl` exists, and every non-null `.answer` in it exists;
       - `stat -c %a` is 700 on `archive`, `<gen>` and `review`.
       - the step-2 answers are in `implement.2/`.
     - **forced down mid-converse:** start a `converse` in the background and wait for its first prompt. Then
       `team down t1 --force` removes every member, so `rm_gen` runs while `converse` is in flight. Wait for the
       background `converse`; the archived log's last line has `outcome == "cancelled"`.
     - **env:** `ANTHROPIC_API_KEY_FILE=decoy` (at :277) is not in the dump. `$TEST_STATE/marker` equals the
       member's `ctl`.
   - Verify: the test takes the tool path (`tool=${1:?}`, :6), and the tool needs the Nix header lines, so:

     ```bash
     t=$(mktemp); printf 'agy_member=false\nsink_path=%s\n' "$(command -v herdr-team-sink)" >"$t"
     cat home/development/herdr-team.sh >>"$t"; chmod +x "$t"
     bash home/development/herdr-team-test.sh "$t" </dev/null
     for i in $(seq 20); do bash home/development/herdr-team-test.sh "$t" </dev/null || break; done
     nice -n 19 bash home/development/herdr-team-test.sh "$t" </dev/null   # with a parallel nix build for load
     ```

     The authoritative run is the `herdr-team` checkPhase (`home/development/agent-run.nix:23–28`), which
     `just test-host` builds.
   - Traps:
     - The fake `agent-env` (:85–88) passes the whole environment, so the test does not prove the real allowlist.
       Step 4 covers that with a grep.
     - `no_leftovers` (:173) greps `$tmp/bin/`, and the orphan must match it or be killed by the case.
4. **The key lists, and the agent-env allowlist.** Add `-u ANTHROPIC_API_KEY_FILE` after each
   `-u ANTHROPIC_API_KEY`:
   - `home/development/codex-cli.nix:37`;
   - `home/development/codex-cli/module.nix:97` and `:117`;
   - `home/development/antigravity-config.nix:198` and `:209`;
   - `modules/ai/antigravity-cli.nix:81`;
   - `home/development/herdr-team.sh:281`.

   In `home/development/agent-env.sh`, add `ANTHROPIC_API_KEY_FILE` to `agent_api_keys` (:6) and
   `HERDR_TEAM_MEMBER` to `agent_env_names` (:11–12). In the test, add `ANTHROPIC_API_KEY_FILE` to the dump
   pattern (:93) and the decoy line (:277).
   - Verify: `grep -rn 'ANTHROPIC_API_KEY\b' --include=*.nix --include=*.sh home modules` shows every `-u` list
     carrying `_FILE`. The `modules/ai/providers/*` exports are not strip lists and stay. Also run
     `bash home/development/agent-review.test.sh` and `agent-implement.test.sh` if present, since they read
     `agent_env_*`.
   - Traps: in Nix `''…''` strings `$` is literal except `${`, so add plain text only.
5. **`docs/applications/herdr.md`** (after the `finish` bullet, :230–238): one bullet.
   - Teardown copies each member's answers to `$XDG_RUNTIME_DIR/herdr-team/archive/<gen>/<member>/` and the
     log to `archive/<gen>/conversation.jsonl`. They are kept until logout.
   - Stopping a member stops every process that carries its `HERDR_TEAM_MEMBER` marker in its group. A process
     that drops the marker or leaves the group is not stopped.
   - Also fix "Every hop goes to `<gen>/conversation.jsonl`" to mention the archive.
   - Verify: `markdownlint docs/applications/herdr.md`.
   - Traps: the pre-push markdownlint lints whole files. No other mkdocs nav change is needed, because the page
     already exists in both `mkdocs.yml` and `mkdocs-full.yml`.
6. **Lead only: build, review, deploy.**
   - `just check-syntax`, `just test-host p620`, `just test-host razer`.
   - Run the Opus review, plus Codex and agy (`reviewers:`), on `git diff origin/main`. Then commit per step
     and open the PR, linking all three artifacts.
   - Announce on the bus, then `just p620` and `just deploy-via-p620 razer`.
   - Live check on p620:
     1. `herdr-team up t review` and `up t implement --step 1`.
     2. Ask the implementer to run `sleep 600 &` and quit.
     3. Check `/proc/<pid>/environ` of that sleep has `HERDR_TEAM_MEMBER`.
     4. `finish t implement`, then check `pgrep -f 'sleep 600'` is empty.
     5. `down t`, then `jq . "$XDG_RUNTIME_DIR/herdr-team/archive/"*/conversation.jsonl`.

## Tests

| Command | Expected |
| ------- | -------- |
| `shellcheck home/development/herdr-team.sh home/development/herdr-team-test.sh` | clean |
| `bash home/development/herdr-team-test.sh "$t"` (step 3) | all `ok` lines, exit 0 |
| 20× loop of the test, plus one loaded run | 20/20 and pass |
| `just test-host p620` / `razer` | build |
| the live check in step 6 | no `sleep 600` left; archive readable |

## Rollback

Revert the merge commit and deploy p620 and razer. The archive dir is plain tmpfs and needs no cleanup.
