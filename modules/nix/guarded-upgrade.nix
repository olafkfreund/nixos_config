{ config, lib, pkgs, ... }:
let
  cfg = config.features.guarded-upgrade;
  python = pkgs.python3.withPackages (ps: [ ps.mcp ps.httpx ]);
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

  config = lib.mkIf cfg.enable {
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
  };
}
