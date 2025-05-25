{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.modules.security.secrets;

  # Helper function to check if a secret file exists
  secretExists = path: builtins.pathExists (toString path);

  # Helper function to conditionally create secret configuration
  mkSecret = name: secretConfig:
    lib.optionalAttrs (secretExists secretConfig.file) {
      ${name} = secretConfig;
    };
in {
  options.modules.security.secrets = {
    enable = lib.mkEnableOption "Agenix secrets management";

    hostKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of SSH host key paths for decryption";
      example = ["/etc/ssh/ssh_host_ed25519_key"];
    };

    userKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of user SSH key paths for secrets management";
      example = ["/home/olafkfreund/.ssh/id_ed25519"];
    };
  };

  config = lib.mkIf cfg.enable {
    # Install agenix CLI tool system-wide
    environment.systemPackages = [
      inputs.agenix.packages.${pkgs.system}.default
    ];

    # Age secrets configuration - only include secrets that exist
    age.secrets = lib.mkMerge [
      # User passwords
      (mkSecret "user-password-olafkfreund" {
        file = ../../secrets/user-password-olafkfreund.age;
        owner = "olafkfreund";
        group = "users";
        mode = "0400";
      })

      # SSH keys
      (mkSecret "ssh-host-ed25519-key" {
        file = ../../secrets/ssh-host-ed25519-key.age;
        owner = "root";
        group = "root";
        mode = "0400";
        path = "/etc/ssh/ssh_host_ed25519_key";
      })

      # WiFi passwords (for laptops)
      (mkSecret "wifi-password" {
        file = ../../secrets/wifi-password.age;
        owner = "root";
        group = "root";
        mode = "0400";
      })

      # Docker registry credentials
      (mkSecret "docker-auth" {
        file = ../../secrets/docker-auth.age;
        owner = "root";
        group = "docker";
        mode = "0440";
      })

      # API keys and tokens
      (mkSecret "github-token" {
        file = ../../secrets/github-token.age;
        owner = "olafkfreund";
        group = "users";
        mode = "0400";
      })

      # Database credentials
      (mkSecret "postgres-password" {
        file = ../../secrets/postgres-password.age;
        owner = "postgres";
        group = "postgres";
        mode = "0400";
      })
    ];

    # Ensure secrets directory exists
    system.activationScripts.agenix-setup = ''
      mkdir -p /run/agenix
      chmod 755 /run/agenix
    '';

    # Warning when secrets directory doesn't exist
    warnings =
      lib.optional (!builtins.pathExists ../../secrets)
      "Secrets directory not found. Run './scripts/setup-secrets.sh' to initialize secrets management.";
  };
}
