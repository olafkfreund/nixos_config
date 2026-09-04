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

  # Announce-before-you-disrupt, enforced rather than remembered.
  #
  # Several agents work these machines at once, and tonight three of them
  # collided: a deploy restarted logind and took a desktop session with it, a
  # garbage collection ran against a disk a CI VM test was building on, and a
  # daemon restart landed mid-build. Each was individually reasonable and each
  # broke work someone else had in flight.
  #
  # The convention "say what you are about to do, and look whether anyone
  # objects" is the fix, and the p510 guard below is the proof that a
  # convention needs a mechanism: it held only as long as the model remembered
  # it. So this is the same shape -- PreToolUse can veto, exit 2 denies and
  # hands the reason back to the model, which then has the bus tools to do the
  # announcing with.
  #
  # It is a prompt, not a wall. AGENT_BUS_ANNOUNCED=1 in the command clears it,
  # which an agent sets *after* posting. That is deliberate: these are our own
  # agents, so the goal is a reliable interruption at the right moment rather
  # than a control someone has to defeat. Anyone who sets the variable without
  # posting has decided to, which is different from forgetting.
  #
  # Read-only inspection stays frictionless -- `nix build`, `systemctl status`,
  # plain ssh -- and the user's own shell is untouched.
  busAnnounceScript = pkgs.writeShellScript "claude-bus-announce-guard.sh" ''
    payload="$(cat)"
    cmd="$(${pkgs.jq}/bin/jq -r '.tool_input.command // empty' <<<"$payload" 2>/dev/null)"
    [ -n "$cmd" ] || exit 0

    # The agent's own escape hatch, set after it has posted.
    case "$cmd" in *AGENT_BUS_ANNOUNCED=1*) exit 0 ;; esac

    # Activating a generation, reclaiming disk, restarting shared services, or
    # taking a machine down. Note `nix build` and `systemctl status` are absent
    # on purpose.
    disruptive='nixos-rebuild[[:space:]]+[^|;]*(switch|boot|test)'
    disruptive="$disruptive"'|nh[[:space:]]+os[[:space:]]+(switch|boot|test)'
    disruptive="$disruptive"'|(^|[[:space:]])nhs([[:space:]]|$)'
    # `just deploy-*` and also `just <host>`: the deploy recipes here are
    # named after the machine (`just p510`), so a deploy-only pattern misses
    # the most common way anyone actually deploys.
    disruptive="$disruptive"'|just[[:space:]]+[a-z-]*deploy'
    disruptive="$disruptive"'|just[[:space:]]+(p510|p620|razer)([[:space:]]|$)'
    disruptive="$disruptive"'|nix-collect-garbage|nix[[:space:]]+store[[:space:]]+optimise'
    disruptive="$disruptive"'|systemctl[[:space:]]+[^|;]*(restart|stop)'
    disruptive="$disruptive"'|(^|[[:space:]])(reboot|poweroff|shutdown)([[:space:]]|$)'

    if printf '%s' "$cmd" | ${pkgs.gnugrep}/bin/grep -qE "($disruptive)"; then
      echo "BLOCKED: this would disrupt a host other agents may be working on." >&2
      echo "" >&2
      echo "Before running it:" >&2
      echo "  1. read_new(\"#agents:freundcloud.org.uk\") -- check whether anyone has" >&2
      echo "     claimed this host or has a long job in flight." >&2
      echo "  2. post(...) what you are about to do, on which host, and roughly" >&2
      echo "     how long it will take." >&2
      echo "  3. rerun with AGENT_BUS_ANNOUNCED=1 prefixed." >&2
      echo "" >&2
      echo "If the bus says someone else is mid-flight, wait or ask the user" >&2
      echo "rather than proceeding -- that is the whole point of checking." >&2
      exit 2
    fi
    exit 0
  '';

  # The other half of the bus, and the half that was missing.
  #
  # `busAnnounceScript` above is the only thing that reliably makes an agent
  # touch the bus, and it fires on disruptive commands -- so the room filled up
  # with announcements and end-of-session write-ups and almost no dialogue. Not
  # because agents will not answer each other: because nothing tells them they
  # were asked. An agent posts a question and stops; the reply can only arrive
  # if some other agent later happens to call read_new and happens to still
  # care. One question sat unanswered for two hours and was then answered
  # independently by someone who had never seen it asked.
  #
  # Stop is the right moment. It is the one point where an agent is idle, still
  # holds the context that makes the answer cheap, and is about to throw it
  # away. Exit 2 hands the pending messages back and asks for a reply -- the
  # same mechanism the announce guard uses, for the same reason.
  #
  # Two things stop this becoming a nag loop: `--peek` advances a cursor of its
  # own, so a message wakes an agent exactly once, and `stop_hook_active` is
  # honoured so a turn that is already a continuation is left alone. Peek also
  # skips the session's own messages -- waking an agent with its own words is a
  # loop it cannot tell from a real question.
  busPeekScript = pkgs.writeShellScript "claude-bus-peek.sh" ''
    payload="$(cat)"

    # Already continuing because of a Stop hook: let the turn end.
    case "$(${pkgs.jq}/bin/jq -r '.stop_hook_active // false' <<<"$payload")" in
      true) exit 0 ;;
    esac

    # The identity has to match the one the MCP server registered for this
    # session, and that is derived from the session id. A hook is not
    # guaranteed the environment variable, but the payload always carries the
    # value -- reading it here is what keeps the two halves the same agent.
    session="$(${pkgs.jq}/bin/jq -r '.session_id // empty' <<<"$payload")"
    [ -n "$session" ] || exit 0
    export CLAUDE_CODE_SESSION_ID="$session"

    export MATRIX_HOMESERVER=https://matrix.freundcloud.org.uk
    export MATRIX_SERVER_NAME=freundcloud.org.uk
    export MATRIX_REGISTRATION_TOKEN_FILE=${config.age.secrets."matrix-registration-token".path}
    export MATRIX_ADMIN_TOKEN_FILE=${config.age.secrets."agent-bus-matrix-token".path}

    # Exit 1 means there is something addressed to this session; anything else
    # (including a homeserver that is down) means get out of the way.
    if pending="$(${pkgs.customPkgs.agent-bus-mcp}/bin/agent-bus-mcp --peek)"; then
      exit 0
    fi

    echo "$pending" >&2
    echo "Reply in a thread on the event id shown -- post(thread=\"\$event_id\") --" >&2
    echo "then stop. If it is not something you can answer, say so briefly:" >&2
    echo "silence is indistinguishable from nobody having read it, which is the" >&2
    echo "failure this hook exists to fix." >&2
    exit 2
  '';

  busPeekHooks = lib.optionalAttrs cfg.busPeekWake.enable {
    Stop = [{
      hooks = [{
        type = "command";
        command = toString busPeekScript;
        timeout = 15;
      }];
    }];
  };

  busAnnounceHooks = lib.optionalAttrs cfg.busAnnounceGuard.enable {
    PreToolUse = [{
      matcher = "Bash";
      hooks = [{
        type = "command";
        command = toString busAnnounceScript;
        timeout = 5;
      }];
    }];
  };

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

    # Small ring-buffered trace in tmpfs. Hook firing order is not documented
    # and had to be established empirically (SubagentStop turned out not to
    # mean what its name suggests for backgrounded agents); keep the evidence
    # trail so the next surprise is diagnosable without a redeploy.
    log="$dir/trace.log"
    printf '%s %-5s -> %s\n' "$(date +%H:%M:%S)" "$action" "$n" >>"$log" 2>/dev/null
    if [ "$(wc -l <"$log" 2>/dev/null || echo 0)" -gt 200 ]; then
      tail -n 100 "$log" >"$log.tmp" 2>/dev/null && mv "$log.tmp" "$log" 2>/dev/null
    fi

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
        busAnnounceHooks
        busPeekHooks
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

    busPeekWake.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Wake an agent at the end of its turn when a bus message names it.

        The bus is pull-only and an agent reads it once, at the start of a
        session -- before it has done the work that produces a question, and
        before anyone has answered. So a question reaches its target only by
        luck, and the room looks dead while it is busy. This makes the delivery
        deterministic: a Stop hook peeks for messages naming this session and,
        if there are any, denies the stop and hands them back.

        Wakes once per message (peek keeps its own cursor, separate from
        read_new's), never on the session's own messages, and never on a turn
        that is already a Stop-hook continuation. A homeserver that is
        unreachable is not an error -- the turn simply ends.
      '';
    };

    busAnnounceGuard.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Require an agent to announce on the agent bus before running a command
        that disrupts a shared host -- deploys, garbage collection, store
        optimise, service restarts, reboots.

        Denies the call with instructions rather than silently allowing it, so
        the rule holds whether or not the model remembers it. The agent posts
        its intent with the bus MCP tools, then reruns with
        AGENT_BUS_ANNOUNCED=1.

        Read-only work is unaffected: `nix build`, `systemctl status` and plain
        ssh never match, and the user's own interactive shell is untouched.
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
