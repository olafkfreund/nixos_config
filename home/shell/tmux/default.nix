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
        # M-c → GogMail TUI (Gmail / Calendar / Tasks / Drive / Contacts /
        # Chat) in a floating popup. Direct launch, same pattern as the AI
        # tools — also available from the M-a ai-tools palette.
        bind-key -n M-c     display-popup -w 90% -h 90% -d '#{pane_current_path}' -E 'gogmail-tmux'

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
        # Path + clock. (The former gog Google-Workspace segments were
        # removed when the PIM widgets were replaced by the gogmail TUI —
        # gogmail is launched on demand via M-c / the ai-tools palette and
        # doesn't feed a passive status segment.)
        set -g status-right " #[fg=#${colors.base04}]#{s|$HOME|~|:pane_current_path} │ %H:%M │ %d-%b "

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
    #   panel    = base00 (popup body — flush with terminal bg, not base01)
    #   selected = base02 (selection / line-highlight)
    #   fg       = base05 (default foreground)
    #   muted    = base03 (comments / dim)
    #   accent   = base05 (icons/headers/markers — terminal fg, not a colour)
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
          "      - name: GogMail (Google Workspace TUI)"
          "        key: m"
          "        command: display-popup -w 90% -h 90% -d '#{pane_current_path}' -E 'gogmail-tmux'"
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
      # render.ts paints `panel` onto every body line (header/search/rows/
      # footer), so it — not sizing.json's bodyStyle — is what's actually
      # visible. base00 keeps the popup flush with the terminal background.
      panel = "#${colors.base00}";
      selected = "#${colors.base02}";
      fg = "#${colors.base05}";
      muted = "#${colors.base03}";
      # accent paints icons, section headers and the row/search markers.
      # base05 keeps them the same colour as surrounding terminal text.
      accent = "#${colors.base05}";
    };

    # Popup chrome. bin/tmux-palette.sh passes explicit -b/-s/-S to
    # display-popup, so the global popup-style/popup-border-* options set in
    # extraConfig never reach this popup — sizing.json is the only lever.
    # Upstream defaults (border "none", bodyStyle "bg=<theme.panel>") render
    # borderless and lighter than the terminal; pin the body to base00 instead.
    xdg.configFile."tmux-palette/sizing.json".text = builtins.toJSON {
      border = "rounded";
      bodyStyle = "bg=#${colors.base00}";
      borderStyle = "fg=#ffffff,bg=#${colors.base00}";
    };

    # tmux-palette AI launcher: triggered by the M-a bind defined above.
    # The palette runs `command` and parses its JSON output as a list of
    # items, each with its own action. We emit a static JSON array via
    # `echo` of a Nix-generated string — keeps the keystrokes/args
    # bullet-proof (Nix handles all shell escaping) and makes it trivial
    # to add more AI tools later without touching the .nix file.
    # Monochrome by design: every entry uses a nerd-font glyph and no
    # per-item `iconColor`, so icons render in the palette's default
    # foreground (theme.json `fg`) instead of multicoloured emoji/accents.
    xdg.configFile."tmux-palette/palettes/ai-tools.json".text = builtins.toJSON {
      title = "AI Tools";
      icon = "󰚩";
      command = "echo " + lib.escapeShellArg (builtins.toJSON [
        {
          icon = "󰚩";
          title = "Claude Code (Popup)";
          subtitle = "Launch Claude overlay in floating window";
          action.tmux = "display-popup -w 85% -h 85% -d '#{pane_current_path}' -E 'claude --dangerously-skip-permissions --resume --remote-control'";
        }
        {
          icon = "󰚩";
          title = "Claude Code (Split Right)";
          subtitle = "Open Claude in a 35% side split";
          action.tmux = "split-window -h -l 35% -c '#{pane_current_path}' 'claude --dangerously-skip-permissions --resume --remote-control'";
        }
        {
          icon = "󰭻";
          title = "Claude Agents (Popup)";
          subtitle = "Launch agents overlay in floating window";
          action.tmux = "display-popup -w 85% -h 85% -d '#{pane_current_path}' -E 'claude agents --dangerously-skip-permissions'";
        }
        {
          icon = "󰔷";
          title = "Antigravity CLI (Popup)";
          subtitle = "Launch agy overlay in floating window";
          action.tmux = "display-popup -w 85% -h 85% -d '#{pane_current_path}' -E 'agy'";
        }
        {
          icon = "󰔷";
          title = "Antigravity CLI (Split Right)";
          subtitle = "Open agy in a 35% side split";
          action.tmux = "split-window -h -l 35% -c '#{pane_current_path}' 'agy'";
        }
        {
          icon = "󰔷";
          title = "Antigravity (Window + Alerts)";
          subtitle = "agy in a named window; tmux flashes on 20s idle, desktop toast on exit";
          action.tmux = "run-shell agy-window-launcher";
        }
        {
          icon = "󰇮";
          title = "GogMail (Popup)";
          subtitle = "Google Workspace TUI — Gmail, Calendar, Tasks, Drive, Contacts, Chat";
          action.tmux = "display-popup -w 90% -h 90% -d '#{pane_current_path}' -E 'gogmail-tmux'";
        }
      ]);
    };

    home.packages = [
      # GogMail — Google Workspace TUI (Gmail/Calendar/Tasks/Drive/Contacts/
      # Chat). Replaces the old gog-backed PIM popups. Launched on demand
      # from the M-a ai-tools palette and the M-c keybind. Wraps the gog
      # CLI + clipboard/browser tools onto its own PATH.
      pkgs.gogmail

      # gogmail launch wrapper for the tmux popups: pins GOG_HOME and sources
      # GOG_KEYRING_PASSWORD from the agenix file so gog can unlock its file
      # keyring regardless of the (possibly older) tmux server environment.
      (pkgs.writeShellApplication {
        name = "gogmail-tmux";
        runtimeInputs = [ pkgs.gogmail pkgs.coreutils ];
        text = ''
          export GOG_HOME="$HOME/.config/gogcli"
          if [ -r /run/agenix/gogcli-keyring-password ]; then
            GOG_KEYRING_PASSWORD="$(cat /run/agenix/gogcli-keyring-password)"
            export GOG_KEYRING_PASSWORD
          fi
          exec gogmail "$@"
        '';
      })

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
    ];
  };
}
