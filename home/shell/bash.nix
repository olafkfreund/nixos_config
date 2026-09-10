# Bash as the interactive shell, brought up to the zsh setup's feature level.
#
# The load-bearing piece is flyline (flake input, overlays/default.nix): a Rust
# loadable builtin that REPLACES readline. Plain bash + starship loses inline
# autosuggestions, syntax highlighting and fuzzy tab completion, and none of
# those have bash equivalents — flyline restores all three natively, which is
# what makes bash viable as the login shell here.
#
# Because flyline replaces readline outright, third-party line editors do not
# work by accident: fzf and atuin must be re-bound through flyline's own
# `runBashCommand()` action rather than via bind -x. That is the whole reason
# the keybinding block at the bottom exists.
#
# Mapping from the old zsh stack, for anyone auditing the migration:
#   deja / zsh-autosuggestions  -> flyline inline suggestions
#   zsh-syntax-highlighting     -> flyline (Stylix-themed below)
#   zsh-fzf-tab                 -> flyline fuzzy tab completion
#   zsh-ai-cmd (Ctrl+G, ZLE)    -> flyline agent mode (`: ` prefix -> claude)
#   hand-rolled precmd ruler    -> PROMPT_RULER
#   zsh-abbr                    -> the Space-expander widget below
#   nix-zsh-completions         -> nix-bash-completions
#   zsh-forgit                  -> git-forgit binary + fzf-git-sh
{ pkgs
, lib
, config
, ...
}:
let
  inherit (config.lib.stylix) colors;

  # Abbreviations: expanded in place when you hit Space, so history records the
  # real command instead of the shorthand. Ported verbatim from the zsh-abbr
  # block that used to live in home/shell/zsh-enhancements.nix.
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
    # just
    jv = "just validate";
    jth = "just test-host";
    jqt = "just quick-test";
    jqd = "just quick-deploy";
    # AI tooling
    cld = "claude";
    cldc = "claude --continue";
    cldp = "claude -p";
  };

  # Global abbreviations expand anywhere on the line, not just in command
  # position (`ls G foo` -> `ls | grep -i foo`).
  globalAbbreviations = {
    G = "| grep -i";
    L = "| less";
    J = "| jq";
    H = "| head";
    T = "| tail";
    NE = "2>/dev/null";
    NUL = "&>/dev/null";
  };

  # Emitted as a bash case statement rather than an associative array so the
  # expansion stays a single O(1) lookup with no subshell.
  mkAbbrCase =
    attrs:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (k: v: "    ${lib.escapeShellArg k}) printf '%s' ${lib.escapeShellArg v} ;;") attrs
    );
in
{
  home.packages = with pkgs; [
    bashInteractive
    bash-completion
    # Nix-aware bash completion — the counterpart to nix-zsh-completions.
    nix-bash-completions
    # NOTE: flyline is deliberately NOT listed here — it ships no `bin/`, only
    # lib/libflyline.so, and the `flyline` command is a bash *builtin* that
    # exists only once that .so is enabled. initExtra references the store
    # path directly, which is what pulls it into the closure.
    # fzf-git-sh: Ctrl+G-prefixed fuzzy pickers over git objects (branches,
    # tags, hashes, files, remotes) for bash.
    fzf-git-sh
    # zsh-forgit is the only nixpkgs source of the `git-forgit` binary, which
    # is itself shell-agnostic — the zsh plugin was only ever aliases over it.
    # We take the binary and define the aliases ourselves below.
    zsh-forgit
  ];

  programs.zoxide.enableBashIntegration = true;

  programs.bash = {
    enable = true;
    enableCompletion = true;

    # Matches the zsh history tuning it replaces.
    historySize = 50000;
    historyFileSize = 50000;
    historyControl = [
      "ignoredups"
      "ignorespace"
      "erasedups"
    ];
    historyIgnore = [
      "ls"
      "cd"
      "cd -"
      "pwd"
      "exit"
      "date"
      "* --help"
      "man *"
      "history"
    ];

    shellOptions = [
      "histappend" # append rather than clobber on exit
      "checkwinsize" # keep $COLUMNS correct for PROMPT_RULER
      "extglob" # flyline previews and expands extglobs
      "globstar" # ** recursive globbing, a zsh default
      "cdspell" # autocorrect small typos in cd targets
      "dirspell"
      "autocd" # bare directory name means cd, like zsh's AUTO_CD
      "cmdhist" # keep multi-line commands as one history entry
    ];

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      ENABLE_LSP_TOOLS = 1;
      OBSIDIAN_VAULT_PATH = "$HOME/Documents/Caliti";
      FORCE_AUTOUPDATE_PLUGINS = "true";
      LESS = "-F -g -i -M -R -S -w -X -z-4";
      PAGER = "less";
      MANPAGER = "sh -c 'col -bx | bat -l man -p'";
      MANROFFOPT = "-c";
      EZA_COLORS = "da=1;34:gm=1;34";
      # No BAT_THEME: Stylix writes --theme=base16-stylix into
      # ~/.config/bat/config, and bat's env var OUTRANKS its config file, so
      # setting it here would silently defeat Stylix everywhere bat is used.
    };

    shellAliases = {
      # sudo wrapper path (NixOS puts the setuid wrapper outside $PATH order)
      sudo = "/run/wrappers/bin/sudo";

      # git
      gc = lib.mkForce "git commit -v";
      gl = lib.mkForce "git log --oneline --graph --decorate";
      gita = "git add --all";
      gitm = "git commit -m";
      gitp = "git push";
      gitc = "git checkout";

      # forgit interactive git, over the shell-agnostic git-forgit binary
      ga = lib.mkForce "git forgit add";
      glo = "git forgit log";
      gd = lib.mkForce "git forgit diff";
      gcf = "git forgit checkout_file";
      gcb = "git forgit checkout_branch";
      gss = "git forgit stash_show";

      # eza
      ls = "eza --icons=auto --color=auto --group-directories-first";
      ll = lib.mkForce "eza --icons=auto --color=auto --long --group-directories-first --git";
      la = "eza --icons=auto --color=auto --long --all --group-directories-first --git";
      l = "eza --icons=auto --color=auto --long --group-directories-first";
      lt = lib.mkForce "eza --icons=auto --color=auto --tree --level=2 --group-directories-first";
      lta = "eza --icons=auto --color=auto --tree --level=2 --all --group-directories-first";
      lr = "eza --icons=auto --color=auto --long --reverse --sort=modified --group-directories-first";
      lz = "eza --icons=auto --color=auto --long --sort=size --group-directories-first";
      ezals = "eza --header --git --classify --long --binary --group --time-style=long-iso --links --all --group-directories-first --sort=name --icons";

      # core
      cp = "cp -rv";
      mkdir = "mkdir -vp";
      mv = "mv -iv";
      top = "btm";
      cat = "bat"; # theme comes from Stylix via ~/.config/bat/config
      mdless = "glow";
      neofetch = "fastfetch";

      # nix
      nhu = "nh home switch";

      # misc
      reload = "exec bash";
      weather = "curl -s https://wttr.in/London";
      today = "curl -s https://wttr.in/London?1";
      wttr = "curl -s https://wttr.in/London?0";
      myip = "curl -s https://ipinfo.io/ip";
      fzfpreview = "fzf --preview 'bat --color=always --line-range :50 {}'";
      aiexplain = "aichat --role explain";
    };

    # Non-interactive-safe environment. Kept out of initExtra so scripts and
    # remote `ssh host cmd` invocations still get the PATH.
    bashrcExtra = ''
      export PATH="$HOME/bin:$HOME/.local/bin:$HOME/go/bin:$PATH"
      export PATH="$HOME/.cargo/bin:$HOME/.npm-global/bin:$PATH"
      export PATH="$HOME/.config/rofi/scripts:$PATH"
    '';

    initExtra = lib.mkMerge [
      (
        ''
          # ── bash-preexec ─────────────────────────────────────────────────────
          # zsh's preexec/precmd hooks have no bash builtin equivalent. Sourcing
          # this early gives us both, and starship detects it and registers
          # through preexec_functions instead of its PS0/DEBUG-trap fallback,
          # which makes its command-duration timing accurate. Must come before
          # starship's init (mkOrder 1900) — this block is default order 1000.
          # Verified to coexist with flyline: preexec is DEBUG-trap based and
          # does not touch readline, which is all flyline replaces.
          if [[ $- == *i* ]] && [[ -r ${pkgs.bash-preexec}/share/bash/bash-preexec.sh ]]; then
            source ${pkgs.bash-preexec}/share/bash/bash-preexec.sh
          fi

          # ── you-should-use ───────────────────────────────────────────────────
          # Reimplementation of zsh-you-should-use, which has no bash port
          # precisely because bash lacks preexec — which we just added above.
          # Reminds you an alias exists for what you just typed longhand.
          # Covered by scripts/test-bash-ysu.sh; keep the two in sync.
          __ysu_check() {
            local cmd="$1"
            [[ -z $cmd ]] && return 0

            local line name value best_name="" best_len=0
            while IFS= read -r line; do
              line=''${line#alias }
              name=''${line%%=*}
              value=''${line#*=}
              # alias output single-quotes the value; unwrap it.
              value=''${value#\'}
              value=''${value%\'}
              [[ -z $name || -z $value || $name == "$line" ]] && continue
              # Never nag when the alias itself was used.
              [[ $cmd == "$name" || $cmd == "$name "* ]] && return 0
              if [[ $cmd == "$value" || $cmd == "$value "* ]] && (( ''${#value} > best_len )); then
                best_name=$name
                best_len=''${#value}
              fi
            done < <(alias 2>/dev/null)

            [[ -n $best_name ]] && printf '\033[2mysu: alias %s exists for this\033[0m\n' "$best_name"
            return 0
          }
          # NOTE: __ysu_check is REGISTERED in the mkOrder 2000 tail block at the
          # bottom of this file, not here. wezterm's shell integration sources its
          # own bash-preexec copy later in the rc, which resets preexec_functions
          # to empty and silently drops anything appended before it.

          # ── flyline ──────────────────────────────────────────────────────────
          # Loadable builtin; replaces readline wholesale. Everything below that
          # says `flyline ...` is configuration state flyline persists per
          # invocation, which is why it is re-applied on every shell start.
          if [[ $- == *i* && $TERM != "dumb" ]]; then
            enable -f ${pkgs.flyline}/lib/libflyline.so flyline 2>/dev/null || true
          fi

          __flyline_loaded() { enable -p 2>/dev/null | grep -q 'enable flyline'; }

          if __flyline_loaded; then
            # Prompt ruler: a hairline above each prompt separating the previous
            # command's output from the new prompt. Replaces the ~30 lines of
            # precmd hook the zsh config used to hand-roll for this.
            export PROMPT_RULER=$'\e[38;2;${colors."base03-rgb-r"};${colors."base03-rgb-g"};${colors."base03-rgb-b"}m─\e[0m'

            # Transient prompt: on submit, redraw without the ruler so scrollback
            # is not full of separator lines.
            export PROMPT_RULER_FINAL=""

            # Syntax highlighting from the active Stylix/base16 scheme — the same
            # mapping the zsh syntaxHighlighting.styles block used, onto flyline's
            # style slots. Styles are rich-syntax strings, not bare colours.
            flyline set-style \
              recognised-command="#${colors.base0C}" \
              unrecognised-command="#${colors.base08}" \
              bash-reserved="#${colors.base08}" \
              single-quoted-text="#${colors.base0B}" \
              double-quoted-text="#${colors.base0B}" \
              env-var="#${colors.base0A}" \
              comment="#${colors.base03}" \
              normal-text="#${colors.base05}" \
              secondary-text="#${colors.base04}" \
              inline-suggestion="dim #${colors.base03}" \
              matching-char="bold #${colors.base0D}" \
              opening-and-closing-pair="#${colors.base0D}" 2>/dev/null || true

            # Carry the zsh history across so 50k entries of muscle memory survive
            # the migration. Harmless once ~/.zsh_history stops growing.
            if [[ -f "$HOME/.zsh_history" ]]; then
              flyline --load-zsh-history "$HOME/.zsh_history" 2>/dev/null || true
            fi

            # Agent mode: replaces the bespoke zsh-ai-cmd plugin (Ctrl+G / ZLE).
            # Type `: find files older than three days` and press Enter.
            flyline set-agent-mode \
              --system-prompt "Be concise. Answer with a JSON array of at most 3 items with objects containing: command and description. Command will be a Bash command. " \
              --trigger-prefix ': ' \
              --command 'claude --effort low --print' 2>/dev/null || true
          fi

          # ── abbreviations (expand on Space) ──────────────────────────────────
          # zsh-abbr has no bash equivalent, but flyline exposes READLINE_LINE to
          # bash functions via runBashCommand(), which is enough to build one.
          __abbr_lookup() {
            case "$1" in
          ${mkAbbrCase abbreviations}
              *) return 1 ;;
            esac
          }

          __abbr_lookup_global() {
            case "$1" in
          ${mkAbbrCase globalAbbreviations}
              *) return 1 ;;
            esac
          }

          __abbr_expand() {
            local line="''${READLINE_LINE}" point="''${READLINE_POINT:-0}"
            local before="''${line:0:$point}" after="''${line:$point}"
            # The word under the cursor is the candidate.
            local word="''${before##* }"
            local prefix="''${before%"$word"}"
            if [[ -z $word ]]; then
              READLINE_LINE="''${before} ''${after}"
              READLINE_POINT=$(( point + 1 ))
              return
            fi

            local expansion
            # Command-position abbreviations only fire as the first word; global
            # ones fire anywhere. Matches zsh-abbr's two-tier behaviour.
            if [[ -z ''${prefix//[[:space:]]/} ]] && expansion=$(__abbr_lookup "$word"); then
              :
            elif expansion=$(__abbr_lookup_global "$word"); then
              :
            else
              expansion="$word"
            fi

            READLINE_LINE="''${prefix}''${expansion} ''${after}"
            READLINE_POINT=$(( ''${#prefix} + ''${#expansion} + 1 ))
          }

          # ── functions ported from zsh ────────────────────────────────────────
          # nhs: idiot-proof NixOS update+switch. Wraps `just update-commit-deploy`
          # so `nhs [HOST] [SCOPE]` does the whole flow. Subshell so the caller's
          # cwd is untouched. See docs/UPDATE-DEPLOY.md.
          nhs() {
            (cd ~/.config/nixos && just update-commit-deploy "$@")
          }

          # nhsb: stage 1 of a split deploy — build + commit without switching.
          # Use when the target is offline; later `nhs HOST` is a cache hit.
          nhsb() {
            (cd ~/.config/nixos && just update-commit "$@")
          }

          # sysdiff: Added/Removed/Upgraded between the last two generations.
          # nvd-backed, so unlike nh's built-in diff it works for remote deploys.
          sysdiff() {
            (cd ~/.config/nixos && ./scripts/system-diff.sh "$@")
          }

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

          # fhost — fuzzy-pick a host and ssh in.
          # NOT `fh`: home/development/productivity.nix already aliases fh to
          # `history | fzf`, and an alias beats a same-named function at parse
          # time. The zsh config had this exact collision, which is why its `fh`
          # ssh-picker never actually ran.
          fhost() {
            local h
            h=$(printf 'p620\nrazer\np510\n' | ${pkgs.fzf}/bin/fzf --prompt='ssh> ' --height=20%) \
              && ssh "$h"
          }

          # wtf — ask Claude to explain/fix the command that just ran
          wtf() {
            local last
            last=$(fc -ln -1 2>/dev/null | sed 's/^[[:space:]]*//')
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

          # __sudo_toggle — toggle sudo on the current line (was Esc-Esc in zsh)
          __sudo_toggle() {
            if [[ ''${READLINE_LINE} == sudo\ * ]]; then
              READLINE_LINE="''${READLINE_LINE#sudo }"
              READLINE_POINT=$(( READLINE_POINT > 5 ? READLINE_POINT - 5 : 0 ))
            else
              READLINE_LINE="sudo ''${READLINE_LINE}"
              READLINE_POINT=$(( READLINE_POINT + 5 ))
            fi
          }

          # ── named directory jumps (zsh dirHashes -> shell vars + autocd) ──────
          # `cd $nixos` rather than zsh's `cd ~nixos`; with autocd, `$nixos` alone
          # is enough. Deliberately NOT exported: these are short generic names
          # ($src, $docs) and putting them in the environment of every child
          # process is asking for a collision.
          nixos="$HOME/.config/nixos"
          dots="$HOME/.config"
          dl="$HOME/Downloads"
          docs="$HOME/Documents"
          src="$HOME/Source"

          # ── atuin ────────────────────────────────────────────────────────────
          # There is no programs.atuin module in this config — atuin is a plain
          # package (modules/helpers) and the zsh side hand-rolled `atuin init
          # zsh`. Same here. This MUST run before the flyline keybindings in the
          # tail block, which reference __atuin_widget_run.
          if command -v atuin >/dev/null 2>&1; then
            eval "$(atuin init bash --disable-up-arrow)"
          fi

          # NOTE: no `fzf --bash` here — home/shell/fzf/default.nix already sets
          # enableBashIntegration, which emits it. fzf-file-widget and __fzf_cd__
          # come from there; the tail block only re-binds them through flyline.

          # ── fzf-git-sh: Ctrl+G pickers over git objects ──────────────────────
          if [[ -r ${pkgs.fzf-git-sh}/share/fzf-git-sh/fzf-git.sh ]]; then
            source ${pkgs.fzf-git-sh}/share/fzf-git-sh/fzf-git.sh
          fi

          # NOTE: nix-bash-completions needs no explicit source line. It installs
          # into share/bash-completion/completions/, which bash-completion loads
          # dynamically off XDG_DATA_DIRS once the package is in home.packages.

        ''
      )

      # ── late tail (order 2000) ───────────────────────────────────────────
      # Everything here MUST run after every other initExtra contributor.
      # Two things force that:
      #   - wezterm's shell integration sources its own bash-preexec copy and
      #     resets preexec_functions, dropping earlier appends;
      #   - starship's init is mkOrder 1900, and flyline keybindings should be
      #     registered once the rest of the shell is fully assembled.
      (lib.mkOrder 2000 ''
          # you-should-use: registered here so wezterm cannot clobber it.
          if [[ -n ''${preexec_functions+x} ]] && declare -F __ysu_check >/dev/null; then
            preexec_functions+=(__ysu_check)
          fi

        # ── flyline keybindings ──────────────────────────────────────────────
        # Must come last: flyline replaces readline, so anything that used to be
        # a `bind -x` (fzf's widgets, atuin's Ctrl+R, our own line editors) has
        # to be re-registered through flyline's action vocabulary instead.
        if __flyline_loaded; then
          # Abbreviation expansion on Space, and the sudo toggle. Alt+s rather
          # than zsh's Esc-Esc: flyline treats Esc as its own dismiss key.
          flyline key bind Space 'always=runBashCommand(__abbr_expand)' 2>/dev/null || true
          flyline key bind Alt+s 'always=runBashCommand(__sudo_toggle)' 2>/dev/null || true

          # atuin owns history search; flyline's own Ctrl+R is superseded.
          if command -v atuin >/dev/null 2>&1; then
            flyline key bind Ctrl+r 'always=runBashCommand(__atuin_widget_run)+submitOrNewline' 2>/dev/null || true
            flyline key bind Up 'editingBufferMode+cursorOnFirstLine=runBashCommand("__atuin_history --shell-up-key-binding --keymap-mode=emacs")+submitOrNewline' 2>/dev/null || true
          fi

          # fzf file/dir widgets, re-bound through flyline.
          flyline_fzf_cd() {
            local cmd
            cmd=$(__fzf_cd__) && READLINE_LINE="$cmd" READLINE_POINT=''${#cmd}
          }
          flyline key bind Ctrl+t 'always=runBashCommand(fzf-file-widget)' 2>/dev/null || true
          flyline key bind Alt+c  'always=runBashCommand(flyline_fzf_cd)+submitOrNewline' 2>/dev/null || true

          # tmux-sessionizer, was `bindkey -s ^f` in zsh.
          flyline key bind Ctrl+f 'always=clearBuffer+insertString(tmux-sessionizer)+submitOrNewline' 2>/dev/null || true
        fi
      '')
    ];
  };
}
