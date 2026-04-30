{ pkgs, ... }: {
  home.file.".config/nvim" = {
    source = ./lazyvim;
    recursive = true;
  };

  # Expose the Nix-built blink.cmp (with prebuilt Rust fuzzy matcher) at a
  # stable path so lazy.nvim can load it via `dir = ...` and skip the broken
  # release-binary download.
  home.file.".local/share/nix-vim-plugins/blink.cmp".source =
    pkgs.vimPlugins.blink-cmp;
}
