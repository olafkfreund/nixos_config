{ pkgs, ... }: {
  home.file.".config/nvim" = {
    source = ./lazyvim;
    recursive = true;
  };
}
