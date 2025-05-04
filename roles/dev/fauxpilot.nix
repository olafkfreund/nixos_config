{
  config,
  pkgs,
  ...
}: {
  networking.firewall.allowedTCPPorts = [
    8000
    8001
    8002
  ];

  # Enable nvidia support for podman
  hardware.opengl.driSupport32Bit = true;
  virtualisation.podman = {
    enable = true;
    enableNvidia = true;
  };

  system.activationScripts.mkFauxpilotNet = ''
    if ! ${pkgs.podman}/bin/podman network exists fauxpilot; then
      echo "Creating 'fauxpilot' network for Podman..."
      ${pkgs.podman}/bin/podman network create fauxpilot
    else
      echo "'fauxpilot' network already exists. Continuing..."
    fi
  '';

  system.activationScripts.buildFauxpilot = ''
    mkdir -p /opt/fauxpilot/
    if [[ ! -d /opt/fauxpilot/src ]]; then
      echo "Cloning fauxpilot repository..."
      ${pkgs.git}/bin/git clone https://github.com/fauxpilot/fauxpilot.git /opt/fauxpilot/src
    else
      echo "Updating fauxpilot repository..."
      ${pkgs.git}/bin/git -C /opt/fauxpilot/src pull origin main
    fi

    echo "Building fauxpilot image..."
    ${pkgs.podman}/bin/podman build -t local/heywoodlh/fauxpilot:latest /opt/fauxpilot/src -f /opt/fauxpilot/src/triton.Dockerfile
  '';

  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      fauxpilot = {
        image = "local/heywoodlh/fauxpilot:latest";
        autoStart = true;
        ports = [
          "8000-8002:8000-8002"
        ];
        volumes = [
          "/opt/fauxpilot/model:/model"
          "/opt/fauxpilot/cache:/root/.cache/huggingface"
          "/etc/localtime:/etc/localtime:ro"
        ];
        dependsOn = ["copilot-proxy"];
        extraOptions = [
          "--network=fauxpilot"
          "--device=nvidia.com/gpu=all"
        ];
        cmd = [
          "mpirun"
          "-n"
          "1"
          "--allow-run-as-root"
          "/opt/tritonserver/bin/tritonserver"
          "--model-repository=/model"
        ];
        environment = {
          NUM_GPUS = "1";
          GPUS = "0";
          CUDA_VISIBLE_DEVICES = "0";
        };
      };
      copilot-proxy = {
        image = "docker.io/heywoodlh/copilot-proxy:latest";
        autoStart = true;
        ports = [
          "5000:5000"
        ];
        extraOptions = [
          "--network=fauxpilot"
        ];
        cmd = [
          "uvicorn"
          "app:app"
          "--host"
          "0.0.0.0"
          "--port"
          "5000"
        ];
      };
    };
  };
}
