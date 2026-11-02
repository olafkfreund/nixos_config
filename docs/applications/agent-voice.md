# Agent voice (spoken turn summaries)

Last Updated: 2026-11-02

When a Claude Code or Codex turn finishes, `agent-say` speaks a calm two- or
three-sentence summary in a narrator voice (Lily, via ElevenLabs with Piper
underneath, through omarchy-voice). It is enabled on **p620** only, via
`features.agentVoice` in `modules/programs/agent-voice.nix`.

razer is deferred: it runs no Ollama and p620's Ollama is not reachable over
the tailnet, so the summary step could never succeed there. It follows in its
own change once a summary endpoint is chosen. p510 is a headless media server
and is not wanted.

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

Claude's hook is a managed Stop hook merged beside the existing ones. Codex's is
a managed hook too: the module appends a `[[hooks.Stop]]` block to
`/etc/codex/requirements.toml` and installs `/etc/codex/hooks/agent-say`.
Managed hooks are trusted by policy; an ordinary `~/.codex/hooks.json` hook is
silently skipped by Codex.

## Enabling it

```nix
features.agentVoice.enable = true;
```

| Option | Default | Purpose |
| --- | --- | --- |
| `enable` | `false` | Install the hooks and config |
| `agents.claude.enable` | `true` | Hook Claude Code's Stop event |
| `agents.codex.enable` | `true` | Hook Codex's Stop event |
| `voice.elevenLabsVoiceId` | Lily | Narrator voice |
| `summary.ollamaUrl` | `http://127.0.0.1:11434` | Where the summary is written |
| `summary.model` | `qwen3:14b` | Summary model |
| `minTurnSeconds` | `60` | Shorter turns stay silent |
| `startEnabled` | `true` | Speak by default |
| `moreKey` | `SUPER + ALT + I` | Key that speaks the long version of the last turn; `""` disables |
| `microphoneGate.enable` | `true` | Stay silent while a call is capturing the mic |
| `microphoneGate.ignore` | Echo-Cancel Capture/Sink, `parecord` | Streams that do not count as a call |

It needs `programs.omarchy-voice.enable` for the user (checked by an
assertion). Settings render to `/etc/agent-say/config.json`.

## When it stays silent

Every gate fails closed and is checked again right before each sound.

- **Runtime switch:** `agent-say off` mutes it until `agent-say on`.
- **Do not disturb:** if the Omarchy shell reports DND on, or its state is
  unreadable, it is silent.
- **Snooze and quiet state:** a global notification snooze still running, or any
  "silenced" state, keeps it silent.
- **Microphone:** an application capturing the mic (outside the ignore list)
  keeps it silent. A failing `pactl` also does.
- **Delegated or scripted runs:** coder agents, `claude -p` and `codex exec`
  never speak; only interactive sessions do.
- **Short turns:** under `minTurnSeconds`.
- **Busy:** one narration at a time; a second is dropped.

**DND and snooze cannot be turned off by any option.** Meeting mode turns DND on
during calls, so calls are covered too.

## Commands

| Command | Effect |
| --- | --- |
| `agent-say on` / `off` | Unmute / mute at runtime |
| `agent-say status` | Print `on` or `off` for the runtime switch (not the other gates) |
| `agent-say more` | Speak the long version of the last turn |

## Logs

```bash
journalctl --user -t agent-say
```

Each silent outcome logs one line, `held <gate>`. The summary text is logged;
the full reply never is.
