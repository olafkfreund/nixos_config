# Enhanced Modern Tmux Configuration
# Optimized for speed, maintainability, and seamless integration with Zsh/Starship
{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.multiplexer.tmux;
  inherit (config.lib.stylix) colors;

in
{
  options.multiplexer.tmux = {
    enable = mkEnableOption {
      default = true;
      description = "tmux";
    };
  };
  config = mkIf cfg.enable {
    programs.tmux = {
      enable = true;
      clock24 = true;
      shortcut = "b";
      aggressiveResize = true;
      baseIndex = 1;
      newSession = true;
      escapeTime = 0;
      secureSocket = true;
      mouse = true;
      terminal = "tmux-256color";
      keyMode = "vi";
      focusEvents = true;

      # Curated plugin selection for optimal performance and functionality
      plugins = with pkgs; [
        # Core functionality
        tmuxPlugins.sensible # Better defaults
        tmuxPlugins.better-mouse-mode # Enhanced mouse support

        # Navigation and window management
        {
          plugin = tmuxPlugins.tilish;
          extraConfig = ''
            # Tiling window management like i3/sway
            set -g @tilish-navigator 'on'
            set -g @tilish-default 'main-vertical'
          '';
        }

        # Enhanced session management
        {
          plugin = tmuxPlugins.t-smart-tmux-session-manager;
          extraConfig = ''
            # Smart session switching with fzf integration
            set -g @t-fzf-prompt '   Session: '
            set -g @t-bind "T"
            set -g @t-fzf-default-results 'sessions'
          '';
        }

        # Modern fuzzy finding
        {
          plugin = tmuxPlugins.tmux-fzf;
          extraConfig = ''
            # Enhanced fzf integration for tmux operations
            set -g @tmux-fzf-launch-key 'C-f'
            set -g @tmux-fzf-order 'session|window|pane|command|keybinding'
          '';
        }

        # URL handling with modern browser integration
        {
          plugin = tmuxPlugins.fzf-tmux-url;
          extraConfig = ''
            set -g @fzf-url-history-limit '3000'
            set -g @fzf-url-fzf-options '-p 70%,40% --prompt="   " --border-label=" 🌐 Open URL " --preview-window="right:50%"'
            set -g @fzf-url-open "${pkgs.firefox}/bin/firefox"
            set -g @fzf-url-bind 'u'
          '';
        }

        # tmux-gruvbox removed — its mkTmuxPlugin wrapper points at
        # `tmux_gruvbox.tmux` while upstream ships `gruvbox.tmux`, so the
        # plugin loader returned exit 127 every conf reload. We never
        # actually used the gruvbox theme — the status bar is fully
        # hand-styled via the explicit `set -g status-*` lines below using
        # Stylix base16 colours. Re-adding gruvbox would require
        # `rtpFilePath = "gruvbox.tmux"` AND the explicit overrides would
        # still win, so the plugin was net negative.

        # Development productivity plugins
        tmuxPlugins.tmux-thumbs # Quick text copying
        tmuxPlugins.extrakto # Enhanced text extraction

        # Session persistence — save layouts + restore after reboot.
        # Pairs with t-smart-tmux-session-manager: smart-session creates
        # them, resurrect/continuum keeps them alive across host restarts
        # (kernel updates, p510 panics, etc). Continuum auto-restores on
        # tmux start and saves every @continuum-save-interval minutes.
        # @resurrect-strategy-nvim=session also persists nvim :mksession
        # state so `vim -S` restores buffers/splits.
        {
          plugin = tmuxPlugins.resurrect;
          extraConfig = ''
            set -g @resurrect-strategy-nvim 'session'
            set -g @resurrect-capture-pane-contents 'on'
          '';
        }
        {
          plugin = tmuxPlugins.continuum;
          extraConfig = ''
            set -g @continuum-restore 'on'
            set -g @continuum-save-interval '15'
          '';
        }

        # Floating scratchpad pane — complements display-popup uses
        # already wired (ccm, expose, palette). Toggleable terminal
        # overlay you can throw transient commands into without
        # touching layout. Default trigger prefix-p collides with
        # previous-window, so rebound to prefix-F (capital).
        {
          plugin = tmuxPlugins.tmux-floax;
          extraConfig = ''
            set -g @floax-bind 'F'
            set -g @floax-width  '85%'
            set -g @floax-height '85%'
            set -g @floax-border-color '#${colors.base0B}'
            set -g @floax-text-color   '#${colors.base05}'
            set -g @floax-change-path 'true'
            set -g @floax-session-name 'scratch'
          '';
        }

        # Discoverable keybindings — like which-key in nvim. Default
        # trigger is prefix-Space (i.e. b-Space here), opens a menu of
        # all user-defined bindings. Complements tmux-palette: palette
        # is fuzzy-search-then-act, which-key is browse-by-prefix.
        {
          plugin = tmuxPlugins.tmux-which-key;
          extraConfig = ''
            set -g @tmux-which-key-xdg-enable 1
          '';
        }

        # tmux-ccm removed from the plugin list — its ccm.tmux script
        # installs an inject-status hook that, ~1 second after every
        # conf reload, asynchronously CLEARS window-status-format and
        # window-status-current-format to commandeer the status bar for
        # ccm's own project list. The `@ccm-status-line` option offers
        # modes 0/1/2 but ALL of them overwrite the user's window-status
        # format (Mode 0 unsets to tmux default; Mode 1/2 set to ""). With
        # ccm.tmux not running, the keybind it would have installed is
        # re-created manually in the top-level extraConfig below —
        # `prefix C-Space` → `display-popup -E "ccm dashboard"`. ccm CLI
        # invocations (`ccm add`, `ccm status`, etc.) still work because
        # pkgs.customPkgs.tmux-ccm is on PATH via home.packages.
      ];

      # Enhanced configuration for modern terminal workflows
      extraConfig = ''
        # ========== ccm dashboard (manual, replaces ccm.tmux plugin) ==========
        # The tmux-ccm plugin used to bind this and also set up
        # status-bar injection that clobbered window-status-format
        # (see the comment in the plugins list above). Manual bind
        # keeps the popup-dashboard workflow without the side effects.
        # `ccm` is on PATH via home.packages (pkgs.customPkgs.tmux-ccm).
        bind C-Space display-popup -E -w 80% -h 60% -T "  ccm  " "ccm dashboard"

        # Reduce Claude Code UI flicker in tmux (alt-screen rendering).
        # ccm.tmux used to set this; preserve the behaviour.
        set-environment -g CLAUDE_CODE_NO_FLICKER 1

        # ========== tmux-expose ==========
        # Mission Control-style session switcher with live previews.
        # Binary lives at ${pkgs.customPkgs.tmux-expose}/bin/tmux-expose.
        # Default trigger M-e (matches upstream tmux.expose.tmux defaults).
        # Inlined here rather than via mkTmuxPlugin because the upstream
        # .tmux file is a thin 5-line keybinder we can replicate directly.
        bind-key -T root M-e display-popup -w "100%" -h "100%" -E "${pkgs.customPkgs.tmux-expose}/bin/tmux-expose"

        # ========== tmux-palette ==========
        # Raycast-style command palette. M-p opens the default `commands`
        # palette (built-in tmux actions + windows + sessions). M-a opens
        # our custom `ai-tools` palette (Claude Code, Claude Agents,
        # Gemini CLI — see xdg.configFile."tmux-palette/palettes/ai-tools.json"
        # below).
        #
        # Note on M-Space: GNOME (Mutter) reserves Alt+Space by default
        # for the Window Menu shortcut. Disable it in
        # Settings → Keyboard → View and Customise Shortcuts → Windows
        # → "Activate window menu" (or via dconf). Both M-Space and M-p
        # are bound here so either works regardless of DE config.
        bind-key -n M-Space run-shell '${pkgs.customPkgs.tmux-palette}/bin/tmux-palette'
        bind-key -n M-p     run-shell '${pkgs.customPkgs.tmux-palette}/bin/tmux-palette'
        bind-key -n M-a     run-shell '${pkgs.customPkgs.tmux-palette}/bin/tmux-palette ai-tools'
        # M-c → PIM palette (Calendar + Tasks + Mail via gog).
        # See xdg.configFile."tmux-palette/palettes/pim.json" below.
        bind-key -n M-c     run-shell '${pkgs.customPkgs.tmux-palette}/bin/tmux-palette pim'

        # ========== Terminal and Display Settings ==========
        set-option -g terminal-overrides ',xterm-256color:RGB,alacritty:RGB,kitty:RGB,foot:RGB,wezterm:RGB,ghostty:RGB'
        set-option -g status-position top
        set-option -ga terminal-overrides ',*:Tc' # True color support

        # Fix powerline alignment and character rendering
        set-option -ga terminal-overrides ',*:sitm=\E[3m'  # Fix italic support
        set-option -ga terminal-overrides ',*:smcup@:rmcup@' # Fix screen buffer
        set-option -g status-justify left # Ensure left alignment

        # Performance optimizations
        set -g repeat-time 600            # Increase repeat timeout
        set -g aggressive-resize on       # Aggressive resizing

        # Modern terminal features
        set -g allow-passthrough on       # Image preview support
        set -ga update-environment TERM
        set -ga update-environment TERM_PROGRAM
        set -ga update-environment SSH_TTY
        set -ga update-environment DISPLAY
        set -ga update-environment WAYLAND_DISPLAY

        # ========== Base Configuration ==========
        set -g base-index 1               # Start windows at 1
        set -g pane-base-index 1          # Start panes at 1
        set -g renumber-windows on        # Renumber windows when closed
        set -g set-titles on              # Set terminal title
        set -g set-titles-string '#h ⸰ #S ● #I #W'

        # History and scrollback
        set -g history-limit 50000        # Increase history limit
        set -g display-time 4000          # Display messages for 4 seconds
        set -g status-interval 5          # Update status every 5 seconds

        # Status line alignment fixes
        set -g status-left-length 40      # Ensure adequate left space
        set -g status-right-length 120    # Ensure adequate right space
        set -g window-status-separator ""  # Remove extra separators

        # ========== Enhanced Keybindings ==========
        # Reload configuration
        bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"

        # Smart pane splitting (intuitive and current directory aware)
        unbind %
        unbind '"'
        bind | split-window -h -c "#{pane_current_path}" # Vertical split
        bind - split-window -v -c "#{pane_current_path}" # Horizontal split
        bind '\' split-window -h -c "#{pane_current_path}" # Alternative vertical
        bind _ split-window -v -c "#{pane_current_path}"  # Alternative horizontal

        # Smart window creation
        bind c new-window -c "#{pane_current_path}"      # New window at current path
        bind C new-window                                 # New window at home

        # ========== Vim-Style Navigation ==========
        # Smart pane switching with awareness of Vim splits.
        # Integrates with nvim-tmux-navigation Lua plugin.
        is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
            | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$'"
        bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
        bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
        bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
        bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
        bind-key -n 'C-\' if-shell "$is_vim" 'send-keys C-\\' 'select-pane -l'

        # Pane navigation (vim-style with fallback)
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        # Pane resizing (vim-style)
        bind -r H resize-pane -L 5
        bind -r J resize-pane -D 5
        bind -r K resize-pane -U 5
        bind -r L resize-pane -R 5

        # Alt-arrow keys for pane switching (no prefix)
        bind -n M-Left select-pane -L
        bind -n M-Right select-pane -R
        bind -n M-Up select-pane -U
        bind -n M-Down select-pane -D

        # Alt-vim keys for pane switching (no prefix)
        bind -n M-h select-pane -L
        bind -n M-l select-pane -R
        bind -n M-k select-pane -U
        bind -n M-j select-pane -D

        # ========== Window Management ==========
        # Window switching
        bind -n S-Left previous-window
        bind -n S-Right next-window
        bind -n M-H previous-window
        bind -n M-L next-window

        # Quick window access
        bind -n M-1 select-window -t 1
        bind -n M-2 select-window -t 2
        bind -n M-3 select-window -t 3
        bind -n M-4 select-window -t 4
        bind -n M-5 select-window -t 5

        # ========== Copy Mode Enhancements ==========
        # Vim-style copy mode.
        #
        # Clipboard strategy: OSC-52 instead of wl-copy. `set-clipboard on`
        # makes tmux forward selections to the outer terminal via the
        # OSC-52 escape sequence; the terminal (kitty here) then writes
        # the system clipboard on its own terms. This avoids the wl-copy
        # zombie / dock-icon problem on GNOME/Mutter (Mutter doesn't
        # implement wlr-data-control, so each wl-copy is forced to create
        # a dummy xdg_toplevel that GNOME Shell tracks as a running
        # window — they accumulate in the dock per yank). See
        # home/desktop/gnome/wl-clipboard-hide.nix for full context.
        set -g set-clipboard on
        bind Enter copy-mode
        bind -T copy-mode-vi 'v' send -X begin-selection
        bind -T copy-mode-vi 'y' send -X copy-pipe-and-cancel
        bind -T copy-mode-vi 'r' send -X rectangle-toggle
        bind -T copy-mode-vi Escape send -X cancel

        # Mouse selection → system clipboard (same OSC-52 path).
        bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel
        # Middle-click paste reads the system clipboard via a one-shot
        # wl-paste — fine on GNOME (only `wl-paste --watch` requires
        # data-control; a single read works via the regular wl_data_offer
        # path that any paste uses).
        bind -n MouseDown2Pane run "${pkgs.wl-clipboard}/bin/wl-paste | tmux load-buffer - && tmux paste-buffer"

        # ========== Session Management ==========
        # Enhanced session switching
        bind s choose-tree -sZ -O name
        bind S new-session

        # Quick session access
        bind -n M-s choose-tree -sZ -O name

        # ========== Development Workflow ==========
        # Quick pane layouts for development
        bind M-1 select-layout even-horizontal
        bind M-2 select-layout even-vertical
        bind M-3 select-layout main-horizontal
        bind M-4 select-layout main-vertical
        bind M-5 select-layout tiled

        # Zoom pane toggle
        bind z resize-pane -Z

        # Clear screen and history
        bind C-l send-keys 'clear' Enter \; clear-history

        # ========== Status-bar theme (explicit, no gruvbox.tmux) ==========
        # Used to call gruvbox.tmux here as a workaround for the home-manager
        # mkTmuxPlugin auto-loader pointing at the wrong filename
        # (tmux_gruvbox.tmux vs upstream's gruvbox.tmux). Removed because the
        # workaround re-ran gruvbox AFTER the explicit overrides below, and
        # gruvbox's $window_format computation produced an empty
        # window-status-format that overrode the intended " #I #W " string
        # async, leaving every window's name as an empty box in the status
        # bar (visible briefly after reload, then gone once gruvbox
        # finished). The explicit settings below define the entire theme
        # we actually want; gruvbox.tmux adds nothing.
        set -g status-left-length 40      # Override theme left length
        set -g status-right-length 200    # Override theme right length
        set -g window-status-separator " " # Clean separator between windows

        # ========== Remove Round Corners and Fix Powerline ==========
        # Force flat separators and prevent powerline curve characters
        set -g status-left "#{?client_prefix,#[bg=#${colors.base0A}]#[fg=#${colors.base00}],#[bg=#${colors.base0D}]#[fg=#${colors.base00}]} #S #[fg=default,bg=default] "
        # Status-right reads cached gog (Google Workspace) output from
        # ~/.cache/gog-status/{event,tasks}.txt — populated by the
        # gog-status-cache systemd user timer every 5 min (definitions
        # later in this file). Files may not exist on first tmux start;
        # `2>/dev/null || true` keeps the status bar quiet until the
        # first cache write. Bumped status-right-length to 200 above
        # to fit the new segments without truncation.
        set -g status-right " #[fg=#${colors.base0B}]#(cat $HOME/.cache/gog-status/event.txt 2>/dev/null || true)#[fg=default] #[fg=#${colors.base0A}]#(cat $HOME/.cache/gog-status/tasks.txt 2>/dev/null || true)#[fg=default] │ #[fg=#${colors.base04}]#{s|$HOME|~|:pane_current_path} │ %H:%M │ %d-%b "

        # Override window status format to ensure clean appearance.
        # Prefix with an AI-tool glyph when the pane's foreground
        # process matches claude*, agy* (Antigravity / Gemini), or
        # gemini* — gives visual at-a-glance window state for the AI
        # workflow without having to read window names. #{m:pattern,str}
        # is tmux's glob-match; pane_current_command is the immediate
        # foreground process in the active pane of that window.
        # Trailing alert glyphs are flag-driven and only render on
        # *background* windows (the current window never carries bell/
        # silence flags): 🔔 = bell (Claude wants attention — see the
        # terminal-bell emitted by claude-notify), 💤 = monitor-silence
        # fired (agy idle, via agy-window-launcher). Deterministic markers
        # that don't depend on tmux's per-build alert-styling internals;
        # the window-status-{bell,activity}-style below add a colour flash
        # on top. Only the non-current format needs them.
        set -g window-status-format         " #{?#{m:claude*,#{pane_current_command}},✻ ,#{?#{m:agy*,#{pane_current_command}},🛸 ,#{?#{m:gemini*,#{pane_current_command}},♊ ,}}}#I #W#{?window_bell_flag, 🔔,}#{?window_silence_flag, 💤,} "
        set -g window-status-current-format " #{?#{m:claude*,#{pane_current_command}},✻ ,#{?#{m:agy*,#{pane_current_command}},🛸 ,#{?#{m:gemini*,#{pane_current_command}},♊ ,}}}#I #W "

        # Ensure no powerline characters are used
        set -g window-status-separator " │ "
        set -g status-style "bg=#${colors.base00},fg=#${colors.base04}"

        # ========== Attention alerts (Claude / agy) ==========
        # Flash a *background* window's status cell when its pane signals
        # it wants attention. Two signal sources feed this:
        #   • Claude Code → claude-notify emits a terminal BEL into the
        #     pane (modules/programs/claude-code-managed.nix, terminalBell)
        #     which trips the bell flag → red flash + 🔔.
        #   • agy → agy-window-launcher sets `monitor-silence 20`; a window
        #     idle that long trips the silence flag → yellow flash + 💤.
        # Kept audibly silent on purpose: `bell-action none` suppresses the
        # client terminal beep, and `visual-bell off` suppresses the
        # takeover "Bell in window" message — yet `monitor-bell on` still
        # sets window_bell_flag, so the cell still flashes (verified on
        # tmux 3.6a). The result is a quiet, visual-only indicator.
        set -g monitor-bell on
        set -g bell-action none
        set -g visual-bell off
        set -g window-status-bell-style     "bg=#${colors.base08},fg=#${colors.base00},bold"
        set -g window-status-activity-style "bg=#${colors.base0A},fg=#${colors.base00},bold"

        # Popup chrome — match the Stylix base16 scheme so display-popup
        # (tmux-palette, tmux-expose, choose-tree -Z, etc.) blends into the
        # terminal instead of using tmux's terminal-default fill which
        # renders darker than gruvbox bg on kitty/ghostty.
        set -g popup-style "bg=#${colors.base00}"
        set -g popup-border-style "fg=#${colors.base0B},bg=#${colors.base00}"
        set -g popup-border-lines rounded
      '';
    };

    # Expose `ccm` (tmux-ccm's CLI) on user PATH so commands like
    # `ccm add`, `ccm status`, `ccm send <project> <msg>` work from any
    # shell, not just from inside the tmux popup that the plugin opens.
    # The second list further below adds `gog-status-cache` (timer-fed
    # status bar helper); module-system list merging keeps both.

    # tmux-palette active theme — full color override sourced from our
    # active stylix base16 scheme, so the palette popup is BYTE-IDENTICAL
    # to the rest of our terminal/UI gruvbox theming (not just close-ish
    # to the tmux-palette-bundled gruvbox-dark, which uses slightly
    # different panel/selected/muted/accent values).
    #
    # Schema discovered from src/theme.ts:
    #   { name: "<slug>" }              → look up bundled/user slug
    #   { bg, panel, selected, fg, muted, accent }  → full Theme override
    #   partial Theme                   → merged onto default theme
    # Note: the field is `name`, NOT `theme` — earlier `theme.json` of
    # `{ "theme": "gruvbox-dark" }` was silently ignored (treated as a
    # Partial<Theme>) and crashed the palette with exit 1.
    #
    # base16 → tmux-palette Theme mapping:
    #   bg       = base00 (default background)
    #   panel    = base01 (lighter background)
    #   selected = base02 (selection / line-highlight)
    #   fg       = base05 (default foreground)
    #   muted    = base03 (comments / dim)
    #   accent   = base0B (green — gruvbox's classic positive accent)
    # tmux-which-key menu (prefix+Space). The upstream default menu covers
    # built-in tmux commands (./which-key-base.yaml); we append a +Tools
    # submenu (key P) exposing our plugin/custom bindings so they're
    # discoverable from one place. Generated rather than shipped static
    # because the +Tools commands embed nix-store paths that change on every
    # rebuild. NOTE: which-key is a *curated* menu — it is NOT auto-synced
    # with `list-keys`. For the complete live list use tmux-fzf
    # (prefix C-f → keybinding) or the built-in `?` entry (list-keys -N).
    xdg.configFile."tmux/plugins/tmux-which-key/config.yaml".text =
      let
        palette = "${pkgs.customPkgs.tmux-palette}/bin/tmux-palette";
        expose = "${pkgs.customPkgs.tmux-expose}/bin/tmux-expose";
        floax = "${pkgs.tmuxPlugins.tmux-floax}/share/tmux-plugins/tmux-floax/scripts/floax.sh";
        tsm = "${pkgs.tmuxPlugins.t-smart-tmux-session-manager}/share/tmux-plugins/t-smart-tmux-session-manager/bin/t";
        toolsMenu = lib.concatStringsSep "\n" [
          "  - separator: true"
          "  - name: +Tools"
          "    key: P"
          "    menu:"
          "      - name: AI tools (palette)"
          "        key: a"
          "        command: run-shell \"${palette} ai-tools\""
          "      - name: Command palette"
          "        key: p"
          "        command: run-shell ${palette}"
          "      - name: Mail / Calendar / Tasks"
          "        key: m"
          "        command: run-shell \"${palette} pim\""
          "      - separator: true"
          "      - name: Session expose"
          "        key: e"
          "        command: display-popup -E -w \"100%\" -h \"100%\" ${expose}"
          "      - name: Floating pane"
          "        key: f"
          "        command: run-shell ${floax}"
          "      - name: Smart session switch"
          "        key: s"
          "        command: run-shell ${tsm}"
          "      - name: ccm dashboard"
          "        key: C"
          "        command: display-popup -E -w \"80%\" -h \"60%\" -T \"  ccm  \" \"ccm dashboard\""
        ] + "\n";
      in
      builtins.readFile ./which-key-base.yaml + toolsMenu;

    xdg.configFile."tmux-palette/theme.json".text = builtins.toJSON {
      bg = "#${colors.base00}";
      panel = "#${colors.base01}";
      selected = "#${colors.base02}";
      fg = "#${colors.base05}";
      muted = "#${colors.base03}";
      accent = "#${colors.base0B}";
    };

    # tmux-palette AI launcher: triggered by the M-a bind defined above.
    # The palette runs `command` and parses its JSON output as a list of
    # items, each with its own action. We emit a static JSON array via
    # `echo` of a Nix-generated string — keeps the keystrokes/args
    # bullet-proof (Nix handles all shell escaping) and makes it trivial
    # to add more AI tools later without touching the .nix file.
    xdg.configFile."tmux-palette/palettes/ai-tools.json".text = builtins.toJSON {
      title = "AI Tools";
      icon = "🤖";
      command = "echo " + lib.escapeShellArg (builtins.toJSON [
        {
          icon = "✻";
          iconColor = "#cc8822";
          title = "Claude Code (Popup)";
          subtitle = "Launch Claude overlay in floating window";
          action.tmux = "display-popup -w 85% -h 85% -d '#{pane_current_path}' -E 'claude --dangerously-skip-permissions --resume --remote-control'";
        }
        {
          icon = "✻";
          iconColor = "#cc8822";
          title = "Claude Code (Split Right)";
          subtitle = "Open Claude in a 35% side split";
          action.tmux = "split-window -h -l 35% -c '#{pane_current_path}' 'claude --dangerously-skip-permissions --resume --remote-control'";
        }
        {
          icon = "🛰";
          iconColor = "#a48ec3";
          title = "Claude Agents (Popup)";
          subtitle = "Launch agents overlay in floating window";
          action.tmux = "display-popup -w 85% -h 85% -d '#{pane_current_path}' -E 'claude agents --dangerously-skip-permissions'";
        }
        {
          icon = "🛸";
          iconColor = "#22aaff";
          title = "Antigravity CLI (Popup)";
          subtitle = "Launch agy overlay in floating window";
          action.tmux = "display-popup -w 85% -h 85% -d '#{pane_current_path}' -E 'agy'";
        }
        {
          icon = "🛸";
          iconColor = "#22aaff";
          title = "Antigravity CLI (Split Right)";
          subtitle = "Open agy in a 35% side split";
          action.tmux = "split-window -h -l 35% -c '#{pane_current_path}' 'agy'";
        }
        {
          icon = "🛸";
          iconColor = "#22aaff";
          title = "Antigravity (Window + Alerts)";
          subtitle = "agy in a named window; tmux flashes on 20s idle, desktop toast on exit";
          action.tmux = "run-shell agy-window-launcher";
        }
      ]);
    };

    # tmux-palette PIM launcher: triggered by M-c (defined above).
    # All actions defer to the `pim-popup` helper (writeShellApplication
    # below) which wraps gog subcommands and pipes through `less -R` so
    # the popup waits for `q` instead of closing on a POSIX sh failure
    # (the previous design embedded bash-only `read -r -p` which broke
    # under tmux's /bin/sh -c — popups appeared empty). Chat entry was
    # dropped because the Google Chat API isn't enabled on the account
    # (`gog chat spaces list` returns 404 notFound).
    xdg.configFile."tmux-palette/palettes/pim.json".text = builtins.toJSON {
      title = "Personal (Gmail / Calendar / Tasks)";
      icon = "📬";
      command = "echo " + lib.escapeShellArg (builtins.toJSON [
        # ---------- Calendar ----------
        {
          icon = "📅";
          iconColor = "#8ec07c";
          title = "Calendar — Today";
          subtitle = "Today's events";
          action.tmux = "display-popup -w 60% -h 45% -E 'pim-popup events-today'";
        }
        {
          icon = "📅";
          iconColor = "#8ec07c";
          title = "Calendar — Tomorrow";
          subtitle = "Tomorrow's events";
          action.tmux = "display-popup -w 60% -h 45% -E 'pim-popup events-tomorrow'";
        }
        {
          icon = "📆";
          iconColor = "#8ec07c";
          title = "Calendar — Next 7 days";
          subtitle = "Upcoming events this week";
          action.tmux = "display-popup -w 70% -h 60% -E 'pim-popup events-week'";
        }
        {
          icon = "🎯";
          iconColor = "#fabd2f";
          title = "Calendar — Next meeting";
          subtitle = "Next timed event, full description (Teams/Zoom/Meet links)";
          action.tmux = "display-popup -w 75% -h 70% -E 'pim-popup events-next'";
        }
        # ---------- Tasks ----------
        {
          icon = "✓";
          iconColor = "#fabd2f";
          title = "Tasks — Open";
          subtitle = "Open Google Tasks";
          action.tmux = "display-popup -w 65% -h 50% -E 'pim-popup tasks'";
        }
        {
          icon = "⚠️";
          iconColor = "#fb4934";
          title = "Tasks — Overdue";
          subtitle = "Tasks past their due date";
          action.tmux = "display-popup -w 60% -h 45% -E 'pim-popup tasks-overdue'";
        }
        {
          icon = "📋";
          iconColor = "#fabd2f";
          title = "Tasks — All (incl. completed)";
          subtitle = "Open + completed, last 100";
          action.tmux = "display-popup -w 70% -h 60% -E 'pim-popup tasks-all'";
        }
        # ---------- Gmail ----------
        {
          icon = "📥";
          iconColor = "#83a598";
          title = "Gmail — Inbox";
          subtitle = "Latest 25 threads in:inbox";
          action.tmux = "display-popup -w 80% -h 65% -E 'pim-popup inbox'";
        }
        {
          icon = "🔴";
          iconColor = "#fb4934";
          title = "Gmail — Unread";
          subtitle = "Unread inbox (is:unread label:INBOX)";
          action.tmux = "display-popup -w 80% -h 60% -E 'pim-popup unread'";
        }
        {
          icon = "⭐";
          iconColor = "#fabd2f";
          title = "Gmail — Starred";
          subtitle = "Starred messages";
          action.tmux = "display-popup -w 80% -h 60% -E 'pim-popup starred'";
        }
        {
          icon = "❗";
          iconColor = "#fb4934";
          title = "Gmail — Important";
          subtitle = "Important messages";
          action.tmux = "display-popup -w 80% -h 60% -E 'pim-popup important'";
        }
        {
          icon = "🔍";
          iconColor = "#83a598";
          title = "Gmail — Search";
          subtitle = "Prompts for a Gmail query (from:foo, has:attachment, …)";
          action.tmux = "command-prompt -p 'gmail search:' 'display-popup -w 80% -h 65% -E \"pim-popup search %%\"'";
        }
        {
          icon = "🏷️";
          iconColor = "#d3869b";
          title = "Gmail — Labels";
          subtitle = "Browse all Gmail labels";
          action.tmux = "display-popup -w 55% -h 55% -E 'pim-popup labels'";
        }
        {
          icon = "📖";
          iconColor = "#83a598";
          title = "Gmail — Read message";
          subtitle = "Prompts for a message id (copy from inbox view)";
          action.tmux = "command-prompt -p 'message id:' 'display-popup -w 80% -h 75% -E \"pim-popup read %%\"'";
        }
      ]);
    };

    # gog status cache — populates ~/.cache/gog-status/{event,tasks}.txt
    # for the status-right cat reads. Refreshed by a systemd user timer
    # every 5 min (definition below). Empty output ⇒ no segment shown.
    # Truncates titles to 30 chars to keep status bar tidy.
    home.packages = [
      pkgs.customPkgs.tmux-ccm

      # agy lifecycle wrappers — agy has no hook system (unlike Claude
      # Code), so the only signals we can wire are session-end (via a
      # trailing notify-send when the wrapped process exits) and
      # per-task idle (via tmux's per-window monitor-silence flashing
      # the window indicator when output stops). Combined they cover
      # ~80% of the "task done" signal a real hook would provide. Drop
      # both in one commit when agy ships a hook system.
      #
      # Icon bundled in repo at assets/icons/antigravity.svg — the
      # official Antigravity IDE logo, lands in the nix store as a
      # reproducible path that notify-send -i resolves.
      (pkgs.writeShellScriptBin "agy-notify" ''
        ${pkgs.coreutils}/bin/env agy "$@"
        rc=$?
        ${pkgs.libnotify}/bin/notify-send -u normal \
          -i ${../../../assets/icons/antigravity.svg} \
          -a "Antigravity" \
          "🛸 Antigravity" "Session ended (exit=$rc)" 2>/dev/null || true
        exit "$rc"
      '')
      (pkgs.writeShellScriptBin "agy-window-launcher" ''
        ${pkgs.tmux}/bin/tmux new-window -n agy 'agy-notify'
        ${pkgs.tmux}/bin/tmux set-window-option monitor-silence 20
      '')

      # PIM popup helper — called by the M-c palette. Each subcommand
      # wraps a gog query and pipes through less so the popup waits for
      # `q` instead of closing on a POSIX `sh` failure (the previous
      # design embedded `read -r -p` which is bash-only; tmux's
      # display-popup -E runs through /bin/sh and exited immediately,
      # making popups appear empty). All output is ANSI-passthrough
      # (less -R) so gog colors survive. Adding new subcommands here
      # is the only change needed when extending the palette.
      (pkgs.writeShellApplication {
        name = "pim-popup";
        runtimeInputs = with pkgs; [ gogcli jq less coreutils ncurses ];
        excludeShellChecks = [ "SC2016" ];
        text = ''
          # Reset LESS: -F (quit-if-one-screen) in the user environment causes
          # display-popup -E to exit immediately when output fits one screen.
          # -R passes ANSI colour escapes through less unchanged.
          export LESS="-R"

          # Popup rendering helper.  The global `smcup@:rmcup@` terminal
          # override (see terminal-overrides above) forces less out of the
          # alternate screen, which bottom-anchors short pages inside a
          # display-popup.  `pager` prints content that fits at the TOP and
          # holds for a keypress; taller content falls back to less so it
          # stays scrollable.
          pager() {
            local body rows
            body="$(cat)"
            rows="$(tput lines 2>/dev/null || echo 40)"
            if [ "$(printf '%s\n' "$body" | wc -l)" -lt "$(( rows - 1 ))" ]; then
              printf '%s\n' "$body"
              printf '\n%s── press any key to close ──%s' \
                "$(tput dim 2>/dev/null || true)" "$(tput sgr0 2>/dev/null || true)"
              read -rsn1 </dev/tty || true
            else
              less -R <<< "$body"
            fi
          }

          # Centre one line across the current popup width.
          center() {
            local s width pad
            s="$1"
            width="$(tput cols 2>/dev/null || echo 80)"
            pad=$(( (width - ''${#s}) / 2 ))
            [ "$pad" -lt 0 ] && pad=0
            printf '%*s%s\n' "$pad" "" "$s"
          }

          cmd="''${1:-help}"
          shift || true

          # Run gog in JSON mode; on any error emit [] so jq sees an empty array.
          gog_json() { gog "$@" 2>/dev/null || echo '[]'; }

          first_tasklist_id() {
            gog_json -j tasks lists --select id --results-only \
              | jq -r '.[0].id // empty'
          }

          # ── Gruvbox palette (shell vars, prepended into every jq filter) ──
          # bash $VAR (no braces) is kept literal in Nix indented strings
          JQ_G='
            def R:"[0m";def bold:"[1m";def dim:"[2m";
            def blue:"[38;5;109m";def aqua:"[38;5;108m";
            def yellow:"[38;5;214m";def orange:"[38;5;208m";
            def red:"[38;5;167m";def green:"[38;5;142m";
            def gray:"[38;5;245m";def purple:"[38;5;175m";'

          # Calendar colour + formatting helpers.
          # primary / @gmail = blue, holidays = green, birthdays = purple,
          # everything else = orange.
          JQ_CAL='
            def cal_color:
              if . == null then blue
              elif test("primary|@gmail\\.com") then blue
              elif test("holiday|holidays") then green
              elif test("birthday|birthdays") then purple
              else orange end;
            def hhmm: .[11:16];
            def norm_tz: gsub("[+-][0-9]{2}:[0-9]{2}$"; "Z");
            def timespan:
              if .start.dateTime then
                (.start.dateTime | hhmm) + "–" + (.end.dateTime | hhmm)
              else "all-day   " end;
            def fmt_event:
              ((.calendarId // "") | cal_color) as $c
              | $c + "▪" + R + "  " + $c + timespan + R + "  "
                + bold + (.summary // "(no title)") + R
                + (if .location and (.location | length > 0)
                   then "\n           " + gray + "@ " + .location + R
                   else "" end);'

          # Format a flat list of events (single-day view).
          fmt_events_flat() {
            jq -r "$JQ_G $JQ_CAL"'
              [ .[] | select(.eventType != "workingLocation") ]
              | if length == 0 then gray + "(no events)" + R
                else .[] | fmt_event end'
          }

          # Format events grouped by date (multi-day view).
          fmt_events_dated() {
            jq -r "$JQ_G $JQ_CAL"'
              [ .[] | select(.eventType != "workingLocation") ]
              | if length == 0 then gray + "(no upcoming events)" + R
                else
                  group_by(
                    if .start.dateTime then .start.dateTime[0:10]
                    else (.start.date // "") end)
                  | .[]
                  | (.[0].start.dateTime // .[0].start.date) as $d
                  | (if ($d | test("T"))
                     then ($d | norm_tz | fromdateiso8601 | strftime("%a %b %d"))
                     else $d end) as $label
                  | (yellow + "── " + $label + " ──" + R),
                    (.[] | fmt_event)
                end'
          }

          # Format task objects.  $1 = current epoch from date -u +%s.
          fmt_tasks() {
            now_epoch="$1"
            jq -r --argjson now "$now_epoch" "$JQ_G"'
              def to_epoch: sub("\\.[0-9]+Z$";"Z") | fromdateiso8601;
              def fmt_task:
                if .status == "completed" then
                  dim + "  ✓  "
                    + (if .due then .due[0:10] else "          " end)
                    + "  " + .title + R
                elif (.due != null) and ((.due | to_epoch) < $now) then
                  red + "  ✗  " + .due[0:10] + "  " + bold + .title + R
                else
                  yellow + "  ○  "
                    + (if .due then .due[0:10] else "          " end)
                    + "  " + .title + R
                end;
              if length == 0 then gray + "(none)" + R
              else .[] | fmt_task end'
          }

          # Format Gmail message objects.
          fmt_email() {
            jq -r "$JQ_G"'
              def has_lbl(l):
                .labels != null
                and (.labels | map(ascii_upcase) | index(l) != null);
              def msg_color:
                if has_lbl("UNREAD") and has_lbl("IMPORTANT") then yellow + bold
                elif has_lbl("UNREAD") then bold
                elif has_lbl("IMPORTANT") then yellow
                elif has_lbl("STARRED") then orange
                elif has_lbl("CATEGORY_PROMOTIONS") then dim
                elif has_lbl("CATEGORY_SOCIAL") then blue
                elif has_lbl("CATEGORY_UPDATES") then aqua
                else "" end;
              def fmt_msg:
                msg_color as $p
                | $p
                  + ((.date // "") | .[0:10])
                  + "  "
                  + ((.from // "(?)") | .[0:28] | . + (" " * (28 - length)))
                  + "  "
                  + (.subject // "(no subject)")
                  + R;
              if length == 0 then gray + "(no messages)" + R
              else .[] | fmt_msg end'
          }

          case "$cmd" in
            # ── Calendar ─────────────────────────────────────────────────
            events-today)
              { center "── Today's events ──"; echo;
                gog_json -j calendar events --today --results-only \
                  | fmt_events_flat; } | pager
              ;;
            events-tomorrow)
              { center "── Tomorrow's events ──"; echo;
                gog_json -j calendar events --tomorrow --results-only \
                  | fmt_events_flat; } | pager
              ;;
            events-week)
              { center "── Upcoming events (next 7 days) ──"; echo;
                gog_json -j calendar events --days 7 --results-only \
                  | fmt_events_dated; } | pager
              ;;
            events-next)
              # Next timed (non-workingLocation) event in next 7 days.
              # Rendered via `event get` for full description with Meet/Teams links.
              next_id="$(gog_json -j calendar events --days 7 --max 50 \
                          --select 'id,start,eventType' --results-only \
                         | jq -r '[ .[]
                                    | select(.eventType != "workingLocation")
                                    | select(.start.dateTime != null) ]
                                  | sort_by(.start.dateTime)
                                  | .[0].id // empty')"
              { center "── Next meeting ──"; echo;
                if [ -n "$next_id" ]; then
                  gog calendar event primary "$next_id" 2>&1 || echo "(error)"
                else
                  echo "(no upcoming timed events in the next 7 days)"
                fi; } | pager
              ;;

            # ── Tasks ─────────────────────────────────────────────────────
            tasks)
              list_id="$(first_tasklist_id)"
              now_epoch="$(date -u +%s)"
              { center "── Open tasks ──"; echo;
                if [ -n "$list_id" ]; then
                  gog_json -j tasks list "$list_id" --results-only \
                    | jq '[.[] | select(.status == "needsAction")]' \
                    | fmt_tasks "$now_epoch"
                else
                  echo "(could not auto-discover a tasklist id)"
                fi; } | pager
              ;;
            tasks-overdue)
              list_id="$(first_tasklist_id)"
              now_epoch="$(date -u +%s)"
              { center "── Overdue tasks ──"; echo;
                if [ -n "$list_id" ]; then
                  gog_json -j tasks list "$list_id" --results-only \
                    | jq --argjson now "$now_epoch" \
                        '[.[] | select(.status == "needsAction")
                              | select(.due != null)
                              | select((.due | sub("\\.[0-9]+Z$";"Z")
                                            | fromdateiso8601) < $now)]' \
                    | fmt_tasks "$now_epoch"
                else
                  echo "(could not auto-discover a tasklist id)"
                fi; } | pager
              ;;
            tasks-all)
              list_id="$(first_tasklist_id)"
              now_epoch="$(date -u +%s)"
              { center "── All tasks (incl. completed) ──"; echo;
                if [ -n "$list_id" ]; then
                  gog_json -j tasks list "$list_id" \
                    --show-completed --max 100 --results-only \
                    | fmt_tasks "$now_epoch"
                else
                  echo "(could not auto-discover a tasklist id)"
                fi; } | pager
              ;;

            # ── Gmail ─────────────────────────────────────────────────────
            inbox)
              { center "── Inbox (latest 25) ──"; echo;
                gog_json -j gmail search "in:inbox" --max 25 --results-only \
                  | fmt_email; } | pager
              ;;
            unread)
              { center "── Unread inbox ──"; echo;
                gog_json -j gmail search "is:unread label:INBOX" \
                  --max 25 --results-only \
                  | fmt_email; } | pager
              ;;
            starred)
              { center "── Starred ──"; echo;
                gog_json -j gmail search "is:starred" --max 25 --results-only \
                  | fmt_email; } | pager
              ;;
            important)
              { center "── Important ──"; echo;
                gog_json -j gmail search "is:important" \
                  --max 25 --results-only \
                  | fmt_email; } | pager
              ;;
            search)
              query="''${*:-}"
              if [ -z "$query" ]; then
                echo "usage: pim-popup search <query>" >&2; exit 2
              fi
              { center "── Gmail search: $query ──"; echo;
                gog_json -j gmail search "$query" --max 25 --results-only \
                  | fmt_email; } | pager
              ;;
            labels)
              { center "── Labels ──"; echo;
                gog gmail labels list 2>&1 || echo "(error)"; } | pager
              ;;
            read)
              msg_id="''${1:-}"
              if [ -z "$msg_id" ]; then
                echo "usage: pim-popup read <messageId>" >&2; exit 2
              fi
              { center "── Message $msg_id ──"; echo;
                gog gmail get "$msg_id" 2>&1 || echo "(error)"; } | pager
              ;;

            help | *)
              cat <<'USAGE'
          pim-popup — tmux M-c palette helper around gog

          Calendar:  blue=primary  green=holidays  purple=birthdays  orange=other
            events-today        today's events
            events-tomorrow     tomorrow's events
            events-week         next 7 days (grouped by date)
            events-next         next meeting with full description (Teams/Zoom links)

          Tasks:  yellow=pending  red=overdue  dim=completed
            tasks               open tasks
            tasks-overdue       overdue tasks only
            tasks-all           open + completed (last 100)

          Gmail:  bold=unread  yellow=important  orange=starred  dim=promotions
            inbox               latest 25 inbox threads
            unread              unread inbox
            starred             starred
            important           important
            search <query>      Gmail search syntax (from:, has:attachment, …)
            labels              list all labels
            read <messageId>    read a message
          USAGE
              ;;
          esac
        '';
      })

      (pkgs.writeShellApplication {
        name = "gog-status-cache";
        runtimeInputs = with pkgs; [ gogcli jq coreutils ];
        text = ''
          # Cache dir + atomic writes via temp + mv. Failures leave the
          # previous cache in place — tmux keeps showing the last good
          # value instead of flickering empty on transient API blips.
          cache="$HOME/.cache/gog-status"
          mkdir -p "$cache"

          # Next event in the next 24h, skipping all-day and
          # workingLocation entries (those are calendar metadata, not
          # meetings). Format: "📅 SUMMARY HH:MM" (24h time).
          tmp_event="$(mktemp)"
          if gog -j calendar events primary --days 1 --max 20 \
               --select 'summary,start,eventType' --results-only \
               2>/dev/null \
             | jq -r '[ .[]
                       | select(.eventType != "workingLocation")
                       | select(.start.dateTime != null) ]
                      | sort_by(.start.dateTime)
                      | .[0]
                      | if . == null then ""
                        else "📅 " + (.summary // "(no title)" | .[0:30]) + " "
                             + (.start.dateTime | .[11:16])
                        end' \
               > "$tmp_event" 2>/dev/null; then
            mv -f "$tmp_event" "$cache/event.txt"
          else
            rm -f "$tmp_event"
          fi

          # Open task count across the default tasks list. Renders as
          # "✓ N" if N>0, empty otherwise.
          tmp_tasks="$(mktemp)"
          tasklist_id="$(gog -j tasks lists --select id --results-only 2>/dev/null \
                         | jq -r '.[0].id // empty')"
          if [ -n "$tasklist_id" ] \
             && gog -j tasks list "$tasklist_id" --select status --results-only 2>/dev/null \
                | jq -r 'map(select(.status == "needsAction")) | length
                         | if . > 0 then "✓ \(.)" else "" end' \
                > "$tmp_tasks"; then
            mv -f "$tmp_tasks" "$cache/tasks.txt"
          else
            rm -f "$tmp_tasks"
          fi
        '';
      })
    ];

    # 5-minute timer that refreshes the status cache. OnBootSec=30s
    # gives the desktop session time to settle (gog OAuth cache, dbus,
    # network) before the first run. RemainAfterExit=false because it's
    # oneshot — the timer re-fires it on the schedule.
    systemd.user.services.gog-status-cache = {
      Unit.Description = "Refresh gog (Google Tasks/Calendar) status cache for tmux";
      Service = {
        Type = "oneshot";
        ExecStart = "${config.home.profileDirectory}/bin/gog-status-cache";
      };
    };
    systemd.user.timers.gog-status-cache = {
      Unit.Description = "Periodic refresh of gog status cache";
      Timer = {
        OnBootSec = "30s";
        OnUnitActiveSec = "5min";
        Unit = "gog-status-cache.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
