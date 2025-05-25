{
  lib,
  pkgs,
  username ? "olafkfreund",
  ...
}: {
  users.users.${username} = {
    isNormalUser = true;
    description = lib.mkDefault "Olaf K-Freund";
    extraGroups = ["wheel" "video" "scanner" "lp"];
    shell = lib.mkDefault pkgs.zsh; # Changed to mkDefault to allow host configs to override
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
