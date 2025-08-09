# Dependency set management with feature flags
{ config
, lib
, pkgs
, ...
}:
with lib; let
  commonDeps = import ./common-deps.nix { inherit pkgs; };
in
{
  options.features.packages = {
    monitoringTools = mkEnableOption "Core monitoring tools (curl, jq, bc, python3)";
    extendedMonitoringTools = mkEnableOption "Extended monitoring tools with network utilities";
    networkTools = mkEnableOption "Network analysis tools";
    basicDevTools = mkEnableOption "Basic development tools (vim, git, curl, wget)";
    containerDevTools = mkEnableOption "Container/K8s development tools";
    extendedDevTools = mkEnableOption "Extended development environment tools";
    scriptTools = mkEnableOption "Script processing dependencies";
    systemScriptTools = mkEnableOption "System administration script tools";
  };

  config = mkMerge [
    (mkIf config.features.packages.monitoringTools {
      environment.systemPackages = commonDeps.monitoringTools;
    })
    (mkIf config.features.packages.extendedMonitoringTools {
      environment.systemPackages = commonDeps.extendedMonitoringTools;
    })
    (mkIf config.features.packages.networkTools {
      environment.systemPackages = commonDeps.networkTools;
    })
    (mkIf config.features.packages.basicDevTools {
      environment.systemPackages = commonDeps.basicDevTools;
    })
    (mkIf config.features.packages.containerDevTools {
      environment.systemPackages = commonDeps.containerDevTools;
    })
    (mkIf config.features.packages.extendedDevTools {
      environment.systemPackages = commonDeps.extendedDevTools;
    })
    (mkIf config.features.packages.scriptTools {
      environment.systemPackages = commonDeps.scriptTools;
    })
    (mkIf config.features.packages.systemScriptTools {
      environment.systemPackages = commonDeps.systemScriptTools;
    })
  ];
}
