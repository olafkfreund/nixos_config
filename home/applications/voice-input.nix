# voice-input — hold-to-talk dictation that types into the focused window.
#
# UX: press SUPER+SHIFT+SPACE, speak, transcript types into the focused app
# via `wtype`. Works with any focused app — that includes claude-code,
# codex, antigravity, copilot in a terminal, plus your normal browser/editor
# windows.
#
# Three transcription backends, switchable per-host:
#
#   programs.voice-input.backend = "local";    # default — uses p620:9300
#   programs.voice-input.backend = "openai";   # OpenAI Whisper API
#   programs.voice-input.backend = "groq";     # Groq Whisper Large v3 (fast + cheap)
#
# For "openai" / "groq", set apiKeyFile to an agenix-decrypted path:
#
#   programs.voice-input = {
#     backend = "groq";
#     apiKeyFile = config.age.secrets."api-groq".path;
#   };
#
# How to add a Groq key (one-time):
#   1. Get a key at https://console.groq.com (free tier is plenty)
#   2. `./scripts/manage-secrets.sh create api-groq` and paste the key
#   3. Set backend = "groq" + apiKeyFile = ... in this user's home config
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.programs.voice-input;

  # Per-backend curl invocation differences.
  backendOf = backend: {
    local = {
      url = cfg.serverUrl;
      authArg = "";
      modelArg = "";
    };
    openai = {
      url = "https://api.openai.com/v1/audio/transcriptions";
      # API key read from file at runtime, NOT embedded in the store.
      authArg = ''-H "Authorization: Bearer $(cat ${toString cfg.apiKeyFile})"'';
      modelArg = ''-F "model=whisper-1"'';
    };
    groq = {
      url = "https://api.groq.com/openai/v1/audio/transcriptions";
      authArg = ''-H "Authorization: Bearer $(cat ${toString cfg.apiKeyFile})"'';
      modelArg = ''-F "model=whisper-large-v3"'';
    };
  }.${backend};

  b = backendOf cfg.backend;

  voiceInputScript = pkgs.writeShellApplication {
    name = "voice-input";
    runtimeInputs = with pkgs; [
      sox # mic recording with VAD
      curl
      libnotify # notify-send
      wtype # Wayland keyboard typing
      coreutils # mktemp, tr
    ];
    text = ''
      set -euo pipefail
      TMP=$(mktemp --suffix=.wav)
      trap 'rm -f "$TMP"' EXIT

      notify-send -t 1500 -a voice-input "🎙️ Listening" \
        "Speak now (auto-stops on silence) — backend: ${cfg.backend}"

      # VAD recording: 16 kHz mono is what Whisper expects.
      #   `silence 1 0.1 1%` : start when audio > 1% for 100 ms
      #   `1 2.0 1%`         : stop after 2 s of audio < 1%
      #   `trim 0 30`        : hard cap at 30 s
      sox -q -d -r 16000 -c 1 "$TMP" \
        silence 1 0.1 1% 1 2.0 1% trim 0 30 2>/dev/null

      # If the file is < 0.5 s, there was no real speech — bail.
      DUR_MS=$(sox --i -D "$TMP" 2>/dev/null | awk '{printf "%d", $1 * 1000}')
      if [ "''${DUR_MS:-0}" -lt 500 ]; then
        notify-send -t 1500 -a voice-input "🎙️ Voice input" "(no speech)"
        exit 0
      fi

      # POST to the configured backend.
      TEXT=$(curl -sS --max-time 20 \
        ${b.authArg} \
        ${b.modelArg} \
        -F "file=@$TMP" \
        -F "response_format=text" \
        -F "temperature=0" \
        "${b.url}" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

      if [ -z "''${TEXT:-}" ]; then
        notify-send -u critical -t 3000 -a voice-input "🎙️ Voice input failed" \
          "Empty response from ${cfg.backend}. ${
            if cfg.backend == "local"
            then "Check: systemctl status whisper-server on p620."
            else "Check API key + network."
          }"
        exit 1
      fi

      # Type into the focused window. 50 ms warm-up gives the focused widget
      # time to receive keystrokes cleanly after the notification dismisses.
      sleep 0.05
      wtype -- "$TEXT"
      notify-send -t 2000 -a voice-input "🎙️ Typed" "$TEXT"
    '';
  };
in
{
  options.programs.voice-input = {
    backend = lib.mkOption {
      type = lib.types.enum [ "local" "openai" "groq" ];
      default = "local";
      description = ''
        Transcription backend. `local` posts to a self-hosted whisper-server
        (default: p620:9300). `openai` and `groq` hit cloud APIs and require
        `apiKeyFile` to be set.

        Latency comparison (approximate, hold-to-talk dictation):
          local  (p620 CPU)         ~1.5-3 s
          openai (whisper-1)        ~500-800 ms
          groq   (whisper-large-v3) ~200-400 ms

        Cost per minute of speech:
          local  free
          openai $0.006
          groq   $0.000111
      '';
    };

    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://p620:9300/inference";
      description = ''
        URL of the local whisper-server. Only used when backend = "local".
      '';
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression ''config.age.secrets."api-groq".path'';
      description = ''
        Path to a file containing the API key. Required for backend =
        "openai" or "groq". Read at runtime, never embedded in the store.
      '';
    };

    hotkey = lib.mkOption {
      type = lib.types.str;
      default = "<Super><Shift>space";
      description = ''
        GNOME-format key combo. Default <Super><Shift>space is push-to-start
        (recording auto-stops on silence via sox VAD).
      '';
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.backend == "local" || cfg.apiKeyFile != null;
        message = ''
          programs.voice-input.backend = "${cfg.backend}" requires
          programs.voice-input.apiKeyFile to be set (e.g. an agenix-decrypted
          path like config.age.secrets."api-${cfg.backend}".path).
        '';
      }
    ];

    home.packages = [ voiceInputScript ];

    # GNOME custom keybinding — additive (home-manager merges dconf settings
    # across modules). Named slot "voice-input" avoids colliding with the
    # numeric custom0..N list in home/desktop/gnome/keybindings.nix.
    dconf.settings = {
      "org/gnome/settings-daemon/plugins/media-keys" = {
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voice-input/"
        ];
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voice-input" = {
        name = "Voice input (whisper → wtype, ${cfg.backend})";
        binding = cfg.hotkey;
        command = "${voiceInputScript}/bin/voice-input";
      };
    };
  };
}
