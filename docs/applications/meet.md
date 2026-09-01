# Meeting transcription (`meet`)

> Module: [`modules/services/meeting-transcribe.nix`](https://github.com/olafkfreund/nixos_config/blob/main/modules/services/meeting-transcribe.nix)
> Enabled on: `razer` (client), `p620` (client + processor). Not on `p510`.
> Shipped 2026-05-31, PR [#699](https://github.com/olafkfreund/nixos_config/pull/699).

## Overview

One-button meeting recording, transcription, and AI summarization. Start a
recording of mic + system audio, stop it, and two to five minutes later a
desktop notification announces a markdown brief at
`~/meetings/YYYY-MM-DD-HHMM.md` with these sections:

- TL;DR, two to three sentences
- Your action items, `- [ ]` checkboxes assigned to you (Ollama separates
  "you" from other speakers using context)
- Action items (others)
- Key decisions
- Open questions
- Flagged, timestamped mentions of configurable keywords (default:
  `blocker, deadline, urgent, incident, risk, escalate`)
- Topic timeline, the meeting carved into three to seven segments
- Participants, diarized speakers with talk-time percentage estimates
- Full transcript, diarized when a HuggingFace token is configured

All processing runs on your own hardware. No audio leaves the local network.

## Pipeline

```text
record  ──▶  transcribe              ──▶  summarize          ──▶  render
ffmpeg       whisperX large-v3            ollama               bash + jq
+ pulse      + pyannote diarize           format=json          checkboxes
~1 MB/min    ~10x realtime (16C CPU)      ~30s for 1h          instant
```

1. **Record** — `ffmpeg` with two PulseAudio inputs (mic + monitor of the
   default sink), mixed via `amix`, encoded to 16 kHz mono Opus at 24 kbps.
   Detached with `setsid` + `nohup` so it survives the calling shell exiting.
   `SIGINT` on stop, five-second poll, `SIGKILL` fallback.
2. **Transcribe** — `whisperX` (`pkgs.whisperx`, currently 3.8.6) on CPU,
   `int8` quantized. Diarization via `pyannote/speaker-diarization-3.1` when a
   HF token is available.
3. **Summarize** — Ollama via `/api/chat` with `format: "json"` and a strict
   schema embedded in the prompt.
4. **Render** — bash and `jq` pull the JSON apart and emit the markdown brief.

## Topology

Two roles, both selected by the same module option:

| Host  | Role               | `processHost` | `installProcessor` |
| ----- | ------------------ | ------------- | ------------------ |
| razer | Client only        | `"p620"`      | `false`            |
| p620  | Client + processor | `"local"`     | `true`             |

razer records locally and offloads the heavy work to p620 over Tailscale SSH
(rsync up, `ssh meet-process`, rsync the brief back). p620 records and
processes locally. The same `meet` CLI runs on both; behaviour is decided at
runtime by `cfg.processHost`.

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

| Option                 | Type           | Default               | Notes |
| ---------------------- | -------------- | --------------------- | ----- |
| `enable`               | bool           | `false`               | Installs the `meet` CLI on this host. |
| `processHost`          | string         | `"local"`             | `"local"` runs whisperX and Ollama here. Anything else is an SSH host name. |
| `installProcessor`     | bool           | `false`               | Installs whisperX and `meet-process`. Must be `true` when `processHost = "local"`. |
| `huggingfaceTokenFile` | path or null   | `null`                | Path to an HF token file. Needed on the processor for diarization; degrades gracefully when missing. |
| `ollamaUrl`            | string         | `"http://p620:11434"` | Ollama API base URL. Set to `http://localhost:11434` on p620. |
| `ollamaModel`          | string         | `"mistral-small3.1"`  | Must already be pulled on the Ollama host. See the caveat below. |
| `whisperModel`         | string         | `"large-v3"`          | One of `tiny`, `base`, `small`, `medium`, `large-v3`. |
| `language`             | string         | `"en"`                | For example `en`, `no`, `da`. |
| `outputDir`            | string         | `"~/meetings"`        | Per-user; the tilde is expanded at runtime. |
| `userName`             | string         | required              | Helps Ollama identify "you" in the transcript. |
| `userEmail`            | string         | required              | Same. |
| `flagKeywords`         | list of string | `[ "blocker" "deadline" "urgent" "incident" "risk" "escalate" ]` | Timestamped into the Flagged section. |

## Setup

### The summarization model must be pulled

`ollamaModel` defaults to `mistral-small3.1`, which is **not currently pulled
on p620** — `ollama list` there has no mistral at all. Until it is, Ollama
returns a model-not-found error and `meet-process` falls back to a
transcript-only brief with no TL;DR, action items or decisions. Either pull it:

```bash
ssh p620 'ollama pull mistral-small3.1'
```

or point the option at a model p620 already has (`qwen3:14b`, `gemma4:12b`,
`qwen3.8:27b`).

### HuggingFace token, for diarization

Diarization needs a HuggingFace account and accepted EULAs on two pyannote
models. The pipeline works without this; it just falls back to a plain
transcript with no speaker labels.

1. Sign up at [huggingface.co/join](https://huggingface.co/join).
2. Accept the terms on
   [`pyannote/speaker-diarization-3.1`](https://huggingface.co/pyannote/speaker-diarization-3.1)
   and
   [`pyannote/segmentation-3.0`](https://huggingface.co/pyannote/segmentation-3.0).
3. Generate a read token at
   [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens).
4. Store it in agenix from a machine that has the user key:

   ```bash
   ./scripts/manage-secrets.sh edit api-huggingface
   ```

5. Deploy: `just quick-deploy p620`.

`secrets/api-huggingface.age` exists in the repo and is encrypted to
`allUsers ++ [ p620 ]` — only p620 needs it at runtime, razer never sees it.

## Usage

### Commands

```bash
meet start      # Start recording mic + system audio
meet stop       # Stop recording, dispatch transcription, return immediately
meet toggle     # Start if idle, stop if recording
meet status     # Show current recording state (PID, elapsed time)
meet process F  # Process an existing audio file F
meet help       # Show subcommands
```

### Keybind: GNOME session only

`SUPER+SHIFT+M` is wired in `home/desktop/gnome/keybindings.nix` (slot
`custom5`) and therefore only works in a GNOME session:

```nix
"org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5" = {
  binding = "<Super><Shift>m";
  command = "meet toggle";
  name = "Meeting record/transcribe/summarize";
};
```

The default session on every host is Omarchy on Hyprland, which has **no
binding for `meet`**. In that session use the CLI (`meet toggle`) directly, or
add a binding to `~/.config/hypr/bindings.lua`.

Verify the GNOME binding after a deploy:

```bash
gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings
```

It should list `custom0/` through `custom5/`.

### Per-user state

Recording state (PID, start timestamp, audio path) lives in
`$XDG_RUNTIME_DIR/meet/`, which is cleaned on logout, so no stale state
survives a session.

## Troubleshooting

### "pactl unavailable" on start

The `pulseaudio` package must be present; the module includes it. Confirm with
`pactl info`. With `services.pipewire.pulse.enable = true` the binary comes
from `pipewire-pulse`.

### Recording is empty or silent

The default sink may have no monitor source:

```bash
pactl list sources short | grep monitor
```

You should see `${default_sink}.monitor`. If not, the default sink is
something unusual (a hardware loopback, say) — switch the default and retry.

### whisperX hangs on `pyannote/speaker-diarization-3.1`

The HF token file is missing or the EULAs are not accepted. Either accept both
models' EULAs and add the token, or drop `huggingfaceTokenFile` from the host
config and accept a plain, non-diarized transcript.

### Brief has a transcript but no summary

Ollama could not answer. Most likely the configured `ollamaModel` is not
pulled on the Ollama host; see the setup section above. Check with:

```bash
ssh p620 'ollama list'
```

### "Remote processing failed" on razer

p620 is unreachable, or `meet-process` is not installed there:

```bash
ssh p620 'which meet-process'
ssh p620 'systemctl is-active ollama'
```

If `meet-process` is missing, p620 needs `installProcessor = true` and a
redeploy.

### Invalid JSON from the LLM

`meet-process` falls back to a transcript-only brief when Ollama returns
unparsable JSON. Logs are in `/tmp/meet-remote.log` on the processor when
running remotely, or on stderr when running locally. The audio file is kept on
disk, so retry with `meet process <file>`.

## Caveats

- **Summarization is currently inert on p620** — the default model is not
  pulled. Fix it before relying on the briefs.
- **No Hyprland keybind** — the one-button promise only holds in GNOME today.
- **HuggingFace EULA dance** — three clicks across two models plus a token, one
  time, but tedious.
- **CPU whisperX** — roughly 10x realtime on a 16-core CPU, so a one-hour
  meeting takes about six minutes. ROCm CTranslate2 wheels are not in nixpkgs
  yet; when they land, switch with `--device rocm`.
- **Speaker-identity heuristic** — the LLM works out which `SPEAKER_NN` is
  "you" from context (who is addressed by name, who hosts). Reliable with five
  or more people, occasionally wrong in one-on-ones.

## Related

- [Blog post: One-button meetings][blog-meet]
- [`voice-input`][voice-input-src] — sibling feature, push-to-talk dictation
  that types into the focused window.
- [whisper-server module][whisper-server-src] — the whisper.cpp HTTP server
  used by `voice-input`. Different from whisperX: no diarization, tuned for
  short utterances.

[blog-meet]: https://www.freundcloud.com/blog/one-button-meetings/
[voice-input-src]: https://github.com/olafkfreund/nixos_config/blob/main/home/applications/voice-input.nix
[whisper-server-src]: https://github.com/olafkfreund/nixos_config/blob/main/modules/services/whisper-server.nix
