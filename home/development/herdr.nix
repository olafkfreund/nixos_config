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
_:
{
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

    # The built-in "terminal" theme draws herdr's chrome in the host terminal's
    # own colours, so it follows `omarchy theme set` live once kitty reloads.
    # Pinned Stylix colours only changed at the next rebuild (#2370).
    [theme]
    name = "terminal"
    auto_switch = false

    # >>> herdr-radar theme block
    [theme.custom]
    active_row_bg = "#414868"
    # <<< herdr-radar theme block

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

    # "symbols" gives blocked/working/done/idle/unknown distinct glyphs instead
    # of colour-only dots, so state survives a dim panel or a colourblind read.
    status_indicators = "symbols"

    # Names the focused workspace in Hyprland's window title, which is what the
    # bar and alt-tab show. {hostname} renders on the herdr SERVER, so a mirrored
    # remote session names the host its panes actually run on, not this one.
    window_title = "{hostname}: {workspace}"

    # Must stay byte-identical to radar's own block: any difference reads as
    # stale and its daemon retries the write (EROFS) on every start.
    # >>> herdr-radar tab-bar block
    tab_bar_right_separator = " · "
    tab_bar_right = [
      { type = 'command', command = 'cat "/home/olafkfreund/.local/state/herdr/plugins/hhdebb.herdr-radar/tabbar''${HERDR_SESSION:+-$HERDR_SESSION}.txt"', interval_seconds = 6, timeout_seconds = 2 },
    ]
    # <<< herdr-radar tab-bar block

    # herdr-radar (hhdebb/herdr-radar) blocks, generated once by its
    # `configure --apply` with the dark palette and text glyphs, then frozen
    # here: radar re-writes them on every light/dark switch, which a store
    # symlink cannot take. Keep the >>> / <<< markers — radar treats them as
    # "installed" and skips its own write. Regenerate after a radar bump.
    # >>> herdr-radar sidebar block
    [ui.sidebar.agents]
    # logo glyphs: text
    rows = [[{ token = "$group_parent", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$group", fg = "#a8abbd", bold = true, dim = false }, { token = "$group_stale", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$split_mark", fg = "#8b8e9c", bold = false, dim = false }, { token = "$logo", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_working", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_working", fg = "#c78a1f", bold = true, dim = false }, { token = "$title_done", fg = "#4c9a5a", bold = false, dim = false }, { token = "$title_blocked", fg = "#c04a4a", bold = false, dim = false }, { token = "$title_idle_fresh", fg = "#95bba2", bold = false, dim = false }, { token = "$title_idle", fg = "#a99e92", bold = false, dim = false }, { token = "$title_idle_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_unknown", fg = "#907aa9", bold = false, dim = false }], ["$gap"]]

    [ui.sidebar.agents.rows_by_agent]
    claude = [[{ token = "$group_parent", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$group", fg = "#a8abbd", bold = true, dim = false }, { token = "$group_stale", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$split_mark", fg = "#8b8e9c", bold = false, dim = false }, { token = "$logo", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_working", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_working", fg = "#d97757", bold = true, dim = false }, { token = "$title_done", fg = "#4c9a5a", bold = false, dim = false }, { token = "$title_blocked", fg = "#c04a4a", bold = false, dim = false }, { token = "$title_idle_fresh", fg = "#95bba2", bold = false, dim = false }, { token = "$title_idle", fg = "#a99e92", bold = false, dim = false }, { token = "$title_idle_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_unknown", fg = "#907aa9", bold = false, dim = false }], ["$gap"]]
    gemini = [[{ token = "$group_parent", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$group", fg = "#a8abbd", bold = true, dim = false }, { token = "$group_stale", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$split_mark", fg = "#8b8e9c", bold = false, dim = false }, { token = "$logo", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_working", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_working", fg = "#4285f4", bold = true, dim = false }, { token = "$title_done", fg = "#4c9a5a", bold = false, dim = false }, { token = "$title_blocked", fg = "#c04a4a", bold = false, dim = false }, { token = "$title_idle_fresh", fg = "#95bba2", bold = false, dim = false }, { token = "$title_idle", fg = "#a99e92", bold = false, dim = false }, { token = "$title_idle_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_unknown", fg = "#907aa9", bold = false, dim = false }], ["$gap"]]
    kimi = [[{ token = "$group_parent", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$group", fg = "#a8abbd", bold = true, dim = false }, { token = "$group_stale", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$split_mark", fg = "#8b8e9c", bold = false, dim = false }, { token = "$logo", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_working", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_working", fg = "#1783ff", bold = true, dim = false }, { token = "$title_done", fg = "#4c9a5a", bold = false, dim = false }, { token = "$title_blocked", fg = "#c04a4a", bold = false, dim = false }, { token = "$title_idle_fresh", fg = "#95bba2", bold = false, dim = false }, { token = "$title_idle", fg = "#a99e92", bold = false, dim = false }, { token = "$title_idle_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_unknown", fg = "#907aa9", bold = false, dim = false }], ["$gap"]]
    qwen = [[{ token = "$group_parent", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$group", fg = "#a8abbd", bold = true, dim = false }, { token = "$group_stale", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$split_mark", fg = "#8b8e9c", bold = false, dim = false }, { token = "$logo", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_working", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_working", fg = "#615ced", bold = true, dim = false }, { token = "$title_done", fg = "#4c9a5a", bold = false, dim = false }, { token = "$title_blocked", fg = "#c04a4a", bold = false, dim = false }, { token = "$title_idle_fresh", fg = "#95bba2", bold = false, dim = false }, { token = "$title_idle", fg = "#a99e92", bold = false, dim = false }, { token = "$title_idle_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_unknown", fg = "#907aa9", bold = false, dim = false }], ["$gap"]]
    kiro = [[{ token = "$group_parent", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$group", fg = "#a8abbd", bold = true, dim = false }, { token = "$group_stale", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$split_mark", fg = "#8b8e9c", bold = false, dim = false }, { token = "$logo", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_working", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_working", fg = "#9046ff", bold = true, dim = false }, { token = "$title_done", fg = "#4c9a5a", bold = false, dim = false }, { token = "$title_blocked", fg = "#c04a4a", bold = false, dim = false }, { token = "$title_idle_fresh", fg = "#95bba2", bold = false, dim = false }, { token = "$title_idle", fg = "#a99e92", bold = false, dim = false }, { token = "$title_idle_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_unknown", fg = "#907aa9", bold = false, dim = false }], ["$gap"]]
    cline = [[{ token = "$group_parent", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$group", fg = "#a8abbd", bold = true, dim = false }, { token = "$group_stale", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$split_mark", fg = "#8b8e9c", bold = false, dim = false }, { token = "$logo", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_working", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_working", fg = "#586876", bold = true, dim = false }, { token = "$title_done", fg = "#4c9a5a", bold = false, dim = false }, { token = "$title_blocked", fg = "#c04a4a", bold = false, dim = false }, { token = "$title_idle_fresh", fg = "#95bba2", bold = false, dim = false }, { token = "$title_idle", fg = "#a99e92", bold = false, dim = false }, { token = "$title_idle_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_unknown", fg = "#907aa9", bold = false, dim = false }], ["$gap"]]
    kilo = [[{ token = "$group_parent", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$group", fg = "#a8abbd", bold = true, dim = false }, { token = "$group_stale", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$split_mark", fg = "#8b8e9c", bold = false, dim = false }, { token = "$logo", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_working", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_working", fg = "#9a9808", bold = true, dim = false }, { token = "$title_done", fg = "#4c9a5a", bold = false, dim = false }, { token = "$title_blocked", fg = "#c04a4a", bold = false, dim = false }, { token = "$title_idle_fresh", fg = "#95bba2", bold = false, dim = false }, { token = "$title_idle", fg = "#a99e92", bold = false, dim = false }, { token = "$title_idle_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_unknown", fg = "#907aa9", bold = false, dim = false }], ["$gap"]]
    muse = [[{ token = "$group_parent", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$group", fg = "#a8abbd", bold = true, dim = false }, { token = "$group_stale", fg = "#8b8e9c", bold = true, dim = false }], [{ token = "$split_mark", fg = "#8b8e9c", bold = false, dim = false }, { token = "$logo", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_working", fg = "#e9e9f0", bold = false, dim = false, rules = [{ contains = "§", fg = "#d97757" }, { contains = "✦", fg = "#4285f4" }, { contains = "✨", fg = "#1783ff" }, { contains = "≋", fg = "#4d6bfe" }, { contains = "Ϙ", fg = "#615ced" }, { contains = "Ω", fg = "#9046ff" }, { contains = "∇", fg = "#586876" }, { contains = "♟", fg = "#9a9808" }, { contains = "Ķ", fg = "#ff521d" }, { contains = "∞", fg = "#0082fb" }, { contains = "♥", fg = "#ff388b" }] }, { token = "$logo_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_working", fg = "#0082fb", bold = true, dim = false }, { token = "$title_done", fg = "#4c9a5a", bold = false, dim = false }, { token = "$title_blocked", fg = "#c04a4a", bold = false, dim = false }, { token = "$title_idle_fresh", fg = "#95bba2", bold = false, dim = false }, { token = "$title_idle", fg = "#a99e92", bold = false, dim = false }, { token = "$title_idle_stale", fg = "#8b8e9c", bold = false, dim = false }, { token = "$title_unknown", fg = "#907aa9", bold = false, dim = false }], ["$gap"]]

    [ui.sidebar.spaces]
    row_gap = 0
    rows = [
      [
        { token = "$space_blocked", fg = "#c04a4a", bold = true, dim = false },
        { token = "$space_working_claude", fg = "#d97757", bold = true, dim = false },
        { token = "$space_working_gemini", fg = "#4285f4", bold = true, dim = false },
        { token = "$space_working_kimi", fg = "#1783ff", bold = true, dim = false },
        { token = "$space_working_deepseek", fg = "#4d6bfe", bold = true, dim = false },
        { token = "$space_working_qwen", fg = "#615ced", bold = true, dim = false },
        { token = "$space_working_kiro", fg = "#9046ff", bold = true, dim = false },
        { token = "$space_working_cline", fg = "#586876", bold = true, dim = false },
        { token = "$space_working_kilo", fg = "#9a9808", bold = true, dim = false },
        { token = "$space_working_kimchi", fg = "#ff521d", bold = true, dim = false },
        { token = "$space_working_other", fg = "#c78a1f", bold = true, dim = false },
        { token = "$space_done", fg = "#4c9a5a", bold = true, dim = false },
        { token = "$space_idle", fg = "#8f95ab", bold = false, dim = false },
        { token = "$space_unknown", fg = "#907aa9", bold = false, dim = false },
        { token = "$space_none", fg = "#9a9eb3", bold = false, dim = false },
        { token = "$space_label", fg = "#9a9eb3", bold = false, dim = false }
      ],
      [
        { token = "$space_logo_claude", fg = "#d97757", bold = false, dim = false },
        { token = "$space_logo_gemini", fg = "#4285f4", bold = false, dim = false },
        { token = "$space_logo_kimi", fg = "#1783ff", bold = false, dim = false },
        { token = "$space_logo_deepseek", fg = "#4d6bfe", bold = false, dim = false },
        { token = "$space_logo_qwen", fg = "#615ced", bold = false, dim = false },
        { token = "$space_logo_kiro", fg = "#9046ff", bold = false, dim = false },
        { token = "$space_logo_cline", fg = "#586876", bold = false, dim = false },
        { token = "$space_logo_kilo", fg = "#9a9808", bold = false, dim = false },
        { token = "$space_logo_kimchi", fg = "#ff521d", bold = false, dim = false },
        { token = "$space_logo_muse", fg = "#0082fb", bold = false, dim = false },
        { token = "$space_logo_crush", fg = "#ff388b", bold = false, dim = false },
        { token = "$space_logo_other", fg = "#e9e9f0", bold = false, dim = false }
      ]
    ]
    # <<< herdr-radar sidebar block

    [worktrees]
    directory = "~/.herdr/worktrees"

    # Only bindings that are unset in the shipped defaults are added here, so
    # nothing upstream is shadowed. Re-checked against 0.9.0's
    # `herdr --default-config`: goto=prefix+g, close_tab=prefix+shift+x,
    # close_pane=prefix+x, settings=prefix+s, detach=prefix+q, and also
    # reload_config=prefix+shift+r and prefix+shift+d, both of which ruled out
    # the obvious keys for the reviewr binding below.
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

    # hintr: which-key style popup listing every binding here by its
    # description; pressing a listed key runs it. prefix+? stays herdr's
    # built-in help modal, which can't run bindings or show custom ones.
    #     herdr plugin install wraithyy/herdr-hintr --yes
    [[keys.command]]
    key = "prefix+k"
    type = "plugin_action"
    command = "hintr.show"
    description = "keybinding cheatsheet"

    # pretty-which: searchable, read-only map of every binding (default vs
    # config vs unset), list/tree views. Unlike hintr it can't run a binding.
    #     herdr plugin install ramarivera/herdr-pretty-which --yes
    [[keys.command]]
    key = "prefix+space"
    type = "plugin_action"
    command = "ramarivera.pretty-which.open"
    description = "binding reference"

    # zoetrope: the session as a live flow graph. This is the only way to see
    # Claude Code's Task subagents — they run in-process with no PTY, so herdr
    # (one agent per pane) can never give them rows of their own. zoetrope reads
    # the transcript JSONL under ~/.claude/projects instead of the terminal, so
    # subagents show up as nested nodes with their tool calls beneath them.
    #
    # prefix+shift+z is upstream's own default. Do NOT run the plugin's
    # setup-keys action to get it: that writes a block into config.toml, which
    # here is a read-only /nix/store symlink. Bind it from this file instead.
    #     herdr plugin install furkankly/zoetrope/herdr-plugin
    # Note the manifest is in a subdirectory, so the bare repo name fails.
    [[keys.command]]
    key = "prefix+shift+z"
    type = "plugin_action"
    command = "furkankly.zoetrope.open"

    [[keys.command]]
    key = "prefix+alt+z"
    type = "plugin_action"
    command = "furkankly.zoetrope.open-tab"

    # reviewr: diff sidebar whose point is the round trip — select lines with v,
    # comment with c, send with s, and the comments land in the agent's input
    # instead of being retyped into a prompt. Four scopes, including the last
    # agent turn.
    #
    # prefix+alt+d, not shift+d or shift+r: 0.9.0 defaults already use
    # prefix+shift+d and prefix+shift+r (reload_config).
    #     herdr plugin install persiyanov/herdr-reviewr
    [[keys.command]]
    key = "prefix+alt+d"
    type = "plugin_action"
    command = "persiyanov.reviewr.toggle"

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

  # radar's own settings. follow_appearance would drive [theme] name and
  # re-colour the frozen blocks above; variant must match the text glyphs
  # their logo rules were generated for.
  xdg.configFile."herdr/plugins/config/hhdebb.herdr-radar/config.toml".text = ''
    follow_appearance = false
    variant = "text"
  '';
}
