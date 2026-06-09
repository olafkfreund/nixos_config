# ntfy-sh — self-hosted push notification server.
#
# Wraps the upstream nixpkgs services.ntfy-sh module with a feature flag and
# injects the agenix-decrypted environment file for auth configuration.
#
# Quick-start after first deploy:
#   ssh p510 -- sudo ntfy user add --role=admin <your-username>
#   ssh p510 -- sudo ntfy user change-pass <your-username>
#   # Then subscribe on mobile/desktop via https://ntfy.freundcloud.org.uk
#
# Sending a notification (example):
#   curl -u user:pass https://ntfy.freundcloud.org.uk/alerts -d "Hello!"
#
# Secrets required (edit before deploy):
#   agenix -e secrets/ntfy-env.age
#   Content:
#     NTFY_AUTH_DEFAULT_ACCESS=deny-all
#
# Reference: https://ntfy.sh/docs/config/
{ config
, lib
, ...
}:
let
  cfg = config.features.ntfy;
in
{
  options.features.ntfy = {
    enable = lib.mkEnableOption "ntfy-sh push notification server";

    baseUrl = lib.mkOption {
      type = lib.types.str;
      example = "https://ntfy.freundcloud.org.uk";
      description = "Public-facing base URL (required for attachments and iOS push).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 2586;
      description = "Local port ntfy-sh listens on (loopback only).";
    };

    attachmentSizeLimit = lib.mkOption {
      type = lib.types.str;
      default = "15M";
      description = "Maximum size of a single attachment.";
    };

    attachmentTotalLimit = lib.mkOption {
      type = lib.types.str;
      default = "2G";
      description = "Total attachment cache size on disk.";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets."ntfy-env" = {
      file = ../../secrets/ntfy-env.age;
      mode = "0400";
    };

    services.ntfy-sh = {
      enable = true;
      environmentFile = config.age.secrets."ntfy-env".path;
      settings = {
        base-url = cfg.baseUrl;
        listen-http = "127.0.0.1:${toString cfg.port}";
        behind-proxy = true;

        attachment-file-size-limit = cfg.attachmentSizeLimit;
        attachment-total-size-limit = cfg.attachmentTotalLimit;
        visitor-attachment-total-size-limit = "100M";

        # Persist messages across restarts (sqlite)
        cache-duration = "12h";

        # Rate limits — sensible defaults for a personal instance
        visitor-request-limit-burst = 60;
        visitor-request-limit-replenish = "5s";
        visitor-message-daily-limit = 250;
      };
    };
  };
}
