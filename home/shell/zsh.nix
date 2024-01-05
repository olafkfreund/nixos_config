{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    zsh
    oh-my-zsh
    zplug
    zsh-edit
    zsh-fzf-tab
    zsh-nix-shell
    zsh-clipboard
    zsh-autocomplete
    zsh-syntax-highlighting
  ];

programs.zsh = {
  enable = true; 
  #ohMyZsh = {
  # enable = true;
  #  plugins = [ 
	#    "azure" 
	#    "aws" 
	#    "docker" 
	#    "kubectl" 
	#    "terraform" 
	#    "kubectx" 
	#    "starship" 
	#    "git" 
	#    "thefuck" ];
  #  theme = "afowler";
  #};
  enableCompletion = true;
  syntaxHighlighting.enable = true;
  };











}
