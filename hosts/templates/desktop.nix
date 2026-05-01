{ profile ? "workstation" }:
{ lib, ... }:
{
  imports = [
    ../../modules/core.nix
    ../../modules/development.nix
    ../../modules/desktop.nix
    ../../modules/virtualization.nix
    ../../modules/performance.nix
    ../../modules/email.nix
    ../../modules/cloud.nix
    ../../modules/programs.nix
    ../../modules/common/ai-defaults.nix
    ../../modules/windows/winboat.nix
  ];

  config = lib.mkMerge [
    {
      aiDefaults.enable = lib.mkDefault true;
      services.openssh.enable = lib.mkDefault true;
    }
    (lib.mkIf (profile == "laptop") {
      services.thermald.enable = lib.mkDefault true;
      powerManagement = {
        enable = lib.mkDefault true;
        cpuFreqGovernor = lib.mkDefault "powersave";
      };
    })
  ];
}
