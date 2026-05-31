# voice-input — hold-to-talk dictation that types into the focused window.
#
# How it works: GNOME custom keybind (SUPER+SHIFT+SPACE by default) runs the
# `voice-input` script. The script:
#   1. Notifies "Listening…"
#   2. Records mic via sox with VAD: starts when sound > 1%, auto-stops after
#      2 s of silence, hard cap 30 s.
#   3. POSTs the .wav to whisper-server (running on p620 over the tailnet).
#   4. Types the returned transcript into the focused window via `wtype`.
#
# Works with any focused app — that includes claude-code, codex, antigravity,
# copilot in a terminal, plus your normal browser/editor windows.
#
# To rebind the hotkey, edit `binding` below.
{ pkgs, ... }:
let
  # Default whisper-server endpoint — Tailscale Magic DNS resolves `p620`.
  serverUrl = "http://p620:9300/inference";

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

      notify-send -t 1500 -a voice-input "🎙️ Listening" "Speak now (auto-stops on silence)"

      # VAD recording: 16 kHz mono is what Whisper wants.
      #   `silence 1 0.1 1%` : start when audio > 1% for 100 ms
      #   `1 2.0 1%`         : stop after 2 s of audio < 1%
      #   `trim 0 30`        : hard cap at 30 s
      # Errors to /dev/null because sox is chatty about VAD on stderr.
      sox -q -d -r 16000 -c 1 "$TMP" \
        silence 1 0.1 1% 1 2.0 1% trim 0 30 2>/dev/null

      # If the file is < 0.5 s, there was no real speech — bail.
      DUR_MS=$(sox --i -D "$TMP" 2>/dev/null | awk '{printf "%d", $1 * 1000}')
      if [ "''${DUR_MS:-0}" -lt 500 ]; then
        notify-send -t 1500 -a voice-input "🎙️ Voice input" "(no speech)"
        exit 0
      fi

      TEXT=$(curl -sS --max-time 20 \
        -F "file=@$TMP" \
        -F "response_format=text" \
        -F "temperature=0" \
        "${serverUrl}" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

      if [ -z "''${TEXT:-}" ]; then
        notify-send -u critical -t 3000 -a voice-input "🎙️ Voice input failed" \
          "Empty response from whisper-server. Check: systemctl status whisper-server on p620."
        exit 1
      fi

      # Type into the focused window. wtype handles Wayland natively under
      # GNOME 45+. A 50 ms warm-up gives the focused widget time to receive
      # the keystroke stream cleanly after the notification dismisses.
      sleep 0.05
      wtype -- "$TEXT"
      notify-send -t 2000 -a voice-input "🎙️ Typed" "$TEXT"
    '';
  };
in
{
  home.packages = [ voiceInputScript ];

  # GNOME custom keybinding — additive to the existing list (home-manager
  # merges dconf settings across modules). The slot identifier here
  # ("voice-input") deliberately uses a name rather than a custom<N> index
  # so it can't collide with the numeric slots in home/desktop/gnome/keybindings.nix.
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
      name = "Voice input (whisper → wtype)";
      binding = "<Super><Shift>space";
      command = "${voiceInputScript}/bin/voice-input";
    };
  };
}
