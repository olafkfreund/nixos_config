# Sideyard: lets an MCP agent (Claude Code, Codex, ...) drive this Omarchy
# desktop -- screenshots, keyboard, mouse, windows, clipboard and the AT-SPI
# accessibility tree -- behind a visible switch.
#
# Off at every login (the state lives in $XDG_RUNTIME_DIR). While an agent
# has control the bar shows a red AGENT CONTROL indicator; clicking it, or
# SUPER+SHIFT+ESCAPE, revokes control and releases any key the agent holds.
# There is no sandbox: with control on, the agent can do what you can.
#
# The module installs `sideyard`, registers the bar plugin through
# programs.nixarchy.plugins (validated at build), writes
# ~/.config/hypr/sideyard-binds.lua, and turns on GTK/Qt accessibility.
#
# Two one-time steps per machine that a rebuild cannot do, because both files
# are user-owned (same caveat as omarchy-gog.nix / omarchy-meet-binds.nix):
#   1. add to ~/.config/hypr/bindings.lua:  pcall(require, "hypr.sideyard-binds")
#      A bare require of a missing file fails the WHOLE Hyprland config.
#   2. omarchy plugin enable hoppcx.sideyard --section right
#      (nixarchy installs plugins but leaves enabling to the shell config).
# Then connect an agent:  claude mcp add sideyard -- sideyard mcp
{ inputs, ... }:
{
  home-manager.users.olafkfreund = {
    imports = [ inputs.sideyard.homeManagerModules.default ];
    programs.sideyard.enable = true;
  };
}
