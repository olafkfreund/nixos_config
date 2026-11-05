# Agent voice (spoken turn summaries)

Last Updated: 2026-11-02

When a Claude Code, Codex or agy turn finishes, `agent-say` speaks a calm two- or
three-sentence summary in a narrator voice (Lily, via ElevenLabs with Piper
underneath, through omarchy-voice). It is enabled on **p620** and **razer**
via `features.agentVoice` in `modules/programs/agent-voice.nix`. p510 is a
headless media server and is not wanted.

p620 writes the summary with its local Ollama. razer runs no Ollama, so it uses
the **claude backend** (`summary.backend = "claude"`): `claude -p --model haiku`
writes the summary. On both hosts the ElevenLabs key comes from agenix through
`voice.elevenLabsKeyFile`, read at run time.

## How it works

1. The agent's Stop hook runs `agent-say hook <agent>`, which returns at once
   and starts the real work with `systemd-run --user`.
2. The last assistant message goes to local Ollama (`qwen3:14b`), which writes
   the summary. If Ollama fails, `agent-say` stays silent. It never reads raw
   agent text aloud.
3. After the silence gates pass, it speaks and shows a "Tell me more"
   notification. Clicking the notification itself, pressing Super+Alt+I, or running
   `agent-say more` speaks a longer
   version of about 45 seconds. The microphone is never used.

agy's hook is an `agent-say` entry the module merges into
`~/.gemini/config/hooks.json` (Syncthing-synced, so it is merged, never
replaced). Its command runs only where `agent-say` exists and always prints
`{}`, because agy blocks on a failing hook. agy sends no reply text, so the
reply is read from the last `PLANNER_RESPONSE` of its transcript. Setting
`agents.agy.enable = false` removes the entry.

Claude's hook is a managed Stop hook merged beside the existing ones. Codex's is
a managed hook too: the module appends a `[[hooks.Stop]]` block to
`/etc/codex/requirements.toml` and installs `/etc/codex/hooks/agent-say`.
Managed hooks are trusted by policy; an ordinary `~/.codex/hooks.json` hook is
silently skipped by Codex.

Every spoken text starts with its source, so concurrent sessions can be told
apart: "From Claude, `<session title>`." (the session's `ai-title`, else the
working folder) or "From Codex, `<folder>`." The notification title carries the
same label, and the long version repeats it.

## Enabling it

```nix
features.agentVoice.enable = true;
```

| Option | Default | Purpose |
| --- | --- | --- |
| `enable` | `false` | Install the hooks and config |
| `agents.claude.enable` | `true` | Hook Claude Code's Stop event |
| `agents.codex.enable` | `true` | Hook Codex's Stop event |
| `agents.agy.enable` | `true` | Hook agy's Stop event |
| `summary.backend` | `ollama` | `ollama` or `claude` (`claude -p`) |
| `summary.claudeModel` | `haiku` | Model for the claude backend |
| `voice.elevenLabsKeyFile` | `null` | Key file read at run time when `ELEVENLABS_API_KEY` is unset. When set, the narrator uses ElevenLabs with it, ignoring the keyring and omarchy-voice's `elevenlabs.enabled` |
| `voice.elevenLabsVoiceId` | Lily | Narrator voice |
| `summary.ollamaUrl` | `http://127.0.0.1:11434` | Where the summary is written |
| `summary.model` | `qwen3:14b` | Summary model |
| `speaker` | `agent-say` | `agent-say` speaks with its own voice; `nixi` hands the summary to Nixi |
| `minTurnSeconds` | `60` | Shorter turns stay silent |
| `startEnabled` | `true` | Speak by default |
| `moreKey` | `SUPER + ALT + I` | Key that speaks the long version of the last turn; `""` disables |
| `toggleKey` | `SUPER + SHIFT + ALT + V` | Key that toggles spoken summaries on/off; `""` disables |
| `microphoneGate.enable` | `true` | Stay silent while a call is capturing the mic |
| `microphoneGate.ignore` | Echo-Cancel Capture/Sink, `parecord` | Streams that do not count as a call |

It needs `programs.omarchy-voice.enable` for the user (checked by an
assertion). Settings render to `/etc/agent-say/config.json`.

## Working with Nixi

With `speaker = "nixi"`, `agent-say` still owns the hooks, the summary and the
silence checks. It hands the whole summary to Nixi once and exits. Nixi owns the
queue, each sentence, stopping and replay, and speaks in his own voice.

- The old voice is used only when Nixi isn't running at all. If he's running but
  hidden, in Do Not Disturb, quiet, in a call or a meeting, or his voice is
  unavailable (cap reached), the summary is silent or stays as text. It is never
  spoken in another voice, and never twice.
- Click, Space or Esc while he speaks a summary stops only the speech. It doesn't
  stop the agent's work or open the mic.
- Settings → Voice has a mute switch per agent (Claude, Codex, agy). A muted
  agent's summary isn't even written.
- Replay keeps the last 5 summaries in Nixi's memory only: they are lost when he
  restarts, and nothing is saved to disk.
- "Tell me more" (the `moreKey`) speaks the long version through Nixi too.
- `speaker = "agent-say"` is the way back, with no other change.

## When it stays silent

Every gate fails closed and is checked again right before each sound.

- **Runtime switch:** `agent-say off` mutes it until `agent-say on`; the
  `toggleKey` flips it.
- **Do not disturb:** if the Omarchy shell reports DND on, or its state is
  unreadable, it is silent.
- **Snooze and quiet state:** a global notification snooze still running, or any
  "silenced" state, keeps it silent. An empty quiet-state file stops holding it
  silent after 5 seconds.
- **Microphone:** an application capturing the mic (outside the ignore list)
  keeps it silent. A failing `pactl` also does.
- **Delegated or scripted runs:** only sessions you start speak. Coder
  agents, agent-team sessions (their tmux socket is `claude-swarm-…`),
  `claude -p`, `codex exec` and an agy started by Claude (`CLAUDECODE` set)
  stay silent.
- **Short turns:** under `minTurnSeconds`.
- **Busy:** one narration at a time; a second is dropped.

**DND and snooze cannot be turned off by any option.** Meeting mode turns DND on
during calls, so calls are covered too.

## Turning it on and off

SUPER + SHIFT + ALT + V toggles spoken summaries and shows a notification
("Agent voice on" or "Agent voice off"). Press Super+K and search "voice" to
find the key.

The CLI does the same:

```bash
agent-say toggle   # flip and print the new state
agent-say on
agent-say off
agent-say status
```

The switch survives reboots. `startEnabled = false` starts muted, and
`enable = false` removes the hooks. To check that a new key is free, run
`hyprctl binds -j`.

## Commands

| Command | Effect |
| --- | --- |
| `agent-say on` / `off` | Unmute / mute at runtime |
| `agent-say toggle` | Flip the runtime switch and show the new state |
| `agent-say status` | Print `on` or `off` for the runtime switch (not the other gates) |
| `agent-say more` | Speak the long version of the last turn |

## Logs

```bash
journalctl --user -t agent-say
```

Each silent outcome logs one line, `held <gate>`. The summary text is logged;
the full reply never is.
