# Claude Code managed-settings.json
#
# Renders /etc/claude-code/managed-settings.json — Claude Code's highest-
# precedence config layer. The CLI reads this file but NEVER writes to it,
# making the read-only nix-store backing both safe and correct.
#
# Use this for settings the user must not be able to disable from the CLI
# (PARR hooks, baseline permissions, apiKeyHelper). User-scope preferences
# like statusLine and enabledPlugins should NOT live here — see the init-
# template pattern in home/development/claude-code-lsp.nix instead.
#
# Reference: https://code.claude.com/docs/en/settings.md
# Tracked in issue #398.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.modules.programs.claude-code-managed;

  # PARR Protocol Reminder Hook — kept identical to the script in
  # home/development/claude-code-lsp.nix so behaviour is unchanged when we
  # move the hook from user scope to managed scope.
  parrReminderScript = pkgs.writeShellScript "parr-reminder.sh" ''
        #!/usr/bin/env bash
        cat << 'PARR_EOF'
    <system-reminder>
    ## MANDATORY: Follow PARR Protocol for This Task

    You MUST structure your response using these phases:

    ### 🎯 PLAN (Before ANY action)
    - State the goal in one sentence
    - List steps with verification criteria
    - Identify approach, assumptions, and risks

    ### ⚡ ACT (Execute ONE step at a time)
    - Announce what you're doing
    - Execute exactly ONE step
    - Show output and verify checkpoint
    - NEVER chain commands without checking results

    ### 🔍 REFLECT (After EACH step)
    - Did it work? Compare expected vs actual
    - Any side effects?
    - Is the plan still valid?

    ### 🔄 REVISE (When needed)
    - If something failed, diagnose root cause
    - Update plan with new information
    - Consider alternative approaches

    ### ✅ COMPLETE (When done)
    - Summarize what was achieved
    - List files changed
    - Note any follow-up needed

    CRITICAL RULES:
    - NEVER skip the PLAN phase
    - NEVER execute multiple steps without reflection
    - STOP immediately if something unexpected happens
    - Ask for clarification if stuck after 2 attempts
    </system-reminder>
    PARR_EOF
  '';

  # Hooks contributed by the parrProtocol convenience flag, merged with
  # whatever the user supplies via cfg.settings.hooks.
  parrHooks = lib.optionalAttrs cfg.parrProtocol.enable {
    UserPromptSubmit = [{
      hooks = [{
        type = "command";
        command = toString parrReminderScript;
      }];
    }];
  };

  # Notification helper — surfaces Claude Code lifecycle events as desktop
  # toasts (libnotify) and/or in-tmux popups/status flashes. Triggered by
  # the Notification / Stop / SubagentStop hooks below.
  #
  # Reads the hook payload JSON from stdin (Claude Code passes
  # `{ session_id, transcript_path, cwd, message?, ... }`), extracts the
  # event-relevant fields, and dispatches based on the subcommand. Values
  # for the toggles + rate limit are baked at module-eval time so a
  # single binary serves both the hook and any user shell.
  #
  # All outward calls (`notify-send`, `tmux display-*`) are backgrounded
  # so a slow dbus session or tmux server doesn't block the hook from
  # returning quickly. Rate limiting is per-event-type via a tiny file in
  # XDG_RUNTIME_DIR so Stop spam (every assistant turn) doesn't drown the
  # status bar.
  # Claude / Anthropic brand icon — bundled in repo at assets/icons/
  # so it lands in the nix store as a reproducible path the notify-send
  # `-i` flag can resolve. SVG has the Anthropic #D77655 orange baked in.
  claudeIcon = ../../assets/icons/claude.svg;

  notifyScript = pkgs.writeShellApplication {
    name = "claude-notify";
    runtimeInputs = with pkgs; [ jq libnotify tmux coreutils ];
    text = ''
      icon_path=${claudeIcon}
      cmd="''${1:-help}"
      payload="$(cat)"
      state_dir="''${XDG_RUNTIME_DIR:-/tmp}/claude-notify"
      mkdir -p "$state_dir"

      rate_limit_seconds=${toString cfg.notifications.rateLimitSeconds}
      use_desktop=${if cfg.notifications.desktopToasts then "1" else "0"}
      use_tmux=${if cfg.notifications.tmuxPopups then "1" else "0"}
      use_bell=${if cfg.notifications.terminalBell then "1" else "0"}

      # Ring the terminal bell in Claude's own pane so tmux (monitor-bell)
      # flashes that window's status-bar cell. Writes straight to the
      # controlling terminal (/dev/tty), bypassing Claude's captured hook
      # stdout, so the BEL reaches the pty tmux watches. No-ops cleanly
      # outside a tty (headless / CI). Paired with `monitor-bell on` +
      # `bell-action none` in home/shell/tmux — visual flash, no audible beep.
      ring_bell() {
        [ "$use_bell" = "1" ] && printf '\a' > /dev/tty 2>/dev/null || true
      }

      msg=$(printf '%s' "$payload" | jq -r '.message // ""' 2>/dev/null || echo "")
      cwd_path=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null || echo "")
      cwd=$(basename "''${cwd_path:-?}" 2>/dev/null || echo "?")

      case "$cmd" in
        notification)
          text="''${msg:-Claude needs your attention}"
          ring_bell
          if [ "$use_desktop" = "1" ] && command -v notify-send >/dev/null 2>&1; then
            notify-send -u normal -i "$icon_path" -a "Claude Code" "✻ Claude · $cwd" "$text" &
          fi
          if [ "$use_tmux" = "1" ] && [ -n "''${TMUX:-}" ]; then
            # Small top-right corner popup so it reads as a notification,
            # not a takeover. `-x R` aligns the popup's right edge to
            # the terminal's right edge; `-y S` aligns it to the status
            # line (status is at top here → popup sits just below it).
            # Piped through `less -R` so `q` dismisses (vim-style) and
            # long messages paginate. ANSI title color survives -R.
            tmux display-popup -w 60 -h 10 -x R -y S -E \
              "printf '\\033[1;33m✻ Claude · %s\\033[0m\\n\\n%s\\n' '$cwd' '$text' | less -R" &
          fi
          ;;

        stop|subagent-stop)
          rate_file="$state_dir/last-$cmd"
          now=$(date +%s)
          if [ -r "$rate_file" ]; then
            last=$(cat "$rate_file" 2>/dev/null || echo 0)
            if [ $((now - last)) -lt "$rate_limit_seconds" ]; then
              exit 0
            fi
          fi
          echo "$now" > "$rate_file"
          ring_bell

          label="✻ Claude"
          [ "$cmd" = "subagent-stop" ] && label="✻ subagent"

          if [ "$use_tmux" = "1" ] && [ -n "''${TMUX:-}" ]; then
            tmux display-message -d 2500 "$label · $cwd · turn done"
          fi
          ;;

        *)
          echo "usage: claude-notify {notification|stop|subagent-stop}" >&2
          exit 2
          ;;
      esac
    '';
  };

  # Hook attrset assembled from the enabled notification events. Each
  # event maps to one `claude-notify <subcommand>` call. Using
  # optionalAttrs so disabled events don't appear in the rendered JSON
  # (cleaner than emitting `null` placeholders).
  notifyHooks = lib.optionalAttrs cfg.notifications.enable (
    (lib.optionalAttrs cfg.notifications.events.notification {
      Notification = [{
        hooks = [{
          type = "command";
          command = "${notifyScript}/bin/claude-notify notification";
        }];
      }];
    }) //
    (lib.optionalAttrs cfg.notifications.events.stop {
      Stop = [{
        hooks = [{
          type = "command";
          command = "${notifyScript}/bin/claude-notify stop";
        }];
      }];
    }) //
    (lib.optionalAttrs cfg.notifications.events.subagentStop {
      SubagentStop = [{
        hooks = [{
          type = "command";
          command = "${notifyScript}/bin/claude-notify subagent-stop";
        }];
      }];
    })
  );

  mergedSettings = lib.recursiveUpdate
    (cfg.settings // {
      hooks = (cfg.settings.hooks or { }) // parrHooks // notifyHooks;
    })
    { };

  managedJson = pkgs.writeText "claude-code-managed-settings.json"
    (builtins.toJSON mergedSettings);
in
{
  options.modules.programs.claude-code-managed = {
    enable = lib.mkEnableOption "Claude Code managed-settings.json (read-only baseline)";

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      example = lib.literalExpression ''
        {
          permissions.deny = [ "Bash(rm -rf /*)" ];
          apiKeyHelper = "/run/wrappers/bin/op-claude-key";
        }
      '';
      description = ''
        Settings to write into /etc/claude-code/managed-settings.json.
        Claude Code reads this with highest precedence and never writes back.
        Anything here is effectively unmodifiable from the CLI/UI.
      '';
    };

    parrProtocol.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Inject the PARR (Plan, Act, Reflect, Revise) UserPromptSubmit hook.
        Equivalent to the previous programs.claudeCode.hooks.enableParrProtocol
        option, but enforced from managed scope so the user cannot disable it
        by editing ~/.claude/settings.json.
      '';
    };

    # Notification submodule — surfaces Claude Code lifecycle events as
    # desktop toasts and/or tmux popups/status flashes via the
    # `claude-notify` helper rendered above. Defaults match the use case
    # from the original conversation: high-signal Notification → both
    # toast and popup, rate-limited Stop/SubagentStop → status flash.
    notifications = {
      enable = lib.mkEnableOption "Claude Code notification hooks (Notification/Stop/SubagentStop)";

      events = {
        notification = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Fire claude-notify on the Notification hook (Claude wants user
            attention, e.g. waiting on permission or completing a long
            run). High signal — recommended always on.
          '';
        };
        stop = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Fire claude-notify on the Stop hook (every assistant turn).
            Rate-limited by `rateLimitSeconds` so quick back-and-forth
            doesn't spam the status bar.
          '';
        };
        subagentStop = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Fire claude-notify on the SubagentStop hook (spawned subagent
            finished). Rate-limited like Stop.
          '';
        };
      };

      desktopToasts = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Fire a libnotify desktop toast for Notification events. No-ops
          gracefully if notify-send / dbus aren't available.
        '';
      };

      tmuxPopups = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Fire a tmux display-popup for Notification events and
          display-message status flash for Stop/SubagentStop. No-ops
          gracefully if $TMUX isn't set.
        '';
      };

      terminalBell = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Emit a terminal BEL into Claude's own pane on Notification and
          (rate-limited) Stop/SubagentStop events, written to /dev/tty.
          With `monitor-bell on` + `bell-action none` in the tmux config
          (home/shell/tmux), tmux flashes that window's status-bar cell
          (red + 🔔) when Claude is in a background window — a quiet,
          visual-only "needs attention" indicator with no audible beep.
          No-ops outside a tty (headless / CI).
        '';
      };

      rateLimitSeconds = lib.mkOption {
        type = lib.types.int;
        default = 10;
        description = ''
          Suppress repeat Stop/SubagentStop events within this many
          seconds of the previous one. Notification events are never
          rate-limited — they always fire.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."claude-code/managed-settings.json" = {
      source = managedJson;
      mode = "0644";
    };
  };
}
