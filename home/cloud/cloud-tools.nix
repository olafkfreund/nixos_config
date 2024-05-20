{ pkgs, ... }: {
  home.packages = with pkgs; [
    teller
    yq
    ytt
  
    
   ];
}
