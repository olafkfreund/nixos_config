# Zsh "pimp my shell" enhancements
#
# Cool-but-usable, declarative additions layered on top of the lean zsh.nix
# (post oh-my-zsh). Everything here merges into programs.zsh via the HM module
# system. Kept in its own file so the additions are reviewable and reversible.
{ pkgs
, lib
, ...
}:
{
  programs.zsh = {
    # ── Abbreviations (expand-on-space) ───────────────────────────────────────
    # Better than aliases: they expand to the real command before you run it, so
    # history stays readable/portable. Keys deliberately avoid existing aliases
    # (gc/gl/ls/…) and real binaries (cc/ag) to prevent clobbering.
    zsh-abbr = {
      enable = true;
      abbreviations = {
        # git
        gst = "git status";
        gco = "git checkout";
        gaa = "git add --all";
        gcm = "git commit -m";
        gca = "git commit -v --amend";
        gpu = "git push";
        gpl = "git pull";
        gdf = "git diff";
        gbr = "git branch";
        glg = "git log --oneline --graph --decorate -20";
        # nix
        nfu = "nix flake update";
        nbd = "nix build";
        nfc = "nix flake check";
        ndv = "nix develop";
        nsh = "nix-shell";
        drs = "sudo nixos-rebuild switch --flake .#$(hostname)";
        # just (you have 100+ recipes)
        jv = "just validate";
        jth = "just test-host";
        jqt = "just quick-test";
        jqd = "just quick-deploy";
        # AI tooling
        cld = "claude";
        cldc = "claude --continue";
        cldp = "claude -p";
      };
      globalAbbreviations = {
        # expand anywhere on the line, e.g.  ls G foo
        G = "| grep -i";
        L = "| less";
        J = "| jq";
        H = "| head";
        T = "| tail";
        NE = "2>/dev/null";
        NUL = "&>/dev/null";
      };
    };

    # ── Named directory jumps:  cd ~nixos ────────────────────────────────────
    dirHashes = {
      nixos = "$HOME/.config/nixos";
      dots = "$HOME/.config";
      dl = "$HOME/Downloads";
      docs = "$HOME/Documents";
      src = "$HOME/Source";
    };

    # ── Functions, pickers and key widgets ───────────────────────────────────
    initContent = lib.mkOrder 1000 ''
      # Esc-Esc → toggle sudo on the current line (replaces the OMZ sudo plugin)
      sudo-command-line() {
        [[ -z $BUFFER ]] && zle up-history
        if [[ $BUFFER == sudo\ * ]]; then BUFFER="''${BUFFER#sudo }"
        else BUFFER="sudo $BUFFER"; fi
        zle end-of-line
      }
      zle -N sudo-command-line
      bindkey '\e\e' sudo-command-line

      # fj — fuzzy-pick a just recipe and run it
      fj() {
        local r
        r=$(${pkgs.just}/bin/just --summary 2>/dev/null | tr ' ' '\n' \
              | ${pkgs.fzf}/bin/fzf --prompt='just> ' --height=40% --reverse) \
          && ${pkgs.just}/bin/just "$r"
      }

      # fgb — fuzzy-pick a git branch and check it out
      fgb() {
        local b
        b=$(git branch --all 2>/dev/null | sed 's/^[* ]*//; s#remotes/[^/]*/##' \
              | grep -v '^HEAD' | sort -u \
              | ${pkgs.fzf}/bin/fzf --height=40% --reverse) \
          && git checkout "$b"
      }

      # fh — fuzzy-pick a host and ssh in
      fh() {
        local h
        h=$(printf 'p620\nrazer\np510\n' | ${pkgs.fzf}/bin/fzf --prompt='ssh> ' --height=20%) \
          && ssh "$h"
      }

      # wtf — ask Claude to explain/fix the previous command (the one that just ran)
      wtf() {
        local last
        last=$(fc -ln -1 2>/dev/null)
        [[ -z $last ]] && { echo "no previous command"; return 1; }
        claude -p "Concisely explain this shell command and how to fix it if it looks wrong:

      $last"
      }

      # cz — fuzzy-jump (zoxide) into a project and launch Claude Code there
      cz() {
        local d
        d=$(zoxide query -l 2>/dev/null | ${pkgs.fzf}/bin/fzf --prompt='claude in> ' --height=40% --reverse) \
          && cd "$d" && claude
      }
    '';
  };
}
