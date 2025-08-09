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
    coreTools = mkEnableOption "Core shared tools (curl, jq, bc, python3, vim, git)";
    monitoringTools = mkEnableOption "Core monitoring tools (requires coreTools)";
    extendedMonitoringTools = mkEnableOption "Extended monitoring tools with network utilities";
    networkTools = mkEnableOption "Network analysis tools";
    basicDevTools = mkEnableOption "Basic development tools (wget, requires coreTools)";
    containerDevTools = mkEnableOption "Container/K8s development tools";
    extendedDevTools = mkEnableOption "Extended development environment tools";
    scriptTools = mkEnableOption "Script processing dependencies (requires coreTools)";
    systemScriptTools = mkEnableOption "System administration script tools";
  };

  config = mkMerge [
    # Core tools - install these first to avoid collisions
    (mkIf config.features.packages.coreTools {
      environment.systemPackages = commonDeps.coreTools;
    })

    # Additional tools that depend on or extend core tools
    (mkIf config.features.packages.monitoringTools {
      environment.systemPackages = commonDeps.monitoringTools;
      # Automatically enable core tools dependency
      features.packages.coreTools = mkDefault true;
    })
    (mkIf config.features.packages.extendedMonitoringTools {
      environment.systemPackages = commonDeps.extendedMonitoringTools;
    })
    (mkIf config.features.packages.networkTools {
      environment.systemPackages = commonDeps.networkTools;
    })
    (mkIf config.features.packages.basicDevTools {
      environment.systemPackages = commonDeps.basicDevTools;
      # Automatically enable core tools dependency
      features.packages.coreTools = mkDefault true;
    })
    (mkIf config.features.packages.containerDevTools {
      environment.systemPackages = commonDeps.containerDevTools;
    })
    (mkIf config.features.packages.extendedDevTools {
      environment.systemPackages = commonDeps.extendedDevTools;
    })
    (mkIf config.features.packages.scriptTools {
      environment.systemPackages = commonDeps.scriptTools;
      # Automatically enable core tools dependency
      features.packages.coreTools = mkDefault true;
    })
    (mkIf config.features.packages.systemScriptTools {
      environment.systemPackages = commonDeps.systemScriptTools;
    })
  ];
}
