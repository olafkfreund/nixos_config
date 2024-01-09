{ pkgs, ... }: {
  home.packages = with pkgs; [
    # aws
    google-cloud-sdk
    google-authenticator
    
   ];
}
