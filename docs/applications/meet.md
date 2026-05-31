# Meeting transcription (`meet`)

> Shipped: 2026-05-31 (PR [#699](https://github.com/olafkfreund/nixos_config/pull/699), closes #698)
> Module: [`modules/services/meeting-transcribe.nix`](https://github.com/olafkfreund/nixos_config/blob/main/modules/services/meeting-transcribe.nix)
> Status: deployed on `razer` (client) and `p620` (client + processor)

## Overview

One-button meeting recording, transcription, and AI summarization. Press
`SUPER+SHIFT+M` to start recording mic + system audio; press again to stop.
~2–5 minutes later a desktop notification announces a markdown brief at
`~/meetings/YYYY-MM-DD-HHMM.md` containing:

- **TL;DR** — 2–3 sentence summary
- **🎯 Your action items** — `- [ ]` checkboxes assigned to you (Ollama
  separates "you" from other speakers using context)
- **📋 Action items (others)** — assigned to other speakers
- **🔑 Key decisions**
- **❓ Open questions**
- **🚩 Flagged moments** — timestamped mentions of configurable keywords
  (default: `blocker, deadline, urgent, incident, risk, escalate`)
- **🗺️ Topic timeline** — meeting carved into 3–7 segments
- **👥 Participants** — diarized speakers with talk-time % estimates
- **📜 Full transcript** — diarized when a HuggingFace token is configured

All processing runs on the user's own hardware — no SaaS, no audio leaves
the local network.

## Pipeline

```text
record  ──▶  transcribe              ──▶  summarize          ──▶  render
ffmpeg       whisperX large-v3            ollama mistral          bash + jq
+ pulse      + pyannote diarize           format=json             checkboxes
~1 MB/min    ~10x realtime (16C CPU)      ~30s for 1h transcript  instant
```

1. **Record** — `ffmpeg` with two PulseAudio inputs (mic + monitor of
   default sink), mixed via `amix`, encoded to 16 kHz mono Opus at
   24 kbps. Detached via `setsid + nohup` so it survives the keybind
   shell exiting. `SIGINT` on stop, 5-second poll, `SIGKILL` fallback.
2. **Transcribe** — `whisperX` (`pkgs.whisperx` 3.8.5) on CPU,
   `int8` quantized. Diarization via
   `pyannote/speaker-diarization-3.1` when HF token is available.
3. **Summarize** — Ollama (`mistral-small3.1`) via `/api/chat` with
   `format: "json"` and a strict schema embedded in the user prompt.
4. **Render** — bash + `jq` queries pull the JSON apart and emit the
   markdown brief.

## Topology

Two roles, both configured by the same module option:

| Host  | Role                | `processHost`  | `installProcessor` |
| ----- | ------------------- | -------------- | ------------------ |
| razer | Client only         | `"p620"`       | `false`            |
| p620  | Client + processor  | `"local"`      | `true`             |

razer records locally and offloads heavy work to p620 over Tailscale SSH
(rsync up → `ssh meet-process` → rsync brief back). p620 records AND
processes locally. The same `meet` CLI runs on both; behaviour is
determined at runtime by `cfg.processHost`.

## Configuration

### Client-only host (razer)

```nix
features.meetingTranscribe = {
  enable = true;
  processHost = "p620";        # SSH-reachable host where meet-process lives
  installProcessor = false;
  userName = "Olaf";
  userEmail = "olaf@freundcloud.com";
};
```

### Client + processor host (p620)

```nix
age.secrets = lib.mkIf (builtins.pathExists ../../secrets/api-huggingface.age) {
  api-huggingface.file = ../../secrets/api-huggingface.age;
};
features.meetingTranscribe = {
  enable = true;
  processHost = "local";
  installProcessor = true;
  huggingfaceTokenFile =
    if builtins.pathExists ../../secrets/api-huggingface.age
    then config.age.secrets."api-huggingface".path
    else null;
  ollamaUrl = "http://localhost:11434";
  userName = "Olaf";
  userEmail = "olaf@freundcloud.com";
};
```

### Available options

| Option                  | Type                  | Default                | Notes |
| ----------------------- | --------------------- | ---------------------- | ----- |
| `enable`                | bool                  | `false`                | Installs the `meet` CLI on this host. |
| `processHost`           | string                | `"local"`              | `"local"` runs whisperX + Ollama here. Anything else is an SSH host name. |
| `installProcessor`      | bool                  | `false`                | Installs whisperX + `meet-process`. Must be `true` if `processHost = "local"`. |
| `huggingfaceTokenFile`  | path or null          | `null`                 | Path to HF token file. Required on processor for diarization; gracefully degrades when missing. |
| `ollamaUrl`             | string                | `"http://p620:11434"`  | Ollama API base URL. Override to `http://localhost:11434` on p620. |
| `ollamaModel`           | string                | `"mistral-small3.1"`   | Must be pulled on the Ollama host. |
| `whisperModel`          | string                | `"large-v3"`           | One of `tiny`, `base`, `small`, `medium`, `large-v3`. |
| `language`              | string                | `"en"`                 | e.g. `en`, `no`, `da`. |
| `outputDir`             | string                | `"~/meetings"`         | Per-user; tilde expanded at runtime. |
| `userName`              | string                | _required_             | Helps Ollama identify "you" in the transcript. |
| `userEmail`             | string                | _required_             | Same. |
| `flagKeywords`          | list of string        | `[ "blocker" "deadline" "urgent" "incident" "risk" "escalate" ]` | Timestamped into the Flagged section. |

## Setup

### One-time, after first deploy

For diarization, you need a HuggingFace account + accepted EULAs on two
pyannote models. **The pipeline works without this — it just falls back
to plain transcription with no speaker labels.**

1. Sign up at [huggingface.co/join](https://huggingface.co/join).
2. Accept the terms on:
   - [`pyannote/speaker-diarization-3.1`](https://huggingface.co/pyannote/speaker-diarization-3.1)
   - [`pyannote/segmentation-3.0`](https://huggingface.co/pyannote/segmentation-3.0)
3. Generate a read token at
   [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens).
4. Add it to agenix on a machine that has the user key:

   ```bash
   ./scripts/manage-secrets.sh edit api-huggingface
   # paste the real token, save, exit
   ```

5. Deploy:

   ```bash
   just quick-deploy p620
   ```

### Recipients

The HF token is encrypted to `allUsers ++ [ p620 ]` — only p620 needs it
at runtime; razer never sees it.

## Usage

### Commands

```bash
meet start      # Start recording mic + system audio
meet stop       # Stop recording, dispatch transcription, return immediately
meet toggle     # Start if idle, stop if recording (used by the keybind)
meet status     # Show current recording state (PID, elapsed time)
meet process F  # Process an existing audio file F
meet help       # Show subcommands
```

### Keybind

`SUPER+SHIFT+M` is wired in `home/desktop/gnome/keybindings.nix`
(slot `custom5`):

```nix
"org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5" = {
  binding = "<Super><Shift>m";
  command = "meet toggle";
  name = "Meeting record/transcribe/summarize";
};
```

Verify after deploy:

```bash
gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings
```

Should list `custom0/` through `custom5/`.

### Per-user state

Recording state (PID, start timestamp, audio path) lives in
`$XDG_RUNTIME_DIR/meet/` — auto-cleaned on logout, so no stale state
across sessions.

## Troubleshooting

### "pactl unavailable" on start

`pulseaudio` package must be installed (the module includes it). Confirm
with `pactl info`. On NixOS with `services.pipewire.pulse.enable = true`
the binary comes from `pipewire-pulse`.

### Recording is empty / silent

Default sink might not have a monitor. Check:

```bash
pactl list sources short | grep monitor
```

You should see `${default_sink}.monitor`. If not, your default sink is
something exotic (e.g. a hardware loopback) — switch the default and
retry.

### whisperX hangs at "pyannote/speaker-diarization-3.1"

The HF token file is missing or the EULAs aren't accepted. Either:

- Accept both pyannote models' EULAs and add the token, OR
- Remove `huggingfaceTokenFile` from the module config — the pipeline
  will drop diarization and produce a plain transcript.

### "Remote processing failed" on razer

p620 isn't reachable, or `meet-process` isn't installed there. Check:

```bash
ssh p620 'which meet-process'
ssh p620 'systemctl is-active ollama'
```

If `meet-process` is missing, p620 needs `installProcessor = true` and a
redeploy.

### Brief is empty or LLM returned invalid JSON

`meet-process` falls back to a transcript-only brief when Ollama returns
unparsable JSON. Logs are in the SSH-side `/tmp/meet-remote.log` (when
running remotely) or stderr (when running locally). The audio file is
kept on disk so you can retry with `meet process <file>`.

## Caveats

- **HuggingFace EULA dance** — three clicks across two models plus a
  token generation. One-time, but annoying.
- **CPU whisperX** — ~10× realtime on a 16-core CPU. A 1-hour meeting
  takes ~6 minutes to process. ROCm CTranslate2 wheels aren't yet in
  nixpkgs; when they land, switch with `--device rocm`.
- **Speaker-identity heuristic** — the LLM identifies which `SPEAKER_NN`
  is "you" using context (who others address by name, who hosts, etc.).
  Reliable for 5+ people; occasionally misfires in 1-on-1s.

## Related

- [Blog post: One-button meetings][blog-meet]
- [Voice input (`voice-input`)][voice-input-src] — sibling feature, push-to-talk
  dictation that types into the focused window.
- [whisper-server module][whisper-server-src] — the lightweight whisper.cpp HTTP
  server used by `voice-input` (different from whisperX, no diarization,
  optimized for short utterances).

[blog-meet]: https://www.freundcloud.com/blog/one-button-meetings/
[voice-input-src]: https://github.com/olafkfreund/nixos_config/blob/main/home/applications/voice-input.nix
[whisper-server-src]: https://github.com/olafkfreund/nixos_config/blob/main/modules/services/whisper-server.nix
