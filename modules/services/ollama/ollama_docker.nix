{ config, pkgs, ... }:

{
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      ollama = {
        image = "docker.io/ollama/ollama:0.1.26";
        autoStart = true;
        extraOptions = [
          "--tty"
          "--network=host"
        ];
        volumes = [
          "/opt/ollama:/root/.ollama"
        ];
      };
      ollama-webui = {
        image = "ghcr.io/open-webui/open-webui:git-a481255"; # Feb 22, 2024
        autoStart = true;
        environment = {
          OLLAMA_API_BASE_URL = "http://localhost:11434/api";
          OLLAMA_WEBUI_PORT = "18080";
          WEBUI_SECRET_KEY= "";
          SCARF_NO_ANALYTICS = "true";
          DO_NOT_TRACK = "true";
        };
        extraOptions = [
          "--network=host"
          "--add-host=host.docker.internal:host-gateway"
        ];
        volumes = [
          "/opt/open-webui:/app/backend/data"
        ];
        dependsOn = [ "ollama" ];
      };
    };
  };
}
