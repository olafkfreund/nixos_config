{ pkgs, ... }: {

home.packages = with pkgs; [
  jdk11 
  gradle 
  maven
  ];
}
