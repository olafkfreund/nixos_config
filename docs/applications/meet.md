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
| `ollamaModel`          | string         | `"gemma4:12b"`        | Must be declared in `features.ollama-server`; asserted at eval time when Ollama is local. |
| `whisperModel`         | string         | `"large-v3"`          | One of `tiny`, `base`, `small`, `medium`, `large-v3`. |
| `language`             | string         | `"en"`                | For example `en`, `no`, `da`. |
| `outputDir`            | string         | `"~/meetings"`        | Per-user; the tilde is expanded at runtime. |
| `userName`             | string         | required              | Helps Ollama identify "you" in the transcript. |
| `userEmail`            | string         | required              | Same. |
| `flagKeywords`         | list of string | `[ "blocker" "deadline" "urgent" "incident" "risk" "escalate" ]` | Timestamped into the Flagged section. |

## Setup

### The summarization model

`ollamaModel` defaults to `gemma4:12b`, chosen to fit rather than to be the
largest available. p620's card has 21.5 GB and `OLLAMA_CONTEXT_LENGTH` is
32768, so at 7.6 GB it loads fully onto the GPU (~51% VRAM) and leaves the
rest for the desktop.

`qwen3.8:27b` was tried first and is the wrong shape: 17 GB of weights plus
that KV cache overflows the card, Ollama splits it 88/12 GPU/CPU, VRAM hits
94% and **the desktop freezes for the whole run**. Both models return valid
JSON of equivalent quality here — this is extraction from a transcript, not
reasoning — so the larger one buys nothing and costs a usable machine.

`OLLAMA_KEEP_ALIVE` is 5m, so nothing stays resident between meetings: every
run pays a cold load, 24s for `gemma4:12b` against ~59s for `qwen3.8:27b`.
`persistentModels` only pre-pulls; it does not pin.

If you point it at a model the Ollama host does not declare, the build now
fails with an assertion naming the models that are available. Before, Ollama
returned a model-not-found error at runtime and `meet-process` quietly fell
back to a transcript-only brief; that failure was invisible.

The assertion can only check a local Ollama. With `processHost` set to a remote
host, make sure the model is pulled there yourself.

### HuggingFace token, for diarization

Diarization needs a HuggingFace account and accepted EULAs on two pyannote
models. The pipeline works without this; it just falls back to a plain
transcript with no speaker labels.

1. Sign up at [huggingface.co/join](https://huggingface.co/join).
2. Accept the terms on
   [`pyannote/speaker-diarization-community-1`](https://huggingface.co/pyannote/speaker-diarization-community-1).

   That is the model **whisperX 3.8.6 actually requests**. Earlier revisions
   of this page named `speaker-diarization-3.1` and `segmentation-3.0`;
   accepting those two leaves diarization failing with a 403
   `GatedRepoError`, because neither is the repo whisperX asks for.
3. Generate a read token at
   [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens).
4. Store it in agenix from a machine that has the user key:

   ```bash
   ./scripts/manage-secrets.sh edit api-huggingface
   ```

   **The secret must be owned by the user**, not root. `meet-process` runs as
   you and enables diarization only if `[[ -r /run/agenix/api-huggingface ]]`.
   agenix defaults to `root:root 0400`, so without an explicit `owner` that
   test fails *silently*: whisperX runs without `--diarize`, the transcript
   has no `SPEAKER_XX` labels, and the summarizer is then asked for
   `user_speaker_label` and `participants[].label` that cannot exist. That
   sent gemma4:12b into a generation loop until the 600 s curl timeout.

   ```nix
   api-huggingface = {
     file = ../../secrets/api-huggingface.age;
     owner = "olafkfreund";
     mode = "0400";
   };
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

### Keybind

`SUPER+SHIFT+M` toggles recording in **both** sessions:

| Session | Declared in |
| --- | --- |
| Omarchy (Hyprland) | `hosts/common/nixos/omarchy-meet-binds.nix` |
| GNOME | `home/desktop/gnome/keybindings.nix`, slot `custom5` |

The Omarchy binding ships as `~/.config/hypr/meet-binds.lua` and is loaded by
the user-owned `bindings.lua`, which needs this line once:

```lua
pcall(require, "hypr.meet-binds")
```

`pcall`, not a bare `require`: `bindings.lua` survives deploys untouched, so it
outlives any generation that stops providing the file — a rollback, or a host
that never enabled the feature. A bare `require` of a missing file fails the
whole Hyprland config and drops the session into the error overlay.

The module is guarded on `features.meetingTranscribe.enable`, so p510 imports
it without getting a binding for a binary it does not have.

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

### Diarization fails with a 403 `GatedRepoError`

The token is readable but the account has not been granted access to
`pyannote/speaker-diarization-community-1`. Accept the conditions there.

whisperX no longer dies on this: it retries without `--diarize`, so you still
get a transcript and a full summary — only the per-speaker attribution and the
Participants section are lost. A token that is present but unauthorized used
to be *worse* than no token at all, because whisperX aborted before producing
any transcript.

### Brief has a transcript but no summary

Ollama could not answer, and the brief says which of the three ways it failed:
the call timed out, the body came back empty (generation hit `num_predict`),
or the JSON could not be parsed. In every case the transcript is still written —
a recording is never lost.

Most likely causes, in order:

1. **Diarization is off**, so the transcript has no speaker labels and the
   model loops on the `SPEAKER_XX` fields. Check the token is readable *as
   your user*: `test -r /run/agenix/api-huggingface && echo ok`.
2. The configured `ollamaModel` is not pulled: `ssh p620 'ollama list'`.

Generation is capped at `num_predict: 4096`, so a runaway fails in well under
a minute rather than hanging for the full 600 s curl timeout.

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
