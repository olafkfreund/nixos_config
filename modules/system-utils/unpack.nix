{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # Unpackers
    unzip
    p7zip
    unrar
    gnutar
    gzip
    bzip2
    xz
    zip
    # archiver
  ];
}
