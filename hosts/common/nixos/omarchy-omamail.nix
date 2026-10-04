# Omamail reopens its window at login if it was open at logout, and has no
# setting to stop that.
{ pkgs, ... }:
{
  home-manager.users.olafkfreund.systemd.user.services.omamail-no-restore = {
    Unit = {
      Description = "Keep the Omamail window closed at login";
      Before = [ "graphical-session-pre.target" ];
      ConditionPathExists = "%h/.config/omamail/window.json";
    };
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "omamail-no-restore" ''
        f="$HOME/.config/omamail/window.json"
        ${pkgs.jq}/bin/jq '.windowOpen = false' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
      '';
    };
    Install.WantedBy = [ "graphical-session-pre.target" ];
  };
}
