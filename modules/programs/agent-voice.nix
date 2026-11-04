{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.features.agentVoice;
  hmVoice = config.home-manager.users.olafkfreund.programs.omarchy-voice;

  # Managed hook commands must sit under /etc/codex/hooks.
  agyHookEntry = (pkgs.formats.json { }).generate "agent-say-agy-hook.json" {
    agent-say.Stop = [{
      type = "command";
      # agy blocks on a failing hook and wants one JSON object on stdout; the
      # guard makes the synced hooks.json a no-op on hosts without agent-say.
      command = "sh -c 'command -v agent-say >/dev/null && agent-say hook agy; echo \"{}\"'";
      timeout = 10;
    }];
  };

  codexHook = pkgs.writeShellScript "agent-say-codex" ''
    exec ${cfg.package}/bin/agent-say hook codex
  '';
in
{
  options.features.agentVoice = {
    enable = mkEnableOption "spoken summaries when Claude Code or Codex finishes a turn";

    package = mkOption {
      type = types.package;
      default = pkgs.customPkgs.agent-say.override { omarchyVoice = hmVoice.package; };
      defaultText = literalExpression "pkgs.customPkgs.agent-say.override { omarchyVoice = <omarchy-voice package>; }";
      description = "agent-say, built on omarchy-voice's Python.";
    };

    agents = {
      claude.enable = mkOption { type = types.bool; default = true; description = "Hook Claude Code's Stop event."; };
      codex.enable = mkOption { type = types.bool; default = true; description = "Hook Codex's Stop event (managed hook)."; };
      agy.enable = mkOption { type = types.bool; default = true; description = "Hook agy's Stop event (entry in ~/.gemini/config/hooks.json)."; };
    };

    voice.elevenLabsVoiceId = mkOption {
      type = types.str;
      default = "pFZP5JQG7iQjIQuC4Bku";
      description = "ElevenLabs voice for the narrator (Lily).";
    };

    voice.elevenLabsKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "File holding the ElevenLabs key, read at run time when ELEVENLABS_API_KEY is unset. When set, the narrator uses ElevenLabs with this key, ignoring the keyring and omarchy-voice's elevenlabs.enabled; if it cannot be read, those apply as usual.";
    };

    summary = {
      backend = mkOption { type = types.enum [ "ollama" "claude" ]; default = "ollama"; description = "What writes the summary: local Ollama, or `claude -p`."; };
      claudeModel = mkOption { type = types.str; default = "haiku"; description = "Model for the claude backend."; };
      ollamaUrl = mkOption { type = types.str; default = "http://127.0.0.1:11434"; description = "Ollama endpoint that writes the summary."; };
      model = mkOption { type = types.str; default = "qwen3:14b"; description = "Ollama model that writes the summary."; };
    };

    minTurnSeconds = mkOption { type = types.int; default = 60; description = "Turns shorter than this stay silent."; };
    startEnabled = mkOption { type = types.bool; default = true; description = "Speak by default; `agent-say off` mutes at runtime."; };

    moreKey = mkOption {
      type = types.str;
      default = "SUPER + ALT + I";
      description = "Hyprland key that speaks the long version of the last turn. Empty disables it.";
    };

    toggleKey = mkOption {
      type = types.str;
      default = "SUPER + SHIFT + ALT + V";
      description = "Hyprland key that toggles spoken summaries on/off. Empty disables it.";
    };

    microphoneGate = {
      enable = mkOption { type = types.bool; default = true; description = "Stay silent while an application is capturing the microphone."; };
      ignore = mkOption {
        type = types.listOf types.str;
        default = [ "Echo-Cancel Capture" "Echo-Cancel Sink" "parecord" ];
        description = "Capture streams (application.name, else media.name) that do not count as a call.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = hmVoice.enable;
      message = "features.agentVoice needs programs.omarchy-voice.enable for olafkfreund.";
    }];

    environment.systemPackages = [ cfg.package ];

    environment.etc."agent-say/config.json".text = builtins.toJSON {
      voiceId = cfg.voice.elevenLabsVoiceId;
      ollamaUrl = cfg.summary.ollamaUrl;
      inherit (cfg.summary) model backend claudeModel;
      elevenLabsKeyFile = cfg.voice.elevenLabsKeyFile;
      inherit (cfg) minTurnSeconds startEnabled;
      microphoneGate = { inherit (cfg.microphoneGate) enable ignore; };
    };

    modules.programs.claude-code-managed.settings.hooks.Stop = mkIf cfg.agents.claude.enable [
      { hooks = [{ type = "command"; command = "${cfg.package}/bin/agent-say hook claude"; timeout = 10; }]; }
    ];

    # A function so lib is Home Manager's (lib.hm.dag), not nixpkgs'.
    home-manager.users.olafkfreund = { lib, ... }: {
      home.file.".config/hypr/agent-voice-binds.lua" = mkIf (cfg.moreKey != "" || cfg.toggleKey != "") {
        text =
          optionalString (cfg.moreKey != "") ''
            o.bind("${cfg.moreKey}", "Agent voice: tell me more", "${cfg.package}/bin/agent-say more")
          ''
          + optionalString (cfg.toggleKey != "") ''
            o.bind("${cfg.toggleKey}", "Agent voice: toggle spoken summaries on/off", "${cfg.package}/bin/agent-say toggle")
          '';
      };

      # Append-only so the user's edits to bindings.lua stay theirs.
      home.activation.agentVoiceRequire = mkIf (cfg.moreKey != "" || cfg.toggleKey != "") (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        f="$HOME/.config/hypr/bindings.lua"
        if [ -f "$f" ] && ! grep -qF '"hypr.agent-voice-binds"' "$f"; then
          # The redirect lives inside run, so a dry run cannot append to the file.
          run ${pkgs.bash}/bin/bash -c 'printf "\n%s\n" "$2" >> "$1"' _ "$f" \
            'pcall(require, "hypr.agent-voice-binds") -- managed by NixOS (#2596)'
        fi
      '');

      # ~/.gemini is Syncthing-synced, so merge into hooks.json instead of
      # replacing it. Writes go through a temp file so a dry run publishes nothing.
      home.activation.agentVoiceAgyHook = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        hooksfile="$HOME/.gemini/config/hooks.json"
        jq=${pkgs.jq}/bin/jq
        if [ -f "$hooksfile" ] && $jq -e 'type == "object"' "$hooksfile" >/dev/null 2>&1; then
          ${if cfg.agents.agy.enable then ''
            if ! $jq -e --slurpfile want ${agyHookEntry} '."agent-say" == $want[0]."agent-say"' "$hooksfile" >/dev/null 2>&1; then
              tmp=$(mktemp)
              $jq -s '.[0] + .[1]' "$hooksfile" ${agyHookEntry} > "$tmp"
              $DRY_RUN_CMD mv "$tmp" "$hooksfile"
            fi
          '' else ''
            if $jq -e 'has("agent-say")' "$hooksfile" >/dev/null 2>&1; then
              tmp=$(mktemp)
              $jq 'del(."agent-say")' "$hooksfile" > "$tmp"
              $DRY_RUN_CMD mv "$tmp" "$hooksfile"
            fi
          ''}
        fi
      '';
    };

    environment.etc."codex/hooks/agent-say" = mkIf cfg.agents.codex.enable { source = codexHook; };
    environment.etc."codex/requirements.toml".text = mkIf cfg.agents.codex.enable (mkAfter ''

      [[hooks.Stop]]

      [[hooks.Stop.hooks]]
      type = "command"
      command = "/etc/codex/hooks/agent-say"
      timeout = 10
    '');
  };
}
