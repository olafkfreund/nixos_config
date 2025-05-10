{pkgs, ...}: {
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      glib
      libGL
      nss
      openssl
      zlib
    ];
  };
}
