{
  config,
  lib,
  pkgs,
  ...
}: {
  # Example secrets configuration for testing
  # This file shows how to use secrets once they're created

  config = lib.mkIf config.modules.security.secrets.enable {
    # Example: Use wifi password in network configuration
    # networking.wireless.networks = lib.mkIf (builtins.hasAttr "wifi-password" config.age.secrets) {
    #   "MyWiFi" = {
    #     pskFile = config.age.secrets.wifi-password.path;
    #   };
    # };

    # Example: Use GitHub token in git configuration
    # environment.variables = lib.mkIf (builtins.hasAttr "github-token" config.age.secrets) {
    #   GITHUB_TOKEN_FILE = config.age.secrets.github-token.path;
    # };

    # Example: Use database password in service configuration
    # services.postgresql = lib.mkIf (builtins.hasAttr "postgres-password" config.age.secrets) {
    #   enable = true;
    #   authentication = ''
    #     local all postgres peer
    #   '';
    #   initialScript = pkgs.writeText "postgres-init" ''
    #     ALTER USER postgres PASSWORD '$(cat ${config.age.secrets.postgres-password.path})';
    #   '';
    # };
  };
}
