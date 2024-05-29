{ pkgs, config, inputs, ... }: {

programs.neovim = {
  enable = true;
  defaultEditor = false;
  viAlias = true;
  vimAlias = true;
  vimdiffAlias = true;
  };
}
