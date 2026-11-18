{ pkgs, ... }: {
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      glib
      libGL
      nss
      openssl
      zlib
      icu # .NET binaries (azmcp) abort without libicu
    ];
  };
}
