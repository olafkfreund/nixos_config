{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  options,
  ...
}:
with lib; let
  cfg = config.ai.ollama;
in {
  options.ai.ollama = {
    enable = mkEnableOption {
      default = false;
      description = "Enable the OLLAMA service";
    };
  };
  config = mkIf cfg.enable {
    services.ollama = {
      enable = true;
      acceleration = "cuda";
      host = "0.0.0.0";
      package = pkgs-unstable.ollama-cuda;
      loadModels = [
        "deepseek-r1:14b"
        "deepseek-coder-v2"
      ];
      user = "ollama";
    };

    services.open-webui = {
      enable = true;
      host = "0.0.0.0";
      port = 8080;
      package = pkgs-unstable.open-webui;
      environment = {
        OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
        WEBUI_AUTH = "False";
      };
    };
    environment.systemPackages = [
      pkgs-unstable.alpaca
    ];
  };
}
