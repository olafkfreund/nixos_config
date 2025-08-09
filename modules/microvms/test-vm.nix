# Testing MicroVM Configuration
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.features.microvms;
in
{
  config = mkIf (cfg.enable && cfg.test-vm.enable) {
    # Testing VM systemd service
    systemd.services.microvm-test = {
      description = "Testing MicroVM";
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
        mkdir -p ${cfg.storageRoot}/test-vm/data
        mkdir -p ${cfg.storageRoot}/test-vm/results

        # Create shared directory
        mkdir -p ${cfg.sharedRoot}/test-vm

        echo "Testing MicroVM service started"
      '';

      preStop = ''
        echo "Stopping Testing MicroVM"
      '';
    };

    # Testing VM runner script
    environment.systemPackages = with pkgs; [
      (writeScriptBin "start-test-vm" ''
        #!/bin/bash
        echo "Starting Testing MicroVM..."
        systemctl start microvm-test
        if [ $? -eq 0 ]; then
          echo "Testing MicroVM started successfully"
          echo "SSH: ssh test@localhost -p 2223"
          echo "Data: ${cfg.storageRoot}/test-vm/data"
        else
          echo "Failed to start Testing MicroVM"
          exit 1
        fi
      '')

      (writeScriptBin "stop-test-vm" ''
        #!/bin/bash
        echo "Stopping Testing MicroVM..."
        systemctl stop microvm-test
        echo "Testing MicroVM stopped"
      '')

      (writeScriptBin "reset-test-vm" ''
        #!/bin/bash
        echo "Resetting Testing MicroVM..."
        systemctl stop microvm-test
        rm -rf ${cfg.storageRoot}/test-vm/data/*
        echo "Testing MicroVM reset complete"
      '')
    ];
  };
}
