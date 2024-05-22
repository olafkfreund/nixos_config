{ pkgs, ... }:

pkgs.writeShellScriptBin "new-nix-index" ''
  download_nixpkgs_cache_index () {
  filename="index-$(uname -m | sed 's/^arm64$/aarch64/')-$(uname | tr A-Z a-z)"
  mkdir -p ~/.cache/nix-index && cd ~/.cache/nix-index
  # -N will only download a new version if there is an update.
  wget -q -N https://github.com/nix-community/nix-index-database/releases/latest/download/$filename
  ln -f $filename files
  }

  download_nixpkgs_cache_index
''
