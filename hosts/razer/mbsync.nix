{ pkgs
, ...
}: {
  systemd.user.timers.mbsync = {
    Unit.Description = "mbsync";
    Timer.OnBootSec = "10m";
    Timer.OnUnitInactiveSec = "10m";
    Timer.Unit = "mbsync.service";
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.mbsync = {
    Service.Type = "oneshot";
    Service.ExecStart = ''
      -${pkgs.isync}/bin/mbsync -a --quiet
    '';
  };
}
