{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    peaclock # clock
    cbonsai # bonsai tree
    asciiquarium-transparent # aquarium
    globe-cli # globe
    pipes-rs # pipes
  ];
}
