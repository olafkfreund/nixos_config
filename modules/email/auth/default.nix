{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.features.email.auth;
  emailCfg = config.features.email;
in {
  imports = [
    ./oauth2.nix
  ];

  options.features.email.auth = {
    enable = mkEnableOption "Email authentication system";

    method = mkOption {
      type = types.enum [ "oauth2" "app-password" ];
      default = "oauth2";
      description = "Authentication method to use for Gmail accounts";
    };

    appPasswords = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          email = mkOption {
            type = types.str;
            description = "Gmail account email address";
          };
          
          passwordFile = mkOption {
            type = types.path;
            description = "Path to file containing app-specific password";
          };
        };
      });
      default = {};
      description = "App-specific password configuration for Gmail accounts";
    };
  };

  config = mkIf (emailCfg.enable && cfg.enable) {
    # Enable OAuth2 if selected
    features.email.auth.oauth2.enable = mkIf (cfg.method == "oauth2") true;

    # Configure OAuth2 accounts if method is oauth2
    features.email.auth.oauth2.accounts = mkIf (cfg.method == "oauth2") {
      primary = {
        email = emailCfg.accounts.primary;
        refreshTokenFile = "/run/agenix/gmail-oauth2-refresh-token-primary";
        accessTokenFile = "/tmp/neomutt-oauth2-access-token-primary";
      };
      
      secondary = {
        email = emailCfg.accounts.secondary;
        refreshTokenFile = "/run/agenix/gmail-oauth2-refresh-token-secondary";
        accessTokenFile = "/tmp/neomutt-oauth2-access-token-secondary";
      };
    };

    # Configure OAuth2 client credentials
    features.email.auth.oauth2.clientCredentials = mkIf (cfg.method == "oauth2") {
      clientId = "YOUR_GMAIL_OAUTH2_CLIENT_ID_HERE";  # To be configured
      clientSecretFile = "/run/agenix/gmail-oauth2-client-secret";
    };

    # Configure app passwords if selected
    features.email.auth.appPasswords = mkIf (cfg.method == "app-password") {
      primary = {
        email = emailCfg.accounts.primary;
        passwordFile = "/run/agenix/gmail-app-password-primary";
      };
      
      secondary = {
        email = emailCfg.accounts.secondary;
        passwordFile = "/run/agenix/gmail-app-password-secondary";
      };
    };

    # Install authentication helper tools
    environment.systemPackages = with pkgs; [
      gnupg  # For password management
    ] ++ optionals (cfg.method == "oauth2") [
      oauth2ms
      curl
      jq
    ];

    # Create directories for temporary token storage
    systemd.tmpfiles.rules = [
      "d /tmp/neomutt-oauth2 0700 olafkfreund users -"
    ];
  };
}