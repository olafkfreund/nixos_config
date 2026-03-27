{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    peaclock # clock
    cbonsai # bonsai tree
    globe-cli # globe
  ];
}
