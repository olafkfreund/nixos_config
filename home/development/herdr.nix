# herdr — terminal workspace manager for AI coding agents (agent multiplexer).
#
# The binary comes from the flake input (see overlays/default.nix) and is
# installed on the interactive hosts only (Users/olafkfreund/profile.nix).
# This module owns its config so p620 and razer stay identical; ~/.config/herdr
# is NOT syncthing-managed (only ~/.claude and ~/.gemini are), so without this
# razer would run on stock defaults.
#
# Every option below was taken from `herdr --default-config` — the schema
# embedded in the installed binary. Do NOT copy config from herdr.dev/docs:
# that site documents the master branch and disagrees with 0.7.5 on ~12 keys
# (`herdr config check` rejects the documented `keys.split_right` outright).
# Validate any change with:
#   HERDR_CONFIG_PATH=<file> herdr config check   # must print "config: ok"
#
# Trade-off: herdr's in-app settings UI (prefix+s) and `herdr config reset-keys`
# cannot write to a Nix store symlink. Config changes go through this file.
# Only config.toml is a symlink — herdr still owns the directory for its
# sockets, logs, session.json and .plugins.lock.
_: {
  xdg.configFile."herdr/config.toml".text = ''
    onboarding = false

    # The binary is read-only in /nix/store and tracked by the flake input.
    # Left enabled, herdr polls herdr.dev 48x/day and offers to install a
    # binary that the next deploy would silently revert — the same collision
    # the Claude Code self-updater caused in #936. Bump with:
    #   nix flake update herdr
    [update]
    version_check = false
    # Agent-detection manifest only; writes no binary, keeps Claude/codex
    # state detection current between herdr releases.
    manifest_check = true

    [theme]
    name = "gruvbox"
    auto_switch = false

    # "herdr" delivery only draws a toast while herdr is on screen, so an agent
    # blocked on a question goes unnoticed. "system" hands it to the desktop
    # notification service instead.
    [ui.toast]
    delivery = "system"
    delay_seconds = 1

    [ui.sound]
    enabled = true

    [ui]
    show_agent_labels_on_pane_borders = true
    # "priority" orders the agent panel as an attention queue, so a blocked
    # agent surfaces above idle ones instead of sorting by workspace.
    agent_panel_sort = "priority"

    # Space rows carry git context, which is what distinguishes one worktree
    # workspace from another at a glance.
    [ui.sidebar.spaces]
    rows = [["state_icon", "workspace"], ["branch", "git_status"]]

    # Claude panes get an extra row showing the stripped terminal title, which
    # is where Claude Code reports what it is currently doing.
    #
    # $agents is a pane-metadata token published by the managed-scope
    # PreToolUse/PostToolUse hooks in modules/programs/claude-code-managed.nix.
    # Claude Code's Task subagents run in-process with no PTY, so herdr can
    # never show them as their own agent rows (it detects one agent per pane).
    # This surfaces the live count on the parent row instead. The token is
    # cleared at zero, so the row stays clean when nothing is fanned out.
    [ui.sidebar.agents.rows_by_agent]
    claude = [["state_icon", "workspace", "tab"], ["terminal_title_stripped"], ["agent", "$agents"]]

    [worktrees]
    directory = "~/.herdr/worktrees"

    # Only bindings that are unset in 0.7.5 defaults are added here, so nothing
    # upstream is shadowed. Checked against: goto=prefix+g, close_tab=
    # prefix+shift+x, close_pane=prefix+x, settings=prefix+s, detach=prefix+q.
    [keys]
    previous_workspace = "prefix+["
    next_workspace = "prefix+]"
    open_worktree = "prefix+shift+o"

    [[keys.command]]
    key = "prefix+alt+g"
    type = "popup"
    command = "lazygit"
    width = "90%"
    height = "90%"

    # Claude Code emits far more output than the 10MB default retains.
    [advanced]
    scrollback_limit_bytes = 50000000

    # Keeps pane screens across herdr server restarts.
    [experimental]
    pane_history = true
  '';
}
