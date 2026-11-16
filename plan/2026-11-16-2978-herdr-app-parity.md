---
status: approved
issue: 2978
spec: spec/2026-11-16-2978-herdr-app-parity.md
coders:
  4: codex     # herdr-app-sync: atomic swaps, manifest states, backups — small, tricky
  7: coder     # notify mod, ~40 lines
  8: codex     # inbox: pagination, de-duplication, provider errors, clone matching
  9: codex     # freund-agents control menu on a cloned upstream mod
  10: codex    # splits mod + Lua dispatch: two halves that must agree
  11: codex    # hook hc branch: shares a flock'd counter with the TUI path
  12: coder    # Nix module wiring, fetchFromGitHub pins, JSON fragments — mechanical
  15: codex    # herdr-team hc backend: lifecycle and safety checks
  16: codex    # herdr-run hc backend: stdio, exit status, cancellation
  19: codex    # herdr-claude-teams hc transport patch + pytest
reviewers:
  - codex      # independent read of each part's diff against this plan
# agy would take the mechanical steps (7, 12) by the agent-team default, but it is
# out of use by owner decision (#2748); add it back here to use it.
---

# Plan: herdr-app parity with the TUI workflow, plus an issues and agent-team overview

Steps are numbered once across the whole plan. Steps not in `coders:` are
done by Claude (Opus): spikes, clones, checkpoints, deploys, commits.

## Approved decisions (carried from the spec)

**Parity.**

- A function counts only when it works in herdr-app. The TUI stays
  installed and unchanged.
- The accepted gaps each get a follow-up issue (step 21):
  - reviewr's send-comments-to-agent;
  - hintr running a listed key;
  - the `nixarchy.herdr` widget;
  - the window title with host and workspace;
  - Collie;
  - lazygit as a float (it becomes a tab).

**Status.** Claude, Codex (`--no-daemon`) and agy report status through OSC
7501 in hc terminals with no hooks (probed 2026-11-16). The TUI's
`herdr integration` hooks stay.

**Agent control.**

- Every hc terminal gets full control: focus, peek, send, interrupt,
  stop, pane/hide.
- Claude Task subagents get a count and the zoe graph, and are controlled
  through their parent.
- The view covers every hc machine.

**Issues inbox** (read-only, every query for open items only):

| Provider | Kind | Filters |
|---|---|---|
| GitHub (`gh search issues`) | issues | `--assignee=@me`, `--author=@me` |
| GitHub (`gh search prs`) | PRs | `--assignee=@me`, `--author=@me`, `--review-requested=@me` |
| gitlab.com (`glab api --paginate`) | issues | `scope=assigned_to_me`, `scope=created_by_me` |
| gitlab.com | MRs | `scope=assigned_to_me`, `scope=created_by_me`, `reviewer_username=<me>` |

How the inbox behaves:

- **Limits:** each query is capped at 100 (`--limit 100`; GitLab
  `per_page=100`, at most 3 pages). A capped list shows "showing 100 of
  more, open on the web".
- **Merging:** rows are merged by ID: `gh:owner/repo#n`, `gl:group/proj#n`
  for issues, `gl:group/proj!n` for MRs. A row carries every reason it
  matched.
- **Errors:** each provider shows its own error line, and the other keeps
  working.
- **Refresh:** every 5 minutes, and a refresh button.
- **Open:** `xdg-open <url>`.
- **Start agent:**
  - Find a local clone: a space whose terminal folder has that remote, else
    a `git remote -v` search under `roots` (in the mod's `mod.json`:
    `~/.config`, `/mnt/code`).
  - Then `space.new {folder, argv: ["claude"], task: "Work on <url>"}`.
  - No clone: a toast, and nothing starts.
- **No writes** to GitHub or GitLab.

**App files** (the app owns `~/.config/herdr-app`):

- `herdr-app-sync` installs managed items as writable copies, never store
  symlinks.
- **State:** `~/.local/state/herdr-app-sync/manifest.json` (sha256 per
  installed file, plus `layout_switched`) and `backups/<time>/`, both
  outside the app home.

For each managed mod folder or layout file:

| On disk | Manifest | Action |
|---|---|---|
| absent | any | install |
| present | no entry | move to `backups/<time>/`, install (first take-over) |
| present, equals manifest | entry | install only if the source differs from the manifest |
| present, differs from manifest (local edit) | entry | move to `backups/<time>/`, install, log the backup path |

Install, for both mods and layouts:

1. Copy into `mods/.sync-<name>.<pid>/` (a temp file for a layout).
2. `herdr-app check` it.
3. On success, `rename` the current one into `backups/<time>/`, then the
   new one into place, then update the manifest.
4. On a failed check, the current one stays, and the error is logged.

`settings.json` and `keys.json`:

- First copy the current file to `backups/<time>/`.
- `jq` merge, with our keys winning and every other key kept.
- Write a temp file, then `rename`.
- Invalid JSON is left untouched and logged.

**Fresh host:** the window launch first sees no app home, so it starts a
detached `sleep 20; herdr-app-sync` after `exec`. The app creates its
home, and the delayed sync converges it while the app reloads live.

**Never fails:** it logs through `systemd-cat -t herdr-app-sync` (stderr
as fallback) and always exits 0.

**Layout `freund`:**

- A clone of `main`, with root `"toast": "notify"`.
- Tab bar `freund-chrome` (a clone of `workspace-chrome`, plus Issues and
  GitLab buttons).
- The agents block uses `freund-agents`.
- After its first install, the sync runs `herdr-app do layout.switch
  --name freund` once, if the app answers (`layout_switched` in the
  manifest).
- `ctrl-shift-l` still cycles back to `main`.

**Mods:**

- Third-party, pinned, MIT:
  - `issues`: jankeesvw/herdr-issues @15ffaad00d37efe17ef952109a3198fe299ecb67;
  - `gitlab`: rem-aster/herdr-gitlab @dc4931a029f827c93632931a2e940a93b9a2da51;
  - `resize`: jmayaalv/herdr-app-resize @4a3b91b11a4c950b1afae87c14ab2fd6236c013b.
- Ours: `inbox`, `freund-agents`, `notify`, `splits`, `freund-chrome`.
- Settings: `{"theme":"omarchy","sounds":{"enabled":true}}`.

**Keys** (`keys.json`, our sections):

| Key | Section | Action |
|---|---|---|
| `ctrl-h/j/k/l` | terminal | `splits.go-left/down/up/right` |
| `alt-h/j/k/l` | terminal | `splits.resize-left/down/up/right` (overrides the app's `pane.go` on purpose) |
| `ctrl-shift-g` | global | `{"command":"terminal.open","args":{"argv":["lazygit"],"place":"tab"}}` |
| `ctrl-shift-y` | global | `terminal.open` `argv ["zoe"]`, `place "right"` |
| `ctrl-alt-shift-y` | global | `terminal.open` `argv ["zoe"]`, `place "tab"` |
| `ctrl-shift-u` | global | `mod.open` `worktree` with props `{action:"open"}` |
| `ctrl-shift-i` | global | `mod.open:inbox` |

Any clash with 0.1.16's defaults, other than alt-hjkl, moves our key.

**hc backends:**

| Environment | herdr-team | herdr-run | claude() |
|---|---|---|---|
| `HERDR_ENV=1` with socket and IDs | TUI (byte-identical) | TUI | herdr-claude-teams (TUI transport) |
| else `HC_TERMINAL_ID` set | hc | hc | herdr-claude-teams (hc transport, step 19) |
| else | "not inside herdr", exit 2 (today) | `exec "$@"` (today) | plain claude |

**Bump checklist** (written into `docs/applications/herdr.md`, step 13):

1. New version and sha256 from `releases.herdr.dev/{app,core}/latest.json`.
2. No SVG beside the exe.
3. Diff the new default `keys.json` against our keys.
4. Re-clone `workspace-chrome` → `freund-chrome` and `agents` →
   `freund-agents`, and re-apply our diffs (kept in each mod's
   `NIXOS.md`).
5. Re-run checks V3-V5.

## Acceptance checks (spec Verification, carried)

- **V1 Build:**
  - `just check-syntax`, `just test-host p620`, `just test-host razer`.
  - The `herdr-team` and `herdr-run` builds pass their TUI and hc tests.
  - The `herdr-claude-teams` build passes pytest.
  - The `herdr-app-sync` build passes test.sh.
- **V2 Sync:**
  - With the app open, a switch installs the managed mods, the layout and
    the merged JSON; `herdr-app status` shows no errors; the window
    switches to `freund` once.
  - Undeclared keys are kept.
  - A hand edit lands in `backups/`.
  - A scratch `HERDR_APP_HOME` with no home converges after the first
    launch.
- **V3 Mods:**
  - Inbox: rows from all four provider/kind pairs, de-duplicated; the cap
    line; Open; Start agent with and without a clone; the GitLab error line
    with `glab` logged out while GitHub still works.
  - The issues panel on this repo; the gitlab panel on a gitlab.com repo.
  - A blocked agent makes a desktop notification, and clicking it focuses
    that agent.
- **V4 Keys:**
  - ctrl+hjkl between app panes, through Neovim splits and out at the
    edge.
  - Inside a Neovim terminal buffer or a picker, the key stays in Neovim.
  - alt+hjkl resizes Neovim splits, or app panes outside Neovim.
  - ctrl-shift-g, y, u and i work.
  - No visible lag.
- **V5 Agents:**
  - Claude, Codex and agy on p620, and one on razer.
  - Every control works, including answering agy's trust prompt through
    Peek.
  - A Claude with Task subagents shows the count while working, and Graph
    opens zoe on the right machine.
- **V6 Teams from an app terminal:**
  - `herdr-team up` → `ask` → `converse` → `finish` → `down`: members show
    under the lead in the team tab, and nothing is left running.
  - Killing the lead lets the watchdog clean up.
  - `herdr-run`: a row, the exit status, separate stderr, cancellation.
  - A Claude agent team: teammates as tabs after the lead; teardown touches
    only its own.
- **V7 hc:**
  - 0.1.21 / 0.1.16, and Updates says managed.
  - One `hc-hold-*` unit per terminal.
  - The screen is restored after `hc server restart`.
- **V8 TUI unchanged:** `herdr` runs with all 13 plugins; `herdr-team` and
  `herdr-run` inside the TUI behave as before.

## Repo traps

- **Explicit imports:** no `readDir`. Scripts use `writeShellApplication`
  (minimal bash: no `compgen`).
- **Every deploy checkpoint:**
  1. `git fetch origin && git merge origin/main` into the task branch first
     (a stale branch rolls hosts back).
  2. `read_new("#agents:freundcloud.org.uk")`. If someone has work in
     flight, wait or ask.
  3. `post` what and how long.
  4. Run from the worktree `~/.config/nixos-2978` with
     `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1`.

  Hosts stay on the branch until merge. The nightly upgrade from
  `/etc/nixos` (main) can revert them, so verify soon after deploying.
- **Hosts:** razer deploys through `just deploy-via-p620 razer`. p510 is
  untouched.
- **`hc server restart` and app restarts** count as disruptive: they follow
  the same bus steps.
- **Launching the app:** from the compositor only,
  `hyprctl eval 'hl.exec_cmd("uwsm-app -- herdr-app")'`; never from a TUI
  pane.
- **Codex in the background** needs `</dev/null`. **Commit bodies** go in
  a file (`-F`); no line starts with `#<n>`.
- **Never** run app or core updates.
- **Docs:** `docs/applications/herdr.md` only. A new page would need both
  `mkdocs.yml` and `mkdocs-full.yml`.

## Steps

### Part 1: packages and hc config

1. **Bump both packages.**
   - `pkgs/herdr-core/default.nix:15` → `"0.1.21"`; `:30` →
     `78424755c10a40dde38a0bdb55c20ac19706e9ae05ed68fc2acf1fcff0d941c1`.
   - `pkgs/herdr-app/default.nix:24` → `"0.1.16"`; `:44` →
     `282d2632196b238206cfe66bfb61c0faf299ca1c91843bd076521bbe36571216`.
   - Check:
     `out=$(nix build --no-link --print-out-paths --impure --expr '(builtins.getFlake (toString ./.)).nixosConfigurations.p620.pkgs.customPkgs.herdr-app')`
     succeeds, and `ls "$out/bin"` has no `herdr-app.svg`.
2. **hc config.** `home/development/herdr.nix`, before `:78`: add
   `xdg.configFile."herdr-core/config.toml".text` with `history_mb = 48`
   (TUI keeps 50 000 000 bytes) and `restore_screen = true` (closest to
   `pane_history`), each with a one-line comment.
   - Check: `just check-syntax`.
3. **Checkpoint A (p620).**
   - Bus steps and merge, `just test-host p620`, then `just p620`.
   - Save the live default `keys.json` before anything edits it:
     `cp ~/.config/herdr-app/keys.json ~/.local/state/herdr-app-defaults-0.1.16.json`.
     The app rewrites an untouched file on upgrade, so this happens after
     the app restarts on 0.1.16.
   - Then `hc server restart` (bus steps).
   - Check V7.

### Part 2 and 3: sync, clones, mods, wiring

1. **`pkgs/herdr-app-sync/`** (new: `default.nix`, `herdr-app-sync.sh`,
   `test.sh`).
   - The package: `writeShellApplication`,
     `runtimeInputs = [ jq rsync coreutils util-linux systemd ]`. Its
     `checkPhase` runs `bash ./test.sh "$target"` with a fake `herdr-app`
     on `PATH` (`check` fails a folder containing a file `BAD`; `status`
     and `do` log their arguments).
   - Register it in `pkgs/default.nix` after `:133`.
   - CLI: `herdr-app-sync [<source-dir>]`; the default source is
     `~/.config/herdr-app-sync/source`. The app home is `HERDR_APP_HOME`,
     else `~/.config/herdr-app`; with no home it exits 0.
   - The source holds `managed.json` (`{mods:[…], layouts:[…],
     first_layout:"freund"}`), `mods/<n>/`, `layouts/<n>.json`,
     `settings.json` and `keys.json`.
   - Behaviour: the table, install steps, JSON merge, `layout_switched` and
     logging under "App files" above.
   - test.sh covers:
     - each table row;
     - a failed check keeping the old one;
     - invalid JSON untouched;
     - undeclared keys kept;
     - JSON backed up before a merge;
     - a rerun as a no-op (manifest bytes unchanged);
     - backups outside the app home;
     - `layout.switch` called exactly once;
     - nothing deleted outside the app home and state dir.
   - Check: `nix build` of the package.
2. **Launch hook.** `pkgs/herdr-app/default.nix:77-82`:
   - Add `herdr-app-sync` to `--prefix PATH`.
   - Add `--run` with this logic. Only when `$# -eq 0` and
     `HERDR_APP_SYNC_RUNNING` is unset, export `HERDR_APP_SYNC_RUNNING=1`;
     then:
     - if the app home exists, run `herdr-app-sync || :`;
     - else `setsid -f sh -c 'sleep 20; herdr-app-sync' >/dev/null 2>&1`.
   - Pass `herdr-app-sync` in as an argument in `pkgs/default.nix:133`.
   - Check: build with a fake `herdr-app-sync` earlier on `PATH` that
     appends to a log.
     - `herdr-app --version` → log empty.
     - `HERDR_APP_HOME=<existing scratch> herdr-app` (killed after 3 s) →
       one line.
     - With an absent scratch home → one line after 20 s.
3. **Clones** (on p620, after checkpoint A, app open on 0.1.16):
   - In the live app:
     - `herdr-app do layout.clone '{"name":"main","as":"freund"}'`;
     - `herdr-app do mod.clone '{"name":"workspace-chrome","as":"freund-chrome"}'`;
     - `herdr-app do mod.clone '{"name":"agents","as":"freund-agents"}'`.
   - Copy them to `home/development/herdr-app/layouts/freund.json` and
     `home/development/herdr-app/mods/freund-{chrome,agents}/`.
   - Layout edits:
     - root `"toast": "notify"`;
     - the tab-bar `content.mod` → `freund-chrome`;
     - the agents block → `freund-agents`.
   - `freund-chrome`: add Issues and GitLab buttons next to Files and
     Changes, copying the exact change from herdr-issues'
     `layouts/main-issues.json` and from herdr-gitlab's `install.py`
     tab-bar edit (read it, never run it).
   - Each clone's diff goes into a `NIXOS.md` beside it.
   - Remove the three live clones afterwards; restore the layout with
     `layout.switch --name main`.
   - Check: `herdr-app check` on both repo mod folders.
4. **`notify`** (`home/development/herdr-app/mods/notify/main.js`,
   `mod.json` with `"place":"none"`):
   - On render it reads `props()` (`title`, `body`, `overlay`, and the
     agent's terminal if present).
   - It calls `exec("sh", ["-c", script, "notify", title, body, terminal ?? ""])`
     without awaiting it, then `closeOverlay(overlay)`, where `script` is:

     ```sh
     r=$(notify-send -a Herdr -A open=Open -- "$1" "$2")
     [ "$r" = open ] && [ -n "$3" ] && herdr-app do agent.focus --terminal "$3"
     ```

   - Check: `herdr-app check` (V3's notification check runs at
     checkpoint B).
5. **`inbox`** (`home/development/herdr-app/mods/inbox/`): the "Issues
   inbox" decisions above, exactly.
   - `mod.json` holds `roots`.
   - Fetch logic lives in `logic.js`, kept separate from the UI, with a
     `node --test` file run in the step's check (`pkgs.nodejs` in the
     check only). It covers:
     - de-duplication with merged reasons;
     - the cap line;
     - one provider failing;
     - `gh:` vs `gl:` IDs never colliding.
   - Check: `node --test`, then `herdr-app check`.
6. **`freund-agents` controls** (`home/development/herdr-app/mods/freund-agents/`,
   from step 6). The row menu:
   - Focus (`agent.focus`), Peek (`terminal.peek`);
   - Send: an input, then `exec("hc", ["send", addr, text])`;
   - Interrupt (`hc interrupt addr`);
   - Stop: a confirm dialog, then `terminal.kill`;
   - Pane / Hide (`terminal.keep` / `terminal.park`).

   Remote rows use the app's `machine/address`, with `hc … --on <machine>`
   where hc needs it.

   Subagent line:
   - It reads `$XDG_RUNTIME_DIR/claude-hc-subagents/<t>`, a JSON
     `{"count": N}`: locally with `cat`, remotely with `hc exec --on <m>
     cat`.
   - It shows only while the row is live and `working`.
   - Graph button: `agent.focus`, then `terminal.open {argv: ["zoe",
     cwd], place: "right"}`.

   Keep the clone's own `setAgentOrder`. Keep changes to upstream lines
   small, and note them in `NIXOS.md`.
   - Check: `herdr-app check`.
7. **`splits` + Neovim.**
    - **The mod** (`home/development/herdr-app/mods/splits/`):
      `nextCommand()` handles `go-*` and `resize-*`.
      - If the focused pane's `program.key === "nvim"`:
        `exec("hc", ["keys", terminal, "ctrl+h"])` (or `alt+h`, and so on).
      - Else `go-*` → `run("pane.go", {direction})`, and `resize-*` → the
        `resize` mod's own command (its name comes from its source at
        step 12).
    - **Lua:** `home/shell/lazyvim/lazyvim/lua/plugins/herdr-splits.lua`
      (54 lines).
      - `:19` cond → `vim.env.HERDR_ENV == "1" or vim.env.HC_TERMINAL_ID ~= nil`.
      - The `keys` entries (`:44-51`) call `nav(dir)` / `size(dir)`. These
        use `require("herdr-splits")` in the TUI. In the app they run a
        local function: `wincmd`, and at the edge
        `vim.fn.jobstart({"herdr-app","do","pane.go","--direction",dir})`;
        `resize` stays inside Neovim.
      - Edge test: the window number didn't change.
      - The local function returns early for the same
        `ignored_buftypes` / `ignored_filetypes` (`:27-41`).
    - Check: `herdr-app check`; `nvim --headless -c 'lua require("lazy")' -c q`
      starts without errors.
8. **Hook hc branch.** `modules/programs/claude-code-managed.nix:687-735`:
    - Lines `:692-694` (today's guard) become the condition for a TUI
      branch with today's body, unchanged.
    - New branch when `HERDR_ENV` != 1 and `HC_TERMINAL_ID` is non-empty:
      - the same `flock`'d counter, named
        `$source-hc-$HC_TERMINAL_ID` (sanitised as today);
      - for `source = claude-subagents` only, also write
        `$XDG_RUNTIME_DIR/claude-hc-subagents/$HC_TERMINAL_ID` as
        `{"count":N}` (a temp file, then `mv`).
      - No `herdr` call.
    - Check: `just check-syntax`, then run the built script by hand:
      `HC_TERMINAL_ID=tX bash $script inc` twice → `{"count":2}`; `reset` →
      `{"count":0}`; with `HERDR_ENV=1` and no pane → exit 0, no file.
9. **Home Manager wiring.** New `home/development/herdr-app.nix`, imported
    in `home/development/default.nix` after `:23`, under
    `config.programs.herdrSkill.enable`.
    - It builds the source with `linkFarm`:
      - `mods/{inbox,notify,splits,freund-chrome,freund-agents}` from
        `./herdr-app/mods/` (listed explicitly);
      - `mods/issues`, `mods/gitlab`, `mods/resize`: `fetchFromGitHub` at
        the pinned commits, subfolder from each repo (`mods/issues`,
        `mods/gitlab`; resize's real path, read from the repo);
      - `layouts/freund.json`;
      - `settings.json` and `keys.json`, from the tables above, via
        `builtins.toJSON`;
      - `managed.json`.
    - `xdg.configFile."herdr-app-sync/source".source` points at it.
    - `home.activation.herdrAppSync` runs after `writeBoundary`:
      `${herdr-app-sync}/bin/herdr-app-sync || true`.
    - Check:
      - `just check-syntax`, `just test-host p620`;
      - `jq` diff of our `keys.json` keys against
        `~/.local/state/herdr-app-defaults-0.1.16.json`: only alt-h/j/k/l
        may overlap.
    - Hashes come from `nix-prefetch-github` or a failed build, never
      guessed.
10. **Checkpoint B** (p620, then razer).
    - Bus steps and merge. `just test-host p620` → `just p620`. Run V2-V5
      and V8 on p620.
    - Then `glab auth status` on razer, and `just deploy-via-p620 razer`.
      Run V2-V5 and V8 on razer.
    - Write the "Herdr app" section into `docs/applications/herdr.md`:
      - what is managed;
      - the keys table;
      - sync, backups and rollback;
      - the gaps;
      - the bump checklist.

### Part 5: `herdr-team` / `herdr-run` on hc

 1. **Spike** (app terminal, scratch names):
    - `herdr-app do tab.new --space <S> --name spike --argv '["true"]'`;
    - `hc run --bg --keep --name spike-m --label herdr.space=<S> --label herdr.tab=<T> -- sleep 300`.

    It must show:
    - the member in tab T, with focus unchanged;
    - `hc get spike-m` has `parent` = the caller;
    - `hc kill spike-m` removes it;
    - whether `hc run` children inherit `CLAUDE_CODE_CHILD_SESSION`. If they
      do, the launch strips it.

    Write the result into this plan before step 15 (a plan update in its
    own commit). If labels don't place the member: `terminal.keep {place:
    "tab"}`, then `space.select` / `tab.select` back. If that also fails,
    stop and report.
 2. **`herdr-team` hc backend** (`home/development/herdr-team.sh`):
    - `:15-18` → the backend choice (table above). The TUI functions stay
      byte-identical.
    - **Member launch on hc** (the TUI's `up`, `:352-600`, including the
      launch and retry at `:538-545` and the readiness loop at `:558-590`):
      1. Write the work dir and the `launch` script first; it reads
         `$HC_TERMINAL_ID` at runtime.
      2. Create the team tab once per task: `herdr-app do tab.new --space
         <lead space from herdr-app ls> --name "team <task>" --argv
         '["true"]'`.
      3. `hc run --bg --keep --name <task>-<role> --cwd <root> --label
         herdr.space=<S> --label herdr.tab=<T> -- bash <launch>`. Codex
         members get `--no-daemon`. Save the address.
      4. Readiness: poll `hc get <t> --json` until the status is reported
         and the foreground is the expected agent, the address matches the
         record, and the launcher's claim, pid and exit checks hold as
         today.
      5. On a failed placement or readiness: `hc kill <t>`, drop the
         record, fail as today.
    - **Verbs:**
      - `same_pane` (`:244`) → a recorded-address check through `hc get`;
      - screen reads (`:566`, `:682`, `:714`) → `hc read <t> --lines <n>`;
      - sends (`:699-701`) → `hc send`;
      - teardown (`:317-350`) → `hc kill`, recorded addresses only;
      - interrupts (`:1121-1128`) → `hc interrupt`;
      - renames → `--name`.
    - Members still go through `agent-env`, which strips `HC_*`.
    - Tests: `herdr-team-test.sh` gets an hc block, with a fake `hc` and
      `herdr-app` in `$tmp/bin`, covering:
      - up / ask / converse / finish / down;
      - lead death (watchdog);
      - timeout cleanup;
      - a failed placement;
      - a duplicate `up` refused;
      - an unrecorded address refused;
      - `finish` with staged changes and with a moved HEAD.
    - Check: `just test-host p620`, which runs the build
      (`agent-run.nix:18-27`).
    - The TUI functions' `git diff` is empty (check by extracting the TUI
      backend functions before and after).
 3. **`herdr-run` hc backend** (`home/development/herdr-run.sh`):
    - `:10-12` → the backend choice; the outside-herdr `exec "$@"` stays.
    - On hc, the runner is
      `hc run --bg --keep --name "↳ <label>" --label herdr.space=<S> --label herdr.tab=<T> -- bash <dir>/run`,
      started from the caller's terminal, so it is the caller's child.
    - The runner writes OSC 7501 `state=working`, then `done` or `error`,
      to its own tty.
    - stdin, stdout, stderr, the exit status and cancellation keep the
      current FIFO design.
    - `place_tab` and the socket calls (`:214-240`) are TUI-only.
    - Tests: `herdr-run-test.sh` gets hc cases for stdin, separate stderr,
      the exit code, cancellation and the outside-herdr pass-through.
    - Check: `just test-host p620`.
 4. **Checkpoint C:** bus steps and merge, deploy p620 then razer, then
    V6 (first three bullets) and V8 on both.

### Part 6: Claude agent teams on hc

 1. **Spike.** In a scratch checkout of the pinned shim
    (`rameshbaskaran/herdr-claude-teams@984b0823` with our two patches),
    write a prototype hc transport for `split-window`, `send-keys`,
    `capture-pane`, `kill-pane` and `respawn-pane`.
    - Run the shim's pytest suite against it (with fakes).
    - Then run a real `claude` agent team with 2 teammates in an app
      terminal: teammates must open as tabs after the lead, and teardown
      must leave nothing.
    - If it fails: stop, report, and Claude teams stay in-process in the
      app.
 2. **`pkgs/herdr-claude-teams/hc-backend.patch`**, added to `patches` at
    `default.nix:22`:
    - **Leader:** `HC_TERMINAL_ID`.
    - **Ownership:** a file
      `$XDG_RUNTIME_DIR/herdr-claude-teams/<leader>.json` lists the
      addresses the shim created. Kill and respawn refuse anything else, as
      `ownership.patch` does with `HERDR_PANE_ID`.
    - **`split-window`:** `herdr-app do tab.new` (unfocused, after the
      lead's tab, named for the teammate, `argv ["cat"]` placeholder), then
      the teammate's labelled `hc run`. Fake `%N` IDs map to addresses.
    - **`respawn-pane`:** `hc interrupt` the placeholder, wait until
      `hc get` shows its foreground is not `cat`, then `hc send`
      (`ownership.patch:180` behaviour).
    - **The rest:** `send-keys` → `hc keys` / `hc send`; `capture-pane` →
      `hc read`; `kill-pane` → `hc kill`; `list-panes` / `display-message`
      → `hc ls --json`, filtered to the owned set.
    - **Tests:** pytest gets hc cases (fake `hc` and `herdr-app`),
      including refusing an unowned address.
    - **Launcher:** `home/development/herdr.nix:42` (`claude()`) also
      routes when `HERDR_ENV` != 1 and `HC_TERMINAL_ID` is set.
    - Check: the package build runs pytest; `just test-host p620`.
 3. **Checkpoint D:** bus steps and merge, deploy p620 then razer, then V6
    (last bullet) and V8.
 4. **Follow-ups and PR.**
    - One issue per gap (6), each linking #2978; put their numbers into the
      docs.
    - Open the PR linking intent, spec and plan, and saying which steps the
      coder or Codex did and any fallbacks.
    - Get a Codex review of the diff against this plan.

## Rollback

- **Code:** each Part is its own commit range; `git revert` it, then
  deploy through the checkpoint steps. Parts 5 and 6 revert alone, because
  the TUI paths never changed. The approved fallback for `resize`: drop the
  alt-h/j/k/l lines from `keys.json`.
- **Live app home**, in this order:
  1. Remove `~/.config/herdr-app-sync/source` (no further syncs) and close
     the app.
  2. For each item in `manifest.json` with no backup, delete it: these were
     new installs.
  3. Copy every `backups/<time>/` item back, oldest first. This covers
     replaced mods and layouts, and `settings.json` / `keys.json`.
  4. Delete `manifest.json`.
  5. Start the app. `ctrl-alt-shift-escape` returns to the default layout
     and keys if needed.
- **Package bump:** revert step 1. If the app says it needs a newer
  herdr-core, run `hc server restart` (bus steps).
