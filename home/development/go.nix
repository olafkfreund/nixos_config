{ pkgs, ... }: {

home.packages = with pkgs; [
  go 
  gopls 
  gore
  go-task
  timoni
  ];
}
