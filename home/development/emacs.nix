{pkgs, ...}: {
  programs.emacs = {
    enable = true;
    package = pkgs.emacs30-nox;
  };
  home.packages = with pkgs; [
    mu
    isync
    offlineimap
    emacsPackages.mu4e
    emacsPackages.mu4easy
    emacsPackages.mu4e-views
    emacsPackages.editorconfig
    emacsPackages.jsonrpc
    emacsPackages.copilot
    emacsPackages.nixfmt
    haskell-language-server
    black
  ];
}
