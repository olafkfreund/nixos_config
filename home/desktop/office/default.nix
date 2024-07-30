{ pkgs, ... }: {
  home.packages = with pkgs; [
    freeoffice
    onlyoffice-bin_latest
    # wpsoffice
  ]; 
}
