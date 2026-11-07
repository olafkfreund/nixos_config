_: {
  imports = [ ];

  # Consolidated security configuration
  security = {
    sudo = {
      # Fix for "no new privileges" flag error
      execWheelOnly = true;
      # No cached approval: an agent sharing the owner's terminal could reuse it (#2759)
      extraConfig = "Defaults timestamp_timeout=0";
    };
    # security.unprivilegedUsernsClone was removed from nixpkgs (2c423e03bb,
    # 2026-08-22) and its assertion now fails the build. Nothing replaces it
    # here because it was already inert: it wrote kernel.unprivileged_userns_clone,
    # a Debian/Arch patch that mainline never carried, and /proc/sys/kernel/
    # unprivileged_userns_clone does not exist on this kernel. Unprivileged user
    # namespaces are governed by user.max_user_namespaces, which sits at its
    # default of 1029777 — i.e. already enabled, and not set anywhere in this
    # repo. Removing the line changes no behaviour.
    #
    # The comment it carried ("ensures sudo doesn't get the no-new-privs flag")
    # was wrong on its own terms: user namespaces have nothing to do with
    # sudo's NoNewPrivileges. execWheelOnly above is the sudo-related setting.

    polkit = {
      enable = true;
      extraConfig = ''
        // Power actions need the administrator's password from every caller, the active session included (#2761).
        polkit.addRule(function (action, subject) {
          if (action.id == "org.freedesktop.login1.reboot" ||
              action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
              action.id == "org.freedesktop.login1.power-off" ||
              action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
              // These imply reboot and default to allowed, so polkit would grant reboot through them.
              action.id.indexOf("org.freedesktop.login1.set-reboot-") == 0) {
            return polkit.Result.AUTH_ADMIN;
          }
        });
      '';
    };
  };
}
