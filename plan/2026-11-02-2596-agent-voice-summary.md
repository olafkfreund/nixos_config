---
status: approved
issue: 2596
spec: spec/2026-11-02-2596-agent-voice-summary.md
---

# Plan: spoken summaries from Claude Code and Codex

## Decisions carried from the approved spec

- One program, `agent-say` (`pkgs/agent-say/agent_say.py`, stdlib only),
  built on omarchy-voice's Python so it imports
  `omarchy_voice.config.load` and `omarchy_voice.feedback.Feedback` and speaks
  through the existing path (ElevenLabs, Piper fallback).
- One NixOS module, `modules/programs/agent-voice.nix`, option tree
  `features.agentVoice`. It installs the package, renders
  `/etc/agent-say/config.json` from options, and wires the hooks. The agent
  modules are not edited.
- The hook returns at once and runs the work as
  `systemd-run --user --collect -p SyslogIdentifier=agent-say …`.
- Summary by local Ollama (`/api/chat`, `qwen3:14b`). If Ollama fails, stay
  silent; never read raw text.
- Narrator voice: Lily `pFZP5JQG7iQjIQuC4Bku`, via
  `config.load(elevenlabs_voice_id=…)`.
- "More": `notify-send -A more="Tell me more" --wait` (60 s), or
  `agent-say more`. Never the microphone.
- **Silence gates, all fail closed, re-checked right before every sound**
  (the summary and "more"). No option disables gates 2 and 3.
  1. Runtime switch: `$XDG_STATE_HOME/agent-say/off` exists → silent.
  2. `omarchy-shell notifications isDnd` (timeout 2 s) must print exactly
     `off`.
  3. `~/.local/state/omarchy/notifications/quiet.json`: unreadable or not
     an object → silent; `dnd == true` → silent; `snoozes["*"].until` in the
     future → silent (compare as ms if > 1e12, else s); `silencedSince > 0`
     → silent.
  4. Microphone (option, default on): any `pactl -f json list
     source-outputs` entry with `corked == false` whose
     `properties["application.name"]` is not in `microphoneGate.ignore` →
     silent. `pactl` failing → silent.
  5. Delegated: env `AGY_CODER`, `AGENT_SAY_QUIET`, or `CODEX_IMPLEMENT` set
     → silent. Claude `SubagentStop` is not hooked.
  6. Turn under `minTurnSeconds` → silent.
  7. `flock -n` on `$XDG_RUNTIME_DIR/agent-say.lock`; busy → drop.
  Each silent outcome logs one line, `held <gate>`. Summary text goes in the
  log, never the full reply.

## Facts found while planning (2026-11-02, p620)

- `omarchy-shell notifications isDnd` prints `on`/`off` (Service.qml:1593).
- `quiet.json` format: Store.js:281-307. The global snooze key is `"*"`
  (Service.qml:302).
- **Meeting mode** (`nixarchy-meeting-mode`, already on) turns DND on while a
  call app holds the mic. So gate 2 covers meetings, and gate 4 is the
  second line.
- An uncorked `parecord` capture stream is held permanently by
  **nixi-companion** (`server.py`). Default `microphoneGate.ignore =
  [ "Echo-Cancel Capture" "Echo-Cancel Sink" "parecord" ]`.
- The ElevenLabs key is in the keyring (`secret-tool lookup service
  omarchy-voice-elevenlabs` succeeds). A `systemd-run --user` unit has the
  session bus, so the cloud voice works outside the daemon.
- omarchy-voice package: `config.home-manager.users.olafkfreund.programs.omarchy-voice.package`
  (`/nix/store/…-omarchy-voice-2.4.0`, python3.14). Its site-packages go on
  `PYTHONPATH` in the wrapper; the interpreter is its own `python3`.
- **agy has no end-of-turn hook.** The agy CLI 1.4.9 binary knows only
  `PreToolUse`/`PostToolUse`. **Deviation from the spec:** agy is dropped and
  there is no `agents.agy` option (an option that does nothing is a lie).
  Revisit when agy grows a Stop event. The PR says so.
- Claude managed hooks merge by `lib.zipAttrsWith (_: concatLists)`
  (claude-code-managed.nix:711), so a `Stop` entry added through
  `modules.programs.claude-code-managed.settings.hooks` sits beside
  `claude-notify stop`.

## Step 1 results (probed 2026-11-02, p620) — these override the steps below

- **Claude Code Stop payload** (2.1.316): `session_id`, `transcript_path`,
  `cwd`, `prompt_id`, `hook_event_name`, `stop_hook_active`,
  **`last_assistant_message`**. Turn start = `timestamp` of the transcript
  line with `"type":"user"` and `promptId == prompt_id`.
- **Claude interactive vs scripted:** the hook env has
  `CLAUDE_CODE_ENTRYPOINT=cli` in an interactive session and `sdk-cli` for
  `claude -p` (which omarchy-voice uses as its brain). Gate 5 adds: Claude
  speaks only when `CLAUDE_CODE_ENTRYPOINT == "cli"`.
- **Codex Stop payload** (docs, learn.chatgpt.com/docs/hooks): `session_id`,
  `transcript_path`, `cwd`, `hook_event_name`, `model`, `turn_id`,
  `stop_hook_active`, **`last_assistant_message`**. A user hook in
  `~/.codex/hooks.json` did **not** fire in the probe: untrusted user hooks
  are skipped silently.
- **Codex is therefore wired as a managed hook (deviation from step 4).** The
  module appends to `environment.etc."codex/requirements.toml".text`
  (type `lines`, so it concatenates with claude-code-managed.nix:994) using
  `lib.mkAfter`, a `[[hooks.Stop]]` / `[[hooks.Stop.hooks]]` block whose
  command is `/etc/codex/hooks/agent-say`, and sets
  `environment.etc."codex/hooks/agent-say".source` to a script that
  `exec`s `${cfg.package}/bin/agent-say hook codex`. Managed hooks are
  trusted by policy. **No home-manager activation, no `hooks.json` edit**,
  and the rollback caveat about a leftover entry goes away.
- **Codex interactive vs delegated:** the first line of the session file at
  `transcript_path` is `session_meta`; `.payload.source` is `"exec"` (string)
  for `codex exec` or an object `{"subagent":…}` for review/subagents, and
  `"cli"`/`"vscode"` interactively. Gate 5 adds: Codex speaks only when the
  source is the string `"cli"` or `"vscode"`. Turn length for Codex: the
  timestamp of the last `"type":"event_msg"` line whose `payload.type ==
  "user_message"`; if not found, treat it as long enough.
- The coder-guard env marker is `CODEX_CODER` (not `CODEX_IMPLEMENT`).
  Gate 5 env list: `AGY_CODER`, `CODEX_CODER`, `AGENT_SAY_QUIET`.

## Steps

1. **Probe the hook payloads (no repo edit).** Add a temporary Stop hook
   (`cat > $XDG_RUNTIME_DIR/stop-<agent>.json`) by hand to
   `~/.claude/settings.local.json` and `~/.codex/hooks.json`, run one turn in
   each, then remove the hook. Record in this plan: whether
   `last_assistant_message` is present, `transcript_path`, and the timestamp
   field used to measure turn length. If Codex 0.166 has no `Stop` hook
   event, use Codex `notify` (`agent-turn-complete` with
   `last-assistant-message`). `~/.codex/config.toml` already has a `notify`
   for nixi-companion, so the module would chain it, and the plan is updated
   before step 4.
   Check: the two JSON files exist and the hand-added hooks are gone.
   Traps: `~/.claude` is Syncthing-synced, so remove the probe at once.

2. **`pkgs/agent-say/agent_say.py` + `test_agent_say.py`.** Subcommands:
   - `hook claude|codex` reads the payload on stdin, writes it to
     `$XDG_RUNTIME_DIR/agent-say/last-<agent>.json`, runs `systemd-run --user
     --collect -p SyslogIdentifier=agent-say agent-say run <agent>`, and exits
     0 **whatever happens**, printing nothing on stdout.
   - `run <agent>` checks gates 5 and 6, gets the last assistant text
     (payload, else transcript), asks Ollama for the summary, saves it to
     `last-summary.json`, then takes the lock, checks gates 1-4, speaks,
     posts the notification and waits; on `more` it checks the gates again
     and speaks the long version.
   - `more`: the same "more" path for the last turn.
   - `on`, `off`, `status`.

   Ollama prompts: summary is "2-3 calm spoken sentences, what was done and
   whether anything needs the user, no code/paths/hashes/commands/markdown";
   the long version is "about 45 seconds of plain speech, same rules". Strip
   `<think>…</think>` from qwen3 output. Config comes from
   `/etc/agent-say/config.json`; a missing file means defaults with the
   microphone gate on.
   Tests (pytest, everything mocked through `subprocess.run`/file fixtures):
   each gate is tested both ways, plus `isDnd` returning `on`/garbage/a
   timeout/a missing binary → silent; `quiet.json` missing/invalid/dnd/global
   snooze → silent; an ignored vs a foreign mic stream; a delegated env; Ollama
   down → silent with no speak call; `hook` always exits 0 even when
   `systemd-run` is missing.
   Check: `pytest pkgs/agent-say -q` is green.
   Traps: never exit non-zero from `hook`. Never print to stdout from `hook`
   (Claude reads Stop-hook stdout as JSON).

3. **`pkgs/agent-say/default.nix` + `pkgs/default.nix`.** Use the same
   shape as `pkgs/agent-bus-mcp/default.nix` (makeWrapper, `dontUnpack`),
   but take `omarchyVoice` as an argument: wrapper interpreter
   `${omarchyVoice}/bin/…`'s python, i.e. the python in its closure, with
   `PYTHONPATH=${omarchyVoice}/lib/python3.14/site-packages`. Prefix `PATH`
   with `pulseaudio` (pactl), `libnotify`, `util-linux` (flock), `systemd`.
   `checkPhase` runs the pytest file. Register it in `pkgs/default.nix` next
   to `agent-bus-mcp`:
   `agent-say = pkgs.callPackage ./agent-say { omarchyVoice = null; };`.
   The module passes the real package through `.override`.
   Check: the package builds as part of step 5's `just test-host p620`,
   and its `checkPhase` runs the tests.
   Traps: overlays poison the cache (memory), so this is `callPackage` only,
   no overlay. Don't hard-code `python3.14`; derive it from
   `omarchyVoice`'s python if exposed, else read it from the package's
   `lib/` at build time.

4. **`modules/programs/agent-voice.nix`.** Use the AGENTS.md module shape,
   with these options: `enable`; `package` (default
   `pkgs.customPkgs.agent-say.override { omarchyVoice =
   config.home-manager.users.olafkfreund.programs.omarchy-voice.package; }`);
   `agents.claude.enable`, `agents.codex.enable` (both default true);
   `voice.elevenLabsVoiceId`; `summary.ollamaUrl`; `summary.model`;
   `minTurnSeconds` (60); `startEnabled` (true); `microphoneGate.enable`
   (true); `microphoneGate.ignore` (list of str, default above).
   `config = mkIf cfg.enable`:
   - `environment.systemPackages = [ cfg.package ];`
   - `environment.etc."agent-say/config.json".text = builtins.toJSON {…};`
   - `modules.programs.claude-code-managed.settings.hooks.Stop =
     mkIf cfg.agents.claude.enable [{ hooks = [{ type = "command"; command
     = "${cfg.package}/bin/agent-say hook claude"; timeout = 10; }]; }];`
   - `home-manager.sharedModules = [ … ]` with one `home.activation` entry
     (`entryAfter [ "writeBoundary" ]`), modelled on
     `codexNixFormatHook` in `home/development/codex-cli.nix`. It adds the
     entry when `agents.codex.enable` and **removes** any entry whose command
     contains `agent-say hook` otherwise. The command is `/bin/sh -c 'command
     -v agent-say >/dev/null || exit 0; exec agent-say hook codex'`.
   - An `assertion` that `programs.omarchy-voice.enable` is true for the user.

   Check: `nix eval .#nixosConfigurations.p620.config.environment.etc."agent-say/config.json".text`
   matches the options, and `managed-settings.json` has two `Stop` entries.
   Traps: never `exit` in an activation entry. If two modules set
   `settings.hooks.Stop`, `types.anything` may refuse to merge lists. If the
   eval errors with a conflict, instead add a `extraHooks`-style concat
   (smallest fix) and record the deviation here. With Codex hook trust, an
   untrusted hook is silently skipped, so check `codex` lists it.

5. **Hosts:** `hosts/p620/configuration.nix` and
   `hosts/razer/configuration.nix` import `../../modules/programs/agent-voice.nix`
   and set `features.agentVoice.enable = true;`. Not p510.
   Check: `just test-host p620` and `just test-host razer` both build.
   Traps: explicit imports only. razer builds via p620.

6. **Docs:** `docs/applications/agent-voice.md` covers what it does, the
   options, the gates, `agent-say on|off|more|status`, and
   `journalctl --user -t agent-say`. Add the nav entry to **both**
   `mkdocs.yml` and `mkdocs-full.yml`.
   Check: `markdownlint` on the file passes (the pre-push hook lints whole
   files).

## Tests

```bash
pytest pkgs/agent-say -q
just check-syntax
just test-host p620
just test-host razer
```

Live on p620 after deploy (announce on the bus first; deploy is the user's
call):

- DND on, Claude turn over 60 s → silent, `held dnd` in
  `journalctl --user -t agent-say`.
- DND off, same turn → two or three sentences in Lily's voice, and a "Tell me
  more" notification; clicking it speaks the long version.
- DND off, `agent-say off` → silent, `held switch`.
- During a Meet call → silent (`held dnd` from meeting mode, or `held mic`).
- One Codex turn over 60 s → spoken.

## Rollback

Set `features.agentVoice.enable = false` and rebuild. The Claude hook goes
with managed settings. A Codex `hooks.json` entry left behind is harmless:
its command starts with `command -v agent-say || exit 0`, and the binary is
gone. To remove it cleanly, rebuild once with `agents.codex.enable = false`
before disabling. Quick
mute without a rebuild: `agent-say off`.
