{
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.waypipe];
  systemd.user.services = {
    waypipe-client = {
      Unit = {
        Description = "Waypipe client for SSH Wayland forwarding";
        After = ["graphical-session.target"];
      };
      Service = {
        ExecStartPre = "${lib.getExe' pkgs.coreutils "mkdir"} -p %h/.waypipe";
        ExecStart = "${lib.getExe pkgs.waypipe} --socket %h/.waypipe/client.sock client";
        ExecStopPost = "${lib.getExe' pkgs.coreutils "rm"} -f %h/.waypipe/client.sock";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = ["graphical-session.target"];
    };
    waypipe-server = {
      Unit = {
        Description = "Waypipe server for SSH Wayland forwarding";
        After = ["default.target"];
      };
      Service = {
        Type = "simple";
        Environment = "WAYLAND_DISPLAY=wayland-waypipe";
        ExecStartPre = "${lib.getExe' pkgs.coreutils "mkdir"} -p %h/.waypipe";
        ExecStart = "${lib.getExe pkgs.waypipe} --socket %h/.waypipe/server.sock --title-prefix '[%H] ' --login-shell --display wayland-waypipe server -- ${lib.getExe' pkgs.coreutils "sleep"} infinity";
        ExecStopPost = "${lib.getExe' pkgs.coreutils "rm"} -f %h/.waypipe/server.sock %t/wayland-waypipe";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
