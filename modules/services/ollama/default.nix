{
  config,
  lib,
  pkgs,
  pkgs-stable,
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
      # acceleration = "cuda";
      package = pkgs.ollama-cuda;
      loadModels = ["deepseek-coder-v2" "llama3.1"];
      user = "ollama";
    };

    services.open-webui = {
      enable = true;
      host = "0.0.0.0";
      port = 8080;
      package = pkgs-stable.open-webui;
      environment = {
        OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
        WEBUI_AUTH = "False";
      };
    };
  };
}
