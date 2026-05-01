{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf optionals;
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
    ++ optionals cfg.claude-desktop [
      pkgs.customPkgs.claude-desktop
      # Claude Desktop's Cowork/Local Agent Mode runtime deps (aaddrick --doctor)
      pkgs.bubblewrap # namespace sandbox (default backend)
      pkgs.socat # Unix-socket relay the cowork daemon uses for IPC
    ];
  };
}
