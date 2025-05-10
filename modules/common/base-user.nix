{
  config,
  lib,
  pkgs,
  username ? "olafkfreund",
  ...
}: {
  users.users.${username} = {
    isNormalUser = true;
    description = "Olaf K-Freund";
    extraGroups = ["wheel" "video" "scanner" "lp"];
    shell = pkgs.zsh;
    packages = with pkgs; [vim wally-cli];
  };

  # Common shell setup
  users.defaultUserShell = pkgs.zsh;
  environment.shells = with pkgs; [zsh];
  programs.zsh.enable = true;

  # Common environment variables
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    NH_FLAKE = "/home/${username}/.config/nixos";
  };
}
