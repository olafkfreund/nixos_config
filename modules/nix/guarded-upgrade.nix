{ config, lib, pkgs, ... }:
let
  cfg = config.features.guarded-upgrade;
  python = pkgs.python3.withPackages (ps: [ ps.mcp ps.httpx ]);
  host = config.networking.hostName;
  # razer fetches p620's staged closure as guarded-stage, a user whose only way in is
  # this forced command: three read-only operations, nothing else (nixarchy#1946).
  stagePublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFwH35HvrdT79mUNYeCm1dqoRzP+6tG6XSeZsyNPF7U9";
  p620HostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID2qbg0iSYU7x4k0tJcGdy7Nu8mSWqU0dg7WBv0lH7Zk";
  stageCommand = pkgs.writeShellScript "guarded-stage-command" ''
    case "''${SSH_ORIGINAL_COMMAND:-}" in
      "readlink -f /var/lib/guarded-upgrade/stage-razer") exec ${pkgs.coreutils}/bin/readlink -f /var/lib/guarded-upgrade/stage-razer ;;
      "cat /var/lib/guarded-upgrade/verified") exec ${pkgs.coreutils}/bin/cat /var/lib/guarded-upgrade/verified ;;
      # nix copy --from asks for --serve --write even to download; serve it read-only.
      "nix-store --serve" | "nix-store --serve --write") exec ${config.nix.package}/bin/nix-store --serve ;;
      *) echo "guarded-stage: refused" >&2; exit 1 ;;
    esac
  '';
  # A second hypridle, beside the desktop's own, so its listener cannot be edited away
  # in ~/.config/hypr. It honours idle inhibitors (a video, a call) by default.
  idleConf = pkgs.writeText "guarded-idle.conf" ''
    # Only the desktop's own hypridle handles sleep; this one must not delay it.
    general {
      inhibit_sleep = 0
    }
    listener {
      timeout = 900
      on-timeout = systemctl --user start guarded-idle-beat.service
      on-resume = systemctl --user stop guarded-idle-beat.service
    }
  '';
in
{
  options.features.guarded-upgrade = {
    enable = lib.mkEnableOption "guarded follow-edge system upgrade";
    autoActivate = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow unattended activation after host gates pass. Keep disabled on p620 until the runner drain test passes.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = config.networking.hostName == "p620" || config.networking.hostName == "razer";
          message = "guarded-upgrade supports only p620 and razer";
        }
      ];
      systemd.services.nixos-upgrade = {
        unitConfig = lib.optionalAttrs (config.networking.hostName == "razer") { ConditionACPower = true; };
        serviceConfig = {
          ExecCondition = lib.mkForce "${pkgs.coreutils}/bin/true";
          StateDirectory = "guarded-upgrade";
          StateDirectoryMode = "0755";
          CacheDirectory = "guarded-upgrade";
          NoNewPrivileges = true;
          ProtectHome = true;
        };
        environment = {
          # ProtectHome makes /root read-only: nix's fetcher cache and the bus's
          # cursor database would otherwise fail there on the first real run.
          XDG_CACHE_HOME = "/var/cache/guarded-upgrade";
          XDG_STATE_HOME = "/var/lib/guarded-upgrade";
          PYTHONPATH = "${pkgs.customPkgs.agent-bus-mcp}/share/agent-bus-mcp";
          MATRIX_HOMESERVER = "https://matrix.freundcloud.org.uk";
          MATRIX_SERVER_NAME = "freundcloud.org.uk";
          MATRIX_REGISTRATION_TOKEN_FILE = config.age.secrets."matrix-registration-token".path;
          MATRIX_ADMIN_TOKEN_FILE = config.age.secrets."agent-bus-matrix-token".path;
          GITHUB_TOKEN_FILE = config.age.secrets."api-github-token".path;
          AGENT_BUS_NAME = "guarded-upgrade-${config.networking.hostName}";
        };
        path = with pkgs; [ git nix coreutils systemd openssh curl ];
        script = lib.mkForce ''
          exec ${python}/bin/python ${../../scripts/guarded_upgrade.py} ${config.networking.hostName} ${lib.boolToString cfg.autoActivate}
        '';
      };
    }
    {
      # The idle report the activation gate reads: one file per user, sticky so nobody
      # replaces another's, and trusted only when the session's own user owns it.
      systemd.tmpfiles.rules = [ "d /run/guarded-upgrade-idle 1733 root root -" ];
      systemd.user.services.guarded-idle-report = {
        description = "Tell the guarded upgrade when this session is idle (nixarchy#1946)";
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        path = [ pkgs.systemd ];
        serviceConfig = {
          ExecStart = "${pkgs.hypridle}/bin/hypridle -c ${idleConf}";
          ExecStopPost = "${pkgs.systemd}/bin/systemctl --user stop guarded-idle-beat.service";
          Restart = "on-failure";
          # The rest of the hardening rule does not fit a user unit: docs/applications/guarded-upgrade.md.
          NoNewPrivileges = true;
        };
      };
      # Rewritten every 60 s while idle: the gate refuses a report older than 120 s,
      # so a beat that dies reads as not idle.
      systemd.user.services.guarded-idle-beat = {
        description = "Idle report heartbeat for the guarded upgrade";
        path = [ pkgs.systemd pkgs.coreutils pkgs.gnused pkgs.gnugrep ];
        serviceConfig = {
          ExecStopPost = "${pkgs.coreutils}/bin/rm -f /run/guarded-upgrade-idle/%U";
          NoNewPrivileges = true;
        };
        script = ''
          uid=$(id -u)
          f=/run/guarded-upgrade-idle/$uid
          sid=$(loginctl show-user "$uid" -p Display --value)
          while :; do
            # Inhibitors (a video, a call) reach whoever owns org.freedesktop.ScreenSaver.
            # If that is not our hypridle, its silence proves nothing: report nothing.
            pid=$(busctl --user status org.freedesktop.ScreenSaver 2>/dev/null | sed -n 's/^PID=//p')
            # An inhibitor taken after the timeout only bumps hypridle's count (0.1.8 runs no
            # on-resume for it), and the count is visible only in its log. No startup line
            # from this run means the log is unreadable: report nothing then too.
            inv=$(systemctl --user show -p InvocationID --value guarded-idle-report.service)
            lines=$(journalctl --user _SYSTEMD_INVOCATION_ID="$inv" -o cat --no-pager 2>/dev/null || true)
            locks=$(printf '%s\n' "$lines" | sed -n 's/.*Inhibit locks: \([0-9]*\).*/\1/p' | tail -n 1)
            if [ -n "$pid" ] && grep -qsF ${idleConf} "/proc/$pid/cmdline" \
              && [ -n "$inv" ] && printf '%s\n' "$lines" | grep -q 'found [0-9]* rules' \
              && [ "''${locks:-0}" = 0 ]; then
              printf '{"session": "%s", "reported_session": "%s", "status": "idle", "at": %s}\n' "$sid" "$sid" "$(date +%s)" > "$f.tmp"
              mv -f "$f.tmp" "$f"
            else
              rm -f "$f"
            fi
            sleep 60
          done
        '';
      };
    }
    (lib.mkIf (host == "razer") {
      age.secrets.guarded-stage-key = {
        file = ../../secrets/guarded-stage-key.age;
        mode = "0400";
        owner = "root";
      };
      systemd.services.nixos-upgrade.environment.STAGE_KEY_FILE = config.age.secrets.guarded-stage-key.path;
      # Pinned, so the first connection does not trust whatever answers as p620.
      programs.ssh.knownHosts.p620-guarded-stage = {
        hostNames = [ "p620" ];
        publicKey = p620HostKey;
      };
    })
    (lib.mkIf (host == "p620") {
      # A reboot during a drain leaves the runners closed: finish it now rather than
      # at the next timer run (nixarchy#1967).
      systemd.services.guarded-upgrade-recover = {
        description = "Finish an interrupted guarded upgrade or runner drain";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        # It never switches: a leftover transaction waits for the timer run. A later
        # switch must not rerun it either.
        restartIfChanged = false;
        serviceConfig = {
          Type = "oneshot";
          # Stays active, so a later switch does not run it again.
          RemainAfterExit = true;
          StateDirectory = "guarded-upgrade";
          StateDirectoryMode = "0755";
          CacheDirectory = "guarded-upgrade";
          NoNewPrivileges = true;
          ProtectHome = true;
        };
        environment = {
          XDG_CACHE_HOME = "/var/cache/guarded-upgrade";
          XDG_STATE_HOME = "/var/lib/guarded-upgrade";
          GITHUB_TOKEN_FILE = config.age.secrets."api-github-token".path;
        };
        path = with pkgs; [ nix coreutils systemd ];
        script = ''
          exec ${python}/bin/python ${../../scripts/guarded_upgrade.py} ${host} recover
        '';
      };
      users.groups.guarded-stage = { };
      users.users.guarded-stage = {
        isSystemUser = true;
        group = "guarded-stage";
        shell = pkgs.bash;
        openssh.authorizedKeys.keys = [ "restrict,command=\"${stageCommand}\" ${stagePublicKey}" ];
      };
    })
  ]);
}
