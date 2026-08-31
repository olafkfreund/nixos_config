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
# p510 has 40 cores, 94 GB of RAM, /dev/kvm, and 840 GB free on /mnt/img_pool.
#
# The build directory is the part that is easy to get wrong. Nix builds in
# TMPDIR, which on this machine is /tmp on the root filesystem with 55 GB free
# and everything else competing for it. A VM test that runs out of room there
# does not fail cleanly -- qemu takes an I/O error mid-install and the test
# hangs until something times out, which reads as flakiness rather than as a
# full disk. So the daemon is pointed at the pool.
let
  cfg = config.services.nixarchy-runner;
  pool = "/mnt/img_pool";
in
{
  options.services.nixarchy-runner = {
    enable = lib.mkEnableOption "GitHub Actions runner for the nixarchy repository";

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/olafkfreund/nixarchy";
      description = "Repository the runner registers against.";
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
      "d ${pool}/nix-build 0755 root root -"
    ];

    # Where nix builds. See the note at the top: this is the setting that
    # decides whether an ISO test finishes or wedges.
    systemd.services.nix-daemon.environment.TMPDIR = "${pool}/nix-build";

    services.github-runners.nixarchy = {
      inherit (cfg) url tokenFile;
      enable = true;
      name = "p510-nixarchy";

      # `nixos` and `kvm` are what the workflow selects on. `big` says this
      # runner has room for the ISO test, so a future lighter runner can carry
      # the same nixos label without being handed an hour-long job.
      extraLabels = [
        "nixos"
        "kvm"
        "big"
      ];

      # No workDir. It is tempting to put this on the pool too and it is the
      # wrong lever: the work directory holds a git checkout, and the sixteen
      # gigabytes belong to the nix build, which happens in the daemon's
      # TMPDIR -- already pointed at the pool above. Left unset, the module
      # uses its StateDirectory, which systemd creates with the right
      # ownership for the dynamic user.
      #
      # Setting it cost an evening: a directory made by tmpfiles as root:root
      # is not writable by a DynamicUser, and the runner registers with GitHub
      # successfully before failing to symlink its own _diag into it. So the
      # runner exists in the repository's settings and has never once run.

      # Not ephemeral. An ephemeral runner unregisters after every job, which
      # is the right shape for untrusted PRs and the wrong one here: this runs
      # nightly against a repository we own, and re-registering costs a token
      # round trip before every job.
      ephemeral = false;

      # A checkout, a flake, and the tools the workflow calls directly.
      # nixos-rebuild is not among them: nothing here rebuilds this machine.
      extraPackages = with pkgs; [
        git
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
    };
  };
}
