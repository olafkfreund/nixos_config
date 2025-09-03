{ pkgs, ... }: {
  networking.firewall.allowedTCPPorts = [
    3000
  ];

  system.activationScripts.mkCoderNet = ''
    if ! ${pkgs.podman}/bin/podman network exists coder; then
      echo "Creating 'coder' network for Podman..."
      ${pkgs.podman}/bin/podman network create coder
    else
      echo "'coder' network already exists. Continuing..."
    fi
  '';

  # Ensure directories exist
  system.activationScripts.mkCoderDirs = ''
    mkdir -p /opt/coder/db /opt/coder/kube
    chmod 755 /opt/coder
    chmod 700 /opt/coder/db /opt/coder/kube
  '';

  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      coder = {
        image = "ghcr.io/coder/coder:v0.24.0";
        autoStart = true;
        ports = [
          "3000:3000"
        ];
        volumes = [
          "/opt/coder/kube:/home/coder/.kube"
          "/etc/localtime:/etc/localtime:ro"
        ];
        extraOptions = [
          "--network=coder"
        ];
        environmentFiles = [
          "/opt/coder/environment"
        ];
        dependsOn = [ "coder-db" ];
      };
      coder-db = {
        image = "docker.io/postgres:14.2";
        autoStart = true;
        extraOptions = [
          "--network=coder"
        ];
        environmentFiles = [
          "/opt/coder/environment"
        ];
        volumes = [
          "/opt/coder/db:/var/lib/postgresql/data"
          "/etc/localtime:/etc/localtime:ro"
        ];
      };
    };
  };
}
