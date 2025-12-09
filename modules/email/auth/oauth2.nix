{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.features.email.auth.oauth2;
  emailCfg = config.features.email;
in
{
  options.features.email.auth.oauth2 = {
    enable = mkEnableOption "OAuth2 authentication for Gmail accounts";

    clientCredentials = {
      clientId = mkOption {
        type = types.str;
        description = "OAuth2 client ID for Gmail API access";
        default = "";
      };

      clientSecretFile = mkOption {
        type = types.path;
        description = "Path to file containing OAuth2 client secret";
        default = "/run/agenix/gmail-oauth2-client-secret";
      };
    };

    accounts = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          email = mkOption {
            type = types.str;
            description = "Gmail account email address";
          };

          refreshTokenFile = mkOption {
            type = types.path;
            description = "Path to file containing OAuth2 refresh token";
          };

          accessTokenFile = mkOption {
            type = types.path;
            description = "Path to file containing OAuth2 access token";
          };
        };
      });
      default = { };
      description = "OAuth2 configuration for Gmail accounts";
    };
  };

  config = mkIf (emailCfg.enable && cfg.enable) {
    # Environment configuration
    environment = {
      # Install OAuth2 helper tools
      systemPackages = with pkgs; [
        oauth2ms # OAuth2 Microsoft and Gmail helper
        curl # For API calls
        jq # JSON processing
      ];

      # OAuth2 scripts
      etc = {
        # Create OAuth2 token refresh script
        "neomutt/oauth2-refresh.sh" = {
          text = ''
            #!/usr/bin/env bash
            set -euo pipefail

            ACCOUNT="$1"
            REFRESH_TOKEN_FILE="$2"
            ACCESS_TOKEN_FILE="$3"
            CLIENT_ID="${cfg.clientCredentials.clientId}"
            CLIENT_SECRET_FILE="${cfg.clientCredentials.clientSecretFile}"

            if [[ ! -f "$CLIENT_SECRET_FILE" ]]; then
              echo "Error: Client secret file not found: $CLIENT_SECRET_FILE" >&2
              exit 1
            fi

            if [[ ! -f "$REFRESH_TOKEN_FILE" ]]; then
              echo "Error: Refresh token file not found: $REFRESH_TOKEN_FILE" >&2
              exit 1
            fi

            CLIENT_SECRET=$(cat "$CLIENT_SECRET_FILE")
            REFRESH_TOKEN=$(cat "$REFRESH_TOKEN_FILE")

            # Request new access token using refresh token
            RESPONSE=$(curl -s -X POST \
              -d "client_id=$CLIENT_ID" \
              -d "client_secret=$CLIENT_SECRET" \
              -d "refresh_token=$REFRESH_TOKEN" \
              -d "grant_type=refresh_token" \
              "https://oauth2.googleapis.com/token")

            if ! echo "$RESPONSE" | jq -e '.access_token' > /dev/null; then
              echo "Error: Failed to refresh OAuth2 token for $ACCOUNT" >&2
              echo "Response: $RESPONSE" >&2
              exit 1
            fi

            # Extract and save new access token
            echo "$RESPONSE" | jq -r '.access_token' > "$ACCESS_TOKEN_FILE"
            chmod 600 "$ACCESS_TOKEN_FILE"

            echo "OAuth2 token refreshed successfully for $ACCOUNT"
          '';
          mode = "0755";
        };

        # Create OAuth2 initial setup script
        "neomutt/oauth2-setup.sh" = {
          text = ''
            #!/usr/bin/env bash
            set -euo pipefail

            echo "OAuth2 Setup for Gmail Accounts"
            echo "================================"
            echo
            echo "To set up OAuth2 authentication for Gmail accounts, you need to:"
            echo "1. Create a Google Cloud Project and enable Gmail API"
            echo "2. Create OAuth2 credentials (Desktop application type)"
            echo "3. Generate initial refresh tokens for each account"
            echo
            echo "Follow these steps:"
            echo
            echo "1. Visit https://console.cloud.google.com/"
            echo "2. Create a new project or select existing one"
            echo "3. Enable Gmail API in APIs & Services"
            echo "4. Create OAuth2 credentials in APIs & Services > Credentials"
            echo "5. Download the credentials JSON file"
            echo "6. Use oauth2ms tool to generate refresh tokens:"
            echo
            echo "   oauth2ms --debug --client-id=YOUR_CLIENT_ID \\"
            echo "           --client-secret=YOUR_CLIENT_SECRET \\"
            echo "           --scope=https://mail.google.com/ \\"
            echo "           --email=olaf@freundcloud.com"
            echo
            echo "7. Store credentials using agenix:"
            echo "   ./scripts/manage-secrets.sh create gmail-oauth2-client-secret"
            echo "   ./scripts/manage-secrets.sh create gmail-oauth2-refresh-token-primary"
            echo "   ./scripts/manage-secrets.sh create gmail-oauth2-refresh-token-secondary"
            echo
            echo "8. Re-enable OAuth2 in email configuration and rebuild"
          '';
          mode = "0755";
        };
      };
    };

    # OAuth2 token refresh systemd service
    systemd.services.neomutt-oauth2-refresh = mkIf (cfg.accounts != { }) {
      description = "Refresh OAuth2 tokens for NeoMutt Gmail accounts";
      serviceConfig = {
        Type = "oneshot";
        User = "olafkfreund";
        ExecStart =
          let
            refreshScript = pkgs.writeShellScript "refresh-all-tokens" ''
              set -euo pipefail
              ${concatStringsSep "\n" (mapAttrsToList (_name: account: ''
                  echo "Refreshing OAuth2 token for ${account.email}..."
                  /etc/neomutt/oauth2-refresh.sh "${account.email}" \
                    "${account.refreshTokenFile}" \
                    "${account.accessTokenFile}" || echo "Failed to refresh token for ${account.email}"
                '')
                cfg.accounts)}
            '';
          in
          "${refreshScript}";
      };
    };

    # Timer to refresh tokens every 30 minutes
    systemd.timers.neomutt-oauth2-refresh = mkIf (cfg.accounts != { }) {
      description = "Timer for OAuth2 token refresh";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "30m";
        Persistent = true;
      };
    };
  };
}
