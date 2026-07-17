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
    ./antigravity-cli.nix
    ./providers/default.nix
    ./mcp-servers.nix
  ];

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.yai
    ]
    ++ optionals cfg.claude-desktop [
      # Official Claude Desktop (Anthropic Linux beta). Cowork/Local Agent Mode
      # runs in a QEMU microVM; its runtime (qemu/ovmf/virtiofsd/bubblewrap) is
      # carried in the package's own wrapper PATH — see pkgs/claude-desktop-beta.
      # KVM acceleration for Cowork needs /dev/kvm (virtualisation + kvm group).
      pkgs.customPkgs.claude-desktop
    ];
  };
}
