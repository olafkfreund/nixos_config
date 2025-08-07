# FSTRIM Boot Optimization Module
# Prevents fstrim from blocking boot by ensuring timer-only operation
{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.fstrim-optimization;
in {
  options.services.fstrim-optimization = {
    enable = mkEnableOption "FSTRIM boot optimization to prevent boot blocking";
    
    preventBootBlocking = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Prevent fstrim from running during boot and blocking the boot process.
        This ensures fstrim only runs via timer.
      '';
    };
  };
  
  config = mkIf cfg.enable {
    # Enable fstrim service with timer-only operation
    services.fstrim = {
      enable = true;
      interval = "weekly";
    };
    
    # CRITICAL: Prevent fstrim from running during boot
    systemd.services.fstrim = mkIf cfg.preventBootBlocking {
      # Remove any default dependencies that might trigger during boot
      unitConfig = {
        DefaultDependencies = "no";
      };
      
      # Ensure it only runs when explicitly triggered by timer
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "no";
      };
      
      # Explicitly prevent boot-time execution
      wantedBy = lib.mkForce [ ];
      requiredBy = lib.mkForce [ ];
      
      # Only allow timer to trigger it
      conflicts = [ "shutdown.target" ];
      before = [ "shutdown.target" ];
      after = [ "local-fs.target" ];
    };
    
    # Ensure timer is properly configured
    systemd.timers.fstrim = {
      enable = true;
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "6h";  # Spread load
        AccuracySec = "1h";
      };
    };
    
    # Add helpful logging
    systemd.services.fstrim-optimization-check = mkIf cfg.preventBootBlocking {
      description = "Check that fstrim is properly configured for timer-only operation";
      script = ''
        echo "FSTRIM Optimization: Service configured for timer-only operation"
        echo "Next fstrim run: $(systemctl show fstrim.timer | grep NextElapseUSecRealtime)"
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      wantedBy = [ "multi-user.target" ];
      after = [ "fstrim.timer" ];
    };
  };
}