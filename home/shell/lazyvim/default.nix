{ pkgs, lib, ... }: {
  home.file.".config/nvim" = {
    source = ./lazyvim;
    recursive = true;
  };

  # Expose the Nix-built blink.cmp (with prebuilt Rust fuzzy matcher) at a
  # stable path so lazy.nvim can load it via `dir = ...` and skip the broken
  # release-binary download.
  #
  # It must be a WRITABLE copy, not a home.file symlink: lazy.nvim always runs
  # `:helptags doc/` on sync, and a read-only nix-store path makes that fail
  # with E152 ("Cannot open .../doc/tags for writing"). home.file (even with
  # recursive=true) keeps the tree read-only, so copy it out and chmod +w.
  # Idempotent — only re-copies when the source store path changes.
  home.activation.blinkCmpWritable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dest="$HOME/.local/share/nix-vim-plugins/blink.cmp"
    src="${pkgs.vimPlugins.blink-cmp}"
    if [ "$(cat "$dest/.nix-src" 2>/dev/null)" != "$src" ]; then
      $DRY_RUN_CMD rm -rf "$dest"
      $DRY_RUN_CMD mkdir -p "$dest"
      $DRY_RUN_CMD cp -rL "$src/." "$dest/"
      $DRY_RUN_CMD chmod -R u+w "$dest"
      $DRY_RUN_CMD echo "$src" > "$dest/.nix-src"
    fi
  '';
}
