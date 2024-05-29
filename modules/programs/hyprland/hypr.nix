{ inputs, lib, config, pkgs-stable, pkgs, ... }:{


# Enable hyprland
programs.hyprland = {
  enable = true;
  package = pkgs.hyprland;
  xwayland = {
    enable = true;
    };
};
programs.firefox = {
  enable = true;
  };
programs.wshowkeys = {
  enable = true;
  };
programs.nix-ld = {
  enable = true;
  libraries = with pkgs; [
      stdenv.cc.cc
    ];
  };
programs.kdeconnect = {
  enable = true;
  package = pkgs.kdePackages.kdeconnect-kde;
  };
}
