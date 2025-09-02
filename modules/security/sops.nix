{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.features.security.sops;
  hostname = config.networking.hostName;

  # Check if host-specific secrets exist
  hasHostSecrets = builtins.pathExists ../../secrets/hosts/${hostname}/secrets.yaml;
in
{
  options.features.security.sops = {
    enable = mkEnableOption "SOPS secrets management";

    enableHostSecrets = mkOption {
      type = types.bool;
      default = true;
      description = "Enable host-specific secrets if they exist";
    };

    users = mkOption {
      type = types.listOf types.str;
      default = [ "olafkfreund" ];
      description = "List of users who need password secrets";
    };

    apiKeys = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable API key secrets";
      };

      providers = mkOption {
        type = types.listOf (types.enum [ "openai" "anthropic" "gemini" "github" ]);
        default = [ "openai" "anthropic" "gemini" "github" ];
        description = "API providers to configure secrets for";
      };
    };

    network = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable network-related secrets";
      };

      wifi = mkOption {
        type = types.bool;
        default = false;
        description = "Enable WiFi password secret";
      };

      tailscale = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Tailscale auth key secret";
      };
    };
  };

  config = mkIf cfg.enable {
    # Ensure sops-nix module is loaded
    assertions = [{
      assertion = config.sops != null;
      message = "sops-nix module must be imported in your flake configuration";
    }];

    # SOPS configuration
    sops = {
      # Use host SSH key for decryption
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

      # Generate age key from SSH key if needed
      age.generateKey = true;
      age.keyFile = "/var/lib/sops-nix/key.txt";

      # Default secrets file
      defaultSopsFile = ../../secrets/common/secrets.yaml;
      defaultSopsFormat = "yaml";

      # Validate all SOPS files on build
      validateSopsFiles = true;

      # Common secrets available to all hosts
      secrets = mkMerge [
        # User passwords
        (mkMerge (map
          (user: {
            "users/${user}/password" = {
              neededForUsers = true;
              sopsFile = ../../secrets/common/users.yaml;
            };
          })
          cfg.users))

        # API keys
        (mkIf cfg.apiKeys.enable (mkMerge (map
          (provider: {
            "api_keys/${provider}" = {
              mode = "0400";
              owner = head cfg.users;
              group = "users";
              sopsFile = ../../secrets/common/api-keys.yaml;
            };
          })
          cfg.apiKeys.providers)))

        # Network secrets
        (mkIf cfg.network.enable (mkMerge [
          (mkIf cfg.network.wifi {
            "network/wifi_password" = {
              mode = "0400";
              owner = "root";
              group = "root";
              sopsFile = ../../secrets/common/network.yaml;
            };
          })

          (mkIf cfg.network.tailscale {
            "network/tailscale_auth_key" = {
              mode = "0400";
              owner = "root";
              group = "root";
              sopsFile = ../../secrets/common/network.yaml;
            };
          })
        ]))

        # Host-specific secrets
        (mkIf (cfg.enableHostSecrets && hasHostSecrets) {
          "host/custom" = {
            sopsFile = ../../secrets/hosts/${hostname}/secrets.yaml;
            mode = "0400";
            owner = "root";
            group = "root";
          };
        })
      ];
    };

    # Update user configuration to use SOPS passwords
    users.users = mkMerge (map
      (user: {
        ${user} = {
          hashedPasswordFile = mkDefault config.sops.secrets."users/${user}/password".path;
        };
      })
      cfg.users);

    # Update AI provider configuration to use SOPS API keys
    ai.providers = mkIf (config.ai.providers.enable or false) {
      openai.apiKeyFile = mkDefault config.sops.secrets."api_keys/openai".path;
      anthropic.apiKeyFile = mkDefault config.sops.secrets."api_keys/anthropic".path;
      gemini.apiKeyFile = mkDefault config.sops.secrets."api_keys/gemini".path;
    };

    # Ensure sops tools are available
    environment.systemPackages = with pkgs; [
      sops
      age
      ssh-to-age
    ];

    # Add shell aliases for convenience
    environment.shellAliases = {
      "sops-edit" = "sops";
      "sops-show" = "sops -d";
      "sops-updatekeys" = "sops updatekeys";
      "sops-rotate" = "sops rotate -i";
    };

    # Create systemd service to validate secrets on boot
    systemd.services.sops-validate = {
      description = "Validate SOPS secrets availability";
      after = [ "sops-nix.service" ];
      wantedBy = [ "multi-user.target" ];

      script = ''
        echo "Validating SOPS secrets..."
        failed=0

        # Check each configured secret exists
        ${concatStringsSep "\n" (mapAttrsToList (name: secret: ''
          if [ ! -f "${secret.path}" ]; then
            echo "ERROR: Secret ${name} not available at ${secret.path}"
            failed=1
          else
            echo "OK: Secret ${name} available"
          fi
        '') config.sops.secrets)}

        if [ $failed -eq 1 ]; then
          echo "Some secrets are not available!"
          exit 1
        fi

        echo "All secrets validated successfully"
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
