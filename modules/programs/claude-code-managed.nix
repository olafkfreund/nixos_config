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

  # Baseline auto-approved commands — read-only / build / test / format only.
  # Enforced from managed scope so safe repo operations never prompt. Anything
  # that mutates the system (deploys, nixos-rebuild, git commit/push, sudo, rm)
  # is deliberately EXCLUDED and still requires explicit approval.
  baselineAllow = lib.optionals cfg.baselineAllow.enable [
    # Nix evaluation / build / format
    "Bash(nix build:*)"
    "Bash(nix flake check:*)"
    "Bash(nix flake show:*)"
    "Bash(nix flake metadata:*)"
    "Bash(nix eval:*)"
    "Bash(nix fmt:*)"
    "Bash(nix-instantiate:*)"
    "Bash(nixpkgs-fmt:*)"
    "Bash(alejandra:*)"
    "Bash(statix check:*)"
    "Bash(deadnix:*)"
    # just recipes — validation / test / inspection only (no deploys)
    "Bash(just validate)"
    "Bash(just validate-quick)"
    "Bash(just check-syntax)"
    "Bash(just quick-test)"
    "Bash(just test-host:*)"
    "Bash(just test-all:*)"
    "Bash(just test-all-parallel)"
    "Bash(just format)"
    "Bash(just ci)"
    "Bash(just diff:*)"
    "Bash(just ping-hosts)"
    # read-only git
    "Bash(git status:*)"
    "Bash(git diff:*)"
    "Bash(git log:*)"
    "Bash(git show:*)"
    "Bash(git branch:*)"
  ];

  # Auto-format edited .nix files with nixpkgs-fmt (the repo's pre-commit
  # formatter), so files Claude touches stay commit-clean. PostToolUse fires
  # after Write/Edit/MultiEdit; the script no-ops on non-.nix paths and never
  # fails the tool.
  formatScript = pkgs.writeShellScript "claude-nix-format.sh" ''
    payload="$(cat)"
    fp="$(${pkgs.jq}/bin/jq -r '.tool_input.file_path // empty' <<<"$payload" 2>/dev/null)"
    case "$fp" in
      *.nix) [ -f "$fp" ] && ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt "$fp" >/dev/null 2>&1 || true ;;
    esac
    exit 0
  '';

  # p510 is the headless media server: a bad switch takes Plex/*arr/k3d/
  # cloudflared down and it is painful to recover remotely (see the 2026-07
  # disk-full incident). The standing rule is "never deploy p510 unless the
  # user explicitly asks", which until now lived only in CLAUDE.md and agent
  # memory — i.e. it held only as long as the model remembered it. PreToolUse
  # can veto a call, so this turns the convention into an actual guardrail.
  #
  # Blocks only *activating* commands (nixos-rebuild switch/boot/test, nh os,
  # nhs, just deploy) aimed at p510. Deliberately does NOT block `nix build
  # .#nixosConfigurations.p510...` or plain `ssh p510 <read-only>`, so
  # testing and inspection stay frictionless. Exit 2 = deny + feed stderr
  # back to the model so it knows to ask instead of retrying.
  #
  # This only constrains Claude Code's own tool calls; the user's interactive
  # shell is untouched and can always deploy p510 directly.
  deployGuardScript = pkgs.writeShellScript "claude-p510-deploy-guard.sh" ''
    payload="$(cat)"
    cmd="$(${pkgs.jq}/bin/jq -r '.tool_input.command // empty' <<<"$payload" 2>/dev/null)"
    [ -n "$cmd" ] || exit 0

    # No \b adjacent to the alternation group: GNU grep -E silently fails to
    # match `\b(switch|boot|test)\b[^|;]*\bp510\b` against
    # "nixos-rebuild switch --flake .#p510". Verified against 13 cases.
    deploy_verb='nixos-rebuild[[:space:]]+[^|;]*(switch|boot|test)|nh[[:space:]]+os[[:space:]]+(switch|boot|test)|(^|[[:space:]])nhs([[:space:]]|$)|just[[:space:]]+[a-z-]*deploy'
    if printf '%s' "$cmd" | ${pkgs.gnugrep}/bin/grep -qE "($deploy_verb)[^|;]*p510|p510[^|;]*($deploy_verb)"; then
      echo "BLOCKED by managed-settings deploy guard: this command would activate a new generation on p510." >&2
      echo "p510 is the headless media server (Plex, *arr, k3d, cloudflared). Deploying it requires the user's explicit approval." >&2
      echo "Ask the user first. Building (nix build .#nixosConfigurations.p510...) and read-only ssh are allowed." >&2
      exit 2
    fi
    exit 0
  '';

  deployGuardHooks = lib.optionalAttrs cfg.deployGuard.enable {
    PreToolUse = [{
      matcher = "Bash";
      hooks = [{
        type = "command";
        command = toString deployGuardScript;
        timeout = 5;
      }];
    }];
  };

  # Claude Code's Task subagents run in-process with no PTY, so herdr cannot
  # show them as agent rows (it detects exactly one agent per pane). Publish the
  # live count as a pane-metadata token instead, rendered by the $agents entry
  # in [ui.sidebar.agents.rows_by_agent] (home/development/herdr.nix).
  #
  # `reset` on Stop is what keeps this honest: a subagent killed without firing
  # PostToolUse would otherwise leak the counter upward forever. When a turn
  # ends nothing can still be fanned out, so zero is always correct there.
  #
  # No-ops entirely outside herdr (HERDR_ENV guard), so p510 and plain terminals
  # are unaffected.
  subagentScript = pkgs.writeShellScript "claude-herdr-subagents.sh" ''
    action="''${1:-}"
    cat >/dev/null 2>&1 || true   # drain hook stdin; the payload is not needed

    [ "''${HERDR_ENV:-}" = "1" ] || exit 0
    [ -n "''${HERDR_PANE_ID:-}" ] || exit 0
    command -v herdr >/dev/null 2>&1 || exit 0

    dir="''${XDG_RUNTIME_DIR:-/tmp}/claude-herdr-subagents"
    mkdir -p "$dir" 2>/dev/null || exit 0
    # Pane-scoped so two Claude panes never share a counter.
    f="$dir/$(printf '%s' "$HERDR_PANE_ID" | tr -c 'A-Za-z0-9_' '_').count"

    # flock: subagents are dispatched in parallel, so a plain read/modify/write
    # loses updates. Verified with 20 concurrent increments.
    exec 9>"$f.lock" 2>/dev/null || exit 0
    ${pkgs.util-linux}/bin/flock -w 2 9 2>/dev/null || exit 0

    n=$(cat "$f" 2>/dev/null)
    case "$n" in ""|*[!0-9]*) n=0 ;; esac
    case "$action" in
      inc)   n=$((n + 1)) ;;
      dec)   n=$((n - 1)); [ "$n" -lt 0 ] && n=0 ;;
      reset) n=0 ;;
      *)     exit 0 ;;
    esac
    printf '%s' "$n" >"$f" 2>/dev/null

    if [ "$n" -gt 0 ]; then
      herdr pane report-metadata "$HERDR_PANE_ID" \
        --source claude-subagents --token "agents=$n" >/dev/null 2>&1
    else
      herdr pane report-metadata "$HERDR_PANE_ID" \
        --source claude-subagents --clear-token agents >/dev/null 2>&1
    fi
    exit 0
  '';

  # SubagentStart/SubagentStop, NOT PreToolUse/PostToolUse on Task: PostToolUse
  # fires when the *tool call* returns, which for a backgrounded agent is
  # immediately — the counter would drop to zero while the agent still had
  # minutes of work left, i.e. exactly the case this is meant to show.
  subagentHooks = lib.optionalAttrs cfg.subagentMetadata.enable {
    SubagentStart = [{
      hooks = [{ type = "command"; command = "${subagentScript} inc"; timeout = 5; }];
    }];
    SubagentStop = [{
      hooks = [{ type = "command"; command = "${subagentScript} dec"; timeout = 5; }];
    }];
    # Reset on SessionStart, NOT Stop. Stop fires at the end of every assistant
    # turn, but backgrounded subagents deliberately outlive the turn that
    # launched them — resetting there cleared the token ~5s into a 10s agent
    # run, killing the exact case this is meant to show. SessionStart still
    # heals a counter leaked by a subagent that died without firing
    # SubagentStop, just at the next session instead of the next turn.
    SessionStart = [{
      hooks = [{ type = "command"; command = "${subagentScript} reset"; timeout = 5; }];
    }];
  };

  formatHooks = lib.optionalAttrs cfg.formatOnEdit.enable {
    PostToolUse = [{
      matcher = "Write|Edit|MultiEdit";
      hooks = [{
        type = "command";
        command = toString formatScript;
      }];
    }];
  };

  # tmux-ccm (Claude Code Monitor) lifecycle hooks, rendered from the package
  # store path so every rebuild tracks the current ${cfg.tmuxCcm.package}. This
  # replaces the previously seed-once ~/.claude/settings.json entries that
  # pinned a /nix/store path which broke after the package was rebuilt + GC'd.
  ccmHooksDir = "${cfg.tmuxCcm.package}/share/tmux-plugins/tmux-ccm/hooks";
  mkCcmHook = script: [{
    hooks = [{ type = "command"; command = "${ccmHooksDir}/${script}"; timeout = 5000; }];
  }];
  mkCcmNotify = matcher: {
    inherit matcher;
    hooks = [{ type = "command"; command = "${ccmHooksDir}/on-notification.sh"; timeout = 5000; }];
  };
  tmuxCcmHooks = lib.optionalAttrs cfg.tmuxCcm.enable {
    UserPromptSubmit = mkCcmHook "on-prompt-submit.sh";
    Stop = mkCcmHook "on-stop.sh";
    StopFailure = mkCcmHook "on-stop.sh";
    PreToolUse = mkCcmHook "on-pre-tool-use.sh";
    PostToolUse = mkCcmHook "on-pre-tool-use.sh";
    PostToolUseFailure = mkCcmHook "on-pre-tool-use.sh";
    SubagentStart = mkCcmHook "on-pre-tool-use.sh";
    SubagentStop = mkCcmHook "on-pre-tool-use.sh";
    PreCompact = mkCcmHook "on-pre-tool-use.sh";
    PostCompact = mkCcmHook "on-pre-tool-use.sh";
    PermissionRequest = mkCcmHook "on-permission-request.sh";
    PermissionDenied = mkCcmHook "on-permission-denied.sh";
    Notification = [
      (mkCcmNotify "permission_prompt")
      (mkCcmNotify "idle_prompt")
      (mkCcmNotify "elicitation_dialog")
    ];
    SessionEnd = mkCcmHook "on-session-end.sh";
  };

  mergedSettings =
    (cfg.settings // {
      # Per-event list concatenation (NOT shallow //) so hook sets that share
      # an event — e.g. tmux-ccm + parr on UserPromptSubmit, tmux-ccm + notify
      # on Stop/Notification — all survive instead of clobbering each other.
      hooks = lib.zipAttrsWith (_event: lib.concatLists) [
        (cfg.settings.hooks or { })
        parrHooks
        notifyHooks
        formatHooks
        deployGuardHooks
        subagentHooks
        tmuxCcmHooks
      ];
    })
    // lib.optionalAttrs (baselineAllow != [ ]) {
      permissions = (cfg.settings.permissions or { }) // {
        allow = (cfg.settings.permissions.allow or [ ]) ++ baselineAllow;
      };
    };

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

    baselineAllow.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Auto-approve a curated baseline of safe, read-only / build / test /
        format commands (nix build/eval/fmt, just validate/test-*, read-only
        git, statix/deadnix/alejandra) via managed-scope permissions.allow, so
        routine repo operations never trigger a permission prompt. System-
        mutating commands (deploys, nixos-rebuild, git commit/push, sudo, rm)
        are deliberately excluded and still require explicit approval.
      '';
    };

    subagentMetadata.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Publish the live Claude Code Task-subagent count to herdr as a pane
        metadata token, rendered by the $agents entry in the sidebar row
        config (home/development/herdr.nix).

        Subagents run in-process with no PTY, so herdr cannot represent them as
        their own agent rows; this makes an otherwise invisible fan-out visible
        on the parent pane. No-ops outside a herdr pane.
      '';
    };

    deployGuard.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Veto Claude Code Bash calls that would activate a new generation on
        p510 (the headless media server), via a managed-scope PreToolUse hook.
        Enforces the standing "never deploy p510 without explicit approval"
        rule mechanically instead of relying on the model remembering it.

        Building (`nix build .#nixosConfigurations.p510...`) and read-only ssh
        are unaffected, as is the user's own interactive shell.
      '';
    };

    formatOnEdit.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Run nixpkgs-fmt (the repo's pre-commit formatter) on any .nix file
        Claude Code edits, via a managed-scope PostToolUse hook. Keeps touched
        files commit-clean automatically. No-ops on non-.nix paths and never
        fails the tool.
      '';
    };

    tmuxCcm = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Render the tmux-ccm (Claude Code Monitor) lifecycle hooks into
          managed scope, pointing at the package's hook scripts in the nix
          store. Replaces the legacy seed-once ~/.claude/settings.json entries
          that pinned a stale /nix/store path (broke after rebuild + GC).
          Defaults on because every host enabling this module previously had
          these hooks; set false per-host to opt out.
        '';
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.customPkgs.tmux-ccm;
        defaultText = lib.literalExpression "pkgs.customPkgs.tmux-ccm";
        description = "The tmux-ccm package providing share/tmux-plugins/tmux-ccm/hooks/*.sh.";
      };
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
