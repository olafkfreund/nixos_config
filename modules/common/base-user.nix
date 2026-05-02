{ lib
, pkgs
, username ? "olafkfreund"
, ...
}:
let inherit (lib) mkDefault; in {
  users.users.${username} = {
    isNormalUser = true;
    description = mkDefault "Olaf K-Freund";
    extraGroups = [ "wheel" "video" "scanner" "lp" ];
    shell = mkDefault pkgs.zsh; # Changed to mkDefault to allow host configs to override
    # vim deliberately not here: it would collide with the
    # programs.neovim.{viAlias,vimAlias} symlinks in home-manager-path
    # (nixpkgs#451). The vim package is still in environment.systemPackages
    # via modules/nixos/packages/core.nix for sudo / root / other users.
    packages = with pkgs; [ wally-cli ];
  };

  # Common shell setup
  users.defaultUserShell = pkgs.zsh;
  environment.shells = with pkgs; [ zsh ];
  programs.zsh.enable = true;

  # Common environment variables
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    NH_FLAKE = "/home/${username}/.config/nixos";
  };
}
