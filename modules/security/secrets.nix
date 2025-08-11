{ config
, lib
, pkgs
, inputs
, ...
}:
with lib; let
  cfg = config.modules.security.secrets;

  # Helper function to check if a secret file exists
  secretExists = path: builtins.pathExists (toString path);

  # Helper function to conditionally create secret configuration
  mkSecret = name: secretConfig:
    optionalAttrs (secretExists secretConfig.file) {
      ${name} = secretConfig;
    };
in
{
  options.modules.security.secrets = {
    enable = mkEnableOption "Agenix secrets management";

    hostKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of SSH host key paths for decryption";
      example = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };

    userKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of user SSH key paths for secrets management";
      example = [ "/home/olafkfreund/.ssh/id_ed25519" ];
    };
  };

  config = mkIf cfg.enable {
    # Install agenix CLI tool system-wide
    environment.systemPackages = [
      inputs.agenix.packages.${pkgs.system}.default
    ];

    # Age secrets configuration - only include secrets that exist
    # TEMPORARY: Commented out broken secrets to fix activation errors
    age.secrets = mkMerge [
      # BROKEN - commented out temporarily
      # (mkSecret "user-password-olafkfreund" {
      #   file = ../../secrets/user-password-olafkfreund.age;
      #   owner = "olafkfreund";
      #   group = "users";
      #   mode = "0400";
      # })

      # BROKEN - commented out temporarily
      # (mkSecret "ssh-host-ed25519-key" {
      #   file = ../../secrets/ssh-host-ed25519-key.age;
      #   owner = "root";
      #   group = "root";
      #   mode = "0400";
      #   path = "/etc/ssh/ssh_host_ed25519_key";
      # })

      # WORKING - WiFi passwords (for laptops)
      (mkSecret "wifi-password" {
        file = ../../secrets/wifi-password.age;
        owner = "root";
        group = "root";
        mode = "0400";
      })

      # BROKEN - commented out temporarily
      # (mkSecret "docker-auth" {
      #   file = ../../secrets/docker-auth.age;
      #   owner = "root";
      #   group = "docker";
      #   mode = "0440";
      # })

      # WORKING - API keys and tokens
      (mkSecret "github-token" {
        file = ../../secrets/github-token.age;
        owner = "olafkfreund";
        group = "users";
        mode = "0400";
      })

      # WORKING - Database credentials
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
      optional (!builtins.pathExists ../../secrets)
        "Secrets directory not found. Run './scripts/setup-secrets.sh' to initialize secrets management.";
  };
}
