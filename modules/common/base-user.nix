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

    # SSH keys authorized to log in as this user across the fleet.
    # odin-dashboard@factory: the Odin homelab portal pod (k3s/factory ns)
    # SSHes into p510/p620/razer to collect host metrics. Without this key
    # authorized, sshd PerSourcePenalties penalises the pod's repeated auth
    # failures and drops its connections ("Not allowed at this time"),
    # making every host render OFFLINE in the dashboard.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAXf9GfUzBSKmfIQcDmaEcG3rmorOzGSOFXqMbHvlWSH odin-dashboard@factory"
    ];
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
