{ pkgs, ... }: {
  services.atuin = {
    enable = true;
    package = pkgs.atuin;
  };

  # atuin-server connects to postgres over the unix socket with peer auth, which
  # resolves the client UID through NSS. Under DynamicUser the UID is allocated at
  # runtime, so if nscd is restarting in the same activation batch the lookup
  # returns nothing, libpq sends the user as "unknown", and postgres rejects it.
  # The unit ordering (After/Requires=postgresql.target) doesn't help — postgres
  # is up; it's the name lookup that isn't. nixpkgs' module sets no Restart=, so
  # that one-off blip is terminal and `nh os switch` fails the whole deploy on it.
  # Retrying is enough: the next attempt resolves the user fine.
  systemd.services.atuin.serviceConfig = {
    Restart = "on-failure";
    RestartSec = 2;
  };
}
