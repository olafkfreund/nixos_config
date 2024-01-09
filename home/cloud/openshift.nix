{ pkgs, ... }: {
  home.packages = with pkgs; [
    # aws
    ocm
    telepresence
    rhoas
    crc
    
   ];
}
