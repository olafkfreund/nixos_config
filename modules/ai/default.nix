{ config
, lib
, pkgs
, ...
}:
with lib;
let
  cfg = config.features.ai;
in
{
  imports = [
    ./gemini-cli.nix
    ./providers/default.nix
    ./mcp-servers.nix
  ];

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.yai
    ]
    ++ optionals cfg.claude-desktop [ pkgs.customPkgs.claude-desktop ];
  };
}
