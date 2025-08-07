{
  config,
  lib,
  ...
}: 
with lib; let 
  cfg = config.security.onepassword;
in {
  options.security.onepassword = {
    enable = mkEnableOption {
      description = "Enable 1Password integration";
      default = false;
    };
  };
  config = mkIf cfg.enable {
    programs._1password.enable = true;
    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = ["olafkfreund"];
    };
  };
}
