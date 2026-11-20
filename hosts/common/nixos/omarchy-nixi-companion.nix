# Nixi's snowflake desktop companion (nixarchy#1432), shared by p620 and razer.
# nixarchy supplies the package; this turns it on and gives it keys. The binds
# ride in their own lua file, loaded from the user-owned bindings.lua with
#   pcall(require, "hypr.nixi-companion-binds")
# pcall for the reason omarchy-gog.nix gives: bindings.lua outlives a
# generation that stops providing the file. SUPER+ALT+S is Omarchy's scratchpad (#2714).
{ inputs, pkgs, ... }:
{
  imports = [ ../../../modules/programs/nixi-agent-hooks.nix ];
  features.nixiAgentHooks.enable = true;

  home-manager.users.olafkfreund = {
    services.nixi.companion.enable = true;
    # A "done" note when a shell command of 30 s or more ends in a terminal you are not looking at (nixi#133).
    services.nixi.companion.commandDone.enable = true;

    # The same Nixi on every machine (nixoarchy-snowflake#99, #3076): shared
    # defaults, written as read-only shared files that Nixi and the bridge
    # layer under their own config. A change made on one machine stays there
    # as a visible override ("differs from your NixOS config", Use shared);
    # change it here to share it. The store is world-readable: no secrets,
    # private plugins or personal text. Devices, paths and other local keys
    # are refused by Nixi and stay per machine.
    services.nixi.settings = {
      trust = "mechanic";
      permissionMode = "yolo";
    };
    services.nixi.companion.settings = {
      agent_approvals = true;
      agent_voice_mute = [ "agy" "codex" "claude" ];
      ambient_calendar = true;
      ambient_weather = false;
      auto_compact = true;
      auto_model = "haiku";
      autostart = true;
      bar_edge = "top";
      barge_in = true;
      click_through = true;
      code_face = "him";
      code_panel = true;
      compact_at = 0.7;
      compact_tokens = 100000;
      effort = "medium";
      eleven_daily_chars = 50000;
      eleven_on = true;
      eleven_voice = "pFZP5JQG7iQjIQuC4Bku";
      espeak_voice = "en-us";
      eye_color = "#3e5993";
      eye_white = "#ffffff";
      follow_focus = true;
      follow_up = 4;
      full_text = true;
      hover = false;
      idle_mode = "doze";
      language = "en";
      lean = true;
      listen_on_show = false;
      live_minutes = 10;
      look = {
        body = "#161616";
        character = "robot";
        follow_theme = true;
        link = true;
        pupL = "#7daea3";
        pupR = "#7daea3";
        random = false;
        skin = "none";
        skinColor = "";
        whiteL = "#d4be98";
        whiteR = "#d4be98";
      };
      look_beat = true;
      look_coding = true;
      look_fullscreen = true;
      look_meeting = true;
      look_music = true;
      look_night = true;
      look_party = true;
      look_weather = true;
      mail_on = true;
      max_cost_usd = 3;
      mic_auto = true;
      model = "auto";
      news_watch = true;
      notifications_takeover = true;
      notify_details = true;
      notify_done = true;
      notify_speak = [ "meeting" "chat" "mail" "download" "video" ];
      notify_speak_subject = true;
      partial_messages = true;
      peers_on = true;
      phone_on = true;
      popup_done = true;
      presence = "orb";
      proactive = true;
      ptt_hotkey = "Ctrl+Alt+Space";
      pupil_style = "circle";
      react_break = true;
      react_load = true;
      react_quips = true;
      react_welcome = true;
      reactions = true;
      sfx = true;
      size = 0.75;
      speak_max_chars = 600;
      stt_prewarm = true;
      trust = "trust";
      tts = "elevenlabs";
      update_check = true;
      voice = "british";
      voice_by_character = { };
      wake_word = true;
      whisper_beam = 5;
      whisper_model = "base.en";
      # Nix-shipped plugins that start on (a local on/off still wins); "you"
      # stays a hand copy (private) and doctor says when it's missing.
      plugins_on = [ "news" "nix-status" "rss-headlines" ];
      private_plugins = [ "you" ];
      # Backup voices, pinned to piper-voices 0ca208a by sha256.
      voices = {
        en_GB-alan-medium = {
          onnx = "0a309668932205e762801f1efc2736cd4b0120329622adf62be09e56339d3330";
          json = "c0f0d124e5895c00e7c03b35dcc8287f319a6998a365b182deb5c8e752ee8c1e";
        };
        en_US-amy-medium = {
          onnx = "cf9ccdec59f05adee47173f6fb4d89e8b0c5f30c178748d2572fe4efd1d2724c";
          json = "27490c2197e3e7b566b051fc0b1dae21200e72b44c209731419effdbbe0789e5";
        };
        en_US-ryan-medium = {
          onnx = "33b53106e049f68a51f014e4fa10bf5a04e0f7d6668692dc05228cc4554c1d71";
          json = "d29061675e660113d51f81650e922134d94cab750271f9ce2bcb05121f925a60";
        };
      };
    };
    services.nixi.companion.plugins =
      with inputs.nixi-companion.legacyPackages.${pkgs.stdenv.hostPlatform.system}.examples; [
        news
        nix-status
        rss-headlines
      ];

    home.file.".config/hypr/nixi-companion-binds.lua".text = ''
      -- Managed by hosts/common/nixos/omarchy-nixi-companion.nix -- edits here
      -- are overwritten on the next deploy.
      o.bind("SUPER + ALT + H", "Nixi companion: show or hide", "nixi-companion")
      o.bind("SUPER + ALT + SHIFT + S", "Nixi companion: listen", "nixi-companion listen")
      -- size: SUPER+ALT+-/= are Omarchy's window nudges, so CTRL joins (keycodes, as Omarchy binds them: any layout)
      o.bind("SUPER + CTRL + ALT + code:21", "Nixi companion: bigger", "nixi-companion size up")
      o.bind("SUPER + CTRL + ALT + code:20", "Nixi companion: smaller", "nixi-companion size down")
      o.bind("SUPER + CTRL + ALT + code:19", "Nixi companion: normal size", "nixi-companion size reset")
      -- card text (nixoarchy-snowflake#109): the same keys with SHIFT
      o.bind("SUPER + CTRL + ALT + SHIFT + code:21", "Nixi companion: bigger card text", "nixi-companion text up")
      o.bind("SUPER + CTRL + ALT + SHIFT + code:20", "Nixi companion: smaller card text", "nixi-companion text down")
      o.bind("SUPER + CTRL + ALT + SHIFT + code:19", "Nixi companion: normal card text", "nixi-companion text reset")
      -- Start him with the session: activation only restarts a running one, so a fresh host never got him.
      o.exec_on_start("nixi-companion show")
    '';
  };
}
