{ config
, lib
, pkgs
, ...
}:
# GitHub Actions runners for nixarchy's heavy checks.
#
# nixarchy has two checks that cannot run on a hosted runner, and the numbers
# are the reason rather than a preference: checks.install-iso builds a 5.6 GB
# image, boots it, and installs a 15.3 GB closure into a qcow2 -- about an hour
# wall clock and roughly 16 GB of build directory. A GitHub-hosted runner has
# 14 GB of disk and no nested virtualisation worth the name.
#
# Shared by every host that runs one. The two things that genuinely differ per
# machine are `buildDir` -- which disk absorbs those 16 GB -- and the runner's
# name, taken from the hostname. Everything else here was paid for once and
# should not have to be rediscovered on the next host: see the comments on
# `replace`, `extraPackages` and the absent `workDir`, each of which cost an
# evening.
let
  cfg = config.services.nixarchy-runner;
in
{
  options.services.nixarchy-runner = {
    enable = lib.mkEnableOption "GitHub Actions runner for the nixarchy repository";

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/olafkfreund/nixarchy";
      description = "Repository the runner registers against.";
    };

    buildDir = lib.mkOption {
      type = lib.types.path;
      example = "/mnt/games/nix-build";
      description = ''
        Where nix builds. Deliberately has no default: it is the setting that
        decides whether an ISO test finishes or wedges, and the right answer is
        a property of the host's disks rather than something this module can
        guess.

        Pick for sustained write throughput and free space, in that order. A VM
        test that runs out of room does not fail cleanly -- qemu takes an I/O
        error mid-install and the test hangs until something times out, which
        reads as flakiness rather than as a full disk. A slow disk fails the
        same way: an SMR drive collapses to single-digit MB/s once its cache
        band fills, and a 16 GB VM install is exactly that write pattern, so
        pointing builds at the roomiest disk in the machine can reproduce the
        hang it was meant to prevent.

        Note this is set machine-wide, not just for the runner: there is one
        nix daemon, so every build on the host follows. If the store is on a
        different filesystem, build output is copied rather than renamed at the
        end -- real, and the price of not building on the root filesystem.
      '';
    };

    instances = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = ''
        How many runners to register, and therefore how many jobs this machine
        will accept at once -- a runner takes one job at a time, so this is the
        only lever there is.

        Two by default. One meant a release build, which owns the machine for
        hours, queued every other check behind it; and because GitHub keeps
        only one pending run per concurrency group, a third arrival cancelled
        the waiting second. The install check went a whole day without a CI
        result on a day it passed repeatedly by hand.

        Raise it only against cores and RAM you can spare while a VM test is
        running. The point is to stop one long job monopolising the machine,
        not to parallelise the queue.
      '';
    };

    extraLabels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "nixos" "kvm" "big" ];
      description = ''
        Labels the workflow selects on. `nixos` and `kvm` say what the machine
        is; `big` says it has room for the ISO test, so a future lighter runner
        can carry the same `nixos` label without being handed an hour-long job.

        Hosts sharing a label share a queue: GitHub hands a job to whichever
        matching runner is free. That is the point when you add a second
        machine, and it is also why a host that should not receive heavy jobs
        must not claim `big`.
      '';
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = config.age.secrets."api-github-token".path;
      defaultText = lib.literalExpression ''config.age.secrets."api-github-token".path'';
      description = ''
        A file holding a GitHub personal access token with `repo` scope. Not a
        registration token: those expire in an hour, and this service has to
        re-register itself after a rebuild with nobody present.

        This reuses the host's general GitHub credential rather than carrying
        its own. That secret is `0600 olafkfreund:users` and the runner runs as
        a dynamic user, which looks like it cannot work and does: the module's
        registration step is prefixed `+` in ExecStartPre, so systemd runs it
        as root, and it copies the token into the state directory for the
        service user. The original is then in InaccessiblePaths, so the runner
        process itself never sees it.

        The cost of sharing it is worth knowing: rotating the general token
        deregisters every runner using it, and the symptom is "the nightly
        stopped running" rather than anything that mentions a token.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Root-owned and 0755: the daemon writes here as root, and nix refuses a
    # world-writable build directory outright.
    systemd.tmpfiles.rules = [
      "d ${cfg.buildDir} 0755 root root -"
    ];

    # Both of these, and the second is the one that actually decides it now.
    #
    # TMPDIR on the nix-daemon unit was the whole answer until nix grew a
    # `build-dir` setting, which defaults to /nix/var/nix/builds -- on the root
    # filesystem -- and takes precedence. On p510 that made the TMPDIR line go
    # quietly inert across a nix bump: it still read as correct, /home/nix-build
    # had zero entries after months, and every build had moved back to /. The
    # symptom was CI dying of ENOSPC on a machine with three disks, and the
    # error surfaced four levels above the cause as a failed ESP assertion
    # (#1643).
    #
    # Keep both. TMPDIR still governs anything that reads the environment
    # rather than the setting, and dropping it would move that half back to /
    # without any error saying so.
    systemd.services.nix-daemon.environment.TMPDIR = cfg.buildDir;
    nix.settings.build-dir = cfg.buildDir;

    # One runner runs one job. That is not a setting, it is what a runner is,
    # so "let this host take two jobs at once" means two runner instances.
    #
    # The first instance keeps the name it registered under -- `<host>-nixarchy`
    # with no suffix. Renaming it would leave a stale offline entry behind and
    # re-register a runner that is working, for nothing.
    services.github-runners = lib.listToAttrs (
      map
        (
          i:
          let
            suffix = lib.optionalString (i > 1) "-${toString i}";
          in
          lib.nameValuePair "nixarchy${suffix}" {
            inherit (cfg) url tokenFile extraLabels;
            enable = true;
            name = "${config.networking.hostName}-nixarchy${suffix}";

            # No workDir. It is tempting to move this too and it is the wrong
            # lever: the work directory holds a git checkout, and the sixteen
            # gigabytes belong to the nix build, which happens in the daemon's
            # build directory -- already pointed at cfg.buildDir above. Left
            # unset, the module uses its StateDirectory, which systemd creates
            # with the right ownership for the dynamic user.
            #
            # Setting it cost an evening: a directory made by tmpfiles as
            # root:root is not writable by a DynamicUser, and the runner
            # registers with GitHub successfully before failing to symlink its
            # own _diag into it. So the runner exists in the repository's
            # settings and has never once run.

            # Re-register over a runner that already has this name. Without it
            # the very first real start fails:
            #
            #   √ Connected to GitHub
            #   A runner exists with the same name p510-nixarchy.
            #
            # Authentication succeeds and registration is refused, so the
            # failure reads like a token problem and is not one.
            #
            # It is also the steady-state need, not just a one-off cleanup: a
            # non-ephemeral runner keeps its GitHub-side registration across
            # rebuilds, and the configure step re-runs whenever the unit's
            # config changes.
            replace = true;

            # Not ephemeral. An ephemeral runner unregisters after every job,
            # which is the right shape for untrusted PRs and the wrong one
            # here: this runs against a repository we own, and re-registering
            # costs a token round trip before every job.
            ephemeral = false;

            # A checkout, a flake, and the tools the workflow calls directly.
            # nixos-rebuild is not among them: nothing here rebuilds the host.
            #
            # The rule, because it has now been learned twice: a step shell
            # here has coreutils, git and what is named in this list. Anything
            # else has to be added before a workflow can use it, and the
            # failure is exit 127 at the end of a job that otherwise worked.
            # `gawk` was the first (an ISO built perfectly, then `awk` died);
            # `gh` was the second, one workflow later, killing `gh release
            # create` after both ISOs had built, split and had notes written.
            extraPackages = with pkgs; [
              git
              gawk
              gh
              gnutar
              gzip
              openssh
              coreutils
              jq
            ];

            serviceOverrides = {
              # The VM tests need KVM, and the runner's dynamic user needs to
              # be let near it. Without this the tests still pass and take ten
              # times as long, under TCG, which is the kind of regression
              # nobody attributes to a permission.
              DeviceAllow = [ "/dev/kvm rw" ];
              SupplementaryGroups = [ "kvm" ];

              # An hour-long job that is killed at the fifty-ninth minute has
              # cost the whole hour and told nobody anything.
              TimeoutStartSec = "0";
            };
          }
        )
        (lib.range 1 cfg.instances)
    );
  };
}
