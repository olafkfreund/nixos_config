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

    # Alien HUD — the Weyland-Yutani propulsion-monitor look, same palette the
    # rest of the desktop wears (assets/themes/alien-hud.yaml, base16 for
    # Stylix). herdr has no theme-file loader, only `[theme.custom]` token
    # overrides on top of a built-in, so every one of the 17 palette fields in
    # `Palette` (src/app/state.rs) is pinned here and the base name below is
    # inert. Borders are always ratatui `Plain` (square corners, title in the
    # top rule) — no border-style knob exists, and square is what the plates
    # use anyway.
    [theme]
    name = "gruvbox"
    auto_switch = false

    # panel_bg = "reset" keeps the host terminal's background, so ghostty's
    # faint plate image still shows through herdr's panels instead of being
    # painted over with a flat fill. base00 is that same #0d1210 regardless.
    #
    # Tokens map to alien-hud.yaml except surface1 / subtext0, which are
    # interpolated: herdr wants four dim tiers (surface_dim < surface0 <
    # surface1, overlay0 < overlay1 < subtext0 < text) and base16 only
    # supplies three.
    [theme.custom]
    accent = "#8fd694"      # base0B phosphor green — active borders, highlights
    panel_bg = "reset"
    surface_dim = "#161d1a" # base01 — separators
    surface0 = "#1f2a25"    # base02 — selected row
    surface1 = "#2b3a32"    # interpolated — hover/active row
    overlay0 = "#3d4f45"    # base03 — hairline rules, dimmest text
    overlay1 = "#6f8a78"    # base04 — dim labels
    subtext0 = "#9fb0a3"    # interpolated — subdued text above the dim labels
    text = "#d8cfae"        # base05 — the plate cream
    green = "#8fd694"       # base0B — idle / done ("ONLINE")
    yellow = "#d9a441"      # base0A — working
    peach = "#d9822b"       # base09 — interrupted, the bar-graph amber
    red = "#e05c4a"         # base08 — blocked / needs attention
    teal = "#7fb3c8"        # base0C — notification accents
    blue = "#6f9fb0"        # base0D
    mauve = "#a98fb0"       # base0E — branch names

    # "herdr" delivery only draws a toast while herdr is on screen, so an agent
    # blocked on a question goes unnoticed. "system" hands it to the desktop
    # notification service instead.
    [ui.toast]
    delivery = "system"
    delay_seconds = 1

    [ui.sound]
    enabled = true

    [ui]
    # Legacy accent, read into `state.accent` for the navigation UI. It is
    # ignored for the palette (theme.custom.accent wins) but still colours the
    # nav paths that read state.accent directly, so keep the two in step.
    accent = "#8fd694"
    show_agent_labels_on_pane_borders = true
    # "priority" orders the agent panel as an attention queue, so a blocked
    # agent surfaces above idle ones instead of sorting by workspace.
    agent_panel_sort = "priority"

    # Space rows carry git context, which is what distinguishes one worktree
    # workspace from another at a glance.
    #
    # Rows accept either a bare token string or a styled table
    # ({ token, fg, bold, dim } — src/config/sidebar.rs RawStyledSidebarToken),
    # which is the only per-element colour control herdr exposes. Styled the
    # way the plates read their subsystem lists: phosphor-green status dot,
    # cream label, purple branch, dim git counts.
    [ui.sidebar.spaces]
    rows = [
      [{ token = "state_icon", fg = "#8fd694" }, { token = "workspace", fg = "#d8cfae", bold = true }],
      [{ token = "branch", fg = "#a98fb0" }, { token = "git_status", fg = "#6f8a78", dim = true }],
    ]

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
    claude = [
      [{ token = "state_icon", fg = "#8fd694" }, { token = "workspace", fg = "#d8cfae", bold = true }, { token = "tab", fg = "#6f8a78" }],
      [{ token = "terminal_title_stripped", fg = "#6f8a78", dim = true }],
      [{ token = "agent", fg = "#7fb3c8" }, { token = "$agents", fg = "#d9822b" }],
    ]

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

    # herdr-splits: unified ctrl+hjkl across herdr panes AND Neovim splits,
    # replacing nvim-tmux-navigation (which crossed into tmux panes that no
    # longer exist). The editor half is
    # home/shell/lazyvim/lazyvim/lua/plugins/herdr-splits.lua; this half needs
    # the plugin itself installed imperatively:
    #     herdr plugin install lmilojevicc/herdr-splits.nvim
    # Action ids come from the plugin's own herdr-plugin.toml (id =
    # "herdr-splits", actions nav-*/resize-*), not from docs.
    [[keys.command]]
    key = "ctrl+h"
    type = "plugin_action"
    command = "herdr-splits.nav-left"

    [[keys.command]]
    key = "ctrl+j"
    type = "plugin_action"
    command = "herdr-splits.nav-down"

    [[keys.command]]
    key = "ctrl+k"
    type = "plugin_action"
    command = "herdr-splits.nav-up"

    [[keys.command]]
    key = "ctrl+l"
    type = "plugin_action"
    command = "herdr-splits.nav-right"

    [[keys.command]]
    key = "alt+h"
    type = "plugin_action"
    command = "herdr-splits.resize-left"

    [[keys.command]]
    key = "alt+j"
    type = "plugin_action"
    command = "herdr-splits.resize-down"

    [[keys.command]]
    key = "alt+k"
    type = "plugin_action"
    command = "herdr-splits.resize-up"

    [[keys.command]]
    key = "alt+l"
    type = "plugin_action"
    command = "herdr-splits.resize-right"

    # Claude Code emits far more output than the 10MB default retains.
    [advanced]
    scrollback_limit_bytes = 50000000

    # Keeps pane screens across herdr server restarts.
    [experimental]
    pane_history = true
  '';
}
