{ config, lib, pkgs, ... }:
let
  cfg = config.features.guarded-upgrade;
  python = pkgs.python3.withPackages (ps: [ ps.mcp ps.httpx ]);
  host = config.networking.hostName;
  # razer fetches p620's staged closure as guarded-stage, a user whose only way in is
  # this forced command: three read-only operations, nothing else (nixarchy#1946).
  stagePublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFwH35HvrdT79mUNYeCm1dqoRzP+6tG6XSeZsyNPF7U9";
  p620HostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID2qbg0iSYU7x4k0tJcGdy7Nu8mSWqU0dg7WBv0lH7Zk";
  stageCommand = pkgs.writeShellScript "guarded-stage-command" ''
    case "''${SSH_ORIGINAL_COMMAND:-}" in
      "readlink -f /var/lib/guarded-upgrade/stage-razer") exec ${pkgs.coreutils}/bin/readlink -f /var/lib/guarded-upgrade/stage-razer ;;
      "cat /var/lib/guarded-upgrade/verified") exec ${pkgs.coreutils}/bin/cat /var/lib/guarded-upgrade/verified ;;
      "nix-store --serve") exec ${config.nix.package}/bin/nix-store --serve ;;
      *) echo "guarded-stage: refused" >&2; exit 1 ;;
    esac
  '';
in
{
  options.features.guarded-upgrade = {
    enable = lib.mkEnableOption "guarded follow-edge system upgrade";
    autoActivate = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow unattended activation after host gates pass. Keep disabled on p620 until the runner drain test passes.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = config.networking.hostName == "p620" || config.networking.hostName == "razer";
          message = "guarded-upgrade supports only p620 and razer";
        }
      ];
      systemd.services.nixos-upgrade = {
        unitConfig = lib.optionalAttrs (config.networking.hostName == "razer") { ConditionACPower = true; };
        serviceConfig = {
          ExecCondition = lib.mkForce "${pkgs.coreutils}/bin/true";
          StateDirectory = "guarded-upgrade";
          StateDirectoryMode = "0755";
          NoNewPrivileges = true;
          ProtectHome = true;
        };
        environment = {
          PYTHONPATH = "${pkgs.customPkgs.agent-bus-mcp}/share/agent-bus-mcp";
          MATRIX_HOMESERVER = "https://matrix.freundcloud.org.uk";
          MATRIX_SERVER_NAME = "freundcloud.org.uk";
          MATRIX_REGISTRATION_TOKEN_FILE = config.age.secrets."matrix-registration-token".path;
          MATRIX_ADMIN_TOKEN_FILE = config.age.secrets."agent-bus-matrix-token".path;
          GITHUB_TOKEN_FILE = config.age.secrets."api-github-token".path;
          AGENT_BUS_NAME = "guarded-upgrade-${config.networking.hostName}";
        };
        path = with pkgs; [ git nix coreutils systemd openssh curl ];
        script = lib.mkForce ''
          exec ${python}/bin/python ${../../scripts/guarded_upgrade.py} ${config.networking.hostName} ${lib.boolToString cfg.autoActivate}
        '';
      };
    }
    (lib.mkIf (host == "razer") {
      age.secrets.guarded-stage-key = {
        file = ../../secrets/guarded-stage-key.age;
        mode = "0400";
        owner = "root";
      };
      systemd.services.nixos-upgrade.environment.STAGE_KEY_FILE = config.age.secrets.guarded-stage-key.path;
      # Pinned, so the first connection does not trust whatever answers as p620.
      programs.ssh.knownHosts.p620-guarded-stage = {
        hostNames = [ "p620" ];
        publicKey = p620HostKey;
      };
    })
    (lib.mkIf (host == "p620") {
      users.groups.guarded-stage = { };
      users.users.guarded-stage = {
        isSystemUser = true;
        group = "guarded-stage";
        shell = pkgs.bash;
        openssh.authorizedKeys.keys = [ "restrict,command=\"${stageCommand}\" ${stagePublicKey}" ];
      };
    })
  ]);
}
