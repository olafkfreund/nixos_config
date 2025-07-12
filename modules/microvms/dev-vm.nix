# Development MicroVM Configuration
{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.features.microvms;
in {
  config = mkIf (cfg.enable && cfg.dev-vm.enable) {
    # Development VM systemd service
    systemd.services.microvm-dev = {
      description = "Development MicroVM";
      wantedBy = [];  # Manual start only
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "forking";
        User = "root";
        Group = "microvm";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      
      script = ''
        # Create persistent storage if not exists
        mkdir -p ${cfg.storageRoot}/dev-vm/projects
        mkdir -p ${cfg.storageRoot}/dev-vm/home
        
        # Create shared directory
        mkdir -p ${cfg.sharedRoot}/dev-vm
        
        echo "Development MicroVM service started"
      '';
      
      preStop = ''
        echo "Stopping Development MicroVM"
      '';
    };
    
    # Development VM runner script
    environment.systemPackages = with pkgs; [
      (writeScriptBin "start-dev-vm" ''
        #!/bin/bash
        echo "Starting Development MicroVM..."
        systemctl start microvm-dev
        if [ $? -eq 0 ]; then
          echo "Development MicroVM started successfully"
          echo "SSH: ssh dev@localhost -p 2222"
          echo "Projects: ${cfg.storageRoot}/dev-vm/projects"
        else
          echo "Failed to start Development MicroVM"
          exit 1
        fi
      '')
      
      (writeScriptBin "stop-dev-vm" ''
        #!/bin/bash
        echo "Stopping Development MicroVM..."
        systemctl stop microvm-dev
        echo "Development MicroVM stopped"
      '')
    ];
  };
}