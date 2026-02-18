_: {
  imports = [
    ./firewall.nix
  ];

  # Consolidated security configuration
  security = {
    sudo = {
      wheelNeedsPassword = false;
      # Fix for "no new privileges" flag error
      execWheelOnly = true;
    };
    # This ensures sudo doesn't get the "no new privs" flag
    unprivilegedUsernsClone = true;

    polkit = {
      enable = true;
      extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (
            subject.isInGroup("users")
              && (
                action.id == "org.freedesktop.login1.reboot" ||
                action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
                action.id == "org.freedesktop.login1.power-off" ||
                action.id == "org.freedesktop.login1.power-off-multiple-sessions"
              )
            )
          {
            return polkit.Result.YES;
          }
        })
      '';
    };
  };
}
