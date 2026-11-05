---
status: approved
issue: 2717
spec: spec/2026-11-05-2717-declare-hypr-keys.md
coders:
  1: codex # small, tricky Nix: options, Lua and JSON generation, chord normalising, assertions
  2: agy # large mechanical transcription of the key table into data
  3: coder # short edits: autostart loader, imports and per-host values
  4: codex # small, tricky shell: guarded read-modify-write of shell.json
  5: coder # a straightforward jq and hyprctl script
  6: coder # docs prose against the declared list
reviewers:
  - codex # second read of generated Lua, loader errors and the hook's guards against this plan
  - agy # independent read of the key table against each host's bindings.lua
---

# Plan: declare and document Hyprland keys and panel layout

## Summary of approved decisions

- Keys are declared as data in `hosts/common/nixos/omarchy-keys.nix`, imported by p620 and razer. It
  generates `~/.config/hypr/repo-keys.lua` and `repo-keys.json`.
- `autostart.lua` (repo-owned, `force = true`) loads `repo-keys` after `bindings.lua`, so a new host
  needs no edit to `bindings.lua`.
- The repo wins on a declared chord: each key runs `hl.unbind` then `o.bind`. Hand-added keys on
  other chords keep working. Live panel and menu changes stay.
- Every top-level bind moves in except Vimarchy (submap and ALT+SPACE) and Omgato, which stay local.
  Omgato is documented only.
- razer gets Exposé, Dev environments, Distrobox and Podman. Govee and Meeting AI stay p620 only.
- p510 doesn't import the module and isn't rolled out to; its derivation must not change. It is
  evaluated, not built, in this work.
- Exposé and AI Kit stay declared even though their targets may be dead. A follow-up issue covers
  them.
- One change from the spec: `hypr.workspace-groups` is left out of `fragments`. Neither host has
  that file and nothing in the repo writes it, so its load line is dead.

Steps 1 and 2 are sequential, then step 3. Steps 4, 5 and 6 each create or edit only their own files
and may run in parallel after step 3. The lead then imports the two new modules into
`omarchy-keys.nix` (step 7).

Chords are written in one canonical order everywhere new: `SUPER`, `CTRL`, `ALT`, `SHIFT`, then the
key. In docs that is `SUPER+CTRL+ALT+SHIFT+K`.

## Steps

1. **New `hosts/common/nixos/omarchy-keys.nix`, machinery only.** A NixOS module `{ config, lib,
   pkgs, ... }`. Declare the options at NixOS level under `options.local.omarchy.keys`, unlike
   `omarchy-enable-once.nix`, because host files set them at top level and
   `programs.nixarchy.menu.extraEntries` is a NixOS option. Write files through
   `home-manager.users.olafkfreund.home.file`. Options:
   - `shared`, `extra`: `listOf { key : str; description : str; action : str; lua : bool (default
     false) }`
   - `external`: `listOf { key; description }`
   - `unbind`: `listOf str`
   - `fragments`: `listOf str`
   - `workProfile`: `str`, no default
   - `calendarCommand`: `str`, no default

   Generate with `home.file`:
   - `.config/hypr/repo-keys.lua`: a local `load(name)` that returns when `package.searchpath(name,
     package.path)` is nil, otherwise uses `pcall(require, name)` and on failure runs
     `hl.exec_cmd("omarchy-notification-send " .. o.shell_quote(name .. " failed: " ..
     tostring(err)))`. Call it for each fragment. Then `hl.unbind` each `unbind` entry. Then for
     each `shared ++ extra` entry, `hl.unbind(key)` and `o.bind(key, description, action)`. Quote
     strings with `builtins.toJSON`; emit `action` raw when `lua = true`. Use no loops over any
     `hl.*` result.
   - `.config/hypr/repo-keys.json`: `{ keys = shared ++ extra; external; unbind; }`, from
     `pkgs.formats.json`.

   Add assertions:
   - No two `shared ++ extra ++ external` chords are equal after normalising: split on `+` and
     spaces, drop empties, upper-case, order modifiers as `SUPER`, `CTRL`, `ALT`, `SHIFT`, keep the
     final key last.
   - For a host in `{ p620 = "4"; razer = "5"; }`, keyed by `networking.hostName`: `workProfile`
     equals `"Profile <n>"`; the generated Lua contains `Profile <n>` and `Profile_<n>`; and it
     contains neither form of the other number. Other hosts skip this assertion, so a new host can
     use any profile.

   Verify: `nix-instantiate --parse hosts/common/nixos/omarchy-keys.nix`, plus `statix check` and
   `deadnix` on the file. Options are evaluated in step 3, once a host imports the module.
   Traps: no `mkIf cond true`; explicit imports only; minimal comments; a bare `require` of a
   missing file takes the session down, and `ipairs(hl.*)` hangs Super+K's stub.

2. **`hosts/common/nixos/omarchy-keys.nix`, the data.** Set the `shared` default, built with `let
   profile = cfg.workProfile`. Transcribe exactly:

   | Chord | Description | Action |
   | --- | --- | --- |
   | SUPER + CTRL + M | Gmail (freundcloud) | `omarchy-launch-or-focus "chrome-fmgjjmmmlfnkbppncabfkddbjimcfncm-Profile_<n>" 'google-chrome-stable --profile-directory="<profile>" --app-id=fmgjjmmmlfnkbppncabfkddbjimcfncm'` |
   | SUPER + CTRL + SHIFT + M | New email (freundcloud) | `gmail-compose-freundcloud "<profile>"` |
   | SUPER + SHIFT + C | Calendar (freundcloud) | value of `calendarCommand` |
   | SUPER + CTRL + J | AI Kit | `aikit` |
   | SUPER + CTRL + SHIFT + D | New Google Doc (freundcloud) | `google-chrome-stable --profile-directory="<profile>" --app="https://docs.new"` |
   | SUPER + CTRL + SHIFT + S | New Google Sheet (freundcloud) | same with `sheets.new` |
   | SUPER + CTRL + SHIFT + P | New Google Slides (freundcloud) | same with `slides.new` |
   | SUPER + SHIFT + S | Google Maps | `omarchy-launch-or-focus "chrome-maps" "omarchy-launch-webapp https://maps.google.com/"` |
   | SUPER + SHIFT + P | Google Photos | `omarchy-launch-or-focus "chrome-photos" "omarchy-launch-webapp https://photos.google.com/"` |
   | SUPER + SHIFT + CTRL + G | Google Messages | `omarchy-launch-or-focus "chrome-messages" "omarchy-launch-webapp https://messages.google.com/web/conversations"` |
   | SUPER + SHIFT + ALT + G | WhatsApp | `omarchy-launch-or-focus "chrome-web.whatsapp" "omarchy-launch-webapp https://web.whatsapp.com/"` |
   | SUPER + E | Exposé | `hl.dsp.event("expose.window-overview:toggle")`, with `lua = true` |
   | SUPER + H | Nixi (nixarchy help) | `nixi` |
   | SUPER + M | Toggle voice control | `omarchy-voice listen toggle` |
   | SUPER + N | Minimize window to the dock | `omarchy-hyprland-window-minimize` |
   | SUPER + SHIFT + H | Herdr sessions menu | `omarchy-shell shell toggle nixarchy.herdr '{}'` |
   | SUPER + ALT + A | GitHub Actions | `python3 ~/.config/omarchy/plugins/olafkfreund.github-actions/menu.py toggle` |
   | SUPER + CTRL + ALT + A | GitHub Actions keybindings | same with `keys` |
   | SUPER + ALT + P | GitLab Pipelines | `python3 ~/.config/omarchy/plugins/olafkfreund.gitlab-pipelines/menu.py toggle` |
   | SUPER + CTRL + ALT + P | GitLab Pipelines keybindings | same with `keys` |
   | SUPER + ALT + B | Bar settings | `omarchy-shell shell toggle skal.bar` |
   | SUPER + ALT + Q | Quick actions | `omarchy-shell -q skal.bar.controls toggle` |
   | SUPER + ALT + N | nixarchy packages | `omarchy-shell shell toggle nixarchy.pkg '{}'` |
   | SUPER + ALT + E | Dev environments | `nixarchy-plugin nixarchy.devenv` |
   | SUPER + ALT + D | Distrobox | `nixarchy-plugin nixarchy.distrobox` |
   | SUPER + ALT + O | Podman | `nixarchy-plugin nixarchy.podman` |
   | SUPER + SHIFT + K | OmaFob | `omarchy-shell yogeshojha.omafob toggle` |

   `<profile>` is `workProfile`. `Profile_<n>` is `lib.replaceStrings [ " " ] [ "_" ] workProfile`,
   for the window class.

   `unbind` default: `SUPER + SHIFT + E`, `SUPER + SHIFT + ALT + E`.

   `fragments` default: `hypr.gog-binds`, `hypr.meet-binds`, `hypr.ai-mirror-binds`,
   `hypr.nixi-companion-binds`, `hypr.microvm-binds`, `hypr.plugin-browser-binds`,
   `hypr.altscape-binds`, `hypr.agent-voice-binds`, `hypr.flea-binds`.

   `external` default:

   - SUPER + ALT + I "Agent voice: tell me more"
   - SUPER + SHIFT + ALT + V "Agent voice: toggle spoken summaries on/off"
   - SUPER + SHIFT + ESCAPE "ai-mirror: stop agent control"
   - ALT + TAB "Altscape: next window"
   - ALT + SHIFT + TAB "Altscape: previous window"
   - SUPER + ALT + SHIFT + W "Altscape settings"
   - SUPER + SHIFT + V "New Google Meet (link copied)"
   - SUPER + CTRL + ALT + M "Meeting record/transcribe/summarize"
   - SUPER + ALT + V "MicroVMs"
   - SUPER + ALT + H "Nixi companion: show or hide"
   - SUPER + ALT + SHIFT + S "Nixi companion: listen"
   - SUPER + ALT + U "Plugin browser"
   - SUPER + SHIFT + L "Cycle workspace layout: scrolling, master, monocle"
   - SUPER + CTRL + SHIFT + L "Layout: flip scrolling between horizontal and vertical"

   Leave out Altscape's `ALT + Alt_L` and `ALT + Alt_R` and the layout keys on `code:` chords: they
   don't match `hyprctl`'s key names, and step 6 documents them by hand. Flea isn't merged (#2694),
   so its keys join `external` when it is.

   Also set `programs.nixarchy.menu.extraEntries`:
   - `apps.distrobox`: icon ``, label `Distrobox`, description `Create, enter and manage containers
     · Super+Alt+D`, aliases `distrobox box boxes containers`, action `nixarchy-plugin
     nixarchy.distrobox`.
   - `apps.podman`: icon ``, label `Podman`, description `Containers, images, volumes and networks
     · Super+Alt+O`, aliases `podman containers docker images volumes networks`, action
     `nixarchy-plugin nixarchy.podman`.

   Verify: `nix-instantiate --parse`, and compare the table with the file by eye. Step 3's build
   evaluates `extraEntries`. If it rejects `description` or `aliases`, stop and report it; dropping
   them needs the spec changed.
   Traps: `toJSON` handles quotes, so Lua long strings aren't needed. Don't add `o.cmd_present`
   guards. `programs.omarchy-voice.keybinding` stays set and its `voice-binds.lua` stays unloaded,
   as today.

3. **Wiring.**
   - `hosts/common/nixos/omarchy-layouts.nix`, in the `autostart.lua` text after the Hyprflip line,
     add the following, and update the file's header comment so it no longer says `autostart.lua`
     stays only for Hyprflip:

     ```lua
     if package.searchpath("hypr.repo-keys", package.path) then
       local ok, err = pcall(require, "hypr.repo-keys")
       if not ok then
         hl.exec_cmd("omarchy-notification-send " .. o.shell_quote("hypr/repo-keys.lua failed: " .. tostring(err)))
       end
     end
     ```

   - Set the values below at top level in each host file, not inside `home-manager.users`.
   - Add `../../common/nixos/omarchy-keys.nix` to the imports in `hosts/p620/nixos/nixarchy.nix` and
     `hosts/razer/nixos/nixarchy.nix`, next to `omarchy-layouts.nix`.
   - p620 values: `workProfile = "Profile 4"`; `calendarCommand` is `omarchy-launch-or-focus
     "chrome-kjbdgfilnfhdoflbpgamdcdgpehopbep-Profile_4" 'google-chrome-stable
     --profile-directory="Profile 4" --app-id=kjbdgfilnfhdoflbpgamdcdgpehopbep'`; `fragments` adds
     `hypr.meetingai-binds`; `extra` is Govee, SUPER + CTRL + ALT + G "Govee lights", `omarchy-shell
     shell toggle olafkfreund.govee '{}'`; `external` adds the six Meeting AI keys:
     - SUPER + ALT + M "Meeting AI overlay"
     - SUPER + ALT + T "Meeting AI: start recording"
     - SUPER + ALT + SHIFT + T "Meeting AI: stop recording"
     - SUPER + ALT + SHIFT + N "Meeting AI: toggle microphone"
     - SUPER + ALT + Y "Meeting AI: toggle system audio"
     - SUPER + ALT + SHIFT + P "Meeting AI: screenshot"
   - razer values: `workProfile = "Profile 5"`; `calendarCommand` is `google-chrome-stable
     --profile-directory="Profile 5"
     --app="https://calendar.google.com/calendar/u/olaf@freundcloud.com/r"`.

   Verify: `nix build --no-link .#nixosConfigurations.p620.config.system.build.toplevel` and the
   same for razer. p510's `drvPath`, evaluated with `system.configurationRevision` forced to one
   fixed value through `extendModules`, equals the same value from `origin/main`; the revision is
   part of the build, so an unpinned comparison always differs. Don't build p510.
   Traps: use pipefail with `nix build`; `listOf` merges, so per-host `fragments` and `external` add
   to the shared ones.

4. **New `hosts/common/nixos/omarchy-bar-free-once.nix`,** a self-contained module; don't edit
   `omarchy-keys.nix`. NixOS option `local.omarchy.barFreeOnce`: `listOf str`, default `[ ]`. The
   lead sets it to `nixarchy.microvm`, `nixarchy.distrobox`, `nixarchy.podman`, `nixarchy.devenv`,
   `io.github.olafkfreund.nixarchy-plugin-browser`. Write
   `omarchy/hooks/post-boot.d/zz-bar-free-once` through
   `home-manager.users.olafkfreund.xdg.configFile`, `executable = true`, using `enable-once`'s
   header and PATH. Omarchy's hook runner goes through the directory in order, one at a time.

   Paths: `CONF=${XDG_CONFIG_HOME:-$HOME/.config}`, the file is `$CONF/omarchy/shell.json`, plugins
   are under `$CONF/omarchy/plugins/`. `.bar.layout` is an object of section arrays whose items are
   objects with `.id`, or a bar folder holding strings in `.widgets`. `.plugins` is an array of `{
   "id": ... }`. Use `stat -c %y` for modification times, since `%Y` only has one-second resolution.
   Logic:
   1. Build `todo` from ids without a marker in
      `${XDG_STATE_HOME:-$HOME/.local/state}/nixarchy-local/bar-free-once/`. Exit if empty.
   2. Wait up to 120 s for `omarchy-shell shell ping`. Exit 0 if it never answers.
   3. Wait up to 60 s until `shell.json` is unchanged for 5 s. Exit 0 otherwise.
   4. Record its modification time. With `jq`, for each id whose plugin directory exists and which
      is an object directly in a `.bar.layout` section, delete that object and add `{id}` to
      `.plugins` if it's missing. Don't touch a string in a bar folder's `widgets`.
   5. If the result differs: write it to a temp file in the same directory, re-check the
      modification time, stop if it changed, otherwise `mv`.
   6. After `sleep 3`, re-read `shell.json`. `touch` the marker only for an id that's in `.plugins`
      and isn't on the bar. Log anything else with `systemd-cat -t omarchy-bar-free-once`.

   Verify: run the script with `XDG_CONFIG_HOME` and `XDG_STATE_HOME` set to a temp directory
   holding a copied `shell.json` and empty plugin directories, with `omarchy-shell` stubbed,
   covering: an id on the bar moves and gets a marker; one already moved gets a marker and no write;
   one in neither place gets no marker; a modification-time change aborts; a second run does
   nothing.
   Traps: never use `omarchy-plugin-enable`, which returns a widget to the bar; `jq` from `pkgs.jq`
   by full path.

5. **New `hosts/common/nixos/omarchy-keys-check.nix`,** a self-contained module; don't edit
   `omarchy-keys.nix`. It adds `hypr-keys-check` with `pkgs.writeShellApplication` through
   `home-manager.users.olafkfreund.home.packages`, with `jq` in `runtimeInputs`. It reads
   `~/.config/hypr/repo-keys.json`, or the path given with `--keys <file>`. It puts every chord in
   canonical order, as in step 1. Binds compared are `hyprctl binds -j` entries with `submap == ""`,
   not `release`, not `mouse`, and a non-empty key. It fails, listing every problem, if:
   - a key in `keys ++ external` is missing from those binds, or its description differs;
   - a key is missing from `omarchy-menu-keybindings --print`, run with a 30 s `timeout`, which
     itself is a failure;
   - an `unbind` chord is still among those binds;
   - any chord among those binds appears more than once;
   - with `--docs <file>`, the file has no table row exactly like ``| `SUPER+ALT+D` | description
     |``.

   Map `hyprctl`'s `modmask`: SHIFT 1, CTRL 4, ALT 8, SUPER 64.

   Verify: `shellcheck` passes in the build; on p620, `hypr-keys-check --keys <fixture>` passes for
   a fixture of keys that exist today, and fails for a missing key and a wrong description.
   Traps: `omarchy-menu-keybindings` prints chords like `SUPER SHIFT CTRL + L`, so split on spaces
   and `+`; stdin is a socket under Claude, so don't read it to end of file; `writeShellApplication`
   uses a minimal bash; `hyprctl -j binds` emits invalid JSON on the 0.56 running in razer's old
   session, so the check is only meaningful after login.

6. **Docs.** `docs/architecture/desktop.md`:
   - New "Keys" section: the declared table, one key per row, with the chord in canonical order and
     no spaces (`SUPER+CTRL+ALT+SHIFT+K`) and the description exactly as declared; per-host keys,
     external keys, plugin-owned Omgato keys (`SUPER+CTRL+ALT+L` lights, `SUPER+ALT+R` record area,
     `SUPER+ALT+SHIFT+R` stop), `code:` and Altscape release keys, Vimarchy, how to change a key,
     how to run `hypr-keys-check`, and the dormant Hyprforge clash on SUPER+ALT+H and
     SUPER+ALT+SHIFT+P.
   - Correct "Layouts": layouts load from the store's `hyprland.lua` since nixarchy#1598, not
     `autostart.lua`; remove the sentence about a nixarchy load-point follow-up.
   - `AGENTS.md`, under Infrastructure notes: one line pointing at `omarchy-keys.nix`, saying
     `bindings.lua` is no longer where declared keys live.

   Verify: `markdownlint` on both whole files, since the pre-push hook lints whole files.
   Traps: no nav change; no line-initial issue numbers.

7. **Lead, not a coder: wire, build, review, merge.** Add `./omarchy-bar-free-once.nix` and
   `./omarchy-keys-check.nix` to the imports in `omarchy-keys.nix`, and set
   `local.omarchy.barFreeOnce` there. Build p620 and razer, and evaluate p510 as in step 3. Review
   the diff with a fresh Opus agent and with Codex and agy, given only this plan and `git diff`.
   Commit each coder's step, open the PR linking all three artifacts, request `@codex review`, and
   merge when CI is green. Open a follow-up issue for Exposé's missing handler and the missing
   `aikit` command.

8. **Lead: rollout.** Hyprland auto-reloads when its config files change, and razer's session from
   Oct 22 predates the layouts load point. So:
   1. Before switching anything, ask the user to log out and in on razer, so a reload can't drop its
      layout keys. Confirm with `ps` that it's a new session.
   2. Read and post on the bus. Switch p620 with `just p620`, then razer with `just deploy-via-p620
      razer`. p510 stays out. Keys now come from `repo-keys`, and the old lines in `bindings.lua`
      are harmless.
   3. Ask the user to log out and in on both hosts, so menu rows and the hook arrive. Until then
      p620 keeps its local menu rows.
   4. On each host, back up, then remove from `~/.config/hypr/bindings.lua` exactly the binds in
      step 2's table and p620's Govee, plus `hl.unbind` of SUPER+SHIFT+E, SUPER+SHIFT+ALT+E and
      SUPER+SHIFT+C, the voice block, and the then-unused `gmail`, `work_profile`, `gsuite` and
      `webapp_focus`. Keep every `pcall(require, ...)` line, including `hypr.omgato-bindings`, and
      all of Vimarchy, with ALT+SPACE. Read the diff, check `luac -p`, run `hyprctl reload` on that
      host, then run `hypr-keys-check`. A pass before this point proves nothing, since
      `bindings.lua` still supplied the keys.
   5. On p620, remove `apps.distrobox` and `apps.podman` from
      `~/.config/omarchy/extensions/omarchy-menu.jsonc`, keeping every other row. Check that the
      generated menu has them first. Also remove the string `nixarchy.devenv` from the bar folder's
      `widgets` in `shell.json`, which step 4's hook deliberately doesn't touch; the user asked for
      this plugin off the panel, and without this its marker never appears.
   6. Run the Tests below on both hosts.

## Tests

- p620 and razer build, and p510's `drvPath` is unchanged with the revision pinned as in step 3.
- A temporary duplicate chord, including one with reordered modifiers, fails evaluation. Setting
  razer's `workProfile` to `"Profile 4"` fails the assertion.
- `luac -p` passes on the generated `repo-keys.lua`. A deliberately broken fragment raises a
  notification and the config still loads; a missing fragment is skipped quietly.
- After login on each host:
  - `hypr-keys-check --docs docs/architecture/desktop.md` passes, and fails after temporarily adding
    a duplicate.
  - `omarchy-menu-keybindings --print` finishes promptly.
  - `shell.json` has all five ids in `plugins[]` and none on the bar, and each has a marker.
  - `nixarchy-plugin <id>` then `omarchy-shell shell isOpen <id>` returns true for each of the five,
    and closes again.
  - The session's generated menu file has `apps.distrobox` and `apps.podman`, with p620's local
    copies gone.
- Turning a plugin back on in Settings survives a rebuild and a login.
- With `bindings.lua` moved aside in a test session or a `nixarchy-desktop` microVM, the declared
  keys appear.

## Rollback

`git revert` the merge and switch both hosts. Restore each `bindings.lua` and p620's menu extension
from their backups. If a host's panel needs restoring, run `omarchy plugin enable <id>`, and remove
`~/.local/state/nixarchy-local/bar-free-once/`.
