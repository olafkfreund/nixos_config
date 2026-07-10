_final: prev: {
  # azure-cli 2.81.0 expects azure-mgmt-web v2024_11_01 which isn't packaged yet;
  # disable installCheck until nixpkgs catches up.
  azure-cli = prev.azure-cli.overrideAttrs (_old: {
    doInstallCheck = false;
  });

  # ollama 0.31.1: the Go scheduler test suite fails in the sandbox — it mocks
  # GPU memory (library=Metal on Linux, simulated cudaMalloc OOM) and is
  # environment-sensitive, not a real defect. Skip checks. Override both the
  # base package and ollama-rocm (p620 uses ollama-rocm; p510 ollama-cuda).
  ollama = prev.ollama.overrideAttrs (_old: { doCheck = false; });
  ollama-rocm = prev.ollama-rocm.overrideAttrs (_old: { doCheck = false; });
  ollama-cuda = prev.ollama-cuda.overrideAttrs (_old: { doCheck = false; });

  # gnome-shell's shell_remove_dark_mode.patch fails to apply on GNOME 49.1.
  # Strip it until nixpkgs catches up. Keep the rest of nixpkgs' patches.
  gnome-shell = prev.gnome-shell.overrideAttrs (oldAttrs: {
    patches = builtins.filter
      (patch: builtins.match ".*shell_remove_dark_mode.*" (toString patch) == null)
      (oldAttrs.patches or [ ]);
  });

  # mesa 26.1.2 regressed the GBM back-buffer path: gnome-shell/mutter on
  # amdgpu segfaults in gbm_bo_destroy (reached via get_back_bo during
  # eglMakeCurrent / frame presentation). mesa 26.1.1 + libgbm 26.0.3 ran
  # crash-free for weeks; the 26.1.1 -> 26.1.2 bump (nixpkgs 14dbea35565,
  # 2026-06-03) is the regression. Revert mesa to 26.1.1 against current
  # build deps; libgbm stays 26.0.3 (unchanged, matching the known-good combo).
  # Remove once a fixed mesa (>= 26.1.3) lands upstream.
  mesa = prev.mesa.overrideAttrs (_old: {
    version = "26.1.1";
    src = prev.fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "mesa";
      repo = "mesa";
      rev = "mesa-26.1.1";
      hash = "sha256-OmhBmBGR12Tl+5msiyL8lYQ3XYcDYCqUUjQObEqjytI=";
    };
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
