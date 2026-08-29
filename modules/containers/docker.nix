{ config
, lib
, pkgs
, hostUsers ? [ ]
, ...
}:
let
  inherit (lib) mkOption mkIf mkEnableOption types genAttrs;
  cfg = config.modules.containers.docker;
in
{
  options.modules.containers.docker = {
    enable = mkEnableOption "Docker container support";

    users = mkOption {
      type = types.listOf types.str;
      default = hostUsers; # Use host users as default
      description = "List of users to add to the docker group";
      example = [ "olafkfreund" "workuser" ];
    };

    rootless = mkOption {
      type = types.bool;
      default = false;
      description = "Enable rootless Docker";
    };

    dataRoot = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/home/docker";
      description = ''
        Directory holding image layers, container writable layers and
        volumes. `null` keeps Docker's own default (/var/lib/docker).

        Pick the filesystem deliberately: this path absorbs every container
        write on the host, so it wants free space *and* low write latency.
        An SMR drive is the wrong answer even when it is the emptiest one —
        shingled rewrites collapse sustained random writes to single-digit
        MB/s, which starves image pulls and database fsyncs alike.
      '';
    };
  };

  config = mkIf cfg.enable {
    # docker itself is provided by virtualisation.docker.enable; listing
    # docker-client here collides with it on /bin/docker and completions.
    environment.systemPackages = with pkgs; [
      docker-compose
      docker-gc
      lazydocker
    ];

    # Docker configuration
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;

      # Container logs go to files, not the host journal.
      #
      # nixpkgs defaults this to "journald", and Docker's journald driver
      # assigns priority by STREAM, not by content: stdout -> info, stderr ->
      # err. Every component that logs to stderr therefore lands in the host
      # journal as an error. On p620 that meant k3s inside k3d filing ~94k
      # INFO-level lines ("enqueueing job", SQL DDL, kubelet chatter) at
      # priority 3 in a single boot — 95% of all errors on the host — which
      # makes `journalctl -p err` useless for triage exactly when it matters.
      #
      # "local" keeps `docker logs` and `kubectl logs` working (both read the
      # runtime's own store, not the journal) and rotates on its own, so this
      # also stops container output counting against journald's SystemMaxUse.
      logDriver = "local";
      rootless = {
        enable = cfg.rootless;
        setSocketVariable = cfg.rootless;
      };
      # Explicitly disable Docker Swarm
      daemon.settings = {
        swarm-default-advertise-addr = "";
        # Keep containers alive across a docker.service restart. Every
        # `nixos-rebuild switch` that touches the docker unit restarts it,
        # and without this that tears down every container. On 2026-08-11
        # it killed the k3d server node while it held mounts from an NFS
        # export served by a pod *inside that same cluster*: the unmount
        # blocked forever, docker never got an exit event, and the node was
        # left as a phantom container ("Up 4 days", no network endpoint,
        # unkillable) that only a reboot could clear. Requires swarm off.
        live-restore = true;
      }
      // lib.optionalAttrs (cfg.dataRoot != null) { data-root = cfg.dataRoot; };
    };

    # nixpkgs puts daemon.json in *reloadTriggers*, so a settings change only
    # SIGHUPs dockerd. dockerd's SIGHUP handler re-reads a subset of the file —
    # log-driver is not in it. That is why setting logDriver = "local" above
    # (#1412) landed in the closure on 2026-08-21 and still had not taken
    # effect three days later: the running daemon kept its old journald driver
    # and the k3d node kept filing ~220k INFO lines at priority err per boot.
    #
    # Safe to force a real restart because live-restore keeps containers up
    # across it (see above). Triggering on the settings rather than on the
    # generated daemon.json path keeps this off nixpkgs internals.
    systemd.services.docker.restartTriggers = [
      (builtins.toJSON config.virtualisation.docker.daemon.settings)
    ];

    # Add specified users to docker group
    users.users = genAttrs cfg.users (_username: {
      extraGroups = [ "docker" ];
    });

    # Validation
    assertions = [
      {
        assertion = cfg.rootless -> (cfg.users != [ ]);
        message = "Rootless Docker requires at least one user to be specified";
      }
      {
        assertion = !cfg.rootless -> (builtins.all (user: user != "root") cfg.users);
        message = "Root user should not be added to docker group in non-rootless mode";
      }
    ];

    # Helpful warnings
    warnings = [
      (mkIf (cfg.enable && !cfg.rootless && cfg.users == [ ]) ''
        Docker is enabled but no users are specified.
        Users won't be able to use Docker without being manually added to the docker group.
      '')
      (mkIf (cfg.rootless && cfg.users != [ ]) ''
        Rootless Docker is enabled. Users will have their own Docker daemon instances.
        Consider the security implications and resource usage.
      '')
    ];
  };
}
