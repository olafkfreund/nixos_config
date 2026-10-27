# nixarchy-meetingai: meeting copilot. A user daemon records and transcribes
# calls with a local whisper.cpp server, answers questions with the AI
# subscriptions (Claude, Antigravity, OpenCode, Codex) or Ollama, and writes
# notes; the Omarchy shell plugin nixarchy.meetingai is its overlay and bar
# widget. Ollama Cloud reads the existing agenix secret api-ollama.
#
# One-time steps per machine (both files are user-owned):
#   omarchy plugin enable nixarchy.meetingai --section right
#   add `pcall(require, "hypr.meetingai-binds")` to ~/.config/hypr/bindings.lua
{ inputs, ... }:
{
  home-manager.users.olafkfreund = {
    imports = [ inputs.nixarchy-meetingai.homeManagerModules.default ];
    programs.nixarchy-meetingai = {
      enable = true;
      ollamaCloud.keyFile = "/run/agenix/api-ollama";
    };
  };
}
