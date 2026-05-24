{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption mkIf types;
  cfg = config.multiplexer.rmux;

  # rmux config file. tmux-style syntax (rmux is tmux-compatible at the
  # config level — see https://github.com/Helvesec/rmux/blob/main/docs/
  # human-friendly-config.md). Loaded via `-f` because rmux has no
  # XDG-default config auto-load (unlike tmux), so we plumb it through
  # a shell alias below.
  rmuxConf = pkgs.writeText "rmux.conf" ''
    # ============================================================
    # rmux config — coexists with tmux.
    # tmux uses prefix C-b (see home/shell/tmux/default.nix); rmux
    # uses C-a here so muscle memory doesn't collide when both
    # multiplexers are attached.
    # ============================================================

    # ----- Prefix -----
    set -g prefix C-a
    unbind C-b
    bind C-a send-prefix

    # ----- Sensible defaults -----
    set -g history-limit 100000
    set -g renumber-windows on
    set -g base-index 1
    setw -g pane-base-index 1
    setw -g mode-keys vi
    set -g status-keys vi
    set -g escape-time 0
    set -g focus-events on

    # ----- Mouse off by default (native terminal selection works) -----
    # Toggle on with `prefix + T` when you want pane-aware mouse mode.
    set -g mouse off
    bind T if-shell -F '#{mouse}' \
      'set -g mouse off ; display-message "mouse OFF: native selection"' \
      'set -g mouse on  ; display-message "mouse ON: pane mouse mode"'

    # ----- Wayland clipboard (wl-copy) -----
    # Copy-mode yank pipes selection to wl-copy. Works in ghostty,
    # wezterm, foot, kitty — anywhere a wl-clipboard session is running.
    set -s copy-command '${pkgs.wl-clipboard}/bin/wl-copy'

    # ----- Cwd-preserving splits + new windows -----
    bind | split-window -h -c "#{pane_current_path}"
    bind - split-window -v -c "#{pane_current_path}"
    bind v split-window -h -c "#{pane_current_path}"
    bind b split-window -v -c "#{pane_current_path}"
    bind c new-window -c "#{pane_current_path}"

    # ----- vi copy mode -----
    bind [ copy-mode
    bind -T copy-mode-vi v send-keys -X begin-selection
    bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel
    bind -T copy-mode-vi C-c send-keys -X copy-pipe-and-cancel

    # ----- Vim-style pane navigation -----
    bind h select-pane -L
    bind j select-pane -D
    bind k select-pane -U
    bind l select-pane -R

    # ----- Reload key -----
    # Use the stable XDG path (HM symlinks it to this rmux.conf store entry).
    # Cannot use $${rmuxConf} here — would self-reference and cause an
    # infinite-recursion error during module evaluation.
    bind r source-file ~/.config/rmux/rmux.conf \; display-message "rmux config reloaded"
  '';
in
{
  options.multiplexer.rmux = {
    # Using mkOption (not mkEnableOption { default = true; ... }) because
    # the latter's `default = true` doesn't take effect in our HM context —
    # observed empirically: cfg.enable evaluated to `false` despite the
    # attrset arg, so the whole config block never fired. Plain mkOption
    # always honors default.
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "rmux multiplexer config + shell alias auto-loading it";
    };
  };

  config = mkIf cfg.enable {
    # Drop the config file at the well-known path. The shell alias
    # below references the same store path via `${rmuxConf}` so the two
    # always stay in sync (no risk of editing one and forgetting the
    # other).
    xdg.configFile."rmux/rmux.conf".source = rmuxConf;

    # Auto-load the config on every rmux invocation. Without this you'd
    # have to type `rmux -f ~/.config/rmux/rmux.conf attach` each time,
    # or call `source-file` after attaching — rmux doesn't auto-load
    # XDG configs the way tmux does.
    programs.zsh.shellAliases = {
      rmux = "rmux -f ${rmuxConf}";
    };
    programs.bash.shellAliases = {
      rmux = "rmux -f ${rmuxConf}";
    };

    # Ensure wl-clipboard is in $PATH so copy-mode yank works without
    # the alias hardcoding store paths everywhere downstream.
    home.packages = [ pkgs.wl-clipboard ];
  };
}
