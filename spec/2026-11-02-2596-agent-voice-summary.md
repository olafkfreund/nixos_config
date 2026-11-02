---
status: approved
issue: 2596
intent: intent/2026-11-02-2596-agent-voice-summary.md
---

# Spec: spoken summaries from Claude Code, Codex and agy

## Design

One small program, `agent-say`, in this repo, plus one hook entry per agent.
There is no new repo and no daemon.

```text
agent turn ends
  -> hook runs `agent-say hook <agent>` in the background, exits 0 at once
     -> silence gates (any fail = log one line, stay quiet)
     -> local Ollama writes a 2-3 sentence calm summary
     -> notification "Tell me more"  +  summary spoken (Lily, Piper fallback)
     -> on "Tell me more": Ollama writes ~45 s explanation, spoken
```

### Where the code lives: one NixOS module

Everything is behind one module, `modules/programs/agent-voice.nix`. A host
turns it on with options and nothing else. The agent modules
(`claude-code-managed.nix`, `codex-cli.nix`, `antigravity-config.nix`) are not
edited: the voice module plugs into them from outside.

| Piece | File | Shape |
| ----- | ---- | ----- |
| Program | `pkgs/agent-say/agent_say.py` (+ `test_agent_say.py`) | one Python module, stdlib only; reads its settings from `/etc/agent-say/config.json` |
| Package | `pkgs/agent-say/default.nix` → `pkgs.customPkgs.agent-say` | python env + wrapper, same shape as `pkgs/agent-bus-mcp`, built on omarchy-voice's Python |
| Module | `modules/programs/agent-voice.nix` | options below; renders the config, installs the package, wires the hooks |
| Host | `hosts/{p620,razer}/configuration.nix` | import the module, `features.agentVoice.enable = true;` |

What the module does when enabled:

- `environment.systemPackages = [ cfg.package ]`.
- `environment.etc."agent-say/config.json"` is generated from the options
  (`builtins.toJSON`), so every setting is declared in Nix, not edited by
  hand. It holds no secrets.
- **Claude Code:** adds a `Stop` hook through the existing NixOS option
  `modules.programs.claude-code-managed.settings.hooks`, which merges with the
  hooks already there.
- **Codex, agy:** a `home-manager.sharedModules` entry adds one
  `home.activation` step per agent that inserts the `Stop` entry into
  `~/.codex/hooks.json` or `~/.gemini/config/hooks.json`. It uses the same
  idempotent `jq` merge `codex-cli.nix` already uses for its format hook.
  When an agent is disabled, the same step **removes** its entry, so turning
  the option off really turns it off. That matters because `~/.gemini` is
  synced by Syncthing and outlives a rebuild.
- **The hook command** returns at once. It hands the work to
  `systemd-run --user --collect` as a transient unit, so the agent is never
  held up, it runs inside your session (audio, D-Bus, notifications), and its
  log is in `journalctl --user -t agent-say`. It is a per-turn user job, not
  a system service, so the DynamicUser/ProtectHome rule does not apply: it
  needs the session's PipeWire and D-Bus, the same exception as Sunshine.
- The hook command is guarded with `command -v agent-say || exit 0`, so the
  synced agy `hooks.json` is a harmless no-op on p510.

### Options

```nix
features.agentVoice = {
  enable = mkEnableOption "spoken end-of-turn summaries from coding agents";
  package = mkPackageOption pkgs.customPkgs "agent-say" { };

  agents = {                     # each defaults to true
    claude.enable = …;
    codex.enable  = …;
    agy.enable    = …;
  };

  voice.elevenLabsVoiceId = "pFZP5JQG7iQjIQuC4Bku";   # Lily; Piper if unavailable
  summary.ollamaUrl = "http://localhost:11434";
  summary.model     = "qwen3:14b";
  minTurnSeconds    = 60;
  startEnabled      = true;      # runtime switch state on first use

  microphoneGate.enable = true;
  microphoneGate.ignore = [ "Echo-Cancel" ];  # capture streams that are not a meeting
};
```

There is deliberately **no option** to turn off the Do Not Disturb and
snooze gates. That is the intent's hard rule, so it is not configurable.
`agent-say off` / `agent-say on` stays as the quick runtime switch on top of
the Nix option.

The package is built with omarchy-voice's own Python, so it can
`from omarchy_voice.feedback import Feedback` and reuse the exact speech
path (ElevenLabs → Piper fallback, pw-cat, its logging). There is no second
TTS stack. Voice: `config.load(elevenlabs_voice_id="pFZP5JQG7iQjIQuC4Bku")`
(Lily, premade, so it works on any ElevenLabs tier). Only the narrator uses
it; omarchy-voice keeps Tarquin.

### Silence gates (the intent's hard rule)

Checked in order, every time, right before speaking (not at hook time, since
summarising takes seconds). The first gate that fails stops it.

1. **Switch:** `agent-say off` writes `$XDG_STATE_HOME/agent-say/off`. The
   switch is on by default, so you can try it.
2. **Do Not Disturb:** `omarchy-shell notifications isDnd` (2 s timeout) must
   print exactly `off`. `on`, an error, a timeout or no shell all mean silent.
   Probed live: it prints `on` today.
3. **Snooze/silence:** `~/.local/state/omarchy/notifications/quiet.json`.
   `dnd: true`, any active global silence, or an unreadable file all mean
   silent. This covers "notifications off" through snooze as well as DND.
4. **Meeting:** any uncorked microphone capture stream (`pactl list
   source-outputs`) other than the echo-canceller and omarchy-voice's own
   means silent. Chrome/Teams/Meet hold the mic for the whole call, so a call
   silences it without you doing anything.
5. **Not delegated:** only top-level turns speak. Claude's `SubagentStop` is
   not hooked, and Codex or agy runs started by Claude (`AGY_CODER`,
   `handoff`, `second-opinion`, `codex exec`) carry an env marker the hook
   checks.
6. **Short turns:** turns under 60 s stay quiet; you were watching anyway.
7. **One voice at a time:** `flock` on a runtime lock. If busy, it drops the
   summary rather than queueing a backlog.

When a gate stops it, there is no sound and no extra notification. The summary
is still saved, so `agent-say more` can play it later.

### "Want to hear more?"

`notify-send -A more="Tell me more"` with a 60 s wait. Clicking it, or running
`agent-say more` (bindable to a key later), speaks a longer explanation of the
last turn. The gates are checked again first. Nothing listens on the
microphone.

### Summaries

These come from Ollama on localhost (`qwen3:14b`, already pulled for
omarchy-voice), so there is no cloud call and no key. The prompt asks for
calm, plain speech, no code, paths, hashes or commands, and two or three
sentences ending with whether anything needs you. If Ollama is down, it stays
silent (we don't read raw text aloud).

## Alternatives rejected

- **Editing the three agent modules directly:** that spreads one feature
  over three files, and disabling it would mean editing all three. One module
  that plugs in from outside can be switched off with one line.
- **A home-manager-only module:** Claude Code's hooks live in the NixOS
  managed settings, and `/etc/agent-say/config.json` belongs to the system.
  A NixOS module reaches both, and reaches home-manager through
  `sharedModules`.
- **A long-running systemd user service:** nothing needs to run between
  turns. A transient unit per turn gives the same logging with zero idle
  cost.
- **A separate GitHub repo / standalone tool:** worth it only to share. It
  adds a flake input and release overhead for ~200 lines used on two hosts.
  If it proves useful, upstreaming it as `omarchy-voice narrate` into
  nixarchy-voice is the natural home, not a third repo.
- **Port codex-voice-agent:** it is Codex-only, uses an always-open
  realtime mic and OpenAI's voice, and is a bar plugin. That is the opposite
  of "not intrusive".
- **Speak through the omarchy-voice daemon (`listen say`):** that runs text
  as a voice *command* through its planner, not plain speech.
- **Shell script + `spd-say`:** a robotic voice, which fails "calm".
- **Summaries via `claude -p`:** slower, uses the subscription on every
  turn, and a hook would recurse into itself.
- **Spoken yes/no for "more":** needs an open mic after every turn.

## Risks

- **Speaking when it must not:** this is the one that matters. Every gate
  fails closed, and tests cover each gate's error path. The residual risk is
  a meeting app that opens the mic only while you talk; the DND gate covers
  that if you set DND for meetings.
- **The mic gate is too eager:** something else may hold the mic
  permanently (a `parecord` stream is uncorked on p620 right now, source
  unknown), which would make the narrator never speak. The plan identifies it
  before wiring the gate; if it is legitimate, it is excluded by name.
- **The ElevenLabs key outside the daemon:** omarchy-voice reads it from
  keyring/env inside its user service. A hook process may not see it, so it
  falls back to Piper (it still works, but less calm). The plan checks it.
- **agy end-of-turn event:** only `PreToolUse` has been probed. If agy has no
  end-of-turn hook, agy is left out and the PR says so. A failing agy hook
  blocks every agy call, and `hooks.json` syncs to p510, so the entry is
  shell-gated (`command -v agent-say || exit 0`) and always exits 0.
- **Codex hooks trust:** an untrusted `hooks.json` hook is silently skipped
  (memory: codex-hook-trust-fails-open). `codex-cli.nix` already handles the
  trust hash, so this reuses that path.
- Hosts: p620 and razer only. p510 is untouched except through the synced
  `~/.gemini` file, which the gate makes a no-op there.

## Verification

- `pytest pkgs/agent-say`: each gate is tested both ways, including DND
  `on`/error/timeout, unreadable `quiet.json`, a mic in use, and a delegated
  env. Each must result in "silent".
- `just test-host p620` and `just test-host razer` build; with `enable = false` the host closure has no agent-say and no hook entries.
- `nix eval` of `/etc/agent-say/config.json` matches the options.
- On p620, live with DND **on**: finish a Claude turn over 60 s. Expected:
  no sound and one `held dnd` log line.
- DND **off**: the same turn is spoken in two or three sentences and a "Tell
  me more" notification appears; clicking it speaks the long version.
- During a Meet call with DND off: silent (`held mic`).
- Repeat one turn each in Codex and agy.
