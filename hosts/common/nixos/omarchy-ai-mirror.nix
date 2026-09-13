# ai-mirror: lets an MCP agent (Claude Code, Codex, ...) drive this Omarchy
# desktop -- screenshots, keyboard, mouse, windows, clipboard and the AT-SPI
# accessibility tree -- behind a visible switch.
#
# Off at every login (the state lives in $XDG_RUNTIME_DIR). While an agent
# has control the bar shows a red AGENT CONTROL indicator; clicking it, or
# SUPER+SHIFT+ESCAPE, revokes control and releases any key the agent holds.
# There is no sandbox: with control on, the agent can do what you can.
#
# The module installs `ai-mirror`, registers the bar plugin through
# programs.nixarchy.plugins (validated at build), writes
# ~/.config/hypr/ai-mirror-binds.lua, and turns on GTK/Qt accessibility.
#
# Two one-time steps per machine that a rebuild cannot do, because both files
# are user-owned (same caveat as omarchy-gog.nix / omarchy-meet-binds.nix):
#   1. add to ~/.config/hypr/bindings.lua:  pcall(require, "hypr.ai-mirror-binds")
#      A bare require of a missing file fails the WHOLE Hyprland config.
#   2. omarchy plugin enable olafkfreund.ai-mirror --section right
#      (nixarchy installs plugins but leaves enabling to the shell config).
# Then connect an agent:  claude mcp add ai-mirror -- ai-mirror mcp
{ inputs, ... }:
{
  home-manager.users.olafkfreund = {
    imports = [ inputs.ai-mirror.homeManagerModules.default ];
    programs.ai-mirror.enable = true;
  };
}
