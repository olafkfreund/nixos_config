# npm/npx global prefix on NixOS.
#
# nixpkgs splits npm out of node: the `npm` on PATH is `npm-cli.js` from
# `nodejs-slim-<ver>-npm`, and its shebang points at `nodejs-slim`, not at the
# full `nodejs` derivation. npm derives its global prefix from `process.execPath`,
# so it lands on the nodejs-slim store path — which ships bin/, include/ and
# share/ but no lib/. Every `npm install -g` and every `npx <pkg>` that has to
# fetch then dies with:
#
#   npm error enoent ENOENT: no such file or directory,
#   lstat '/nix/store/...-nodejs-slim-20.20.2/lib'
#
# The store path is also read-only, so even a present lib/ would not help.
# Point the prefix at a writable directory in $HOME instead. That is the right
# answer regardless of the shebang bug: global npm packages are mutable state
# and have no business inside the store.
{ config, lib, ... }:
let
  prefix = "${config.home.homeDirectory}/.npm-global";
in
{
  home.sessionVariables.NPM_CONFIG_PREFIX = prefix;

  # npx invoked via an absolute path (${pkgs.nodejs}/bin/npx, as the MCP server
  # configs do) never sources the shell profile, so the session variable alone
  # is not enough — npm reads ~/.npmrc unconditionally.
  # force: razer already carries a hand-rolled ~/.npmrc with the same two
  # settings. backupFileExtension is not set repo-wide, so without force the
  # activation aborts with "Existing file ... is in the way" on any host that
  # has one — and p620 has none, so it would pass locally and break remotely.
  home.file.".npmrc" = {
    force = true;
    text = ''
      registry=https://registry.npmjs.org/
      prefix=${prefix}
    '';
  };

  home.sessionPath = [ "${prefix}/bin" ];

  # npm requires <prefix>/lib to already exist; it will not create it, and
  # fails with the same ENOENT if it is missing.
  home.activation.npmGlobalPrefix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArg "${prefix}/lib"} ${lib.escapeShellArg "${prefix}/bin"}
  '';
}
