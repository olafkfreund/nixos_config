# nixarchy-meetingai: meeting copilot. A user daemon records and transcribes
# calls with Parakeet in-process (or Deepgram), answers questions with the AI
# subscriptions (Claude, Antigravity, OpenCode, Codex) or Ollama, and writes
# notes; the Omarchy shell plugin nixarchy.meetingai is its overlay and bar
# widget. Ollama Cloud and Deepgram read the agenix secrets api-ollama and
# api-deepgram. The echo-cancelled mic needs one PipeWire restart (or login).
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
      deepgram.keyFile = "/run/agenix/api-deepgram";
      # Each finished meeting is written here as Markdown (notes, transcript,
      # screenshots, interview documents); plain files in the Obsidian vault.
      settings.exportFolder = "/home/olafkfreund/Documents/Synechron/Meetings";
    };
  };
}
