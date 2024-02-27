{ pkgs, ... }: {

home.packages = with pkgs; [
  jdk11 
  gradle 
  maven
  jetbrains.idea-community-bin
  ];
}
