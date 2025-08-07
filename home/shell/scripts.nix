{ pkgs, ... }: {
  home.packages = [
    (import ./tmux/tmux-sessionizer.nix { inherit pkgs; })
  ];
}
