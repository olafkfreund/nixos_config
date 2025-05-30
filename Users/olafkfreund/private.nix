{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    gitui
    git-credential-oauth
    git-credential-manager
    onefetch
  ];
  programs.git = {
    enable = true;
    # package = pkgs.gitAndTools.gitFull;
    lfs.enable = true;
    delta.enable = false;
    aliases = {
      a = "add";
      af = "!git add $(git ls-files -m -o --exclude-standard | sk -m)";
      b = "branch";
      br = "branch";
      c = "commit";
      ca = "commit --amend";
      cm = "commit -m";
      co = "checkout";
      d = "diff";
      ds = "diff --staged";
      edit-unmerged = "!f() { git ls-files --unmerged | cut -f2 | sort -u ; }; hx `f`";
      essa = "push --force";
      fuck = "commit --amend -m";
      graph = "log --all --decorate --graph --oneline";
      hist = "log --pretty=format:\"%Cgreen%h %Creset%cd %Cblue[%cn] %Creset%s%C(yellow)%d%C(reset)\" --graph --date=relative --decorate --all";
      l = "log";
      llog = "log --graph --name-status --pretty=format:\"%C(red)%h %C(reset)(%cd) %C(green)%an %Creset%s %C(yellow)%d%Creset\" --date=relative";
      oops = "checkout --";
      p = "push";
      pf = "push --force-with-lease";
      pl = "!git pull origin $(git rev-parse --abbrev-ref HEAD)";
      ps = "!git push origin $(git rev-parse --abbrev-ref HEAD)";
      r = "rebase";
      s = "status --short";
      ss = "status";
      st = "status";
    };

    userName = "olafkfreund";
    userEmail = lib.mkForce "olaf.loken@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      branch.autosetupmerge = "true";
      push.default = "current";
      merge.stat = "true";
      core.whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
      repack.usedeltabaseoffset = "true";
      pull.ff = "only";
      rebase = {
        autoSquash = true;
        autoStash = true;
      };
      rerere = {
        enabled = true;
        autoupdate = true;
      };
    };
    ignores = [
      "*~"
      "*.swp"
      "*result*"
      ".direnv"
      "node_modules"
    ];
  };

  # Enable nixd for improved Nix language server support
  development.nixd = {
    enable = true;
    offlineMode = true;
    formatterCommand = ["alejandra"];
    diagnosticsIgnored = [];
    diagnosticsExcluded = [
      "\\.direnv"
      "result"
      "\\.git"
      "node_modules"
    ];
  };
}
