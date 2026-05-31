# meeting-transcribe — one-button meeting recording + transcription + summary.
#
# UX: SUPER+SHIFT+M to start, again to stop. After stop, a background job
# transcribes (whisperX + diarization) and summarizes (Ollama, mistral-small3.1)
# the audio. ~2-5 min later, notify-send fires with a markdown brief at
# ~/meetings/YYYY-MM-DD-HHMM.md containing TL;DR, your action items, decisions,
# flagged keywords, topic timeline, and the full diarized transcript.
#
# Topology: razer records locally + offloads heavy work to p620 over Tailscale
# SSH. p620 records AND processes locally. Per-host wiring:
#
#   # razer  (client only)
#   features.meetingTranscribe = {
#     enable = true;
#     processHost = "p620";
#     installProcessor = false;
#     userName = "Olaf";
#     userEmail = "olaf@freundcloud.com";
#   };
#
#   # p620  (client + processor)
#   features.meetingTranscribe = {
#     enable = true;
#     processHost = "local";
#     installProcessor = true;
#     huggingfaceTokenFile = config.age.secrets."api-huggingface".path;
#     ollamaUrl = "http://localhost:11434";
#     userName = "Olaf";
#     userEmail = "olaf@freundcloud.com";
#   };
#
# Setup (one-time, post-deploy on p620):
#   1. Sign up at https://huggingface.co/join (free).
#   2. Accept terms at https://huggingface.co/pyannote/speaker-diarization-3.1
#      (and the dependency https://huggingface.co/pyannote/segmentation-3.0).
#   3. Create a read token at https://huggingface.co/settings/tokens.
#   4. ./scripts/manage-secrets.sh create api-huggingface  (paste token).
#   5. just quick-deploy p620 && just quick-deploy razer.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.features.meetingTranscribe;

  # Local vs remote processing dispatch. "local" means run whisperx + ollama
  # on the same host as the recording. Any other value is treated as an SSH
  # host name (typically a Tailscale node).
  processLocal = cfg.processHost == "local";

  flagKeywordsCsv = lib.concatStringsSep "," cfg.flagKeywords;

  meet = pkgs.writeShellApplication {
    name = "meet";
    runtimeInputs = with pkgs; [
      ffmpeg-headless # record + mix mic & monitor → opus in one process
      pulseaudio # pactl: get-default-{sink,source} (pipewire-pulse compat)
      libnotify # notify-send
      coreutils
      jq
      curl
      openssh
      rsync
      gawk
      util-linux # setsid: detach ffmpeg from the parent so it survives the keybind shell exiting
    ];
    text = ''
      set -euo pipefail

      # ---- config (substituted at build time) ----
      # Only vars actually used by the client wrapper live here. The
      # processing config (whisper/ollama/user/keywords) is baked into
      # `meet-process` on the processor host.
      OUTPUT_DIR="''${MEET_OUTPUT_DIR:-${cfg.outputDir}}"
      OUTPUT_DIR="''${OUTPUT_DIR/#\~/$HOME}"
      PROCESS_HOST=${lib.escapeShellArg cfg.processHost}

      # Per-user state. XDG_RUNTIME_DIR auto-cleans on logout — no stale PIDs.
      STATE_DIR="''${XDG_RUNTIME_DIR:-/tmp}/meet"
      mkdir -p "$STATE_DIR" "$OUTPUT_DIR"
      PID_FILE="$STATE_DIR/recording.pid"
      META_FILE="$STATE_DIR/recording.meta"

      cmd_status() {
        if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
          local started
          started=$(cut -d, -f1 < "$META_FILE")
          local elapsed=$(( $(date +%s) - started ))
          printf 'recording (pid %s, %d:%02d elapsed)\n' \
            "$(cat "$PID_FILE")" $((elapsed/60)) $((elapsed%60))
          return 0
        fi
        echo "idle"
        return 1
      }

      cmd_start() {
        if cmd_status >/dev/null 2>&1; then
          notify-send -t 2000 -a meet "🎙️ Already recording" "Run: meet stop"
          cmd_status
          return 0
        fi

        local ts default_sink default_source monitor audio_file pid
        ts=$(date +%Y-%m-%d-%H%M)
        audio_file="$OUTPUT_DIR/$ts.opus"

        if ! default_sink=$(pactl get-default-sink 2>/dev/null); then
          notify-send -u critical -t 4000 -a meet "🎙️ Recording failed" \
            "pactl unavailable — is PipeWire/pulse running?"
          return 1
        fi
        default_source=$(pactl get-default-source 2>/dev/null || echo "")
        monitor="''${default_sink}.monitor"

        # Two pulse inputs (mic + speaker monitor) mixed to one mono opus
        # stream. 16 kHz / 24 kbps is what Whisper expects and keeps files
        # at ~1 MB/min so a 2-hour meeting fits comfortably in memory.
        # setsid + nohup + closed stdio: ffmpeg survives the keybind shell
        # exiting and writes nothing back. SIGINT (sent by cmd_stop) makes
        # ffmpeg flush the opus trailer cleanly; SIGTERM would leave a
        # truncated file.
        setsid nohup ffmpeg -hide_banner -loglevel error -nostdin -y \
          -f pulse -i "$default_source" \
          -f pulse -i "$monitor" \
          -filter_complex "[0:a][1:a]amix=inputs=2:duration=longest:normalize=0" \
          -ac 1 -ar 16000 \
          -c:a libopus -b:a 24k -application voip \
          "$audio_file" \
          </dev/null >/dev/null 2>&1 &
        pid=$!
        disown "$pid" 2>/dev/null || true

        # Give ffmpeg a moment to open both pulse streams; bail if it died.
        sleep 0.5
        if ! kill -0 "$pid" 2>/dev/null; then
          notify-send -u critical -t 4000 -a meet "🎙️ Recording failed" \
            "ffmpeg exited immediately — check 'pactl list sources short'"
          return 1
        fi

        printf '%s\n' "$pid" > "$PID_FILE"
        printf '%s,%s,%s\n' "$(date +%s)" "$audio_file" "$ts" > "$META_FILE"
        notify-send -t 2500 -a meet "🎙️ Recording" \
          "Started — toggle key again to stop ($ts)"
      }

      cmd_stop() {
        if ! cmd_status >/dev/null 2>&1; then
          notify-send -t 2000 -a meet "🎙️ Not recording" "Run: meet start"
          return 1
        fi

        local pid started audio_file ts dur_sec
        pid=$(cat "$PID_FILE")
        IFS=, read -r started audio_file ts < "$META_FILE"

        kill -INT "$pid" 2>/dev/null || true
        # ffmpeg needs a beat to flush the opus trailer. Poll up to 5 s.
        for _ in 1 2 3 4 5 6 7 8 9 10; do
          kill -0 "$pid" 2>/dev/null || break
          sleep 0.5
        done
        kill -KILL "$pid" 2>/dev/null || true
        rm -f "$PID_FILE" "$META_FILE"

        if [[ ! -s "$audio_file" ]]; then
          notify-send -u critical -a meet "🎙️ Recording failed" \
            "$audio_file is empty or missing."
          return 1
        fi

        dur_sec=$(( $(date +%s) - started ))
        local size_kb
        size_kb=$(du -k "$audio_file" | awk '{print $1}')
        notify-send -t 4000 -a meet "🎙️ Recording stopped" \
          "$(printf '%d:%02d' $((dur_sec/60)) $((dur_sec%60))) — ''${size_kb} KB — processing..."

        # Detached processing — return control to the keybind shell immediately.
        # The processor pipeline is implemented in cmd_process (steps 5-6).
        setsid nohup "$0" process "$audio_file" </dev/null >/dev/null 2>&1 &
        disown $! 2>/dev/null || true
      }

      cmd_toggle() {
        if cmd_status >/dev/null 2>&1; then cmd_stop; else cmd_start; fi
      }

      cmd_process() {
        local audio_file="''${1:-}"
        if [[ -z "$audio_file" || ! -f "$audio_file" ]]; then
          echo "meet process: audio file required (got: '$audio_file')" >&2
          return 2
        fi

        local md_file="''${audio_file%.opus}.md"

        # Local mode: this host has whisperX + meet-process installed.
        if [[ "$PROCESS_HOST" == "local" ]]; then
          if ! meet-process "$audio_file"; then
            notify-send -u critical -t 6000 -a meet "🎙️ Processing failed" \
              "See logs. Audio kept at: $audio_file"
            return 1
          fi
          notify-send -t 8000 -a meet "🎙️ Meeting brief ready" "$md_file"
          return 0
        fi

        # Remote mode: rsync up, exec, rsync down. Same absolute path on
        # both sides — assumes matching user/home (true for olafkfreund
        # on razer + p620).
        local remote="$PROCESS_HOST"
        local remote_dir
        remote_dir=$(dirname "$audio_file")

        notify-send -t 3000 -a meet "🎙️ Uploading to $remote" \
          "$(basename "$audio_file")"

        if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$remote" \
             "mkdir -p ''${remote_dir@Q}" 2>/dev/null; then
          notify-send -u critical -t 6000 -a meet "🎙️ $remote unreachable" \
            "SSH failed. Audio kept locally: $audio_file"
          return 1
        fi

        if ! rsync -aq "$audio_file" "$remote:$audio_file"; then
          notify-send -u critical -t 6000 -a meet "🎙️ Upload failed" \
            "rsync to $remote failed. Audio kept locally: $audio_file"
          return 1
        fi

        notify-send -t 3000 -a meet "🎙️ Processing on $remote" \
          "whisperX + ollama — please wait..."

        if ! ssh -o BatchMode=yes "$remote" \
             "meet-process ''${audio_file@Q}" 2>/tmp/meet-remote.log; then
          notify-send -u critical -t 8000 -a meet "🎙️ Remote processing failed" \
            "See /tmp/meet-remote.log. Audio kept at $remote:$audio_file"
          return 1
        fi

        if ! rsync -aq "$remote:$md_file" "$md_file"; then
          notify-send -u critical -t 6000 -a meet "🎙️ Download failed" \
            "Brief produced on $remote but rsync back failed."
          return 1
        fi

        ssh -o BatchMode=yes "$remote" \
          "rm -f ''${audio_file@Q} ''${md_file@Q}" 2>/dev/null || true

        notify-send -t 10000 -a meet "🎙️ Meeting brief ready" "$md_file"
      }

      cmd_help() {
        cat <<EOF
      meet — one-button meeting recording + transcription + summary

      Usage:
        meet start      Start recording mic + system audio
        meet stop       Stop recording and dispatch transcription
        meet toggle     Start if idle, stop if recording (for keybind)
        meet status     Show current recording state
        meet process F  Process an existing audio file F
        meet help       This message

      Output:          $OUTPUT_DIR/YYYY-MM-DD-HHMM.{opus,md}
      Processing on:   $PROCESS_HOST
      EOF
      }

      case "''${1:-help}" in
        start)   cmd_start "$@" ;;
        stop)    cmd_stop "$@" ;;
        toggle)  cmd_toggle "$@" ;;
        status)  cmd_status "$@" ;;
        process) shift; cmd_process "$@" ;;
        help|-h|--help) cmd_help ;;
        *) echo "unknown subcommand: $1" >&2; cmd_help; exit 2 ;;
      esac
    '';
  };

  # Processor-side helper. Runs on the host where whisperX + Ollama live.
  # Takes an .opus path and writes a .md alongside it.
  #
  # The HF token path is substituted at build time; the script checks at
  # runtime whether the file exists/is readable and falls back to plain
  # transcription (no diarization) if not.
  hfTokenPath =
    if cfg.huggingfaceTokenFile != null
    then toString cfg.huggingfaceTokenFile
    else "";

  meetProcess = pkgs.writeShellApplication {
    name = "meet-process";
    runtimeInputs = with pkgs; [
      whisperx
      jq
      curl
      coreutils
      gawk
    ];
    text = ''
      set -euo pipefail

      AUDIO_FILE="''${1:-}"
      if [[ -z "$AUDIO_FILE" || ! -f "$AUDIO_FILE" ]]; then
        echo "meet-process: usage: meet-process <audio.opus>" >&2
        exit 2
      fi

      OUTPUT_DIR=$(dirname "$AUDIO_FILE")
      BASE=$(basename "$AUDIO_FILE" .opus)
      JSON_FILE="$OUTPUT_DIR/$BASE.json"
      MD_FILE="$OUTPUT_DIR/$BASE.md"

      WHISPER_MODEL=${lib.escapeShellArg cfg.whisperModel}
      LANGUAGE=${lib.escapeShellArg cfg.language}
      OLLAMA_URL=${lib.escapeShellArg cfg.ollamaUrl}
      OLLAMA_MODEL=${lib.escapeShellArg cfg.ollamaModel}
      USER_NAME=${lib.escapeShellArg cfg.userName}
      USER_EMAIL=${lib.escapeShellArg cfg.userEmail}
      FLAG_KEYWORDS=${lib.escapeShellArg flagKeywordsCsv}
      HF_TOKEN_PATH=${lib.escapeShellArg hfTokenPath}

      # Diarization is opt-in: needs a readable HF token file and an
      # accepted pyannote model license. Missing token → plain transcript.
      DIARIZE_ARGS=()
      if [[ -n "$HF_TOKEN_PATH" && -r "$HF_TOKEN_PATH" ]]; then
        HF_TOKEN=$(tr -d '[:space:]' < "$HF_TOKEN_PATH")
        if [[ -n "$HF_TOKEN" ]]; then
          DIARIZE_ARGS=(--diarize --hf_token "$HF_TOKEN")
        fi
      fi

      echo "meet-process: transcribing $AUDIO_FILE (model=$WHISPER_MODEL, diarize=''${#DIARIZE_ARGS[@]})" >&2

      # whisperX writes <BASE>.json into --output_dir. CPU device is the
      # safe default on AMD (ROCm wheels for CTranslate2 are not yet in
      # nixpkgs); 16-core Threadripper still gets ~10x realtime on large-v3.
      whisperx \
        --model "$WHISPER_MODEL" \
        --language "$LANGUAGE" \
        --device cpu \
        --compute_type int8 \
        --output_dir "$OUTPUT_DIR" \
        --output_format json \
        "''${DIARIZE_ARGS[@]}" \
        "$AUDIO_FILE" >&2

      if [[ ! -s "$JSON_FILE" ]]; then
        echo "meet-process: whisperX produced no JSON at $JSON_FILE" >&2
        exit 1
      fi

      # Build a plain-text transcript for the LLM. Format:
      #   [MM:SS] SPEAKER_00: <text>
      # whisperx omits .speaker when diarization is off.
      TRANSCRIPT_TXT=$(jq -r '
        .segments[]
        | (.start | floor) as $s
        | "[\($s/60|floor):\($s%60|tostring|("00"+.)[-2:])]\(if .speaker then " \(.speaker):" else "" end) \(.text|gsub("^[[:space:]]+|[[:space:]]+$"; ""))"
      ' "$JSON_FILE")

      if [[ -z "$TRANSCRIPT_TXT" ]]; then
        echo "meet-process: empty transcript — skipping summary" >&2
        cp "$JSON_FILE" "$MD_FILE"  # leave the raw JSON visible for debugging
        exit 1
      fi

      SYSTEM_PROMPT="You are an expert meeting analyst. Extract structured information from a diarized meeting transcript and return ONLY valid JSON matching the provided schema. Never invent facts not stated in the transcript. If a section has no entries, return an empty array — never omit a field."

      USER_PROMPT=$(cat <<PROMPT
      The user is $USER_NAME ($USER_EMAIL). The transcript below uses speaker
      labels like SPEAKER_00. One of those speakers IS the user; identify
      which one from context (who others address by name, who hosts the
      meeting, who takes notes, who matches the user's role). Use that to
      separate the user's own action items from others'.

      Return a JSON object with EXACTLY these fields:
      {
        "user_speaker_label": "SPEAKER_XX or null if unclear",
        "tldr": "2-3 sentence summary of the meeting",
        "your_action_items": [
          {"task": "...", "deadline": "string or null", "context": "string or null"}
        ],
        "other_action_items": [
          {"assignee": "SPEAKER_XX or name", "task": "...", "deadline": "string or null"}
        ],
        "key_decisions": ["string", ...],
        "open_questions": ["string", ...],
        "flagged_moments": [
          {"timestamp": "MM:SS", "speaker": "SPEAKER_XX", "keyword": "...", "context": "one-line quote or paraphrase"}
        ],
        "topic_timeline": [
          {"start": "MM:SS", "end": "MM:SS", "topic": "short label"}
        ],
        "participants": [
          {"label": "SPEAKER_XX", "likely_identity": "name or role guess or null", "talk_time_pct": 0}
        ]
      }

      Rules:
      - your_action_items: things the user committed to or was asked to do.
      - other_action_items: things explicitly assigned to other speakers.
      - flagged_moments: timestamped mentions of these keywords (case-insensitive): $FLAG_KEYWORDS
      - topic_timeline: 3-7 segments covering the whole meeting.
      - talk_time_pct: rough estimate based on segment durations, should sum to ~100.

      Transcript:
      ---
      $TRANSCRIPT_TXT
      ---
      PROMPT
      )

      # Build the chat request via jq so quoting/escaping is bulletproof.
      REQUEST=$(jq -n \
        --arg model "$OLLAMA_MODEL" \
        --arg system "$SYSTEM_PROMPT" \
        --arg user "$USER_PROMPT" \
        '{
          model: $model,
          stream: false,
          format: "json",
          options: { temperature: 0.2, num_ctx: 32768 },
          messages: [
            { role: "system", content: $system },
            { role: "user",   content: $user }
          ]
        }')

      echo "meet-process: calling ollama ($OLLAMA_MODEL @ $OLLAMA_URL)" >&2
      RESPONSE=$(curl -sS --max-time 600 \
        -H 'Content-Type: application/json' \
        -d "$REQUEST" \
        "$OLLAMA_URL/api/chat") || {
          echo "meet-process: ollama call failed" >&2
          exit 1
        }

      SUMMARY_JSON=$(jq -r '.message.content // empty' <<<"$RESPONSE")
      if [[ -z "$SUMMARY_JSON" ]]; then
        echo "meet-process: empty ollama response: $RESPONSE" >&2
        exit 1
      fi

      # Verify the LLM returned parseable JSON; on failure, still write the
      # transcript so the recording isn't lost.
      if ! jq empty <<<"$SUMMARY_JSON" 2>/dev/null; then
        echo "meet-process: ollama returned invalid JSON, falling back to transcript-only" >&2
        {
          echo "# Meeting: $BASE"
          echo ""
          echo "_Ollama returned invalid JSON — transcript-only fallback._"
          echo ""
          echo "## Full transcript"
          echo ""
          echo "$TRANSCRIPT_TXT"
        } > "$MD_FILE"
        exit 0
      fi

      # Render the markdown brief. All field access uses // [] fallbacks
      # so partial summaries still render rather than erroring out.
      DATE_PART="''${BASE%-*}"
      TIME_PART="''${BASE##*-}"
      MEETING_DATE=$(date -d "$DATE_PART ''${TIME_PART:0:2}:''${TIME_PART:2:2}" '+%A, %d %b %Y %H:%M' 2>/dev/null || echo "$BASE")
      DURATION_SEC=$(jq -r '.segments | last | .end | floor' "$JSON_FILE" 2>/dev/null || echo 0)
      DURATION_FMT=$(printf '%d min %d sec' $((DURATION_SEC/60)) $((DURATION_SEC%60)))

      {
        echo "# Meeting: $MEETING_DATE"
        echo ""
        echo "**Duration:** $DURATION_FMT  •  **Source:** \`$(basename "$AUDIO_FILE")\`"
        echo ""

        echo "## TL;DR"
        echo ""
        jq -r '.tldr // "_(no summary)_"' <<<"$SUMMARY_JSON"
        echo ""

        echo "## 🎯 Your action items"
        echo ""
        N=$(jq '.your_action_items // [] | length' <<<"$SUMMARY_JSON")
        if [[ "$N" -eq 0 ]]; then
          echo "_None._"
        else
          jq -r '.your_action_items[] | "- [ ] \(.task)\(if .deadline then "  _(\(.deadline))_" else "" end)\(if .context then "  \n  _\(.context)_" else "" end)"' <<<"$SUMMARY_JSON"
        fi
        echo ""

        echo "## 📋 Action items (others)"
        echo ""
        N=$(jq '.other_action_items // [] | length' <<<"$SUMMARY_JSON")
        if [[ "$N" -eq 0 ]]; then
          echo "_None._"
        else
          jq -r '.other_action_items[] | "- [ ] **\(.assignee):** \(.task)\(if .deadline then "  _(\(.deadline))_" else "" end)"' <<<"$SUMMARY_JSON"
        fi
        echo ""

        echo "## 🔑 Key decisions"
        echo ""
        N=$(jq '.key_decisions // [] | length' <<<"$SUMMARY_JSON")
        if [[ "$N" -eq 0 ]]; then
          echo "_None recorded._"
        else
          jq -r '.key_decisions[] | "- \(.)"' <<<"$SUMMARY_JSON"
        fi
        echo ""

        echo "## ❓ Open questions"
        echo ""
        N=$(jq '.open_questions // [] | length' <<<"$SUMMARY_JSON")
        if [[ "$N" -eq 0 ]]; then
          echo "_None._"
        else
          jq -r '.open_questions[] | "- \(.)"' <<<"$SUMMARY_JSON"
        fi
        echo ""

        echo "## 🚩 Flagged ($FLAG_KEYWORDS)"
        echo ""
        N=$(jq '.flagged_moments // [] | length' <<<"$SUMMARY_JSON")
        if [[ "$N" -eq 0 ]]; then
          echo "_No flagged moments._"
        else
          jq -r '.flagged_moments[] | "- \(.timestamp) **\(.speaker)** [\(.keyword)] — \(.context)"' <<<"$SUMMARY_JSON"
        fi
        echo ""

        echo "## 🗺️ Topic timeline"
        echo ""
        N=$(jq '.topic_timeline // [] | length' <<<"$SUMMARY_JSON")
        if [[ "$N" -eq 0 ]]; then
          echo "_Not segmented._"
        else
          jq -r '.topic_timeline[] | "- \(.start)–\(.end)  \(.topic)"' <<<"$SUMMARY_JSON"
        fi
        echo ""

        echo "## 👥 Participants"
        echo ""
        USER_LABEL=$(jq -r '.user_speaker_label // "unknown"' <<<"$SUMMARY_JSON")
        N=$(jq '.participants // [] | length' <<<"$SUMMARY_JSON")
        if [[ "$N" -eq 0 ]]; then
          echo "_No diarization data._"
        else
          jq -r --arg you "$USER_LABEL" --arg name "$USER_NAME" '
            .participants[]
            | "- **\(.label)**\(if .label == $you then " (likely \($name))" elif .likely_identity then " — \(.likely_identity)" else "" end) — ~\(.talk_time_pct)% talk time"
          ' <<<"$SUMMARY_JSON"
        fi
        echo ""

        echo "---"
        echo ""
        echo "## 📜 Full transcript"
        echo ""
        echo '```'
        echo "$TRANSCRIPT_TXT"
        echo '```'
      } > "$MD_FILE"

      echo "meet-process: brief written to $MD_FILE" >&2
    '';
  };
in
{
  options.features.meetingTranscribe = {
    enable = lib.mkEnableOption "Meeting recording, transcription, and summarization";

    processHost = lib.mkOption {
      type = lib.types.str;
      default = "local";
      example = "p620";
      description = ''
        Where transcription + summarization runs. "local" means same host
        (requires installProcessor = true). Otherwise an SSH-reachable host
        name (typically a Tailscale node) where the processor is installed.
      '';
    };

    installProcessor = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install processor-side dependencies (whisperX, meet-process helper).
        Set true on the host that runs the heavy lifting (typically p620).
      '';
    };

    huggingfaceTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression ''config.age.secrets."api-huggingface".path'';
      description = ''
        Path to a HuggingFace token file (required by whisperX for the
        pyannote diarization model). Required on the processor host. Read
        at runtime, never embedded in the store.
      '';
    };

    ollamaUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://p620:11434";
      description = ''
        Ollama API base URL for summarization. On p620, override to
        http://localhost:11434.
      '';
    };

    ollamaModel = lib.mkOption {
      type = lib.types.str;
      default = "mistral-small3.1";
      description = "Ollama model name for summarization (must be pulled on the host).";
    };

    whisperModel = lib.mkOption {
      type = lib.types.str;
      default = "large-v3";
      description = "whisperX model size: tiny | base | small | medium | large-v3.";
    };

    language = lib.mkOption {
      type = lib.types.str;
      default = "en";
      description = "Language code for whisperX (e.g. en, no, da).";
    };

    outputDir = lib.mkOption {
      type = lib.types.str;
      default = "~/meetings";
      description = "Where finished meeting briefs land (per-user; tilde expanded at runtime).";
    };

    userName = lib.mkOption {
      type = lib.types.str;
      example = "Olaf";
      description = ''
        Your display name. Used in the Ollama prompt to identify "your action
        items" vs others'.
      '';
    };

    userEmail = lib.mkOption {
      type = lib.types.str;
      example = "olaf@freundcloud.com";
      description = "Your email. Helps the LLM identify you in the transcript.";
    };

    flagKeywords = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "blocker" "deadline" "urgent" "incident" "risk" "escalate" ];
      description = "Keywords extracted with timestamps into the 'Flagged' section of the brief.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(processLocal && !cfg.installProcessor);
        message = ''
          features.meetingTranscribe.processHost = "local" requires
          installProcessor = true (whisperX must be installed locally).
        '';
      }
      # huggingfaceTokenFile is intentionally NOT required when
      # installProcessor = true: when it's null (or the file is missing
      # at runtime), the processor falls back to plain transcription
      # without speaker diarization. This lets the feature ship and work
      # end-to-end before the HF account/token is set up.
    ];

    environment.systemPackages =
      [ meet ]
      ++ lib.optionals cfg.installProcessor [ meetProcess ];
  };
}
