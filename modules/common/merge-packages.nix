{lib, ...}: {
  # Function to merge package lists and eliminate duplicates
  mergePackageLists = pkgLists:
    lib.unique (lib.flatten pkgLists);

  # Example usage:
  # packages = mergePackageLists [
  #   commonPackages
  #   devPackages
  #   systemPackages
  # ];
}
