{pkgs, ...}: {
  programs.emacs = {
    enable = true;
    package = pkgs.emacs-nox;
    extraPackages = epkgs: [
      epkgs.doom
    ];
  };
}
