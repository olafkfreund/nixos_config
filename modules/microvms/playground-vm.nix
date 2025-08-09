# Playground MicroVM Configuration
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.features.microvms;
in
{
  config = mkIf (cfg.enable && cfg.playground-vm.enable) {
    # Playground VM systemd service
    systemd.services.microvm-playground = {
      description = "Playground MicroVM";
      wantedBy = [ ]; # Manual start only
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
        mkdir -p ${cfg.storageRoot}/playground-vm/experiments
        mkdir -p ${cfg.storageRoot}/playground-vm/sandbox

        # Create shared directory
        mkdir -p ${cfg.sharedRoot}/playground-vm

        echo "Playground MicroVM service started"
      '';

      preStop = ''
        echo "Stopping Playground MicroVM"
      '';
    };

    # Playground VM runner script
    environment.systemPackages = with pkgs; [
      (writeScriptBin "start-playground-vm" ''
        #!/bin/bash
        echo "Starting Playground MicroVM..."
        systemctl start microvm-playground
        if [ $? -eq 0 ]; then
          echo "Playground MicroVM started successfully"
          echo "SSH: ssh root@localhost -p 2224"
          echo "Experiments: ${cfg.storageRoot}/playground-vm/experiments"
        else
          echo "Failed to start Playground MicroVM"
          exit 1
        fi
      '')

      (writeScriptBin "stop-playground-vm" ''
        #!/bin/bash
        echo "Stopping Playground MicroVM..."
        systemctl stop microvm-playground
        echo "Playground MicroVM stopped"
      '')

      (writeScriptBin "destroy-playground-vm" ''
        #!/bin/bash
        echo "⚠️  This will destroy all playground data!"
        read -p "Type 'yes' to confirm: " confirm
        if [ "$confirm" = "yes" ]; then
          systemctl stop microvm-playground
          rm -rf ${cfg.storageRoot}/playground-vm/*
          echo "Playground MicroVM destroyed"
        else
          echo "Cancelled"
        fi
      '')
    ];
  };
}
