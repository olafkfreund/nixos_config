# Consolidated envvar.nix - used by all hosts
{ lib, ... }:
let
  sharedVars = import ../shared-variables.nix;
in
{
  environment.sessionVariables = sharedVars.baseEnvironment // {
    QT_QPA_PLATFORMTHEME = lib.mkForce "qt5ct";
    # Skip git's optional index-refresh lock so background tools (editors,
    # MCP git daemons running `git status`/`diff`) don't grab .git/index.lock
    # and race a concurrent `git commit` (e.g. pre-commit's write-tree).
    # Required locks (commit/add/write-tree) are unaffected.
    GIT_OPTIONAL_LOCKS = "0";
  };
}
