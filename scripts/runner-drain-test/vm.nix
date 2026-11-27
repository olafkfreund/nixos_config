# Isolated NixOS QEMU VM for testing github-runner drain and guarded_upgrade.py (nixarchy#1967).
#
# Defines two system generations:
#   - baseline: boots the VM with 4 self-hosted runners via modules/services/nixarchy-runner.nix
#   - candidate: adds runner-drain-candidate-check.service, which succeeds normally and fails
#     during verification when /etc/runner-drain-test/force-verify-fail exists.
#
# Both closures are registered in the VM's Nix store database at boot so guarded_upgrade.py can
# switch to candidate and roll back to baseline with real switch-to-configuration calls.
{ nixpkgs ? let
    lock = builtins.fromJSON (builtins.readFile ../../flake.lock);
    node = lock.nodes.${lock.nodes.root.inputs.nixpkgs}.locked;
  in
  builtins.fetchTree {
    inherit (node)
      type
      owner
      repo
      rev
      narHash
      ;
  }
, system ? "x86_64-linux"
, repo ? "olafkfreund/nixarchy-drain-test"
, label ? "runner-drain-test"
,
}:
let
  lib = import "${nixpkgs}/lib";

  mkSystem =
    { isCandidate }:
    import "${nixpkgs}/nixos/lib/eval-config.nix" {
      inherit system;
      modules = [
        "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
        ../../modules/services/nixarchy-runner.nix
        (
          { pkgs, ... }:
          {
            system.stateVersion = "25.05";
            networking.hostName = "p620";
            networking.firewall.enable = false;
            boot.loader.grub.enable = false;

            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = [
              (final: _prev: {
                customPkgs = import ../../pkgs { pkgs = final; };
              })
            ];

            virtualisation = {
              memorySize = 4096;
              cores = 4;
              diskSize = 12288;
              graphics = false;
              writableStore = true;
              useHostCerts = false;
              additionalPaths = lib.optionals (!isCandidate) [
                candidate.config.system.build.toplevel
              ];
            };

            users.groups.kvm = { };

            services.openssh = {
              enable = true;
              settings = {
                PermitRootLogin = "prohibit-password";
                PasswordAuthentication = false;
              };
              authorizedKeysFiles = lib.mkForce [
                "/run/runner-drain-test/authorized_keys"
              ];
            };

            services.nixarchy-runner = {
              enable = true;
              url = "https://github.com/${repo}";
              buildDir = "/var/lib/nix-build";
              instances = 4;
              extraLabels = [ label ];
              tokenFile = "/run/runner-drain-test/github-token";
              minFree = 0;
              maxFree = 0;
            };

            systemd.tmpfiles.rules = [
              "d /var/lib/runner-drain-test 0755 root root -"
              "d /var/lib/runner-drain-test/counters 1777 root root -"
              "d /var/lib/guarded-upgrade 0755 root root -"
            ];

            systemd.services = lib.mkMerge [
              (lib.listToAttrs (
                map
                  (
                    i:
                    let
                      suffix = lib.optionalString (i > 1) "-${toString i}";
                    in
                    lib.nameValuePair "github-runner-nixarchy${suffix}" {
                      serviceConfig.ReadWritePaths = [
                        "/var/lib/runner-drain-test/counters"
                      ];
                    }
                  )
                  (lib.range 1 4)
              ))
              {
                home-manager-olafkfreund = {
                  description = "Home Manager environment for olafkfreund (VM test stub)";
                  wantedBy = [ "multi-user.target" ];
                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    DynamicUser = true;
                    ProtectSystem = "strict";
                    NoNewPrivileges = true;
                    ProtectHome = true;
                    ExecStart = "${pkgs.coreutils}/bin/true";
                  };
                };
              }
              (lib.optionalAttrs isCandidate {
                runner-drain-candidate-check = {
                  description = "Candidate verification probe for runner-drain-test";
                  wantedBy = [ "multi-user.target" ];
                  serviceConfig = {
                    Type = "simple";
                    DynamicUser = true;
                    ProtectSystem = "strict";
                    NoNewPrivileges = true;
                    ProtectHome = true;
                    ExecStart = pkgs.writeShellScript "runner-drain-candidate-check" ''
                      if [ -e /etc/runner-drain-test/force-verify-fail ]; then
                        sleep 1
                        exit 1
                      fi
                      exec ${pkgs.coreutils}/bin/sleep infinity
                    '';
                  };
                };
              })
            ];

            system.nixos.tags = lib.optionals isCandidate [ "candidate" ];

            boot.postBootCommands = ''
              install -d -m 0755 /run/runner-drain-test /var/lib/runner-drain-test /etc/runner-drain-test
              install -d -m 1777 /var/lib/runner-drain-test/counters
              if [ -f /tmp/shared/github-token ]; then
                install -m 0400 /tmp/shared/github-token /run/runner-drain-test/github-token
              fi
              if [ -f /tmp/shared/authorized_keys ]; then
                install -m 0644 /tmp/shared/authorized_keys /run/runner-drain-test/authorized_keys
              fi
              ${lib.optionalString (!isCandidate) ''
                readlink -f /run/booted-system > /var/lib/runner-drain-test/baseline-path
                printf '%s\n' "${candidate.config.system.build.toplevel}" > /var/lib/runner-drain-test/candidate-path
              ''}
            '';

            environment.systemPackages = with pkgs; [
              bashInteractive
              coreutils
              curl
              findutils
              gawk
              git
              gnugrep
              gnused
              iproute2
              jq
              openssh
              procps
              psmisc
              python3
              util-linux
            ];
          }
        )
      ];
    };

  candidate = mkSystem { isCandidate = true; };
  baseline = mkSystem { isCandidate = false; };
in
{
  inherit baseline candidate;
  vm = baseline.config.system.build.vm;
  baselineToplevel = baseline.config.system.build.toplevel;
  candidateToplevel = candidate.config.system.build.toplevel;
}
