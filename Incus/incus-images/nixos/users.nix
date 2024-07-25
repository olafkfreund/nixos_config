# users
{ pkgs, ... }:

let
  MAIN_USER = "nixos";
  MAIN_USER_PASSWORD = "nixos";
in {
  nix.settings.trusted-users = [ "root" MAIN_USER];

  users = {
    mutableUsers = false;

    users."${MAIN_USER}" = {
      password = MAIN_USER_PASSWORD;
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      shell = pkgs.zsh;
      
      packages = with pkgs; [
        # use home-manager?
      ];
    };
  };
}
