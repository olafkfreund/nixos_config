{ pkgs, pkgs-stable, ... }: {

environment.systemPackages = with pkgs; [
  lavat #lava lamp
  browsh #text based browser
  peaclock #clock
  cbonsai #bonsai tree
  asciiquarium-transparent #aquarium
  globe-cli #globe
  pipes-rs #pipes
  cowsay #cowsay
  socat #socat
  #thefuck #Magnificent app which corrects your previous console command
  pomodoro #A simple CLI pomodoro timer using desktop notifications written in Rust
  tomato-c
  fortune
  lolcat
  ];
}
