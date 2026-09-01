{ config
, lib
, pkgs
, ...
}:
# A GitHub Actions runner for nixarchy's heavy checks.
#
# nixarchy has two checks that cannot run on a hosted runner, and the numbers
# are the reason rather than a preference: checks.install-iso builds a 5.6 GB
# image, boots it, and installs a 15.3 GB closure into a qcow2 -- about an hour
# wall clock and roughly 16 GB of build directory. A GitHub-hosted runner has
# 14 GB of disk and no nested virtualisation worth the name.
#
# p510 has 40 cores, 94 GB of RAM, /dev/kvm, and 825 GB free on /home.
#
# The build directory is the part that is easy to get wrong, and it is wrong in
# two different ways here.
#
# Nix builds in TMPDIR, which on this machine is /tmp on the root filesystem
# with 47 GB free and everything else competing for it. A VM test that runs out
# of room there does not fail cleanly -- qemu takes an I/O error mid-install and
# the test hangs until something times out, which reads as flakiness rather than
# as a full disk. So the daemon has to be pointed somewhere else.
#
# Somewhere else is /home (/dev/sdd1, WD10EZEX, 7200 rpm CMR), NOT
# /mnt/img_pool. The pool has the most free space and is the worst possible
# target: /dev/sdb1 is an ST1000LM035, a drive-managed SMR disk that collapses
# to single-digit MB/s once its cache band is full, and a 16 GB VM install is
# exactly the sustained-write pattern that fills it. Pointing builds there
# would have reproduced the hang it was meant to prevent, with the disk as the
# cause instead of the free-space figure. Measured, same host, same day:
#
#                    sequential 512M    4M writes, O_DSYNC
#   /home            125 MB/s           59.4 MB/s
#   /mnt/img_pool    (SMR)              ~9.5 MB/s previously measured
#
# /home has its own history of filling up -- it is where per-commit container
# images have run away before -- so this shares a filesystem with something that
# needs watching. 16 GB against 825 GB free is not the thing that will fill it.
#
# /nix/store is on the root disk either way, so build output is copied across
# filesystems rather than renamed at the end. That cost is identical for any
# TMPDIR that is not on /, and is not a reason to prefer one of these.
let
  cfg = config.services.nixarchy-runner;
  buildDir = "/home/nix-build";
in
{
  options.services.nixarchy-runner = {
    enable = lib.mkEnableOption "GitHub Actions runner for the nixarchy repository";

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/olafkfreund/nixarchy";
      description = "Repository the runner registers against.";
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
        deregisters this runner, and the symptom is "the nightly stopped
        running" rather than anything that mentions a token.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Where nix builds. Root-owned and 0755: the daemon writes here as root,
    # and nix refuses a world-writable build directory outright.
    systemd.tmpfiles.rules = [
      "d ${buildDir} 0755 root root -"
    ];

    # Where nix builds. See the note at the top: this is the setting that
    # decides whether an ISO test finishes or wedges.
    systemd.services.nix-daemon.environment.TMPDIR = buildDir;

    # One runner runs one job. That is not a setting, it is what a runner is,
    # so "let p510 take two jobs at once" means two runner instances.
    #
    # Why it is worth doing: a release build occupies this machine for hours,
    # and while it does, every other check queues behind it. GitHub keeps only
    # ONE pending run per concurrency group, so a third arrival cancels the
    # waiting second -- which is how checks.install came to have no CI success
    # on a day it passed three times locally. A release should not blind the
    # checks.
    #
    # Two, not more. Each of these jobs boots a VM and wants real cores and
    # real memory; two heavy jobs on 40 cores and 94 GB is comfortable, and
    # the point here is to stop one long job monopolising the machine, not to
    # parallelise the queue.
    #
    # The first instance keeps the name it registered under. Renaming it would
    # leave `p510-nixarchy` behind as a stale offline entry and re-register a
    # runner that is working, for nothing.
    services.github-runners = lib.listToAttrs (
      map
        (
          i:
          let
            suffix = lib.optionalString (i > 1) "-${toString i}";
          in
          lib.nameValuePair "nixarchy${suffix}" {
            inherit (cfg) url tokenFile;
            enable = true;
            name = "p510-nixarchy${suffix}";

            # `nixos` and `kvm` are what the workflow selects on. `big` says this
            # runner has room for the ISO test, so a future lighter runner can carry
            # the same nixos label without being handed an hour-long job.
            extraLabels = [
              "nixos"
              "kvm"
              "big"
            ];

            # No workDir. It is tempting to move this too and it is the wrong lever: the work directory holds a git checkout, and the sixteen
            # gigabytes belong to the nix build, which happens in the daemon's
            # TMPDIR -- already pointed at /home/nix-build above. Left unset, the module
            # uses its StateDirectory, which systemd creates with the right
            # ownership for the dynamic user.
            #
            # Setting it cost an evening: a directory made by tmpfiles as root:root
            # is not writable by a DynamicUser, and the runner registers with GitHub
            # successfully before failing to symlink its own _diag into it. So the
            # runner exists in the repository's settings and has never once run.

            # Re-register over a runner that already has this name. Without it the
            # very first real start fails, because the name was already taken by a
            # registration left behind while this module was being written:
            #
            #   √ Connected to GitHub
            #   A runner exists with the same name p510-nixarchy.
            #
            # Authentication succeeds and registration is refused, so the failure
            # reads like a token problem and is not one. The module's own note about
            # the workDir dead end says that runner "exists in the repository's
            # settings and has never once run" -- this is that runner, still there.
            #
            # It is also the steady-state need, not just a one-off cleanup: a
            # non-ephemeral runner keeps its GitHub-side registration across
            # rebuilds, and the configure step re-runs whenever the unit's config
            # changes. Deleting the stale one by hand fixes today; this fixes every
            # time after it.
            replace = true;

            # Not ephemeral. An ephemeral runner unregisters after every job, which
            # is the right shape for untrusted PRs and the wrong one here: this runs
            # nightly against a repository we own, and re-registering costs a token
            # round trip before every job.
            ephemeral = false;

            # A checkout, a flake, and the tools the workflow calls directly.
            # nixos-rebuild is not among them: nothing here rebuilds this machine.
            extraPackages = with pkgs; [
              git
              # gawk, because its absence is what broke the first real nightly:
              # the step shell is a Nix bash carrying coreutils and not much else,
              # and `awk` in a workflow step died with exit 127 after the ISO had
              # built perfectly well. The workflow no longer needs it; the next
              # one written should not have to find this out again.
              gawk
              gnutar
              gzip
              openssh
              coreutils
              jq
            ];

            serviceOverrides = {
              # The VM tests need KVM, and the runner's dynamic user needs to be let
              # near it. Without this the tests still pass and take ten times as
              # long, under TCG, which is the kind of regression nobody attributes to
              # a permission.
              DeviceAllow = [ "/dev/kvm rw" ];
              SupplementaryGroups = [ "kvm" ];

              # An hour-long job that is killed at the fifty-ninth minute has cost
              # the whole hour and told nobody anything.
              TimeoutStartSec = "0";
            };
          }
        )
        (lib.range 1 cfg.instances)
    );
  };
}
