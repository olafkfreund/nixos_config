{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.features.agentVoice;
  hmVoice = config.home-manager.users.olafkfreund.programs.omarchy-voice;

  # Managed hook commands must sit under /etc/codex/hooks.
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
    };

    voice.elevenLabsVoiceId = mkOption {
      type = types.str;
      default = "pFZP5JQG7iQjIQuC4Bku";
      description = "ElevenLabs voice for the narrator (Lily).";
    };

    summary = {
      ollamaUrl = mkOption { type = types.str; default = "http://127.0.0.1:11434"; description = "Ollama endpoint that writes the summary."; };
      model = mkOption { type = types.str; default = "qwen3:14b"; description = "Ollama model that writes the summary."; };
    };

    minTurnSeconds = mkOption { type = types.int; default = 60; description = "Turns shorter than this stay silent."; };
    startEnabled = mkOption { type = types.bool; default = true; description = "Speak by default; `agent-say off` mutes at runtime."; };

    microphoneGate = {
      enable = mkOption { type = types.bool; default = true; description = "Stay silent while an application is capturing the microphone."; };
      ignore = mkOption {
        type = types.listOf types.str;
        default = [ "Echo-Cancel Capture" "Echo-Cancel Sink" "parecord" ];
        description = "Capture streams (application.name) that do not count as a call.";
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
      inherit (cfg.summary) model;
      inherit (cfg) minTurnSeconds startEnabled;
      microphoneGate = { inherit (cfg.microphoneGate) enable ignore; };
    };

    modules.programs.claude-code-managed.settings.hooks.Stop = mkIf cfg.agents.claude.enable [
      { hooks = [{ type = "command"; command = "${cfg.package}/bin/agent-say hook claude"; timeout = 10; }]; }
    ];

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
