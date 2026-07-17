{ pkgs, ... }:
# AccountsService avatar for the primary user, from a repo-committed image.
# The DMS greeter (via the freedesktop.accounts getUserIconFile D-Bus call),
# GNOME and the lock screens read the file at /var/lib/AccountsService/icons/
# <user> — which is also AccountsService's default IconFile path, and the value
# the users file's Icon= already points at on every host. We force-copy the
# committed avatar there on each switch (a plain `C` tmpfiles rule would only
# copy when absent and so never replace an existing icon), leaving the stateful
# users file (Session / Languages / …) untouched.
let
  username = "olafkfreund";
  avatar = ../../assets/avatars/olafkfreund.jpg;
in
{
  system.activationScripts.userAvatar.text = ''
    ${pkgs.coreutils}/bin/install -Dm0644 ${avatar} /var/lib/AccountsService/icons/${username}
  '';
}
