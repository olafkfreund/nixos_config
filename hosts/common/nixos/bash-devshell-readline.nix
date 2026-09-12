{ lib, pkgs, ... }:
# Hand an interactive shell to a bash that can actually be one.
#
# nixpkgs ships two builds: bashInteractive, and the plain `bash`, built
# without readline. `nix develop` and devenv put the plain one first on PATH,
# so typing `bash` inside a project shell gets a shell with no `bind` and no
# `complete` builtin, no progcomp/dirspell shopts, and no interpretation of
# the \[ \] non-printing markers in PS1 — the prompt renders them literally.
# Every rc that follows then errors its way down the screen: Omarchy's
# `bind -f inputrc`, bash-completion, our own line-editor bindings.
#
# This has to live in /etc/bashrc rather than in ~/.bashrc: bash reads the
# system file first, and Omarchy's rc is sourced from there, so a guard in the
# user file arrives several errors too late. mkBefore puts it ahead of that
# source line — verified against the generated /etc/bashrc, not assumed.
#
# Re-exec rather than stub the missing builtins: stubbing silences the errors
# and still leaves a shell with no history search, no completion and a broken
# prompt. `exec` keeps the project environment — same PATH, same variables,
# same directory — and swaps only the interpreter.
#
# The loop guard is the marker variable, not the readline test: if the target
# ever lacked readline too, the test alone would exec forever.
{
  programs.bash.interactiveShellInit = lib.mkBefore ''
    if [ -z "''${__NIXOS_BASH_READLINE_REEXEC:-}" ] && ! type -t bind >/dev/null 2>&1; then
      export __NIXOS_BASH_READLINE_REEXEC=1
      if shopt -q login_shell; then
        exec ${pkgs.bashInteractive}/bin/bash -l
      else
        exec ${pkgs.bashInteractive}/bin/bash
      fi
    fi
  '';
}
