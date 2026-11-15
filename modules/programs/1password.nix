{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.security;
in
{
  config = mkIf (cfg.enable && cfg.onepassword) {
    programs._1password.enable = true;
    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = [ "olafkfreund" ];
    };
  };
}
