_final: prev: {
  # azure-cli 2.81.0 expects azure-mgmt-web v2024_11_01 which isn't packaged yet;
  # disable installCheck until nixpkgs catches up.
  azure-cli = prev.azure-cli.overrideAttrs (_old: {
    doInstallCheck = false;
  });

  # nixpkgs-unstable ships nix-prefetch-git as `nix-prefetch-git-VERSION`,
  # breaking fetchCargoVendor which calls the binary by its short name.
  # Symlink the short name to the versioned binary.
  nix-prefetch-git = prev.nix-prefetch-git.overrideAttrs (_oldAttrs: {
    postFixup =
      let
        versionedName = prev.nix-prefetch-git.name;
      in
      ''
        if [ ! -e "$out/bin/nix-prefetch-git" ] && [ -e "$out/bin/${versionedName}" ];
        then
        ln -s "${versionedName}" "$out/bin/nix-prefetch-git"
        fi
      '';
  });
}
