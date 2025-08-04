{...}: {
  imports = [
    ./ssh-hardening.nix
    # ./firewall.nix  # Temporarily disabled for deployment
  ];
  security.sudo.wheelNeedsPassword = false;
  # Fix for "no new privileges" flag error
  security.sudo.execWheelOnly = true;
  # This ensures sudo doesn't get the "no new privs" flag
  security.unprivilegedUsernsClone = true;
  security.pam.services.hyprlock = {};
  security.pam.services.hyprland.enableGnomeKeyring = true;
  security.pam.services.swaylock = {};
  security.polkit.enable = true;

  security.polkit.extraConfig = ''
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
}
