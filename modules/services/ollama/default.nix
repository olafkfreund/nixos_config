{ pkgs, ... }: {

  # Enable the Ollama service, which is a tool for generating text based on input
  # It uses a machine learning model to generate responses
  services.ollama = {

    # Enable the Ollama service
    enable = true;

    # The Ollama package to use
    package = pkgs.ollama;

    # The type of hardware acceleration to use. We're using CUDA for our GPU
    # acceleration = "cuda";

    # The models to load. These are the specific models that Ollama will use to generate responses
    loadModels = [ "deepseek-coder-v2" "llama3.1" ];

    # The user that the Ollama service will run as
    user = "ollama";
  };

  # Enable the Next.js Ollama LLM UI service, which is a web UI for the Ollama service
  services.open-webui = {
    enable = true;
    package = pkgs.open-webui;
    environment = 
      {
        OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
        WEBUI_AUTH = "False";
      };
  };
}
