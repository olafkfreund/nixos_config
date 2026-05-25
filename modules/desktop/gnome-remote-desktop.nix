{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption mkForce mkOption types;
  cfg = config.features.gnome-remote-desktop;

  # Auto-wire the agenix-encrypted RDP password if the encrypted file
  # exists in the repo. Lets `features.gnome-remote-desktop.enable = true`
  # be sufficient — no per-host age.secrets boilerplate needed.
  rdpSecretFile = ../../secrets/grd-rdp-password.age;
  rdpSecretExists = builtins.pathExists rdpSecretFile;
in
{
  options.features.gnome-remote-desktop = {
    enable = mkEnableOption "GNOME Remote Desktop (system-mode RDP)";

    credentialsFile = mkOption {
      type = types.nullOr types.path;
      default =
        if rdpSecretExists
        then config.age.secrets.grd-rdp-password.path
        else null;
      defaultText = lib.literalExpression ''
        config.age.secrets.grd-rdp-password.path  # when secrets/grd-rdp-password.age exists
      '';
      example = "/run/agenix/grd-rdp-password";
      description = ''
        Path to a file containing the RDP password (plaintext, no trailing
        newline). When set, the grd-bootstrap oneshot writes the password
        into the system gnome-remote-desktop daemon's credential store on
        every boot.

        Auto-defaults to the agenix-decrypted path
        `config.age.secrets.grd-rdp-password.path` when
        `secrets/grd-rdp-password.age` is present in the repo. The file is
        read at runtime — its contents never enter the Nix store.
      '';
    };

    credentialsUser = mkOption {
      type = types.str;
      default = "olafkfreund";
      description = ''
        Username RDP clients authenticate as. Written into the system
        gnome-remote-desktop credentials store alongside the password.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Declare the agenix secret only when the encrypted file is present
    # — keeps the build green pre-`agenix -e` while letting the wiring
    # activate the moment the file is created and re-keyed.
    age.secrets = lib.optionalAttrs rdpSecretExists {
      grd-rdp-password = {
        file = rdpSecretFile;
        owner = cfg.credentialsUser;
        group = "users";
        mode = "0400";
      };
    };

    services = {
      # The system gnome-remote-desktop.service is what serves RDP. It
      # runs as a dedicated `gnome-remote-desktop` system user, stores
      # credentials in a GKeyFile under /var/lib/gnome-remote-desktop/,
      # and does NOT require a logged-in graphical session or an
      # unlocked libsecret keyring — which is what makes RDP-into-the-box
      # reliable on every host class (workstation, laptop, headless).
      gnome.gnome-remote-desktop.enable = true;

      # Completely disable xrdp — port conflicts with GRD on 3389.
      xrdp.enable = lib.mkForce false;

      # mDNS discovery so clients can find the host by .local name.
      avahi = {
        enable = true;
        nssmdns4 = true;
        publish = {
          enable = true;
          addresses = true;
          userServices = true;
        };
      };

      # Disable autologin — RDP doesn't need it, and an autologin session
      # would hold a console seat that the headless daemon could collide
      # with.
      displayManager.autoLogin.enable = false;
      getty.autologinUser = lib.mkForce null;
    };

    systemd = {
      services = {
        xrdp.enable = lib.mkForce false;
        xrdp-sesman.enable = lib.mkForce false;

        gnome-remote-desktop.wantedBy = [ "graphical.target" ];
      };

      # Bootstrap the system daemon's credentials + TLS cert on every
      # boot, sourced from the agenix-decrypted credentialsFile. The
      # system daemon already binds 3389 on its own; this just makes
      # sure the keystore is populated and TLS is in place so clients
      # can actually connect.
      #
      # We deliberately do NOT use `grdctl --system rdp set-credentials`
      # for the password — that call goes through pkexec, which audit-
      # logs the full argv into the journal and would leak the RDP
      # password to anyone with journal read access. Instead we write
      # the GVariant credentials.ini file directly as root.
      services.grd-bootstrap = mkIf (cfg.credentialsFile != null) {
        description = "Bootstrap GNOME Remote Desktop (TLS + RDP credentials)";
        wantedBy = [ "multi-user.target" ];
        after = [ "gnome-remote-desktop.service" ];
        wants = [ "gnome-remote-desktop.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        # polkit gives `pkexec` for the no-secret grdctl calls
        # (set-tls-cert, set-tls-key, enable). Those are safe to put
        # through audit logging — only paths and bare verbs in argv.
        path = with pkgs; [ gnome-remote-desktop openssl coreutils systemd polkit ];
        script = ''
          set -euo pipefail

          statedir=/var/lib/gnome-remote-desktop
          credsdir=$statedir/.local/share/gnome-remote-desktop
          credsfile=$credsdir/credentials.ini

          install -d -o gnome-remote-desktop -g gnome-remote-desktop -m 0700 "$statedir"
          install -d -o gnome-remote-desktop -g gnome-remote-desktop -m 0700 \
            "$statedir/.local" "$statedir/.local/share" "$credsdir"

          # Self-signed RDP TLS cert. Generated once on first boot;
          # subsequent boots reuse the existing cert so clients keep
          # their pinned fingerprint.
          if [ ! -s "$statedir/rdp-tls.crt" ] || [ ! -s "$statedir/rdp-tls.key" ]; then
            openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
              -subj "/CN=${config.networking.hostName}" \
              -keyout "$statedir/rdp-tls.key" \
              -out    "$statedir/rdp-tls.crt"
            chown gnome-remote-desktop:gnome-remote-desktop \
              "$statedir/rdp-tls.crt" "$statedir/rdp-tls.key"
            chmod 0644 "$statedir/rdp-tls.crt"
            chmod 0600 "$statedir/rdp-tls.key"
          fi

          grdctl --system rdp set-tls-cert "$statedir/rdp-tls.crt"
          grdctl --system rdp set-tls-key  "$statedir/rdp-tls.key"
          grdctl --system rdp enable

          # Write credentials.ini directly. Format is GVariant a{sv}:
          #   [RDP]
          #   credentials={'username': <'…'>, 'password': <'…'>}
          # Read password into a variable (strip trailing newline) so we
          # never pass it via env / argv where ps or audit logs could see
          # it. Escape single-quotes + backslashes for GVariant.
          password="$(cat "${cfg.credentialsFile}")"
          password="''${password%$'\n'}"
          escape() { printf %s "$1" | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g"; }
          escaped_user="$(escape "${cfg.credentialsUser}")"
          escaped_pass="$(escape "$password")"
          unset password

          tmpfile="$(mktemp -p "$credsdir" .credentials.ini.XXXXXX)"
          chmod 0600 "$tmpfile"
          chown gnome-remote-desktop:gnome-remote-desktop "$tmpfile"
          {
            printf '[RDP]\n'
            printf "credentials={'username': <'%s'>, 'password': <'%s'>}\n" \
              "$escaped_user" "$escaped_pass"
          } > "$tmpfile"
          mv -f "$tmpfile" "$credsfile"
          unset escaped_pass

          systemctl restart gnome-remote-desktop.service
        '';
      };

      # Disable systemd sleep/suspend on hosts that should always be
      # reachable (workstations, headless servers). Laptops keep suspend
      # so lid-close behaves; the dconf no-sleep policy in
      # home/desktop/gnome/apps.nix already prevents idle suspend
      # during active RDP sessions.
      targets = mkIf (config.host.class or "workstation" != "laptop") {
        sleep.enable = mkForce false;
        suspend.enable = mkForce false;
      };
    };

    # Open firewall ports for GNOME Remote Desktop.
    networking.firewall.allowedTCPPorts = [
      3389 # RDP
      5900 # VNC (legacy fallback, not actively used by system daemon)
    ];
  };
}
