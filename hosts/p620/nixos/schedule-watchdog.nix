# Starts a nixarchy workflow GitHub's scheduler missed or delayed, and cancels
# GitHub's late copy of one it started (olafkfreund/nixarchy#1942). On p620
# because a GitHub cron is the scheduler that fails; the decisions and their
# check live in nixarchy, at the script's path below.
{ inputs, pkgs, ... }:
let
  script = "${inputs.nixarchy}/.github/scripts/schedule-watchdog.sh";
  run = pkgs.writeShellScript "nixarchy-schedule-watchdog" ''
    # Read at every tick, so a rotated token is picked up without a rebuild.
    GH_TOKEN=$(cat /run/agenix/api-github-token) || exit 1
    export GH_TOKEN
    exec ${pkgs.bash}/bin/bash ${script}
  '';
in
{
  systemd.user.services.nixarchy-schedule-watchdog = {
    description = "Start nixarchy workflows GitHub's scheduler missed";
    unitConfig.ConditionUser = "olafkfreund";
    path = with pkgs; [
      gh
      jq
      coreutils
      gawk
      gnugrep
      gnused
      libnotify
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = run;
    };
  };
  systemd.user.timers.nixarchy-schedule-watchdog = {
    description = "Check nixarchy's scheduled workflows every 5 minutes";
    wantedBy = [ "timers.target" ];
    unitConfig.ConditionUser = "olafkfreund";
    timerConfig = {
      OnCalendar = "*:0/5";
      Persistent = false;
    };
  };
}
