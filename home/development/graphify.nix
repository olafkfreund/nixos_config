{ config, lib, pkgs, ... }:
let
  dev = config.features.development;
  bin = "${config.home.profileDirectory}/bin";
in
{
  config = lib.mkIf (dev.enable && dev.graphify) {
    home.packages = [ pkgs.customPkgs.graphify ];
    programs.git.ignores = [ "graphify-out/" ];

    # Never `exit` in an activation entry: they are concatenated into one script.
    home.activation.codexGraphifyMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -x "${bin}/codex" ] && ! "${bin}/codex" mcp get graphify >/dev/null 2>&1; then
        $DRY_RUN_CMD "${bin}/codex" mcp add graphify -- "${bin}/graphify-mcp"
      fi
    '';
  };
}
