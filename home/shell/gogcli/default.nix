{ config, lib, pkgs, ... }:

# gog-dashboard — feeds splashboard's read_store widgets with Gmail unread,
# Google Tasks, and upcoming Calendar events via gogcli (`gog`).
#
# Splashboard has no command/exec fetcher; its escape hatch is `basic_read_store`,
# which reads $HOME/.splashboard/store/<widget-id>.txt. A systemd user timer runs
# `gog … -j` periodically and writes those store files atomically. When the token
# isn't provisioned yet (or a fetch fails) the collector leaves the previous file
# in place, so splashboard renders the panel empty/quiet rather than erroring.
#
# Token provisioning (headless-friendly, no keyring daemon):
#   1. one-time on a workstation: `gog login <email>` (browser consent)
#   2. `gog auth tokens export <email> <file>`; encrypt as secrets/gogcli-token.age
#   3. agenix decrypts to tokenFile; the import oneshot below seeds the file-based
#      keyring on every host (including p510) before the collector runs.
let
  inherit (lib) mkOption mkEnableOption mkIf mkPackageOption types getExe;
  cfg = config.programs.gogDashboard;
  storeDir = "${config.home.homeDirectory}/.splashboard/store";
in
{
  options.programs.gogDashboard = {
    enable = mkEnableOption "gogcli-fed splashboard email/tasks/events widgets";

    package = mkPackageOption pkgs "gogcli" { };

    account = mkOption {
      type = types.str;
      example = "you@gmail.com";
      description = "Google account email passed to gog as --account.";
    };

    tokenFile = mkOption {
      type = types.str;
      default = "/run/agenix/gogcli-token";
      description = ''
        Path to the agenix-decrypted gogcli refresh-token export. Imported into
        the file-based keyring by the gog-token-import user service. Read at
        runtime only — never enters the Nix store.
      '';
    };

    interval = mkOption {
      type = types.str;
      default = "10m";
      description = "How often the collector refreshes the store files (systemd time span).";
    };

    maxItems = mkOption {
      type = types.ints.positive;
      default = 6;
      description = "Max lines written to each store file (also cap the widget max_items).";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package pkgs.jq ];

    # GOG_HOME keeps gogcli's config/data/state under a stable per-user root so
    # the file-based keyring and the import are deterministic across services.
    home.sessionVariables.GOG_HOME = "${config.home.homeDirectory}/.config/gogcli";

    # Seed the file-based keyring from the agenix token. Idempotent: re-imports
    # on each activation/boot; no-op (no failure) when the token isn't present.
    systemd.user.services.gog-token-import = {
      Unit.Description = "Import gogcli refresh token into the file keyring";
      Service = {
        Type = "oneshot";
        Environment = [ "GOG_HOME=${config.home.homeDirectory}/.config/gogcli" ];
        ExecStart = getExe (pkgs.writeShellScriptBin "gog-token-import" ''
          set -u
          tok="${cfg.tokenFile}"
          [ -r "$tok" ] || { echo "gog token not present at $tok; skipping import"; exit 0; }
          ${getExe cfg.package} auth keyring set file >/dev/null 2>&1 || true
          ${getExe cfg.package} auth tokens import "$tok" >/dev/null 2>&1 || true
        '');
      };
      Install.WantedBy = [ "default.target" ];
    };

    # Collector: pull the three feeds and write store files atomically.
    # jq field paths verified against gogcli 0.19.0 JSON output (events under
    # .events, tasks under .tasks, threads under .threads). On any error or
    # empty result the prior file is left in place so splashboard stays quiet.
    systemd.user.services.gog-dashboard = {
      Unit = {
        Description = "Refresh splashboard gog store (gmail/tasks/events)";
        After = [ "gog-token-import.service" ];
      };
      Service = {
        Type = "oneshot";
        Environment = [ "GOG_HOME=${config.home.homeDirectory}/.config/gogcli" ];
        ExecStart = getExe (pkgs.writeShellScriptBin "gog-dashboard-refresh" ''
          set -u
          GOG=${getExe cfg.package}
          JQ=${getExe pkgs.jq}
          ACCT=${lib.escapeShellArg cfg.account}
          N=${toString cfg.maxItems}
          STORE=${lib.escapeShellArg storeDir}
          mkdir -p "$STORE"

          # $1 = store id, $2... = gog argv (after `gog -a ACCT`), reads stdin jq prog last
          emit() {
            id="$1"; shift
            prog="$1"; shift
            out="$STORE/$id.txt"
            tmp="$out.tmp.$$"
            if "$GOG" -a "$ACCT" --no-input -j "$@" 2>/dev/null \
                 | "$JQ" -r "$prog" 2>/dev/null | head -n "$N" > "$tmp" \
               && [ -s "$tmp" ]; then
              mv -f "$tmp" "$out"
            else
              rm -f "$tmp"
            fi
          }

          # Today's events: "HH:MM  Summary" for timed, bare "Summary" for all-day.
          emit gog_events \
            '.events[]? | (.start.dateTime // "") as $dt | (if $dt != "" then ($dt[11:16] + "  ") else "" end) + (.summary // "(no title)")' \
            calendar events --today

          # Active tasks from the default list: "☐ Title"
          emit gog_tasks \
            '.tasks[]? | select((.status // "") != "completed") | "☐ \(.title // "(untitled)")"' \
            tasks list @default

          # Unread inbox: "● Subject"
          emit gog_email \
            '.threads[]? | "● \(.subject // "(no subject)")"' \
            gmail search "is:unread in:inbox"
        '');
      };
    };

    systemd.user.timers.gog-dashboard = {
      Unit.Description = "Periodic splashboard gog refresh";
      Timer = {
        OnStartupSec = "30s";
        OnUnitActiveSec = cfg.interval;
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
